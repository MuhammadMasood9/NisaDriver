import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart' as cloudFirestore;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/controller/active_order_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart' as prefix;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class OrderMapController extends GetxController {
  final Completer<GoogleMapController> mapController =
      Completer<GoogleMapController>();
  Rx<TextEditingController> enterOfferRateController =
      TextEditingController().obs;

  RxBool isLoading = true.obs;

  @override
  void onInit() {
    addMarkerSetup();
    getArgument();
    super.onInit();
  }

  @override
  void onClose() {
    ShowToastDialog.closeLoader();
    super.onClose();
  }

  // New method to animate camera to source location (same as FloatingActionButton functionality)
  Future<void> animateToSourceLocation() async {
    final GoogleMapController controller = await mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          zoom: 12,
          target: LatLng(
            orderModel.value.sourceLocationLAtLng?.latitude ??
                Constant.currentLocation?.latitude ??
                45.521563,
            orderModel.value.sourceLocationLAtLng?.longitude ??
                Constant.currentLocation?.longitude ??
                -122.677433,
          ),
        ),
      ),
    );
  }

  // In OrderMapController class

  Future<void> acceptOrder() async {
    // Prevent multiple simultaneous calls
    if (_isAcceptingRide) {
      ShowToastDialog.showToast("Please wait, processing previous request...".tr);
      return;
    }

    try {
      _isAcceptingRide = true;

      // 1. Quick validation
      if (!_validateRideAcceptance()) {
        return;
      }

      ShowToastDialog.showLoader("Accepting ride...".tr);

      // 2. Update local state immediately for better UX
      _updateLocalOrderState();

      // 3. Perform critical database update first
      await _updateOrderInDatabase();

      // 4. Send notification to customer and wait for it
      await _sendCustomerNotification();

      // 5. Navigate after notification is sent
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Ride Accepted".tr);

      // 6. Navigate to active ride tab
      _navigateToActiveRideTab();

      // 7. Perform other non-critical operations in background
      _performOtherBackgroundOperations();

    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to accept ride: $e".tr);
      if (kDebugMode) {
        print("Error accepting order: $e");
      }
      
      // Reset local state if the operation failed
      _resetLocalOrderState();
    } finally {
      _isAcceptingRide = false;
    }
  }

  // Flag to prevent multiple simultaneous calls
  bool _isAcceptingRide = false;

  // Quick validation method
  bool _validateRideAcceptance() {
    // Validate offer amount
    if (newAmount.value.isEmpty || double.tryParse(newAmount.value) == null) {
      ShowToastDialog.showToast("Please enter a valid offer amount".tr);
      return false;
    }

    double amount = double.parse(newAmount.value);
    if (amount <= 0) {
      ShowToastDialog.showToast("Please enter a valid offer amount".tr);
      return false;
    }

    // Validate wallet balance
    try {
      double walletAmount = double.parse(driverModel.value.walletAmount.toString());
      double minDeposit = double.parse(Constant.minimumDepositToRideAccept);
      if (walletAmount < minDeposit) {
        ShowToastDialog.showToast(
          "You need at least ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept)} in your wallet to accept this order."
              .tr,
        );
        return false;
      }
    } catch (e) {
      ShowToastDialog.showToast("Invalid wallet data".tr);
      return false;
    }

    // Validate order model
    if (orderModel.value.id?.isEmpty ?? true) {
      ShowToastDialog.showToast("Invalid order data".tr);
      return false;
    }

    return true;
  }

  // Update local order state immediately
  void _updateLocalOrderState() {
    orderModel.value.driverId = FireStoreUtils.getCurrentUid();
    orderModel.value.status = Constant.rideActive;
    orderModel.value.finalRate = newAmount.value;
    orderModel.value.acceptedDriverId = [FireStoreUtils.getCurrentUid()];
    orderModel.value.updateDate = cloudFirestore.Timestamp.now();
  }

  // Reset local order state on failure
  void _resetLocalOrderState() {
    orderModel.value.driverId = "";
    orderModel.value.status = "";
    orderModel.value.finalRate = "";
    orderModel.value.acceptedDriverId = [];
  }

  // Critical database update
  Future<void> _updateOrderInDatabase() async {
    Map<String, dynamic> updatedData = {
      'acceptedDriverId': [FireStoreUtils.getCurrentUid()],
      'driverId': FireStoreUtils.getCurrentUid(),
      'status': Constant.rideActive,
      'finalRate': newAmount.value,
      'updateDate': cloudFirestore.Timestamp.now(),
    };

    await FireStoreUtils.fireStore
        .collection(CollectionName.orders)
        .doc(orderModel.value.id)
        .update(updatedData);
  }

  // Perform other non-critical operations in background
  void _performOtherBackgroundOperations() {
    // Run these operations asynchronously without blocking the UI
    Future.microtask(() async {
      try {
        // Save driver acceptance details
        await _saveDriverAcceptanceDetails();
        
        // Update driver subscription
        await _updateDriverSubscription();
        
        // Notify other controllers (without excessive logging)
        _notifyRideStateChange();
        
      } catch (e) {
        if (kDebugMode) {
          print("Background operation error: $e");
        }
      }
    });
  }

  // Send notification to customer
  Future<void> _sendCustomerNotification() async {
    try {
      var customer = await FireStoreUtils.getCustomer(
          orderModel.value.userId.toString());
      if (customer?.fcmToken != null) {
        await SendNotification.sendOneNotification(
          token: customer!.fcmToken.toString(),
          title: 'Ride Accepted'.tr,
          body: 'Your ride has been accepted by the driver for ${Constant.amountShow(amount: newAmount.value)}.'.tr,
          payload: {'orderId': orderModel.value.id},
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error sending notification: $e");
      }
    }
  }

  // Save driver acceptance details
  Future<void> _saveDriverAcceptanceDetails() async {
    try {
      DriverIdAcceptReject driverIdAcceptReject = DriverIdAcceptReject(
        driverId: FireStoreUtils.getCurrentUid(),
        acceptedRejectTime: cloudFirestore.Timestamp.now(),
        offerAmount: newAmount.value,
      );
      await FireStoreUtils.acceptRide(orderModel.value, driverIdAcceptReject);
    } catch (e) {
      if (kDebugMode) {
        print("Error saving driver acceptance details: $e");
      }
    }
  }

  // Update driver subscription
  Future<void> _updateDriverSubscription() async {
    try {
      if (driverModel.value.subscriptionTotalOrders != "-1" &&
          driverModel.value.subscriptionTotalOrders != null) {
        int totalOrders = int.parse(driverModel.value.subscriptionTotalOrders.toString());
        driverModel.value.subscriptionTotalOrders = (totalOrders - 1).toString();
        await FireStoreUtils.updateDriverUser(driverModel.value);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error updating driver subscription: $e");
      }
    }
  }

  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;

  RxString newAmount = "0.0".obs;

  Future<void> getArgument() async {
    isLoading.value = true; // Keep loading true until all data is ready
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      String orderId = argumentData['orderModel'];
      await getData(orderId);
      newAmount.value = orderModel.value.offerRate.toString();
      enterOfferRateController.value.text =
          orderModel.value.offerRate.toString();
      await addMarkerSetup(); // Ensure markers are set up first
      await getPolyline(); // Then call getPolyline

      // Apply the same functionality as FloatingActionButton when page initializes
      // Add a small delay to ensure map is fully loaded
      await Future.delayed(const Duration(milliseconds: 500));
      await animateToSourceLocation();
    }

    FireStoreUtils.fireStore
        .collection(CollectionName.driverUsers)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen((event) {
      if (event.exists) {
        driverModel.value = DriverUserModel.fromJson(event.data()!);
      }
    });
    isLoading.value = false;
    update(); // Force GetX to rebuild the UI
  }

  Future<void> getPolyline() async {
    if (orderModel.value.sourceLocationLAtLng != null &&
        orderModel.value.destinationLocationLAtLng != null) {
      List<LatLng> polylineCoordinates = [];
      PolylineRequest polylineRequest = PolylineRequest(
        origin: PointLatLng(
          orderModel.value.sourceLocationLAtLng!.latitude ?? 0.0,
          orderModel.value.sourceLocationLAtLng!.longitude ?? 0.0,
        ),
        destination: PointLatLng(
          orderModel.value.destinationLocationLAtLng!.latitude ?? 0.0,
          orderModel.value.destinationLocationLAtLng!.longitude ?? 0.0,
        ),
        mode: TravelMode.driving,
      );

      try {
        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          googleApiKey: Constant.mapAPIKey,
          request: polylineRequest,
        );

        // Process result if available
        if (result.points.isNotEmpty) {
          for (var point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        } else {
          ShowToastDialog.showToast(
              "Failed to fetch route: No points found".tr);
        }
      } catch (e) {
        ShowToastDialog.showToast("Error fetching route: $e".tr);
        print("Error Fetch $e");
      }

      _addPolyLine(polylineCoordinates);
      addMarker(
        LatLng(
          orderModel.value.sourceLocationLAtLng!.latitude ?? 0.0,
          orderModel.value.sourceLocationLAtLng!.longitude ?? 0.0,
        ),
        "Source",
        departureIcon,
      );
      addMarker(
        LatLng(
          orderModel.value.destinationLocationLAtLng!.latitude ?? 0.0,
          orderModel.value.destinationLocationLAtLng!.longitude ?? 0.0,
        ),
        "Destination",
        destinationIcon,
      );
      markers.refresh();
      polyLines.refresh();
      update();
    }
  }

  getData(String id) async {
    await FireStoreUtils.getOrder(id).then((value) {
      if (value != null) {
        orderModel.value = value;
      }
    });
  }

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;

  Future<void> addMarkerSetup() async {
    final Uint8List departure =
        await Constant().getBytesFromAsset('assets/images/red_mark.png', 70);
    final Uint8List destination =
        await Constant().getBytesFromAsset('assets/images/green_mark.png', 70);
    departureIcon = BitmapDescriptor.fromBytes(departure);
    destinationIcon = BitmapDescriptor.fromBytes(destination);
  }

  RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  PolylinePoints polylinePoints = PolylinePoints();

  double zoomLevel = 0;

  Future<void> movePosition() async {
    if (orderModel.value.sourceLocationLAtLng == null ||
        orderModel.value.destinationLocationLAtLng == null) {
      return;
    }

    double distance = double.parse((prefix.Geolocator.distanceBetween(
              orderModel.value.sourceLocationLAtLng!.latitude ?? 0.0,
              orderModel.value.sourceLocationLAtLng!.longitude ?? 0.0,
              orderModel.value.destinationLocationLAtLng!.latitude ?? 0.0,
              orderModel.value.destinationLocationLAtLng!.longitude ?? 0.0,
            ) /
            1609.32)
        .toString());
    LatLng center = LatLng(
      (orderModel.value.sourceLocationLAtLng!.latitude! +
              orderModel.value.destinationLocationLAtLng!.latitude!) /
          2,
      (orderModel.value.sourceLocationLAtLng!.longitude! +
              orderModel.value.destinationLocationLAtLng!.longitude!) /
          2,
    );

    double radiusElevated = (distance / 2) + ((distance / 2) / 2);
    double scale = radiusElevated / 500;

    zoomLevel = 6 - log(scale) / log(2);

    final GoogleMapController controller = await mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(center, zoomLevel));
  }

  _addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      points: polylineCoordinates,
      width: 3,
      color: AppColors.primary,
      patterns: [
        PatternItem.dash(20),
        PatternItem.gap(10)
      ], // Pink from AppColors
    );
    polyLines[id] = polyline;
  }

  addMarker(LatLng? position, String id, BitmapDescriptor? descriptor) {
    if (position != null && descriptor != null) {
      MarkerId markerId = MarkerId(id);
      Marker marker = Marker(
        markerId: markerId,
        icon: descriptor,
        position: position,
      );
      markers[markerId] = marker;
    }
  }

  // Notify other controllers about ride state changes
  void _notifyRideStateChange() {
    try {
      // Notify active order controller to refresh (most important)
      if (Get.isRegistered<ActiveOrderController>()) {
        final activeOrderController = Get.find<ActiveOrderController>();
        activeOrderController.refreshData();
      }
      
      // Notify dashboard controller if needed (less frequent)
      if (Get.isRegistered<DashBoardController>()) {
        final dashboardController = Get.find<DashBoardController>();
        dashboardController.fetchDriverData();
      }
      
      // Home controller will update automatically via its listener
      // No need to call getActiveRide() here as it creates multiple listeners
    } catch (e) {
      if (kDebugMode) {
        print("Error notifying controllers about ride state change: $e");
      }
    }
  }

  // Navigate to active ride tab
  void _navigateToActiveRideTab() {
    try {
      // Navigate back to home screen
      Get.back();
      
      // Use a small delay to ensure the home screen is loaded
      Future.delayed(const Duration(milliseconds: 200), () {
        try {
          // Find the HomeController using dynamic typing to avoid import issues
          if (Get.isRegistered<HomeController>()) {
            final homeController = Get.find<HomeController>();
            homeController.selectedIndex.value = 2; // Active ride tab index
            homeController.onItemTapped(2); // Trigger the tab change
          }
        } catch (e) {
          if (kDebugMode) {
            print("Error switching to active ride tab: $e");
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error navigating to active ride tab: $e");
      }
      // Fallback: just go back to previous screen
      Get.back();
    }
  }
}
