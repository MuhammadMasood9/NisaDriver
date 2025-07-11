import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui; // Needed for map camera bounds and image codec

import 'package:cloud_firestore/cloud_firestore.dart' as cloud_firestore;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';


/*
  ✅ INTEGRATION STEPS (If not already done):

  1. Add this method to your `lib/utils/fire_store_utils.dart` file:
  --------------------------------------------------------------------------------
    static Future<List<OrderModel>> getScheduledOrders() async {
      List<OrderModel> rideList = [];
      try {
        cloud_firestore.QuerySnapshot<Map<String, dynamic>> rideSnapshot = await firestore
            .collection(CollectionName.orders)
            .where('isScheduledRide', isEqualTo: true)
            .where('status', isEqualTo: 'scheduled')
            .orderBy('createdDate', descending: true)
            .get();

        for (var document in rideSnapshot.docs) {
          OrderModel ride = OrderModel.fromJson(document.data());
          rideList.add(ride);
        }
      } catch (e, s) {
        if (kDebugMode) {
          print('-----------GET-SCHEDULED-ORDERS-ERROR-----------');
          print(e);
          print(s);
        }
      }
      return rideList;
    }
  --------------------------------------------------------------------------------

  2. In your `lib/controller/home_controller.dart`, add this screen to your `widgetOptions`.
  3. In your `lib/ui/home_screen.dart`, add a new navigation item for "Scheduled" rides.
*/

