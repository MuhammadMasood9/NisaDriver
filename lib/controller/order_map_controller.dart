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
    final GoogleMapController? controller = await mapController.future;
    controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          zoom: 15,
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

  acceptOrder() async {
    if (double.parse(driverModel.value.walletAmount.toString()) >=
        double.parse(Constant.minimumDepositToRideAccept)) {
      ShowToastDialog.showLoader("Please wait".tr);
      List<dynamic> newAcceptedDriverId = [];
      if (orderModel.value.acceptedDriverId != null) {
        newAcceptedDriverId = orderModel.value.acceptedDriverId!;
      } else {
        newAcceptedDriverId = [];
      }
      newAcceptedDriverId.add(FireStoreUtils.getCurrentUid());
      orderModel.value.acceptedDriverId = newAcceptedDriverId;
      // orderModel.value.offerRate = newAmount.value;
      await FireStoreUtils.setOrder(orderModel.value);

      await FireStoreUtils.getCustomer(orderModel.value.userId.toString())
          .then((value) async {
        if (value != null) {
          await SendNotification.sendOneNotification(
            token: value.fcmToken.toString(),
            title: 'New Driver Bid'.tr,
            body:
                'Driver has offered ${Constant.amountShow(amount: newAmount.value)} for your journey.🚗'
                    .tr,
            payload: {},
          );
        }
      });

      DriverIdAcceptReject driverIdAcceptReject = DriverIdAcceptReject(
        driverId: FireStoreUtils.getCurrentUid(),
        acceptedRejectTime: cloudFirestore.Timestamp.now(),
        offerAmount: newAmount.value,
      );
      FireStoreUtils.acceptRide(orderModel.value, driverIdAcceptReject)
          .then((value) async {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Ride Accepted".tr);
        if (driverModel.value.subscriptionTotalOrders != "-1") {
          driverModel.value.subscriptionTotalOrders =
              (int.parse(driverModel.value.subscriptionTotalOrders.toString()) -
                      1)
                  .toString();
          await FireStoreUtils.updateDriverUser(driverModel.value);
        }
        Get.back(result: true);
      });
    } else {
      ShowToastDialog.showToast(
        "You have to minimum ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} wallet amount to Accept Order and place a bid"
            .tr,
      );
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
        List<PolylineResult> results =
            await polylinePoints.getRouteBetweenCoordinates(
          googleApiKey: Constant.mapAPIKey,
          request: polylineRequest,
        );

        // Process first result if available
        if (results.isNotEmpty && results.first.points.isNotEmpty) {
          for (var point in results.first.points) {
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
        await Constant().getBytesFromAsset('assets/images/pickup.png', 100);
    final Uint8List destination =
        await Constant().getBytesFromAsset('assets/images/dropoff.png', 100);
    departureIcon = BitmapDescriptor.fromBytes(departure);
    destinationIcon = BitmapDescriptor.fromBytes(destination);
  }

  RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  PolylinePoints polylinePoints = PolylinePoints();

  double zoomLevel = 0;

  Future<void> movePosition() async {
    if (orderModel.value.sourceLocationLAtLng == null ||
        orderModel.value.destinationLocationLAtLng == null) return;

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

    zoomLevel = 16 - log(scale) / log(2);

    final GoogleMapController controller = await mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(center, zoomLevel));
  }

  _addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      points: polylineCoordinates,
      width: 6,
      color: AppColors.primary, // Pink from AppColors
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
}
