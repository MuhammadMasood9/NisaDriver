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
  RxBool showPickupToDestinationRoute = false.obs;

  final RxDouble remainingDistance = 0.0.obs;
  final RxString tripProgress = "0%".obs;
  final RxDouble tripProgressValue = 0.0.obs;
  final RxString currentStep = "".obs;

  // Navigation view properties
  RxBool isNavigationView = true.obs;
  RxDouble navigationZoom = 17.0.obs;
  RxDouble navigationTilt = 60.0.obs;
  RxDouble navigationBearing = 0.0.obs;
  RxInt nextRoutePointIndex = 0.obs;

  @override
  void onInit() {
    addMarkerSetup();
    getArgument();
    isFollowingDriver.value = true;
    isNavigationView.value = true;
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
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      updateDriverLocation();
    });
  }

  void startEstimationUpdates() {
    _estimationUpdateTimer?.cancel();
    _estimationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      updateTimeAndDistanceEstimates();
    });
  }

  void updateDriverLocation() async {
    if (driverUserModel.value.location == null) {
      print("Debug: Driver location is null");
      return;
    }

    // Update driver marker with proper rotation
    addDriverMarker();

    // Update navigation bearing with driver's rotation
    if (driverUserModel.value.rotation != null) {
      double newBearing = driverUserModel.value.rotation!;
      navigationBearing.value = interpolateBearing(navigationBearing.value, newBearing);
    }

    // Always follow driver and update camera
    if (isFollowingDriver.value) {
      updateNavigationView();
    }

    // Update route visibility based on ride status
    updateRouteVisibility();
    updateNavigationInstructions();
    updateNextRoutePoint();
    adjustDynamicZoom();
  }

  void addDriverMarker() {
    if (driverUserModel.value.location?.latitude == null || 
        driverUserModel.value.location?.longitude == null) {
      return;
    }

    addMarker(
      latitude: driverUserModel.value.location!.latitude,
      longitude: driverUserModel.value.location!.longitude,
      id: "Driver",
      descriptor: driverIcon!,
      rotation: driverUserModel.value.rotation ?? 0.0,
    );
  }

  double interpolateBearing(double currentBearing, double targetBearing) {
    double diff = targetBearing - currentBearing;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    double interpolated = currentBearing + diff * 0.3;
    return (interpolated + 360) % 360;
  }

  void updateNextRoutePoint() {
    if (routePoints.isEmpty || driverUserModel.value.location == null) {
      return;
    }

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

    nextRoutePointIndex.value = min(closestIndex + 3, routePoints.length - 1);
  }

  void adjustDynamicZoom() async {
    if (routePoints.isEmpty || driverUserModel.value.location == null) {
      navigationZoom.value = 17.0;
      return;
    }

    double distanceToNextTurn = double.infinity;
    if (nextRoutePointIndex.value < routePoints.length - 1) {
      distanceToNextTurn = await calculateDistance(
        driverUserModel.value.location!.latitude!,
        driverUserModel.value.location!.longitude!,
        routePoints[nextRoutePointIndex.value + 1].latitude,
        routePoints[nextRoutePointIndex.value + 1].longitude,
      );
    }

    if (distanceToNextTurn < 200) {
      navigationZoom.value = 18.0;
    } else if (distanceToNextTurn < 500) {
      navigationZoom.value = 17.5;
    } else {
      navigationZoom.value = 16.5;
    }
  }

  void updateTimeAndDistanceEstimates() async {
    if (driverUserModel.value.location == null) {
      print("Debug: Skipping time/distance estimates due to null driver location");
      return;
    }

    LatLng targetLocation;
    bool isGoingToPickup = false;

    // Determine target location based on ride status
    if (type.value == "orderModel") {
      if (orderModel.value.status == Constant.rideInProgress) {
        // Going to destination
        targetLocation = LatLng(
          orderModel.value.destinationLocationLAtLng!.latitude!,
          orderModel.value.destinationLocationLAtLng!.longitude!
        );
        currentStep.value = "Heading to destination";
      } else {
        // Going to pickup
        targetLocation = LatLng(
          orderModel.value.sourceLocationLAtLng!.latitude!,
          orderModel.value.sourceLocationLAtLng!.longitude!
        );
        currentStep.value = "Heading to pickup";
        isGoingToPickup = true;
      }
    } else {
      if (intercityOrderModel.value.status == Constant.rideInProgress) {
        // Going to destination
        targetLocation = LatLng(
          intercityOrderModel.value.destinationLocationLAtLng!.latitude!,
          intercityOrderModel.value.destinationLocationLAtLng!.longitude!
        );
        currentStep.value = "Heading to destination";
      } else {
        // Going to pickup
        targetLocation = LatLng(
          intercityOrderModel.value.sourceLocationLAtLng!.latitude!,
          intercityOrderModel.value.sourceLocationLAtLng!.longitude!
        );
        currentStep.value = "Heading to pickup";
        isGoingToPickup = true;
      }
    }

    double distanceInMeters = await calculateDistance(
      driverUserModel.value.location!.latitude!,
      driverUserModel.value.location!.longitude!,
      targetLocation.latitude,
      targetLocation.longitude
    );
    
    distance.value = distanceInMeters / 1000;

    // Calculate estimated time
    double avgSpeed = isGoingToPickup ? 35.0 : 40.0; // km/h
    double timeInHours = distance.value / avgSpeed;
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
          orderModel.value.destinationLocationLAtLng!.longitude!
        );
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
          intercityOrderModel.value.destinationLocationLAtLng!.longitude!
        );
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
      return await Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    } catch (e) {
      print("Error calculating distance: $e");
      return calculateDistanceBetweenPoints(startLat, startLng, endLat, endLng) * 1000;
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

    // Always center camera on driver with navigation bearing
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

  double getBearing(double startLat, double startLng, double endLat, double endLng) {
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

    if (minDistance > 50) {
      navigationInstruction.value = "Off route! Recalculating...";
      updateRouteVisibility();
      return;
    }

    String target = showDriverToPickupRoute.value ? "pickup" : "destination";
    if (closestIndex < routePoints.length - 1) {
      LatLng nextPoint = routePoints[closestIndex + 1];
      double distanceToNext = await calculateDistance(
        driverPos.latitude,
        driverPos.longitude,
        nextPoint.latitude,
        nextPoint.longitude,
      );
      navigationInstruction.value =
          "Proceed ${formatDistance(distanceToNext / 1000)} to $target";
    } else {
      navigationInstruction.value = "Approaching $target";
    }
  }

  void updateRouteVisibility() {
    bool wasShowingPickup = showDriverToPickupRoute.value;
    bool wasShowingDestination = showPickupToDestinationRoute.value;

    if (type.value == "orderModel") {
      // Before pickup: show driver to pickup route
      showDriverToPickupRoute.value = (orderModel.value.status == Constant.rideActive);
      // After pickup: show driver to destination route
      showPickupToDestinationRoute.value = (orderModel.value.status == Constant.rideInProgress);
    } else {
      // Before pickup: show driver to pickup route
      showDriverToPickupRoute.value = (intercityOrderModel.value.status == Constant.rideActive);
      // After pickup: show driver to destination route
      showPickupToDestinationRoute.value = (intercityOrderModel.value.status == Constant.rideInProgress);
    }

    // Update markers and polyline if route visibility changed
    if (wasShowingPickup != showDriverToPickupRoute.value || 
        wasShowingDestination != showPickupToDestinationRoute.value) {
      updateMarkersAndPolyline();
    }
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
        InterCityOrderModel argumentOrderModel = argumentData['interCityOrderModel'];
        FireStoreUtils.fireStore
            .collection(CollectionName.ordersIntercity)
            .doc(argumentOrderModel.id)
            .snapshots()
            .listen((event) {
          if (event.data() != null) {
            intercityOrderModel.value = InterCityOrderModel.fromJson(event.data()!);
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

    if (driverUserModel.value.location == null) {
      return;
    }

    // Always add driver marker
    addDriverMarker();

    if (type.value == "orderModel") {
      if (orderModel.value.sourceLocationLAtLng == null ||
          orderModel.value.destinationLocationLAtLng == null) {
        return;
      }

      // Show pickup phase: driver to pickup location
      if (showDriverToPickupRoute.value) {
        addMarker(
          latitude: orderModel.value.sourceLocationLAtLng!.latitude,
          longitude: orderModel.value.sourceLocationLAtLng!.longitude,
          id: "Departure",
          descriptor: departureIcon!,
          rotation: 0.0,
        );

        getPolyline(
          sourceLatitude: driverUserModel.value.location!.latitude,
          sourceLongitude: driverUserModel.value.location!.longitude,
          destinationLatitude: orderModel.value.sourceLocationLAtLng!.latitude,
          destinationLongitude: orderModel.value.sourceLocationLAtLng!.longitude,
          polylineId: "DriverToPickup",
          color: AppColors.primary,
        );
      }

      // Show destination phase: driver to destination
      if (showPickupToDestinationRoute.value) {
        addMarker(
          latitude: orderModel.value.destinationLocationLAtLng!.latitude,
          longitude: orderModel.value.destinationLocationLAtLng!.longitude,
          id: "Destination",
          descriptor: destinationIcon!,
          rotation: 0.0,
        );

        getPolyline(
          sourceLatitude: driverUserModel.value.location!.latitude,
          sourceLongitude: driverUserModel.value.location!.longitude,
          destinationLatitude: orderModel.value.destinationLocationLAtLng!.latitude,
          destinationLongitude: orderModel.value.destinationLocationLAtLng!.longitude,
          polylineId: "DriverToDestination",
          color: Colors.green,
        );
      }
    } else {
      if (intercityOrderModel.value.sourceLocationLAtLng == null ||
          intercityOrderModel.value.destinationLocationLAtLng == null) {
        return;
      }

      // Show pickup phase: driver to pickup location
      if (showDriverToPickupRoute.value) {
        addMarker(
          latitude: intercityOrderModel.value.sourceLocationLAtLng!.latitude,
          longitude: intercityOrderModel.value.sourceLocationLAtLng!.longitude,
          id: "Departure",
          descriptor: departureIcon!,
          rotation: 0.0,
        );

        getPolyline(
          sourceLatitude: driverUserModel.value.location!.latitude,
          sourceLongitude: driverUserModel.value.location!.longitude,
          destinationLatitude: intercityOrderModel.value.sourceLocationLAtLng!.latitude,
          destinationLongitude: intercityOrderModel.value.sourceLocationLAtLng!.longitude,
          polylineId: "DriverToPickup",
          color: AppColors.primary,
        );
      }

      // Show destination phase: driver to destination
      if (showPickupToDestinationRoute.value) {
        addMarker(
          latitude: intercityOrderModel.value.destinationLocationLAtLng!.latitude,
          longitude: intercityOrderModel.value.destinationLocationLAtLng!.longitude,
          id: "Destination",
          descriptor: destinationIcon!,
          rotation: 0.0,
        );

        getPolyline(
          sourceLatitude: driverUserModel.value.location!.latitude,
          sourceLongitude: driverUserModel.value.location!.longitude,
          destinationLatitude: intercityOrderModel.value.destinationLocationLAtLng!.latitude,
          destinationLongitude: intercityOrderModel.value.destinationLocationLAtLng!.longitude,
          polylineId: "DriverToDestination",
          color: Colors.green,
        );
      }
    }

    updateTimeAndDistanceEstimates();
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
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: Constant.mapAPIKey,
        request: polylineRequest,
      );

      if (result.points.isNotEmpty) {
        polylineCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
        
        // Update route points for current active route
        if ((polylineId == "DriverToPickup" && showDriverToPickupRoute.value) ||
            (polylineId == "DriverToDestination" && showPickupToDestinationRoute.value)) {
          routePoints.value = polylineCoordinates;
        }
      } else {
        print("Debug: No points found for polyline $polylineId: ${result.errorMessage}");
        navigationInstruction.value = "Route unavailable, please try again";
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

  void _addPolyLine(List<LatLng> polylineCoordinates, String polylineId, Color color) {
    if (polylineCoordinates.isEmpty) {
      return;
    }

    PolylineId id = PolylineId(polylineId);
    Polyline polyline = Polyline(
      polylineId: id,
      points: polylineCoordinates,
      color: color,
      width: 6,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      patterns: [],
    );
    polyLines[id] = polyline;
  }

  void updateCameraLocation(LatLng source, LatLng destination) async {
    if (mapController == null) {
      return;
    }

    // If following driver, don't change camera bounds
    if (isFollowingDriver.value) {
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
    isFollowingDriver.value = true;
    isNavigationView.value = true;
    updateNavigationView();
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