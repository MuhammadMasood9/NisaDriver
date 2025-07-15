import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui; // Needed for map camera bounds and image codec

import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
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
    final driver = await FireStoreUtils.getDriverProfile(
        FireStoreUtils.getCurrentUid() ?? '');
    if (driver != null) {
      driverModel.value = driver;
    }
  }

  /// Fetches scheduled orders from Firestore and filters them to show only
  /// those available to the current driver.
  Future<void> fetchScheduledOrders() async {
    try {
      String currentDriverId = FireStoreUtils.getCurrentUid() ?? '';
      if (currentDriverId.isEmpty) {
        scheduledOrdersList.clear();
        return;
      }
      List<OrderModel> orders =
          await FireStoreUtils.getScheduledOrders(currentDriverId);

      // We still need to filter out rides the driver has explicitly rejected.
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

  /// Handles the logic for a driver accepting a specific scheduled ride.
  Future<void> acceptRide(OrderModel orderToAccept) async {
    // Renamed for clarity
    // 1. Check if driver's wallet has sufficient funds
    if (double.parse(driverModel.value.walletAmount.toString()) <
        double.parse(Constant.minimumDepositToRideAccept ?? '0.0')) {
      ShowToastDialog.showToast(
        "You need at least ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept)} in your wallet to accept this order."
            .tr,
      );
      return;
    }

    ShowToastDialog.showLoader("Accepting Ride...".tr);

    try {
      String driverId = FireStoreUtils.getCurrentUid() ?? '';

      // 2. Prepare the data to update in Firestore
      Map<String, dynamic> updatedData = {
        'status':
            Constant.rideActive, // Update status to 'active' or 'accepted'
        'driverId': driverId,
        'driver': driverModel.value.toJson(), // Attach driver's details
      };

      // 3. Update the specific order document using its unique ID
      await FireStoreUtils.fireStore
          .collection(CollectionName.orders)
          .doc(orderToAccept.id) // <--- Uses the ID of the specific order
          .update(updatedData);

      // 4. Notify the customer
      var customer =
          await FireStoreUtils.getCustomer(orderToAccept.userId.toString());
      if (customer != null && customer.fcmToken != null) {
        await SendNotification.sendOneNotification(
          token: customer.fcmToken!,
          title: 'Ride Secured!'.tr,
          body: 'Your driver is assigned for the scheduled ride.'.tr,
          payload: {'orderId': orderToAccept.id},
        );
      }

      // 5. Update the local list to remove the accepted ride from the screen instantly
      scheduledOrdersList.removeWhere((o) => o.id == orderToAccept.id);
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

  void _showRideDetailsBottomSheet(BuildContext context, OrderModel orderModel,
      ScheduledOrderController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RideDetailBottomSheet(orderModel: orderModel),
    ).then((accepted) {
      // If the bottom sheet returns true, it means "Accept Ride" was pressed
      if (accepted != null && accepted == true) {
        // The controller's acceptRide function is called with the specific orderModel
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
          backgroundColor: AppColors.grey50,
          body: SafeArea(
            child: controller.isLoading.value
                ? Constant.loader(context)
                : RefreshIndicator(
                    onRefresh: () => controller.fetchInitialData(),
                    color: AppColors.primary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: controller.scheduledOrdersList.isEmpty
                              ? _buildEmptyState(context, controller)
                              : ListView.builder(
                                  itemCount:
                                      controller.scheduledOrdersList.length,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 6),
                                  itemBuilder: (context, index) {
                                    // Each card is built with a specific 'order' object
                                    OrderModel order =
                                        controller.scheduledOrdersList[index];
                                    return _buildScheduledRideCard(
                                        context, order, controller);
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

  Widget _buildEmptyState(
      BuildContext context, ScheduledOrderController controller) {
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
                        side: BorderSide(
                            color: AppColors.primary.withOpacity(0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
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

  // NEW: A consistent container for all ride cards.
  Widget _buildRideCardContainer({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      );

  // NEW: Redesigned card to match modern styling.
  Widget _buildScheduledRideCard(BuildContext context, OrderModel order,
      ScheduledOrderController controller) {
    final rideDate = order.createdDate?.toDate();
    final formattedDate = rideDate != null
        ? DateFormat('E, d MMM yyyy').format(rideDate)
        : 'Date not available';
    final formattedTime =
        rideDate != null ? DateFormat('h:mm a').format(rideDate) : 'Time n/a';

    return InkWell(
        onTap: () => _showRideDetailsBottomSheet(context, order, controller),
        borderRadius: BorderRadius.circular(12),
        child: _buildRideCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Date and Time
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '$formattedDate at $formattedTime',
                    style: AppTypography.boldLabel(context)
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              const Divider(height: 20, thickness: 1),

              // Pickup point and Payment row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_circle_down,
                      size: 22, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.sourceLocationName.toString(),
                            style: AppTypography.boldLabel(context).copyWith(
                                fontWeight: FontWeight.w500, height: 1.3)),
                        Text("Pickup point".tr,
                            style: AppTypography.caption(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      Constant.amountShow(amount: order.finalRate.toString()),
                      style: AppTypography.boldLabel(context)
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              // Dotted line connecting the points
              Row(
                children: [
                  Container(
                    width: 22,
                    alignment: Alignment.center,
                    child: Container(
                        height: 20, width: 1.5, color: AppColors.grey200),
                  ),
                  Expanded(child: Container()),
                ],
              ),
              // Destination and Distance row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 22, color: Colors.black),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.destinationLocationName.toString(),
                            style: AppTypography.boldLabel(context).copyWith(
                                fontWeight: FontWeight.w500, height: 1.3)),
                        Text("Destination".tr,
                            style: AppTypography.caption(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Distance".tr,
                          style: AppTypography.caption(context)),
                      Text(
                        "${(double.parse(order.distance.toString())).toStringAsFixed(Constant.currencyModel!.decimalDigits!)} ${order.distanceType}",
                        style: AppTypography.boldLabel(context),
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
        ));
  }
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~ RIDE DETAIL BOTTOM SHEET WIDGET ~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class RideDetailBottomSheet extends StatefulWidget {
  final OrderModel orderModel;
  const RideDetailBottomSheet({Key? key, required this.orderModel})
      : super(key: key);

  @override
  State<RideDetailBottomSheet> createState() => _RideDetailBottomSheetState();
}

class _RideDetailBottomSheetState extends State<RideDetailBottomSheet> {
  // TODO: IMPORTANT! Replace with your actual Google Maps API Key.
  final String _googleApiKey =
      "AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4"; // IMPORTANT

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
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<void> _setMarkersAndDrawRoute() async {
    if (widget.orderModel.sourceLocationLAtLng?.latitude == null ||
        widget.orderModel.sourceLocationLAtLng?.longitude == null ||
        widget.orderModel.destinationLocationLAtLng?.latitude == null ||
        widget.orderModel.destinationLocationLAtLng?.longitude == null) {
      if (kDebugMode)
        print('Error: Missing coordinates for source or destination');
      if (mounted) {
        setState(() {
          _routeDistance = 'Error';
          _routeDuration = 'Error';
          _isLoadingRoute = false;
        });
      }
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
      final Uint8List sourceIcon =
          await getBytesFromAsset('assets/images/green_mark.png', 30);
      final Uint8List destinationIcon =
          await getBytesFromAsset('assets/images/red_mark.png', 30);

      _markers.add(Marker(
          markerId: const MarkerId('source'),
          position: source,
          icon: BitmapDescriptor.fromBytes(sourceIcon),
          anchor: const Offset(0.5, 0.5)));

      _markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          icon: BitmapDescriptor.fromBytes(destinationIcon),
          anchor: const Offset(0.5, 0.5)));

      if (mounted) setState(() {});

      await _drawRouteAndGetDetails();
    } catch (e) {
      if (kDebugMode) print('Error setting markers: $e');
      if (mounted) {
        setState(() {
          _routeDistance = 'Error';
          _routeDuration = 'Error';
          _isLoadingRoute = false;
        });
      }
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
          final List<PointLatLng> decodedPoints =
              PolylinePoints().decodePolyline(overviewPolyline);
          final List<LatLng> routePoints = decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          if (routePoints.isNotEmpty) {
            _polylines.clear();
            _polylines.add(Polyline(
                polylineId: const PolylineId('route'),
                points: routePoints,
                color: AppColors.primary,
                width: 2,
                patterns: <PatternItem>[
                  PatternItem.dash(20),
                  PatternItem.gap(10)
                ]));
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
          String errorMessage = data['error_message'] ?? 'No route found';
          if (kDebugMode)
            print("Directions API Error: ${data['status']} - $errorMessage");
          if (mounted) {
            setState(() {
              _routeDistance = 'Route Error';
              _routeDuration = 'Route Error';
              _isLoadingRoute = false;
            });
          }
        }
      } else {
        if (kDebugMode)
          print("HTTP request failed with status: ${response.statusCode}");
        if (mounted) {
          setState(() {
            _routeDistance = 'HTTP Error';
            _routeDuration = 'HTTP Error';
            _isLoadingRoute = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching directions: $e");
      if (mounted) {
        setState(() {
          _routeDistance = 'Network Error';
          _routeDuration = 'Network Error';
          _isLoadingRoute = false;
        });
      }
    }
  }

  void _fitMapToShowRoute() {
    if (_mapController == null || _markers.length < 2) return;

    final bounds = _boundsFromLatLngList(
        _markers.map((marker) => marker.position).toList());

    Future.delayed(const Duration(milliseconds: 50), () {
      if (_mapController != null && mounted) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 40.0), // Padding
        );
      }
    });
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double minLat = list.first.latitude;
    double maxLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLng = list.first.longitude;

    for (LatLng latLng in list) {
      minLat = min(minLat, latLng.latitude);
      maxLat = max(maxLat, latLng.latitude);
      minLng = min(minLng, latLng.longitude);
      maxLng = max(maxLng, latLng.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
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
                const Divider(
                    height: 22, thickness: 1, color: AppColors.grey200),
                _buildDetailsCard(),
                const SizedBox(height: 10),
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
                      widget.orderModel.sourceLocationLAtLng!.longitude!),
                  zoom: 10,
                ),
                onMapCreated: (controller) async {
                  _mapController = controller;

                  try {
                    String style =
                        await rootBundle.loadString('assets/map_style.json');
                    _mapController?.setMapStyle(style);
                  } catch (e) {
                    debugPrint("Error loading map style: $e");
                  }
                  _fitMapToShowRoute();
                },
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                compassEnabled: false,
                mapToolbarEnabled: false,
              ),
              if (_isLoadingRoute)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDetailItem(
            'Ride Fare'.tr,
            Constant.amountShow(amount: widget.orderModel.finalRate),
            AppColors.primary,
          ),
          _buildDetailItem(
            'Distance'.tr,
            _isLoadingRoute ? '...' : _routeDistance,
            Colors.black87,
          ),
          _buildDetailItem(
            'Duration'.tr,
            _isLoadingRoute ? '...' : _routeDuration,
            Colors.black87,
          ),
          _buildDetailItem(
            'Payment'.tr,
            widget.orderModel.paymentType.toString(),
            Colors.black87,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String title, String value, Color valueColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.caption(context).copyWith(
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.appTitle(context).copyWith(
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text("Close".tr,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Passing true signals to accept the ride
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text("Accept Ride".tr,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
