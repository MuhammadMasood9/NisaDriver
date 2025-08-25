import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui; // Needed for map camera bounds and image codec

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/home_screens/order_map_screen.dart';
import 'package:driver/ui/home_screens/zone_ride_screen.dart';
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

// Enum to identify the type of ride for conditional logic
enum RideType { newRequest, scheduled, active }

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~ UNIFIED ORDER CONTROLLER ~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class NewOrderController extends GetxController {
  // Observables for UI state
  RxBool isLoading = true.obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;

  // Observables for ride lists
  RxList<OrderModel> acceptedOrdersList = <OrderModel>[].obs;
  RxList<OrderModel> scheduledOrdersList = <OrderModel>[].obs;
  RxList<OrderModel> newOrdersList = <OrderModel>[].obs;

  // Stream subscriptions
  StreamSubscription? _acceptedOrdersSubscription;
  StreamSubscription? _newOrdersSubscription;
  StreamSubscription? _locationSubscription;

  @override
  void onInit() {
    super.onInit();
    initializeAllData();

    // Listen for driver status changes
    ever(driverModel, (DriverUserModel driver) {
      if (driver.isOnline == true && driver.documentVerification == true) {
        setupStreams();
      } else {
        _acceptedOrdersSubscription?.cancel();
        _newOrdersSubscription?.cancel();
        acceptedOrdersList.clear();
        newOrdersList.clear();
      }
    });

    // Set up periodic refresh every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (driverModel.value.isOnline == true &&
          driverModel.value.documentVerification == true) {
        _refreshNewOrdersStream();
      }
    });
  }

  @override
  void onClose() {
    _acceptedOrdersSubscription?.cancel();
    _newOrdersSubscription?.cancel();
    _locationSubscription?.cancel();
    super.onClose();
  }

  Future<void> initializeAllData() async {
    isLoading.value = true;

    // Fetch initial static data
    await fetchDriverData();
    await fetchScheduledOrders();

    // Always set up streams if driver is online and verified
    if (driverModel.value.isOnline == true &&
        driverModel.value.documentVerification == true) {
      setupStreams();
    } else {
      // Clear existing streams if driver is offline or not verified
      _acceptedOrdersSubscription?.cancel();
      _newOrdersSubscription?.cancel();
      acceptedOrdersList.clear();
      newOrdersList.clear();
    }

    isLoading.value = false;
  }

  Future<void> fetchDriverData() async {
    final driver = await FireStoreUtils.getDriverProfile(
        FireStoreUtils.getCurrentUid() ?? '');
    if (driver != null) {
      driverModel.value = driver;
    }
  }

  Future<void> fetchScheduledOrders() async {
    try {
      String currentDriverId = FireStoreUtils.getCurrentUid() ?? '';
      if (currentDriverId.isEmpty) return;

      List<OrderModel> orders =
          await FireStoreUtils.getScheduledOrders(currentDriverId);
      scheduledOrdersList.value = orders.where((order) {
        final rejectedIds = order.rejectedDriverId ?? [];
        return !rejectedIds.contains(currentDriverId);
      }).toList();
    } catch (e) {
      if (kDebugMode) print("Error fetching scheduled orders: $e");
    }
  }

  void setupStreams() {
    // Cancel existing streams before creating new ones
    _acceptedOrdersSubscription?.cancel();
    _newOrdersSubscription?.cancel();

    // Stream for accepted orders
    _acceptedOrdersSubscription = FirebaseFirestore.instance
        .collection(CollectionName.orders)
        .where('acceptedDriverId',
            arrayContains: FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen((snapshot) {
      acceptedOrdersList.value =
          snapshot.docs.map((doc) => OrderModel.fromJson(doc.data())).toList();
    });

    // Stream for new orders - only if we have current location
    if (Constant.currentLocation != null) {
      _newOrdersSubscription = FireStoreUtils()
          .getOrders(driverModel.value, Constant.currentLocation?.latitude,
              Constant.currentLocation?.longitude)
          .listen((orders) {
        newOrdersList.value = orders;
      });
    } else {
      // If no location, clear the list
      newOrdersList.clear();
    }
  }

  // Method to manually refresh data
  Future<void> refreshData() async {
    await initializeAllData();
  }

  // Method to refresh new orders stream when location changes
  void _refreshNewOrdersStream() {
    if (driverModel.value.isOnline == true &&
        driverModel.value.documentVerification == true &&
        Constant.currentLocation != null) {
      _newOrdersSubscription?.cancel();
      _newOrdersSubscription = FireStoreUtils()
          .getOrders(driverModel.value, Constant.currentLocation?.latitude,
              Constant.currentLocation?.longitude)
          .listen((orders) {
        newOrdersList.value = orders;
      });
    }
  }

  Future<void> acceptScheduledRide(OrderModel orderToAccept) async {
    if (double.parse(driverModel.value.walletAmount.toString()) <
        double.parse(Constant.minimumDepositToRideAccept ?? '0.0')) {
      ShowToastDialog.showToast(
          "You need at least ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept)} in your wallet."
              .tr);
      return;
    }

    ShowToastDialog.showLoader("Accepting Ride...".tr);

    try {
      String driverId = FireStoreUtils.getCurrentUid() ?? '';
      Map<String, dynamic> updatedData = {
        'status': Constant.rideActive,
        'driverId': driverId,
        'driver': driverModel.value.toJson(),
      };

      await FireStoreUtils.fireStore
          .collection(CollectionName.orders)
          .doc(orderToAccept.id)
          .update(updatedData);

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

      scheduledOrdersList.removeWhere((o) => o.id == orderToAccept.id);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Ride Accepted! Check your active rides.".tr);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to accept ride: $e".tr);
    }
  }

  Future<void> handleTimerExpiry(String orderId) async {
    String? driverId = FireStoreUtils.getCurrentUid();
    if (driverId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(CollectionName.orders)
          .doc(orderId)
          .update({
        'acceptedDriverId': FieldValue.arrayRemove([driverId])
      });
    } catch (e) {
      debugPrint("Error updating order on timer expiry: $e");
    }
  }
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~ NEW ORDER SCREEN ~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen>
    with WidgetsBindingObserver {
  late NewOrderController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(NewOrderController());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app comes back to foreground
      controller.refreshData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.refreshData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey75,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Constant.loader(context);
          }

          if (controller.driverModel.value.isOnline == false) {
            return _buildInfoMessage("You Are Offline",
                "Go online from the dashboard to see new ride requests.",
                icon: Icons.wifi_off_rounded);
          }
          if (controller.driverModel.value.documentVerification == false) {
            return _buildInfoMessage("Documents Not Verified",
                "Please complete document verification to receive ride orders.",
                icon: Icons.description_outlined);
          }

          return RefreshIndicator(
            onRefresh: () => controller.refreshData(),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildLiveRidesNavigationCard(context),

                      // Sections for different ride types
                      _buildAcceptedOrdersSection(context, controller),
                      _buildScheduledOrdersSection(context, controller),
                      _buildNewOrdersSection(context, controller),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showRideDetailsBottomSheet(
      BuildContext context, OrderModel orderModel, RideType rideType) {
    final controller = Get.find<NewOrderController>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RideDetailBottomSheet(
        orderModel: orderModel,
        rideType: rideType,
      ),
    ).then((accepted) {
      if (accepted != null && accepted == true) {
        if (rideType == RideType.scheduled) {
          controller.acceptScheduledRide(orderModel);
        } else if (rideType == RideType.newRequest) {
          Get.to(() => const OrderMapScreen(),
              arguments: {"orderModel": orderModel.id.toString()});
        }
      }
    });
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Text(title, style: AppTypography.boldHeaders(context)),
    );
  }

  String _formatDistanceText(String? dist, String? unit) {
    final double? parsed = double.tryParse((dist ?? '').toString());
    final int decimals = Constant.currencyModel?.decimalDigits ?? 2;
    final String value = parsed != null ? parsed.toStringAsFixed(decimals) : '--';
    final String suffix = unit ?? '';
    return suffix.isNotEmpty ? '$value $suffix' : value;
  }

  Widget _buildLiveRidesNavigationCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: () => Get.to(() => const RouteMatchingScreen()),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.darkModePrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.radar, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Drive Your Way, Get Paid".tr,
                        style: AppTypography.boldHeaders(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Set your destination and we'll find passengers who need a ride along your route."
                            .tr,
                        style: AppTypography.smBoldLabel(context).copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptedOrdersSection(
      BuildContext context, NewOrderController controller) {
    if (controller.acceptedOrdersList.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, "Active Orders".tr),
        ListView.builder(
          itemCount: controller.acceptedOrdersList.length,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            OrderModel orderModel = controller.acceptedOrdersList[index];
            return InkWell(
              onTap: () => _showRideDetailsBottomSheet(
                  context, orderModel, RideType.active),
              child: OrderItemWithTimer(
                key: ValueKey("accepted-${orderModel.id}"),
                orderModel: orderModel,
                onExpired: () => controller.handleTimerExpiry(orderModel.id!),
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
          child: Divider(),
        ),
      ],
    );
  }

  Widget _buildScheduledOrdersSection(
      BuildContext context, NewOrderController controller) {
    if (controller.scheduledOrdersList.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, "Scheduled Rides".tr),
        ListView.builder(
          itemCount: controller.scheduledOrdersList.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            OrderModel orderModel = controller.scheduledOrdersList[index];
            return _buildGenericRideCard(
                context, orderModel, RideType.scheduled);
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
          child: Divider(),
        ),
      ],
    );
  }

  Widget _buildNewOrdersSection(
      BuildContext context, NewOrderController controller) {
    if (controller.newOrdersList.isEmpty) {
      // Show "All Caught Up" only if there are no other rides either
      if (controller.acceptedOrdersList.isEmpty &&
          controller.scheduledOrdersList.isEmpty) {
        return _buildInfoMessage("All Caught Up!", "No new rides found nearby.",
            icon: Icons.done_all_rounded);
      }
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, "New Ride Requests".tr),
        ListView.builder(
          itemCount: controller.newOrdersList.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            OrderModel orderModel = controller.newOrdersList[index];
            return _buildGenericRideCard(
                context, orderModel, RideType.newRequest,
                key: ValueKey("new-${orderModel.id}"));
          },
        ),
      ],
    );
  }

  Widget _buildGenericRideCard(
      BuildContext context, OrderModel order, RideType rideType,
      {Key? key}) {
    final rideDate = order.createdDate?.toDate();
    final formattedDate = rideDate != null
        ? DateFormat('E, d MMM yyyy').format(rideDate)
        : 'Date not available';
    final formattedTime =
        rideDate != null ? DateFormat('h:mm a').format(rideDate) : 'Time n/a';
    final String amount = rideType == RideType.newRequest
        ? (order.offerRate ?? '0')
        : (order.finalRate ?? '0');

    return InkWell(
        key: key,
        onTap: () => _showRideDetailsBottomSheet(context, order, rideType),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rideType == RideType.scheduled) ...[
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
              ],
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      Constant.amountShow(amount: amount),
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
                        _formatDistanceText(order.distance, order.distanceType),
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

  Widget _buildInfoMessage(String title, String subtitle, {IconData? icon}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 24),
              Text(title.tr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  )),
              const SizedBox(height: 8),
              Text(
                subtitle.tr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~ RIDE DETAIL BOTTOM SHEET WIDGET ~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class RideDetailBottomSheet extends StatefulWidget {
  final OrderModel orderModel;
  final RideType rideType;

  const RideDetailBottomSheet({
    super.key,
    required this.orderModel,
    required this.rideType,
  });

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
      if (kDebugMode) {
        print('Error: Missing coordinates for source or destination');
      }
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
          if (kDebugMode) {
            print("Directions API Error: ${data['status']} - $errorMessage");
          }
          if (mounted) {
            setState(() {
              _routeDistance = 'Route Error';
              _routeDuration = 'Route Error';
              _isLoadingRoute = false;
            });
          }
        }
      } else {
        if (kDebugMode) {
          print("HTTP request failed with status: ${response.statusCode}");
        }
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
    final String amount = widget.rideType == RideType.newRequest
        ? (widget.orderModel.offerRate ?? '0')
        : (widget.orderModel.finalRate ?? '0');

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
                  amount: amount,
                  distance: widget.orderModel.distance,
                  distanceType: widget.orderModel.distanceType,
                ),
                const Divider(
                    height: 22, thickness: 1, color: AppColors.grey200),
                _buildDetailsCard(amount),
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
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              if (widget.rideType == RideType.active)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.to(() => const OrderMapScreen(),
                            arguments: {"orderModel": widget.orderModel.id.toString()});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("Accept Ride".tr,
                          style: AppTypography.button(context)
                              .copyWith(color: AppColors.background)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(String amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        spacing: 5,
        children: [
          _buildDetailItem(
            'Ride Fare'.tr,
            Constant.amountShow(amount: amount),
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
        child: Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
          border: Border.all(color: AppColors.grey200),
          borderRadius: BorderRadius.circular(3)),
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
            style: AppTypography.boldLabel(context).copyWith(
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ));
  }

  Widget _buildActionButtons() {
    if (widget.rideType == RideType.active) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade800,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text("Close".tr,
                  style: AppTypography.button(context)
                      .copyWith(color: AppColors.grey500)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Get.to(() => const OrderMapScreen(),
                    arguments: {"orderModel": widget.orderModel.id.toString()});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text("Open Map".tr,
                  style: AppTypography.button(context)
                      .copyWith(color: AppColors.background)),
            ),
          ),
        ],
      );
    }

    // Both New and Scheduled rides have an Accept/Decline (or Close) choice
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () =>
                Navigator.pop(context), // Pops with null, won't trigger .then()
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade800,
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: Text(
                widget.rideType == RideType.newRequest
                    ? "Decline".tr
                    : "Close".tr,
                style: AppTypography.button(context)
                    .copyWith(color: AppColors.grey500)),
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
                  borderRadius: BorderRadius.circular(5)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: Text("Accept Ride".tr,
                style: AppTypography.button(context)
                    .copyWith(color: AppColors.background)),
          ),
        ),
      ],
    );
  }
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~ ORDER ITEM WITH TIMER ~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class OrderItemWithTimer extends StatefulWidget {
  final OrderModel orderModel;
  final VoidCallback onExpired;
  const OrderItemWithTimer(
      {super.key, required this.orderModel, required this.onExpired});
  @override
  State<OrderItemWithTimer> createState() => _OrderItemWithTimerState();
}

