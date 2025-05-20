import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class LiveTrackingController extends GetxController {
  GoogleMapController? mapController;
  Timer? _locationUpdateTimer;
  Timer? _estimationUpdateTimer;

  Rx<DriverUserModel> driverUserModel = DriverUserModel().obs;
  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<InterCityOrderModel> intercityOrderModel = InterCityOrderModel().obs;

  RxBool isLoading = true.obs;
  RxString type = "".obs;
  RxString status = "".obs;
  RxDouble distance = 0.0.obs;
  RxString estimatedTime = "Calculating...".obs;
  RxString estimatedArrival = "Calculating...".obs;
  RxBool isFollowingDriver = true.obs;
  RxString navigationInstruction = "".obs;

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? driverIcon;

  RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  PolylinePoints polylinePoints = PolylinePoints();

  RxList<LatLng> routePoints = <LatLng>[].obs;
  RxBool showDriverToPickupRoute = false.obs;
  RxBool showPickupToDestinationRoute = true.obs;

  final RxDouble remainingDistance = 0.0.obs;
  final RxString tripProgress = "0%".obs;
  final RxDouble tripProgressValue = 0.0.obs;
  final RxString currentStep = "".obs;

  // Added for navigation view
  RxBool isNavigationView = true.obs;
  RxDouble navigationZoom = 17.0.obs;
  RxDouble navigationTilt = 60.0.obs;
  RxDouble navigationBearing = 0.0.obs;
  RxInt nextRoutePointIndex = 0.obs;

  @override
  void onInit() {
    addMarkerSetup();
    getArgument();
    startLocationUpdates();
    startEstimationUpdates();
    super.onInit();
  }

  @override
  void onClose() {
    _locationUpdateTimer?.cancel();
    _estimationUpdateTimer?.cancel();
    mapController?.dispose();
    ShowToastDialog.closeLoader();
    super.onClose();
  }

  void startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      updateDriverLocation();
    });
  }

  void startEstimationUpdates() {
    _estimationUpdateTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      updateTimeAndDistanceEstimates();
    });
  }

  void updateDriverLocation() async {
    if (driverUserModel.value.location != null) {
      // Update driver marker
      addMarker(
        latitude: driverUserModel.value.location!.latitude,
        longitude: driverUserModel.value.location!.longitude,
        id: "Driver",
        descriptor: driverIcon!,
        rotation: driverUserModel.value.rotation,
      );

      // Update navigation bearing based on driver rotation
      if (driverUserModel.value.rotation != null) {
        navigationBearing.value = driverUserModel.value.rotation!;
      }

      if (isFollowingDriver.value) {
        updateNavigationView();
      }

      updateTimeAndDistanceEstimates();
      updateRouteVisibility();
      updateNavigationInstructions();
      updateNextRoutePoint(); // Find next route point for navigation
    } else {
      print("Debug: Driver location is null");
    }
  }

  void updateNextRoutePoint() {
    if (routePoints.isEmpty || driverUserModel.value.location == null) {
      return;
    }

    // Find the closest point on the route to the driver's current location
    LatLng driverPos = LatLng(
      driverUserModel.value.location!.latitude!,
      driverUserModel.value.location!.longitude!,
    );

    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length; i++) {
      double dist = calculateDistanceBetweenPoints(
        driverPos.latitude,
        driverPos.longitude,
        routePoints[i].latitude,
        routePoints[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // Set next point index (looking ahead on the route)
    nextRoutePointIndex.value = min(closestIndex + 3, routePoints.length - 1);
  }

  void updateTimeAndDistanceEstimates() async {
    if (driverUserModel.value.location == null) {
      print(
          "Debug: Skipping time/distance estimates due to null driver location");
      return;
    }

    LatLng targetLocation;
    if (type.value == "orderModel") {
      if (orderModel.value.status == Constant.rideInProgress) {
        targetLocation = LatLng(
            orderModel.value.destinationLocationLAtLng!.latitude!,
            orderModel.value.destinationLocationLAtLng!.longitude!);
        currentStep.value = "Heading to destination";
      } else {
        targetLocation = LatLng(
            orderModel.value.sourceLocationLAtLng!.latitude!,
            orderModel.value.sourceLocationLAtLng!.longitude!);
        currentStep.value = "Heading to pickup";
      }
    } else {
      if (intercityOrderModel.value.status == Constant.rideInProgress) {
        targetLocation = LatLng(
            intercityOrderModel.value.destinationLocationLAtLng!.latitude!,
            intercityOrderModel.value.destinationLocationLAtLng!.longitude!);
        currentStep.value = "Heading to destination";
      } else {
        targetLocation = LatLng(
            intercityOrderModel.value.sourceLocationLAtLng!.latitude!,
            intercityOrderModel.value.sourceLocationLAtLng!.longitude!);
        currentStep.value = "Heading to pickup";
      }
    }

    double distanceInMeters = await calculateDistance(
        driverUserModel.value.location!.latitude!,
        driverUserModel.value.location!.longitude!,
        targetLocation.latitude,
        targetLocation.longitude);
    distance.value = distanceInMeters / 1000;

    double timeInHours = distance.value / 40;
    int minutes = (timeInHours * 60).round();
    estimatedTime.value = minutes < 1 ? "Less than 1 min" : "$minutes min";

    DateTime now = DateTime.now();
    DateTime arrival = now.add(Duration(minutes: minutes));
    estimatedArrival.value = DateFormat('hh:mm a').format(arrival);

    updateTripProgress();
  }

  void updateTripProgress() {
    double totalDistance;
    double progressPercentage;

    if (type.value == "orderModel") {
      if (orderModel.value.status == Constant.rideInProgress) {
        totalDistance = calculateDistanceBetweenPoints(
            orderModel.value.sourceLocationLAtLng!.latitude!,
            orderModel.value.sourceLocationLAtLng!.longitude!,
            orderModel.value.destinationLocationLAtLng!.latitude!,
            orderModel.value.destinationLocationLAtLng!.longitude!);
        double coveredDistance = totalDistance - distance.value;
        progressPercentage = (coveredDistance / totalDistance) * 100;
      } else {
        progressPercentage = 0;
      }
    } else {
      if (intercityOrderModel.value.status == Constant.rideInProgress) {
        totalDistance = calculateDistanceBetweenPoints(
            intercityOrderModel.value.sourceLocationLAtLng!.latitude!,
            intercityOrderModel.value.sourceLocationLAtLng!.longitude!,
            intercityOrderModel.value.destinationLocationLAtLng!.latitude!,
            intercityOrderModel.value.destinationLocationLAtLng!.longitude!);
        double coveredDistance = totalDistance - distance.value;
        progressPercentage = (coveredDistance / totalDistance) * 100;
      } else {
        progressPercentage = 0;
      }
    }

    progressPercentage = progressPercentage.clamp(0.0, 100.0);
    tripProgressValue.value = progressPercentage / 100;
    tripProgress.value = "${progressPercentage.toStringAsFixed(0)}%";
  }

  Future<double> calculateDistance(
      double startLat, double startLng, double endLat, double endLng) async {
    try {
      return await Geolocator.distanceBetween(
          startLat, startLng, endLat, endLng);
    } catch (e) {
      print("Error calculating distance: $e");
      return calculateDistanceBetweenPoints(
              startLat, startLng, endLat, endLng) *
          1000;
    }
  }

  double calculateDistanceBetweenPoints(
      double startLat, double startLng, double endLat, double endLng) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((endLat - startLat) * p) / 2 +
        c(startLat * p) * c(endLat * p) * (1 - c((endLng - startLng) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void updateNavigationView() async {
    if (mapController == null || driverUserModel.value.location == null) {
      print("Debug: Cannot update camera, mapController or location is null");
      return;
    }

    LatLng driverLocation = LatLng(
      driverUserModel.value.location!.latitude!,
      driverUserModel.value.location!.longitude!,
    );

    // Get the next target point from route points (if available)
    LatLng targetPoint = driverLocation;

    // If we have route points, look ahead on the path
    if (routePoints.isNotEmpty &&
        nextRoutePointIndex.value < routePoints.length) {
      targetPoint = routePoints[nextRoutePointIndex.value];
    }

    // Calculate bearing to target if not using driver's rotation
    double bearingToTarget = driverUserModel.value.rotation ??
        getBearing(driverLocation.latitude, driverLocation.longitude,
            targetPoint.latitude, targetPoint.longitude);

    // Update the navigation bearing (smoothly to avoid jerky movement)
    navigationBearing.value = bearingToTarget;

    // Place camera behind and slightly above the driver, looking ahead along the route
    // This creates the 3D navigation perspective
    await mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: driverLocation,
          zoom: navigationZoom.value,
          tilt: navigationTilt.value,
          bearing: navigationBearing.value,
        ),
      ),
    );
  }

  // Calculate bearing between two points for navigation
  double getBearing(
      double startLat, double startLng, double endLat, double endLng) {
    double latitude1 = startLat * pi / 180;
    double longitude1 = startLng * pi / 180;
    double latitude2 = endLat * pi / 180;
    double longitude2 = endLng * pi / 180;

    double y = sin(longitude2 - longitude1) * cos(latitude2);
    double x = cos(latitude1) * sin(latitude2) -
        sin(latitude1) * cos(latitude2) * cos(longitude2 - longitude1);

    double bearing = atan2(y, x);
    bearing = bearing * 180 / pi;
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  void updateNavigationInstructions() async {
    if (routePoints.isEmpty || driverUserModel.value.location == null) {
      navigationInstruction.value = "Waiting for route data...";
      return;
    }

    // Find the closest point on the route to the driver's current location
    LatLng driverPos = LatLng(
      driverUserModel.value.location!.latitude!,
      driverUserModel.value.location!.longitude!,
    );
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length; i++) {
      double dist = await calculateDistance(
        driverPos.latitude,
        driverPos.longitude,
        routePoints[i].latitude,
        routePoints[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // Check if driver is off-route
    if (minDistance > 50) {
      navigationInstruction.value = "Off route! Recalculating...";
      updateRouteVisibility();
      return;
    }

    // Get the next point for navigation instruction
    if (closestIndex < routePoints.length - 1) {
      LatLng nextPoint = routePoints[closestIndex + 1];
      double distanceToNext = await calculateDistance(
        driverPos.latitude,
        driverPos.longitude,
        nextPoint.latitude,
        nextPoint.longitude,
      );
      navigationInstruction.value =
          "Proceed ${formatDistance(distanceToNext / 1000)} to next turn";
    } else {
      navigationInstruction.value = "Approaching destination";
    }
  }

  void updateRouteVisibility() {
    if (type.value == "orderModel") {
      showDriverToPickupRoute.value =
          orderModel.value.status == Constant.rideActive;
      showPickupToDestinationRoute.value =
          orderModel.value.status == Constant.rideInProgress;
    } else {
      showDriverToPickupRoute.value =
          intercityOrderModel.value.status == Constant.rideActive;
      showPickupToDestinationRoute.value =
          intercityOrderModel.value.status == Constant.rideInProgress;
    }
    updateMarkersAndPolyline();
  }

  getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      type.value = argumentData['type'];
      if (type.value == "orderModel") {
        OrderModel argumentOrderModel = argumentData['orderModel'];
        FireStoreUtils.fireStore
            .collection(CollectionName.orders)
            .doc(argumentOrderModel.id)
            .snapshots()
            .listen((event) {
          if (event.data() != null) {
            orderModel.value = OrderModel.fromJson(event.data()!);
            status.value = orderModel.value.status ?? "";
            updateRouteVisibility();
            if (orderModel.value.status == Constant.rideComplete) {
              Get.back();
            }
          }
        });
        FireStoreUtils.fireStore
            .collection(CollectionName.driverUsers)
            .doc(argumentOrderModel.driverId)
            .snapshots()
            .listen((event) {
          if (event.data() != null) {
            driverUserModel.value = DriverUserModel.fromJson(event.data()!);
            updateRouteVisibility();
          }
        });
      } else {
        InterCityOrderModel argumentOrderModel =
            argumentData['interCityOrderModel'];
        FireStoreUtils.fireStore
            .collection(CollectionName.ordersIntercity)
            .doc(argumentOrderModel.id)
            .snapshots()
            .listen((event) {
          if (event.data() != null) {
            intercityOrderModel.value =
                InterCityOrderModel.fromJson(event.data()!);
            status.value = intercityOrderModel.value.status ?? "";
            updateRouteVisibility();
            if (intercityOrderModel.value.status == Constant.rideComplete) {
              Get.back();
            }
          }
        });
        FireStoreUtils.fireStore
            .collection(CollectionName.driverUsers)
            .doc(argumentOrderModel.driverId)
            .snapshots()
            .listen((event) {
          if (event.data() != null) {
            driverUserModel.value = DriverUserModel.fromJson(event.data()!);
            updateRouteVisibility();
          }
        });
      }
    }
    isLoading.value = false;
    update();
    updateRouteVisibility();
    updateMarkersAndPolyline();
  }

  void updateMarkersAndPolyline() {
    markers.clear();
    polyLines.clear();

    if (type.value == "orderModel") {
      if (orderModel.value.sourceLocationLAtLng == null ||
          orderModel.value.destinationLocationLAtLng == null ||
          driverUserModel.value.location == null) {
        return;
      }

      // Only show departure/destination markers when not in navigation view
      // or when they're within visible range
      if (!isNavigationView.value ||
          isLocationInVisibleRange(orderModel.value.sourceLocationLAtLng!)) {
        addMarker(
          latitude: orderModel.value.sourceLocationLAtLng!.latitude,
          longitude: orderModel.value.sourceLocationLAtLng!.longitude,
          id: "Departure",
          descriptor: departureIcon!,
          rotation: 0.0,
        );
      }

      if (!isNavigationView.value ||
          isLocationInVisibleRange(
              orderModel.value.destinationLocationLAtLng!)) {
        addMarker(
          latitude: orderModel.value.destinationLocationLAtLng!.latitude,
          longitude: orderModel.value.destinationLocationLAtLng!.longitude,
          id: "Destination",
          descriptor: destinationIcon!,
          rotation: 0.0,
        );
      }

      // In navigation view, we don't need to show the driver marker (we're seeing from driver's perspective)
      if (!isNavigationView.value) {
        addMarker(
          latitude: driverUserModel.value.location!.latitude,
          longitude: driverUserModel.value.location!.longitude,
          id: "Driver",
          descriptor: driverIcon!,
          rotation: driverUserModel.value.rotation,
        );
      }

      if (showDriverToPickupRoute.value) {
        getPolyline(
          sourceLatitude: driverUserModel.value.location!.latitude,
          sourceLongitude: driverUserModel.value.location!.longitude,
          destinationLatitude: orderModel.value.sourceLocationLAtLng!.latitude,
          destinationLongitude:
              orderModel.value.sourceLocationLAtLng!.longitude,
          polylineId: "DriverToPickup",
          color: AppColors.primary,
        );
      }

      if (showPickupToDestinationRoute.value) {
        getPolyline(
          sourceLatitude: orderModel.value.sourceLocationLAtLng!.latitude,
          sourceLongitude: orderModel.value.sourceLocationLAtLng!.longitude,
          destinationLatitude:
              orderModel.value.destinationLocationLAtLng!.latitude,
          destinationLongitude:
              orderModel.value.destinationLocationLAtLng!.longitude,
          polylineId: "PickupToDestination",
          color: Colors.green,
        );
      }
    } else {
      // Intercity order logic
      if (intercityOrderModel.value.sourceLocationLAtLng == null ||
          intercityOrderModel.value.destinationLocationLAtLng == null ||
          driverUserModel.value.location == null) {
        return;
      }

      // Only show departure/destination markers when not in navigation view
      // or when they're within visible range
      if (!isNavigationView.value ||
          isLocationInVisibleRange(
              intercityOrderModel.value.sourceLocationLAtLng!)) {
        addMarker(
          latitude: intercityOrderModel.value.sourceLocationLAtLng!.latitude,
          longitude: intercityOrderModel.value.sourceLocationLAtLng!.longitude,
          id: "Departure",
          descriptor: departureIcon!,
          rotation: 0.0,
        );
      }

      if (!isNavigationView.value ||
          isLocationInVisibleRange(
              intercityOrderModel.value.destinationLocationLAtLng!)) {
        addMarker(
          latitude:
              intercityOrderModel.value.destinationLocationLAtLng!.latitude,
          longitude:
              intercityOrderModel.value.destinationLocationLAtLng!.longitude,
          id: "Destination",
          descriptor: destinationIcon!,
          rotation: 0.0,
        );
      }

      // In navigation view, we don't need to show the driver marker
      if (!isNavigationView.value) {
        addMarker(
          latitude: driverUserModel.value.location!.latitude,
          longitude: driverUserModel.value.location!.longitude,
          id: "Driver",
          descriptor: driverIcon!,
          rotation: driverUserModel.value.rotation,
        );
      }

      if (showDriverToPickupRoute.value) {
        getPolyline(
          sourceLatitude: driverUserModel.value.location!.latitude,
          sourceLongitude: driverUserModel.value.location!.longitude,
          destinationLatitude:
              intercityOrderModel.value.sourceLocationLAtLng!.latitude,
          destinationLongitude:
              intercityOrderModel.value.sourceLocationLAtLng!.longitude,
          polylineId: "DriverToPickup",
          color: AppColors.primary,
        );
      }

      if (showPickupToDestinationRoute.value) {
        getPolyline(
          sourceLatitude:
              intercityOrderModel.value.sourceLocationLAtLng!.latitude,
          sourceLongitude:
              intercityOrderModel.value.sourceLocationLAtLng!.longitude,
          destinationLatitude:
              intercityOrderModel.value.destinationLocationLAtLng!.latitude,
          destinationLongitude:
              intercityOrderModel.value.destinationLocationLAtLng!.longitude,
          polylineId: "PickupToDestination",
          color: Colors.green,
        );
      }
    }

    updateTimeAndDistanceEstimates();
  }

  // Check if a location is in visible range for navigation view
  bool isLocationInVisibleRange(dynamic location) {
    if (driverUserModel.value.location == null || location == null) {
      return false;
    }

    // Calculate distance to determine if a marker should be visible in navigation view
    double dist = calculateDistanceBetweenPoints(
        driverUserModel.value.location!.latitude!,
        driverUserModel.value.location!.longitude!,
        location.latitude,
        location.longitude);

    // Only show markers that are within 1km in navigation view
    return dist < 1.0;
  }

  void getPolyline({
    required double? sourceLatitude,
    required double? sourceLongitude,
    required double? destinationLatitude,
    required double? destinationLongitude,
    required String polylineId,
    required Color color,
  }) async {
    if (sourceLatitude == null ||
        sourceLongitude == null ||
        destinationLatitude == null ||
        destinationLongitude == null) {
      return;
    }

    List<LatLng> polylineCoordinates = [];
    PolylineRequest polylineRequest = PolylineRequest(
      origin: PointLatLng(sourceLatitude, sourceLongitude),
      destination: PointLatLng(destinationLatitude, destinationLongitude),
      mode: TravelMode.driving,
    );

    try {
      List<PolylineResult> results =
          await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: Constant.mapAPIKey,
        request: polylineRequest,
      );

      if (results.isNotEmpty) {
        var result = results.first;
        if (result.points.isNotEmpty) {
          for (var point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
          if (polylineId == "DriverToPickup" ||
              polylineId == "PickupToDestination") {
            routePoints.value = polylineCoordinates;
          }
        }
      }
    } catch (e) {
      print("Debug: Error fetching polyline for $polylineId: $e");
      navigationInstruction.value = "Route unavailable, please try again";
    }

    _addPolyLine(polylineCoordinates, polylineId, color);
  }

  void addMarker({
    required double? latitude,
    required double? longitude,
    required String id,
    required BitmapDescriptor descriptor,
    required double? rotation,
  }) {
    if (latitude == null || longitude == null) {
      return;
    }

    MarkerId markerId = MarkerId(id);
    String title = id == "Departure"
        ? "Pickup Location"
        : id == "Destination"
            ? "Destination"
            : "Driver";
    String snippet = id == "Driver"
        ? driverUserModel.value.fullName ?? ""
        : type.value == "orderModel"
            ? (id == "Departure"
                ? orderModel.value.sourceLocationName ?? ""
                : orderModel.value.destinationLocationName ?? "")
            : (id == "Departure"
                ? intercityOrderModel.value.sourceLocationName ?? ""
                : intercityOrderModel.value.destinationLocationName ?? "");

    Marker marker = Marker(
      markerId: markerId,
      icon: descriptor,
      position: LatLng(latitude, longitude),
      rotation: rotation ?? 0.0,
      infoWindow: InfoWindow(title: title, snippet: snippet),
    );
    markers[markerId] = marker;
  }

  void addMarkerSetup() async {
    try {
      final Uint8List departure =
          await Constant().getBytesFromAsset('assets/images/pickup.png', 50);
      final Uint8List destination =
          await Constant().getBytesFromAsset('assets/images/dropoff.png', 50);
      final Uint8List driver =
          await Constant().getBytesFromAsset('assets/images/ic_cab.png', 30);
      departureIcon = BitmapDescriptor.fromBytes(departure);
      destinationIcon = BitmapDescriptor.fromBytes(destination);
      driverIcon = BitmapDescriptor.fromBytes(driver);
    } catch (e) {
      print("Debug: Error loading marker icons: $e");
    }
  }

  void _addPolyLine(
      List<LatLng> polylineCoordinates, String polylineId, Color color) {
    if (polylineCoordinates.isEmpty) {
      return;
    }

    PolylineId id = PolylineId(polylineId);
    Polyline polyline = Polyline(
      polylineId: id,
      points: polylineCoordinates,
      color: color,
      width: 8,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      patterns: isNavigationView.value
          ? []
          : [PatternItem.dash(20), PatternItem.gap(10)],
    );
    polyLines[id] = polyline;

    if (polylineId == "DriverToPickup" && !isFollowingDriver.value) {
      updateCameraLocation(polylineCoordinates.first, polylineCoordinates.last);
    }
  }

  void updateCameraLocation(LatLng source, LatLng destination) async {
    if (mapController == null) {
      return;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        min(source.latitude, destination.latitude),
        min(source.longitude, destination.longitude),
      ),
      northeast: LatLng(
        max(source.latitude, destination.latitude),
        max(source.longitude, destination.longitude),
      ),
    );

    CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 100);
    await mapController!.animateCamera(cameraUpdate);
  }

  void toggleMapView() {
    isFollowingDriver.toggle();
    isNavigationView.value = isFollowingDriver.value;

    if (isFollowingDriver.value) {
      updateNavigationView();
    } else if (routePoints.isNotEmpty && routePoints.length > 1) {
      updateCameraLocation(routePoints.first, routePoints.last);
    }

    // Update markers and polylines for the view type
    updateMarkersAndPolyline();
  }

  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      int meters = (distanceInKm * 1000).round();
      return "$meters m";
    }
    return "${distanceInKm.toStringAsFixed(1)} km";
  }
}