/// Controller for fetching and managing scheduled ride data.
class ScheduledOrderController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<OrderModel> scheduledOrdersList = <OrderModel>[].obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
  }

  /// Fetches both scheduled orders and the current driver's data in parallel.
  Future<void> fetchInitialData() async {
    isLoading.value = true;
    try {
      await Future.wait([
        fetchScheduledOrders(),
        fetchDriverData(),
      ]);
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching initial data: $e");
      }
      Get.snackbar("Error".tr, "Failed to load data.".tr);
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetches the current driver's data from Firestore.
  Future<void> fetchDriverData() async {
    final driver = await FireStoreUtils.getDriverProfile(FireStoreUtils.getCurrentUid() ?? '');
    if (driver != null) {
      driverModel.value = driver;
    }
  }

  /// Fetches scheduled orders from Firestore and filters out any rejected by the current driver.
  Future<void> fetchScheduledOrders() async {
    try {
      List<OrderModel> orders = await FireStoreUtils.getScheduledOrders();
      String currentDriverId = FireStoreUtils.getCurrentUid() ?? '';

      // Filter out orders that this driver has already rejected
      scheduledOrdersList.value = orders.where((order) {
        final rejectedIds = order.rejectedDriverId ?? [];
        return !rejectedIds.contains(currentDriverId);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching scheduled orders: $e");
      }
      Get.snackbar(
        "Error".tr,
        "Failed to load scheduled rides.".tr,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  /// Handles the logic for a driver accepting a scheduled ride.
  Future<void> acceptRide(OrderModel order) async {
    // 1. Check if driver's wallet has sufficient funds
    if (double.parse(driverModel.value.walletAmount.toString()) < double.parse(Constant.minimumDepositToRideAccept ?? '0.0')) {
      ShowToastDialog.showToast(
        "You need at least ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept)} in your wallet to accept this order.".tr,
      );
      return;
    }

    ShowToastDialog.showLoader("Accepting Ride...".tr);

    try {
      String driverId = FireStoreUtils.getCurrentUid() ?? '';

      // 2. Prepare the data to update in Firestore
      Map<String, dynamic> updatedData = {
        'status': Constant.rideActive, // Update status to 'active' or 'accepted'
        'driverId': driverId,
        'driver': driverModel.value.toJson(), // Attach driver's details
      };

      // 3. Update the order document
      await FireStoreUtils.fireStore.collection(CollectionName.orders).doc(order.id).update(updatedData);

      // 4. Notify the customer
      var customer = await FireStoreUtils.getCustomer(order.userId.toString());
      if (customer != null && customer.fcmToken != null) {
        await SendNotification.sendOneNotification(
          token: customer.fcmToken!,
          title: 'Ride Secured!'.tr,
          body: 'Your driver is assigned for the scheduled ride.'.tr,
          payload: {'orderId': order.id},
        );
      }

      // 5. Update the local list to remove the accepted ride from the screen instantly
      scheduledOrdersList.removeWhere((o) => o.id == order.id);
      scheduledOrdersList.refresh();

      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Ride Accepted! Check your active rides.".tr);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to accept ride: $e".tr);
      if (kDebugMode) {
        print("Error accepting scheduled ride: $e");
      }
    }
  }
}

/// A screen to display a list of available scheduled rides.
class ScheduledOrderScreen extends StatelessWidget {
  const ScheduledOrderScreen({Key? key}) : super(key: key);

  void _showRideDetailsBottomSheet(BuildContext context, OrderModel orderModel, ScheduledOrderController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RideDetailBottomSheet(orderModel: orderModel),
    ).then((accepted) {
      // If the bottom sheet returns true, it means "Accept Ride" was pressed
      if (accepted != null && accepted == true) {
        controller.acceptRide(orderModel);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetX<ScheduledOrderController>(
      init: ScheduledOrderController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.grey100,
          body: SafeArea(
            child: controller.isLoading.value
                ? Constant.loader(context)
                : RefreshIndicator(
                    onRefresh: () => controller.fetchInitialData(),
                    color: AppColors.primary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        Expanded(
                          child: controller.scheduledOrdersList.isEmpty
                              ? _buildEmptyState(context, controller)
                              : ListView.builder(
                                  itemCount: controller.scheduledOrdersList.length,
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                  itemBuilder: (context, index) {
                                    OrderModel order = controller.scheduledOrdersList[index];
                                    return _buildScheduledRideCard(context, order, controller);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        "Scheduled Rides".tr,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ScheduledOrderController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: constraints.maxHeight,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 24),
                  Text(
                    "No Scheduled Rides Available".tr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Check back later for new scheduled ride opportunities.".tr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => controller.fetchInitialData(),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: Text("Refresh".tr),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduledRideCard(BuildContext context, OrderModel order, ScheduledOrderController controller) {
    final rideDate = order.createdDate?.toDate();
    final formattedDate = rideDate != null ? DateFormat('E, d MMM yyyy').format(rideDate) : 'Date not available';
    final formattedTime = rideDate != null ? DateFormat('h:mm a').format(rideDate) : 'Time n/a';

    return InkWell(
      onTap: () => _showRideDetailsBottomSheet(context, order, controller),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and Time Header
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$formattedDate at $formattedTime',
                  style: AppTypography.boldLabel(context).copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const Divider(height: 16),
            // User and Fare Info
            UserView(
              userId: order.userId,
              amount: order.finalRate, // Use finalRate for scheduled rides
              distance: order.distance,
              distanceType: order.distanceType,
            ),
            const Divider(height: 12, color: AppColors.grey200),
            // Location Info
            LocationView(
              sourceLocation: order.sourceLocationName.toString(),
              destinationLocation: order.destinationLocationName.toString(),
            ),
          ],
        ),
      ),
    );
  }
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~ RIDE DETAIL BOTTOM SHEET WIDGET ~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class RideDetailBottomSheet extends StatefulWidget {
  final OrderModel orderModel;
  const RideDetailBottomSheet({Key? key, required this.orderModel}) : super(key: key);

  @override
  State<RideDetailBottomSheet> createState() => _RideDetailBottomSheetState();
}

class _RideDetailBottomSheetState extends State<RideDetailBottomSheet> {
  // TODO: IMPORTANT! Replace with your actual Google Maps API Key.
  // Make sure the "Directions API" is enabled in your Google Cloud Console.
  final String _googleApiKey = "AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4"; // <--- REPLACE THIS

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _isLoadingRoute = true;
  String _routeDistance = '...';
  String _routeDuration = '...';

  @override
  void initState() {
    super.initState();
    _setMarkersAndDrawRoute();
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  Future<void> _setMarkersAndDrawRoute() async {
    if (widget.orderModel.sourceLocationLAtLng?.latitude == null ||
        widget.orderModel.sourceLocationLAtLng?.longitude == null ||
        widget.orderModel.destinationLocationLAtLng?.latitude == null ||
        widget.orderModel.destinationLocationLAtLng?.longitude == null) {
      if (kDebugMode) print('Error: Missing coordinates for source or destination');
      if (!mounted) return;
      setState(() {
        _routeDistance = 'Error';
        _routeDuration = 'Error';
        _isLoadingRoute = false;
      });
      return;
    }

    final source = LatLng(
      widget.orderModel.sourceLocationLAtLng!.latitude!,
      widget.orderModel.sourceLocationLAtLng!.longitude!,
    );
    final destination = LatLng(
      widget.orderModel.destinationLocationLAtLng!.latitude!,
      widget.orderModel.destinationLocationLAtLng!.longitude!,
    );

    try {
      Uint8List? sourceIcon = await getBytesFromAsset('assets/images/green_mark.png', 40);
      Uint8List? destinationIcon = await getBytesFromAsset('assets/images/red_mark.png', 40);

      _markers.add(Marker(
        markerId: const MarkerId('source'),
        position: source,
        icon: BitmapDescriptor.fromBytes(sourceIcon),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ));

      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        icon: BitmapDescriptor.fromBytes(destinationIcon),
        infoWindow: const InfoWindow(title: 'Drop-off Location'),
      ));

      if (mounted) setState(() {});
      await _drawRouteAndGetDetails();
    } catch (e) {
      if (kDebugMode) print('Error setting markers or loading custom icons: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingRoute = false;
        _routeDistance = "Error";
        _routeDuration = "Error";
      });
    }
  }

  Future<void> _drawRouteAndGetDetails() async {
    final LatLng origin = LatLng(
      widget.orderModel.sourceLocationLAtLng!.latitude!,
      widget.orderModel.sourceLocationLAtLng!.longitude!,
    );
    final LatLng destination = LatLng(
      widget.orderModel.destinationLocationLAtLng!.latitude!,
      widget.orderModel.destinationLocationLAtLng!.longitude!,
    );

    String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          final overviewPolyline = route['overview_polyline']['points'];

          final List<PointLatLng> decodedPoints = PolylinePoints().decodePolyline(overviewPolyline);
          final List<LatLng> routePoints = decodedPoints.map((point) => LatLng(point.latitude, point.longitude)).toList();

          if (routePoints.isNotEmpty) {
            _polylines.add(Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: AppColors.primary,
              width: 4,
            ));
          }

          if (mounted) {
            setState(() {
              _routeDistance = leg['distance']['text'] ?? 'N/A';
              _routeDuration = leg['duration']['text'] ?? 'N/A';
              _isLoadingRoute = false;
            });
          }
          _fitMapToShowRoute();
        } else {
          if (kDebugMode) print("Directions API Error: ${data['status']} - ${data['error_message']}");
          if (mounted) setState(() => _isLoadingRoute = false);
        }
      } else {
        if (kDebugMode) print("HTTP request failed with status: ${response.statusCode}");
        if (mounted) setState(() => _isLoadingRoute = false);
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching directions: $e");
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  void _fitMapToShowRoute() {
    if (_mapController == null || _markers.isEmpty) return;
    final bounds = _boundsFromLatLngList(_markers.map((marker) => marker.position).toList());
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double minLat = list.first.latitude, maxLat = list.first.latitude;
    double minLng = list.first.longitude, maxLng = list.first.longitude;
    for (final latLng in list) {
      minLat = min(minLat, latLng.latitude);
      maxLat = max(maxLat, latLng.latitude);
      minLng = min(minLng, latLng.longitude);
      maxLng = max(maxLng, latLng.longitude);
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          _buildMapSection(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                UserView(
                  userId: widget.orderModel.userId,
                  amount: widget.orderModel.finalRate,
                  distance: widget.orderModel.distance,
                  distanceType: widget.orderModel.distanceType,
                ),
                const Divider(height: 24),
                LocationView(
                  sourceLocation: widget.orderModel.sourceLocationName.toString(),
                  destinationLocation: widget.orderModel.destinationLocationName.toString(),
                ),
                const Divider(height: 24),
                _buildRouteInfoRow(),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    widget.orderModel.sourceLocationLAtLng!.latitude!,
                    widget.orderModel.sourceLocationLAtLng!.longitude!,
                  ),
                  zoom: 12,
                ),
                onMapCreated: (controller) async {
                  _mapController = controller;
                  String style = await rootBundle.loadString('assets/map_style.json');
                  _mapController?.setMapStyle(style);
                  Future.delayed(const Duration(milliseconds: 300), () => _fitMapToShowRoute());
                },
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
              if (_isLoadingRoute)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfoRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoChip(icon: Icons.timer_outlined, label: 'ETA', value: _routeDuration),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          _buildInfoChip(icon: Icons.map_outlined, label: 'Distance', value: _routeDistance),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Text(label.tr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(value, style: AppTypography.headers(context)),
          ],
        )
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade800,
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text("Close".tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // Pop with `true` to indicate acceptance
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text("Accept Ride".tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}