class _OrderItemWithTimerState extends State<OrderItemWithTimer> {
  final RxInt _remainingSeconds = 30.obs;
  final RxBool _isExpired = false.obs;
  Timer? _timer;
  DateTime? _expiryAt;

  @override
  void initState() {
    super.initState();
    _initTimer();
  }

  Future<void> _initTimer() async {
    try {
      final String? driverId = FireStoreUtils.getCurrentUid();
      if (driverId != null && widget.orderModel.id != null) {
        final info = await FireStoreUtils.getAcceptedOrders(
            widget.orderModel.id!, driverId);
        if (info?.acceptedRejectTime != null) {
          final start = info!.acceptedRejectTime!.toDate();
          _expiryAt = start.add(const Duration(seconds: 30));
          final now = DateTime.now();
          final int left = _expiryAt!.isAfter(now)
              ? _expiryAt!.difference(now).inSeconds
              : 0;
          _remainingSeconds.value = left;
        }
      }
    } catch (_) {}
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int next;
      if (_expiryAt != null) {
        final now = DateTime.now();
        next = _expiryAt!.isAfter(now)
            ? _expiryAt!.difference(now).inSeconds
            : 0;
      } else {
        next = _remainingSeconds.value - 1;
      }

      if (next > 0) {
        _remainingSeconds.value = next;
      } else {
        _timer?.cancel();
        if (mounted) {
          _isExpired.value = true;
        }
        widget.onExpired();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _isExpired.value
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      spreadRadius: 1,
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    )
                  ]),
              child: Column(
                children: [
                  TimerIndicator(remainingSeconds: _remainingSeconds),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
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
                                  Text(
                                      widget.orderModel.sourceLocationName
                                          .toString(),
                                      style: AppTypography.boldLabel(context)
                                          .copyWith(
                                              fontWeight: FontWeight.w500,
                                              height: 1.3)),
                                  Text("Pickup point".tr,
                                      style: AppTypography.caption(context)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 22,
                              alignment: Alignment.center,
                              child: Container(
                                  height: 20,
                                  width: 1.5,
                                  color: AppColors.grey200),
                            ),
                            Expanded(child: Container()),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on,
                                size: 22, color: Colors.black),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      widget.orderModel.destinationLocationName
                                          .toString(),
                                      style: AppTypography.boldLabel(context)
                                          .copyWith(
                                              fontWeight: FontWeight.w500,
                                              height: 1.3)),
                                  Text("Destination".tr,
                                      style: AppTypography.caption(context)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }
}

class TimerIndicator extends StatelessWidget {
  final RxInt remainingSeconds;
  const TimerIndicator({super.key, required this.remainingSeconds});
  Color _getTimerColor(int seconds) {
    if (seconds > 20) return Colors.green;
    if (seconds > 10) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      int seconds = remainingSeconds.value;
      double progress = seconds / 30.0;
      Color timerColor = _getTimerColor(seconds);

      return Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: timerColor.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Center(
              child: Text(
                'Awaiting Confirmation: $seconds s'.tr,
                style: GoogleFonts.poppins(
                  color: timerColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.transparent,
            color: timerColor,
            minHeight: 4,
          ),
        ],
      );
    });
  }
}
