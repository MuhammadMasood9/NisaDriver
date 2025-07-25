import 'dart:async';
import 'dart:math';
import 'dart:developer' as dev;
import 'package:sensors_plus/sensors_plus.dart';
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
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:io';
import 'package:retry/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationStep {
  final String instruction;
  final double distance;
  final String maneuver;
  final LatLng location;
  final double duration;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.maneuver,
    required this.location,
    required this.duration,
  });
}

class LiveTrackingController extends GetxController {
  GoogleMapController? mapController;
  Timer? _locationUpdateTimer;
  Timer? _estimationUpdateTimer;
  Timer? _autoNavigationTimer;
  Timer? _trafficUpdateTimer;
  FlutterTts? _flutterTts;
  StreamSubscription<Position>? _positionStream;
  DateTime? _lastRerouteTime;
  StreamSubscription<CompassEvent>? _compassSubscription;
  RxList<double> announcedDistances = <double>[].obs;
  Rx<DriverUserModel> driverUserModel = DriverUserModel().obs;
  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<InterCityOrderModel> intercityOrderModel = InterCityOrderModel().obs;

  Rx<Position?> currentPosition = Rx<Position?>(null);
  RxDouble compassHeading =
      0.0.obs; // Bearing from device compass for marker rotation
  RxDouble mapBearing =
      0.0.obs; // Bearing for map camera rotation (direction of travel)
  RxBool isLocationPermissionGranted = false.obs;
  Rx<TextEditingController> otpController = TextEditingController().obs;
  RxBool isLoading = true.obs;
  RxString type = "".obs;
  RxString status = "".obs;
  RxDouble distance = 0.0.obs;
  RxString estimatedTime = "Calculating...".obs;
  RxString estimatedArrival = "Calculating...".obs;
  RxBool isFollowingDriver = true.obs;
  RxString navigationInstruction = "".obs;
  RxString nextTurnInstruction = "".obs;
  RxDouble distanceToNextTurn = 0.0.obs;
  RxString currentManeuver = "straight".obs;

  RxBool isVoiceEnabled = true.obs;
  RxBool isAutoNavigationEnabled = true.obs;
  RxBool isNightMode = false.obs;
  RxDouble currentSpeed = 0.0.obs;
  RxString speedLimit = "".obs;
  RxBool isOffRoute = false.obs;
  RxInt trafficLevel = 0.obs;

  RxList<NavigationStep> navigationSteps = <NavigationStep>[].obs;
  RxInt currentStepIndex = 0.obs;

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

  RxBool isNavigationView = true.obs;
  RxDouble navigationZoom = 16.0.obs;
  RxInt nextRoutePointIndex = 0.obs;
  Position? _previousPosition;
  DateTime? _previousTime;

  RxList<String> currentLanes = <String>[].obs;
  RxString recommendedLane = "".obs;

  final List<Map<String, dynamic>> _ttsQueue = [];
  bool _isSpeaking = false;

  @override
  void onInit() {
    super.onInit();
    addMarkerSetup();
    initializeTTS();
    initializeLocationServices(); // This now also starts location tracking
    _initializeCompass();
    getArgument();
    isFollowingDriver.value = true;
    isNavigationView.value = true;

    // Fetch initial location and center immediately
    getCurrentLocation().then((_) {
      addDeviceMarker();
      updateNavigationView();
      updateMarkersAndPolyline();
    });

    startEstimationUpdates();
    startAutoNavigation();
    startTrafficUpdates();
  }

  @override
  void onClose() {
    _locationUpdateTimer?.cancel();
    _estimationUpdateTimer?.cancel();
    _autoNavigationTimer?.cancel();
    _trafficUpdateTimer?.cancel();
    _positionStream?.cancel();
    _compassSubscription?.cancel();
    mapController?.dispose();
    _flutterTts?.stop();
    ShowToastDialog.closeLoader();
    super.onClose();
  }

  void initializeTTS() async {
    _flutterTts = FlutterTts();
    await _flutterTts?.setLanguage("en-US");
    await _flutterTts?.setSpeechRate(0.5);
    await _flutterTts?.setVolume(1.0);
    await _flutterTts?.setPitch(1.0);
    if (Platform.isAndroid) {
      await _flutterTts?.setQueueMode(1);
    }
  }

  void queueAnnouncement(String text, {int priority = 1}) {
    _ttsQueue.add({'text': text, 'priority': priority});
    _ttsQueue.sort((a, b) => b['priority'].compareTo(a['priority']));
    _processTtsQueue();
  }

  void _processTtsQueue() async {
    if (_isSpeaking || _ttsQueue.isEmpty || !isVoiceEnabled.value) return;
    _isSpeaking = true;
    var announcement = _ttsQueue.removeAt(0);
    await _flutterTts?.speak(announcement['text']);
    await _flutterTts?.awaitSpeakCompletion(true);
    _isSpeaking = false;
    _processTtsQueue();
  }

  Future<void> initializeLocationServices() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ShowToastDialog.showToast("Please enable location services");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ShowToastDialog.showToast("Location permissions denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ShowToastDialog.showToast("Location permissions permanently denied");
      return;
    }

    isLocationPermissionGranted.value = true;
    _startLocationUpdates(); // Start tracking once permissions are confirmed
  }

  void _initializeCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        compassHeading.value = event.heading!;
        // Update marker rotation in real-time for responsiveness
        if (markers.containsKey(const MarkerId("Device"))) {
          final Marker marker = markers[const MarkerId("Device")]!;
          markers[const MarkerId("Device")] = marker.copyWith(
            rotationParam: compassHeading.value,
          );
        }
      }
    });
  }

  void _startLocationUpdates() {
    _positionStream?.cancel();
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: currentSpeed.value > 50 ? 5 : 2, // Optimized filter
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) => updateDeviceLocation(position),
      onError: (error) {
        ShowToastDialog.showToast("Error tracking location. Please check GPS.");
        Future.delayed(Duration(seconds: 5), () => _startLocationUpdates());
      },
    );
  }

  void updateDeviceLocation(Position position) {
    currentPosition.value = position;
    currentSpeed.value = position.speed * 3.6;

    _previousPosition = position;
    _previousTime = DateTime.now();

    _updateMapBearing(); // Calculate bearing for the map camera

    addDeviceMarker(); // Update marker position and initial bearing

    if (isFollowingDriver.value && isNavigationView.value) {
      updateNavigationView();
    }

    fetchSpeedLimit(LatLng(position.latitude, position.longitude));
    updateRouteVisibility();
    updateNavigationInstructions();
    updateNextRoutePoint();
    checkOffRoute();
    updateTimeAndDistanceEstimates();
    updateDynamicPolyline();
  }

  void addDeviceMarker() {
    if (currentPosition.value == null) return;
    markers.removeWhere((key, value) => key.value == "Device");
    addMarker(
      latitude: currentPosition.value!.latitude,
      longitude: currentPosition.value!.longitude,
      id: "Device",

      descriptor: driverIcon!,
      rotation: compassHeading.value, // Use compass bearing for marker
    );
  }

  void _updateMapBearing() {
    if (currentPosition.value == null) return;

    double newBearing;

    // Prioritize GPS heading if moving and accurate
    if (currentSpeed.value > 5.0 &&
        currentPosition.value!.headingAccuracy < 45.0 &&
        currentPosition.value!.heading >= 0) {
      newBearing = currentPosition.value!.heading;
    }
    // Otherwise, calculate bearing towards the next route point
    else if (routePoints.isNotEmpty) {
      LatLng devicePos = LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude);
      LatLng nextPoint = getNextRoutePoint(devicePos);
      newBearing = _calculateBearing(devicePos, nextPoint);
    }
    // Fallback to the last known bearing
    else {
      newBearing = mapBearing.value;
    }

    // Smooth the transition for the map camera
    mapBearing.value = _smoothBearing(mapBearing.value, newBearing);
  }

  double _smoothBearing(double oldBearing, double newBearing) {
    double diff = (newBearing - oldBearing) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (oldBearing + 0.3 * diff) % 360;
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double startLat = start.latitude * pi / 180;
    double startLng = start.longitude * pi / 180;
    double endLat = end.latitude * pi / 180;
    double endLng = end.longitude * pi / 180;

    double deltaLng = endLng - startLng;

    double y = sin(deltaLng) * cos(endLat);
    double x = cos(startLat) * sin(endLat) -
        sin(startLat) * cos(endLat) * cos(deltaLng);
    double bearing = atan2(y, x) * 180 / pi;

    return (bearing + 360) % 360;
  }

  LatLng getNextRoutePoint(LatLng devicePos) {
    if (routePoints.isEmpty) return getTargetLocation();

    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length; i++) {
      double dist = calculateDistanceBetweenPoints(
        devicePos.latitude,
        devicePos.longitude,
        routePoints[i].latitude,
        routePoints[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    int lookAheadDistance = currentSpeed.value > 30 ? 15 : 8;
    return routePoints[
        min(closestIndex + lookAheadDistance, routePoints.length - 1)];
  }

  LatLng getTargetLocation() {
    if (type.value == "orderModel") {
      if (orderModel.value.status == Constant.rideInProgress) {
        return LatLng(orderModel.value.destinationLocationLAtLng!.latitude!,
            orderModel.value.destinationLocationLAtLng!.longitude!);
      } else {
        return LatLng(orderModel.value.sourceLocationLAtLng!.latitude!,
            orderModel.value.sourceLocationLAtLng!.longitude!);
      }
    } else {
      if (intercityOrderModel.value.status == Constant.rideInProgress) {
        return LatLng(
            intercityOrderModel.value.destinationLocationLAtLng!.latitude!,
            intercityOrderModel.value.destinationLocationLAtLng!.longitude!);
      } else {
        return LatLng(intercityOrderModel.value.sourceLocationLAtLng!.latitude!,
            intercityOrderModel.value.sourceLocationLAtLng!.longitude!);
      }
    }
  }

  void startEstimationUpdates() {
    _estimationUpdateTimer?.cancel();
    _estimationUpdateTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) {
      updateTimeAndDistanceEstimates();
    });
  }

  void startAutoNavigation() {
    _autoNavigationTimer?.cancel();
    _autoNavigationTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (isAutoNavigationEnabled.value) {
        updateAutoNavigation();
      }
    });
  }

  void startTrafficUpdates() {
    _trafficUpdateTimer?.cancel();
    _trafficUpdateTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      updateMarkersAndPolyline();
    });
  }

  void updateAutoNavigation() {
    if (!isAutoNavigationEnabled.value ||
        routePoints.isEmpty ||
        currentPosition.value == null) return;

    LatLng devicePos = LatLng(
        currentPosition.value!.latitude, currentPosition.value!.longitude);
    checkUpcomingTurns(devicePos);
    adjustCameraForNavigation(devicePos);
    updateLaneGuidance();
  }

  void resetToDefaultView() {
    isFollowingDriver.value = true;
    isNavigationView.value = true;
    polyLines.clear(); // Clear polylines when resetting view
    updateNavigationView();
    updateMarkersAndPolyline();
  }

  void checkUpcomingTurns(LatLng devicePos) async {
    if (navigationSteps.isEmpty ||
        currentStepIndex.value >= navigationSteps.length) return;

    NavigationStep currentStep = navigationSteps[currentStepIndex.value];
    double distanceToStep = await calculateDistance(
      devicePos.latitude,
      devicePos.longitude,
      currentStep.location.latitude,
      currentStep.location.longitude,
    );

    distanceToNextTurn.value = distanceToStep;
    currentManeuver.value = currentStep.maneuver;

    if (isVoiceEnabled.value) {
      const List<double> announcementDistances = [200, 100, 50, 20];
      double? targetDistance;
      for (var dist in announcementDistances) {
        if (distanceToStep <= dist && distanceToStep > (dist - 10)) {
          targetDistance = dist;
          break;
        }
      }

      if (targetDistance != null &&
          !announcedDistances.contains(targetDistance)) {
        String announcement = targetDistance == 20
            ? "Now: ${currentStep.instruction}"
            : currentStep.instruction;
        queueAnnouncement(announcement, priority: 2);
        announcedDistances.add(targetDistance);
      }
    }

    if (distanceToStep < 10) {
      currentStepIndex.value =
          min(currentStepIndex.value + 1, navigationSteps.length - 1);
      announcedDistances.clear();
      updateNavigationInstructions();
    }
  }

  void adjustCameraForNavigation(LatLng devicePos) {
    navigationZoom.value = showDriverToPickupRoute.value ? 16.0 : 15.0;

    if (currentSpeed.value < 5)
      navigationZoom.value += 0.5;
    else if (currentSpeed.value > 50) navigationZoom.value -= 0.5;

    if (distanceToNextTurn.value < 150) navigationZoom.value += 0.5;

    navigationZoom.value = navigationZoom.value.clamp(14.0, 17.0);

    if (mapController != null && isFollowingDriver.value) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: devicePos,
            zoom: navigationZoom.value,
            tilt: 0.0, // Set to 0.0 for 2D view
            bearing: mapBearing.value, // Use map bearing for camera rotation
          ),
        ),
      );
    }
  }

  void onMapTap(LatLng position) {
    isFollowingDriver.value = false;
    Timer(Duration(seconds: 8), () {
      if (!isFollowingDriver.value) {
        isFollowingDriver.value = true;
        polyLines.clear(); // Clear polylines when recentering
        updateNavigationView();
      }
    });
  }

  void updateLaneGuidance() {
    if (distanceToNextTurn.value < 300) {
      if (currentManeuver.value.contains("right")) {
        currentLanes.value = ["straight", "straight", "right", "right"];
        recommendedLane.value = "right";
      } else if (currentManeuver.value.contains("left")) {
        currentLanes.value = ["left", "left", "straight", "straight"];
        recommendedLane.value = "left";
      } else if (currentManeuver.value.contains("roundabout")) {
        currentLanes.value = ["roundabout", "roundabout"];
        recommendedLane.value = "roundabout";
      } else {
        currentLanes.value = ["straight", "straight"];
        recommendedLane.value = "straight";
      }
    } else {
      currentLanes.clear();
      recommendedLane.value = "";
    }
  }

  void checkOffRoute() async {
    if (routePoints.isEmpty || currentPosition.value == null) return;

    LatLng devicePos = LatLng(
        currentPosition.value!.latitude, currentPosition.value!.longitude);
    double minDistanceToRoute = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < routePoints.length; i++) {
      double distance = await calculateDistance(
        devicePos.latitude,
        devicePos.longitude,
        routePoints[i].latitude,
        routePoints[i].longitude,
      );
      if (distance < minDistanceToRoute) {
        minDistanceToRoute = distance;
        closestIndex = i;
      }
    }

    bool wasOffRoute = isOffRoute.value;
    isOffRoute.value = minDistanceToRoute > 25;

    if (isOffRoute.value && !wasOffRoute) {
      queueAnnouncement("You are off route. Recalculating route.", priority: 3);
      polyLines.clear();
      recalculateRoute();
    } else if (!isOffRoute.value && wasOffRoute) {
      queueAnnouncement("Back on route. Continue following the path.",
          priority: 3);
      polyLines.remove(PolylineId("ReturnToRoute"));
      nextRoutePointIndex.value = closestIndex;
      updateDynamicPolyline();
    }
  }

  void updateDynamicPolyline() {
    if (routePoints.isEmpty || currentPosition.value == null) return;

    LatLng devicePos = LatLng(
        currentPosition.value!.latitude, currentPosition.value!.longitude);
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length; i++) {
      double dist = calculateDistanceBetweenPoints(
        devicePos.latitude,
        devicePos.longitude,
        routePoints[i].latitude,
        routePoints[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    List<LatLng> remainingPoints = routePoints.sublist(closestIndex);
    String polylineId = showDriverToPickupRoute.value
        ? "DeviceToPickup"
        : "DeviceToDestination";
    Color color =
        showDriverToPickupRoute.value ? AppColors.primary : Colors.black;

    polyLines.clear();
    _addPolyLine(remainingPoints, polylineId, color);
  }

  void updateNextRoutePoint() {
    if (routePoints.isEmpty || currentPosition.value == null) return;

    LatLng devicePos = LatLng(
        currentPosition.value!.latitude, currentPosition.value!.longitude);
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length; i++) {
      double dist = calculateDistanceBetweenPoints(
        devicePos.latitude,
        devicePos.longitude,
        routePoints[i].latitude,
        routePoints[i].longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    nextRoutePointIndex.value = min(closestIndex + 5, routePoints.length - 1);
  }

  void updateTimeAndDistanceEstimates() async {
    if (currentPosition.value == null) return;

    LatLng targetLocation = getTargetLocation();
    double distanceInMeters = await calculateDistance(
      currentPosition.value!.latitude,
      currentPosition.value!.longitude,
      targetLocation.latitude,
      targetLocation.longitude,
    );

    distance.value = distanceInMeters / 1000;
    double adjustedSpeed = 40.0 * getTrafficSpeedMultiplier();
    int minutes = (distance.value / adjustedSpeed * 60).round();
    estimatedTime.value = minutes < 1 ? "Less than 1 min" : "$minutes min";

    DateTime arrival = DateTime.now().add(Duration(minutes: minutes));
    estimatedArrival.value = DateFormat('hh:mm a').format(arrival);

    updateTripProgress();
  }

  double getTrafficSpeedMultiplier() {
    return trafficLevel.value == 2
        ? 0.6
        : trafficLevel.value == 1
            ? 0.8
            : 1.0;
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
          orderModel.value.destinationLocationLAtLng!.longitude!,
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
          intercityOrderModel.value.destinationLocationLAtLng!.longitude!,
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
      return await Geolocator.distanceBetween(
          startLat, startLng, endLat, endLng);
    } catch (e) {
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
    if (mapController == null || currentPosition.value == null) return;
    LatLng deviceLocation = LatLng(
        currentPosition.value!.latitude, currentPosition.value!.longitude);
    await mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: deviceLocation,
          zoom: navigationZoom.value,
          tilt: 0.0, // Set to 0.0 for 2D view
          bearing: mapBearing.value, // Use map bearing for camera rotation
        ),
      ),
    );
  }

  void updateNavigationInstructions() async {
    if (navigationSteps.isEmpty ||
        currentStepIndex.value >= navigationSteps.length) {
      navigationInstruction.value = "Follow route";
      nextTurnInstruction.value = "";
      announcedDistances.clear();
      return;
    }

    NavigationStep currentStep = navigationSteps[currentStepIndex.value];
    navigationInstruction.value = currentStep.instruction;

    if (currentStepIndex.value + 1 < navigationSteps.length) {
      nextTurnInstruction.value =
          navigationSteps[currentStepIndex.value + 1].instruction;
    } else {
      nextTurnInstruction.value = showDriverToPickupRoute.value
          ? "Nearing pickup"
          : "Nearing destination";
    }
  }

  void updateRouteVisibility() {
    bool wasShowingPickup = showDriverToPickupRoute.value;
    bool wasShowingDestination = showPickupToDestinationRoute.value;

    if (type.value == "orderModel") {
      showDriverToPickupRoute.value =
          (orderModel.value.status == Constant.rideActive);
      showPickupToDestinationRoute.value =
          (orderModel.value.status == Constant.rideInProgress);
    } else {
      showDriverToPickupRoute.value =
          (intercityOrderModel.value.status == Constant.rideActive);
      showPickupToDestinationRoute.value =
          (intercityOrderModel.value.status == Constant.rideInProgress);
    }

    if (wasShowingPickup != showDriverToPickupRoute.value ||
        wasShowingDestination != showPickupToDestinationRoute.value) {
      polyLines.clear(); // Clear polylines when route visibility changes
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
            if (orderModel.value.status == Constant.rideComplete) Get.back();
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
            if (intercityOrderModel.value.status == Constant.rideComplete)
              Get.back();
          }
        });
      }
    }
    isLoading.value = false;
    update();
    updateRouteVisibility();
  }

  void updateMarkersAndPolyline() {
    markers.clear();
    polyLines.clear();

    if (currentPosition.value == null) {
      ShowToastDialog.showToast("Waiting for location...");
      getCurrentLocation().then((_) => updateMarkersAndPolyline());
      return;
    }

    addDeviceMarker();

    if (type.value == "orderModel") {
      if (showDriverToPickupRoute.value) {
        addMarker(
          latitude: orderModel.value.sourceLocationLAtLng!.latitude,
          longitude: orderModel.value.sourceLocationLAtLng!.longitude,
          id: "Departure",
          descriptor: departureIcon!,
          rotation: 0.0,
        );
        getPolyline(
          sourceLatitude: currentPosition.value!.latitude,
          sourceLongitude: currentPosition.value!.longitude,
          destinationLatitude: orderModel.value.sourceLocationLAtLng!.latitude,
          destinationLongitude:
              orderModel.value.sourceLocationLAtLng!.longitude,
          polylineId: "DeviceToPickup",
          color: AppColors.primary,
        );
      }
      if (showPickupToDestinationRoute.value) {
        addMarker(
          latitude: orderModel.value.destinationLocationLAtLng!.latitude,
          longitude: orderModel.value.destinationLocationLAtLng!.longitude,
          id: "Destination",
          descriptor: destinationIcon!,
          rotation: 0.0,
        );
        getPolyline(
          sourceLatitude: currentPosition.value!.latitude,
          sourceLongitude: currentPosition.value!.longitude,
          destinationLatitude:
              orderModel.value.destinationLocationLAtLng!.latitude,
          destinationLongitude:
              orderModel.value.destinationLocationLAtLng!.longitude,
          polylineId: "DeviceToDestination",
          color: Colors.black,
        );
      }
    } else {
      if (showDriverToPickupRoute.value) {
        addMarker(
          latitude: intercityOrderModel.value.sourceLocationLAtLng!.latitude,
          longitude: intercityOrderModel.value.sourceLocationLAtLng!.longitude,
          id: "Departure",
          descriptor: departureIcon!,
          rotation: 0.0,
        );
        getPolyline(
          sourceLatitude: currentPosition.value!.latitude,
          sourceLongitude: currentPosition.value!.longitude,
          destinationLatitude:
              intercityOrderModel.value.sourceLocationLAtLng!.latitude,
          destinationLongitude:
              intercityOrderModel.value.sourceLocationLAtLng!.longitude,
          polylineId: "DeviceToPickup",
          color: AppColors.primary,
        );
      }
      if (showPickupToDestinationRoute.value) {
        addMarker(
          latitude:
              intercityOrderModel.value.destinationLocationLAtLng!.latitude,
          longitude:
              intercityOrderModel.value.destinationLocationLAtLng!.longitude,
          id: "Destination",
          descriptor: destinationIcon!,
          rotation: 0.0,
        );
        getPolyline(
          sourceLatitude: currentPosition.value!.latitude,
          sourceLongitude: currentPosition.value!.longitude,
          destinationLatitude:
              intercityOrderModel.value.destinationLocationLAtLng!.latitude,
          destinationLongitude:
              intercityOrderModel.value.destinationLocationLAtLng!.longitude,
          polylineId: "DeviceToDestination",
          color: Colors.black,
        );
      }
    }

    updateTimeAndDistanceEstimates();
    updateNavigationView();
  }

  Future<Map<String, dynamic>?> fetchDirections({
    required double sourceLatitude,
    required double sourceLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    const retryOptions = RetryOptions(
        maxAttempts: 3,
        delayFactor: Duration(seconds: 1),
        maxDelay: Duration(seconds: 5));
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String cacheKey =
        "$sourceLatitude,$sourceLongitude-$destinationLatitude,$destinationLongitude";
    String? cachedDirections = prefs.getString(cacheKey);
    DateTime? lastFetchTime = prefs.getString("${cacheKey}_time") != null
        ? DateTime.parse(prefs.getString("${cacheKey}_time")!)
        : null;

    if (cachedDirections != null &&
        lastFetchTime != null &&
        DateTime.now().difference(lastFetchTime).inMinutes < 5) {
      return json.decode(cachedDirections);
    }

    try {
      return await retry(() async {
        final String url =
            'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=$sourceLatitude,$sourceLongitude&'
            'destination=$destinationLatitude,$destinationLongitude&'
            'mode=driving&'
            'departure_time=now&'
            'traffic_model=best_guess&'
            'key=${Constant.mapAPIKey}';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          Map<String, dynamic> data = json.decode(response.body);
          if (data['status'] == 'OK') {
            await prefs.setString(cacheKey, json.encode(data));
            await prefs.setString(
                "${cacheKey}_time", DateTime.now().toIso8601String());
            return data;
          } else {
            throw Exception('Directions API error: ${data['status']}');
          }
        } else {
          throw Exception('HTTP error: ${response.statusCode}');
        }
      }, retryIf: (e) => e is SocketException || e is TimeoutException);
    } catch (e) {
      if (cachedDirections != null) return json.decode(cachedDirections);
      return null;
    }
  }

  Future<void> fetchSpeedLimit(LatLng position) async {
    speedLimit.value = "50";
    if (currentSpeed.value > double.parse(speedLimit.value)) {
      queueAnnouncement(
          "You are exceeding the speed limit of ${speedLimit.value} km/h.",
          priority: 3);
    }
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
        destinationLongitude == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String cacheKey =
        "$sourceLatitude,$sourceLongitude-$destinationLatitude,$destinationLongitude";
    String? cachedPolyline = prefs.getString(cacheKey);
    if (cachedPolyline != null) {
      List<PointLatLng> decodedPoints =
          polylinePoints.decodePolyline(cachedPolyline);
      List<LatLng> polylineCoordinates = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
      if ((polylineId == "DeviceToPickup" && showDriverToPickupRoute.value) ||
          (polylineId == "DeviceToDestination" &&
              showPickupToDestinationRoute.value)) {
        routePoints.value = polylineCoordinates;
      }
      _addPolyLine(polylineCoordinates, polylineId, color);
      updateDynamicPolyline();
      return;
    }

    Map<String, dynamic>? directionsData = await fetchDirections(
      sourceLatitude: sourceLatitude,
      sourceLongitude: sourceLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
    );

    if (directionsData == null ||
        directionsData['status'] != 'OK' ||
        directionsData['routes'].isEmpty) {
      navigationInstruction.value = "Route unavailable, please try again";
      ShowToastDialog.showToast("Failed to load route");
      return;
    }

    String encodedPolyline =
        directionsData['routes'][0]['overview_polyline']['points'];
    List<PointLatLng> decodedPoints =
        polylinePoints.decodePolyline(encodedPolyline);
    List<LatLng> polylineCoordinates = decodedPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    await prefs.setString(cacheKey, encodedPolyline);

    if ((polylineId == "DeviceToPickup" && showDriverToPickupRoute.value) ||
        (polylineId == "DeviceToDestination" &&
            showPickupToDestinationRoute.value)) {
      routePoints.value = polylineCoordinates;
      parseNavigationSteps(directionsData);
      updateTrafficLevel(directionsData);
    }

    _addPolyLine(polylineCoordinates, polylineId, color);
    updateDynamicPolyline();
  }

  void parseNavigationSteps(Map<String, dynamic> directionsData) {
    navigationSteps.clear();
    currentStepIndex.value = 0;

    List<dynamic> steps = directionsData['routes'][0]['legs'][0]['steps'];
    for (var step in steps) {
      String instruction =
          _stripHtmlTags(step['html_instructions'] ?? "Continue");
      double distance = (step['distance']['value'] ?? 0).toDouble();
      String maneuver = step['maneuver'] ?? "straight";
      LatLng location =
          LatLng(step['end_location']['lat'], step['end_location']['lng']);
      navigationSteps.add(NavigationStep(
        instruction: _simplifyInstruction(maneuver, distance),
        distance: distance,
        maneuver: maneuver,
        location: location,
        duration: (step['duration']['value'] ?? 0).toDouble(),
      ));
    }
    updateNavigationInstructions();
  }

  String _simplifyInstruction(String maneuver, double distance) {
    String formattedDistance = formatDistance(distance / 1000);
    switch (maneuver) {
      case 'turn-left':
        return "Left in $formattedDistance";
      case 'turn-right':
        return "Right in $formattedDistance";
      case 'turn-sharp-left':
        return "Sharp left in $formattedDistance";
      case 'turn-sharp-right':
        return "Sharp right in $formattedDistance";
      case 'turn-slight-left':
        return "Slight left in $formattedDistance";
      case 'turn-slight-right':
        return "Slight right in $formattedDistance";
      case 'roundabout-left':
      case 'roundabout-right':
        return "Roundabout in $formattedDistance";
      case 'straight':
        return "Continue $formattedDistance Straight";
      default:
        return "Proceed $formattedDistance";
    }
  }

  String _stripHtmlTags(String htmlText) {
    final RegExp exp = RegExp(r'<[^>]+>', multiLine: true);
    return htmlText.replaceAll(exp, '').trim();
  }

  void updateTrafficLevel(Map<String, dynamic> directionsData) {
    double duration =
        (directionsData['routes'][0]['legs'][0]['duration']['value'] ?? 0)
            .toDouble();
    double durationInTraffic = (directionsData['routes'][0]['legs'][0]
                ['duration_in_traffic']?['value'] ??
            duration)
        .toDouble();

    if (duration > 0) {
      double trafficRatio = durationInTraffic / duration;
      trafficLevel.value = trafficRatio > 1.5
          ? 2
          : trafficRatio > 1.2
              ? 1
              : 0;
      if (isVoiceEnabled.value && trafficLevel.value > 0) {
        queueAnnouncement(getTrafficLevelText(), priority: 1);
      }
    }
  }

  void addMarker({
    required double? latitude,
    required double? longitude,
    required String id,
    required BitmapDescriptor descriptor,
    required double? rotation,
  }) {
    if (latitude == null || longitude == null) return;

    MarkerId markerId = MarkerId(id);
    String title = id == "Departure"
        ? "Pickup Location"
        : id == "Destination"
            ? "Destination"
            : "Your Location";
    String snippet = id == "Device"
        ? "Current Position"
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
    final Uint8List departure =
        await Constant().getBytesFromAsset('assets/images/pickup.png', 50);
    final Uint8List destination =
        await Constant().getBytesFromAsset('assets/images/dropoff.png', 50);
    final Uint8List driver =
        await Constant().getBytesFromAsset('assets/images/ic_cab.png', 60);
    departureIcon = BitmapDescriptor.fromBytes(departure);
    destinationIcon = BitmapDescriptor.fromBytes(destination);
    driverIcon = BitmapDescriptor.fromBytes(driver);
  }

  void _addPolyLine(
      List<LatLng> polylineCoordinates, String polylineId, Color color) {
    if (polylineCoordinates.isEmpty) return;

    PolylineId id = PolylineId(polylineId);
    Polyline polyline = Polyline(
      polylineId: id,
      points: polylineCoordinates,
      color: color,
      width: 6,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      patterns:
          isOffRoute.value ? [PatternItem.dash(10), PatternItem.gap(5)] : [],
    );
    polyLines[id] = polyline;
  }

  void updateCameraLocation(LatLng source, LatLng destination) async {
    if (mapController == null || isFollowingDriver.value) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(min(source.latitude, destination.latitude),
          min(source.longitude, destination.longitude)),
      northeast: LatLng(max(source.latitude, destination.latitude),
          max(source.longitude, destination.longitude)),
    );

    CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 100);
    await mapController!.animateCamera(cameraUpdate);
  }

  void toggleMapView() {
    isFollowingDriver.value = true;
    isNavigationView.value = true;
    polyLines.clear(); // Clear polylines when toggling view
    updateNavigationView();
    updateMarkersAndPolyline();
  }

  void toggleVoiceGuidance() {
    isVoiceEnabled.value = !isVoiceEnabled.value;
    if (!isVoiceEnabled.value) {
      _flutterTts?.stop();
      ShowToastDialog.showToast("Voice guidance disabled");
    } else {
      ShowToastDialog.showToast("Voice guidance enabled");
    }
  }

  void toggleAutoNavigation() {
    isAutoNavigationEnabled.value = !isAutoNavigationEnabled.value;
    ShowToastDialog.showToast(
        "Auto navigation ${isAutoNavigationEnabled.value ? 'enabled' : 'disabled'}");
  }

  void toggleNightMode() {
    isNightMode.value = !isNightMode.value;
    if (mapController != null) {
      String mapStyle = isNightMode.value ? _getNightModeStyle() : '';
      mapController!.setMapStyle(mapStyle);
    }
    ShowToastDialog.showToast(
        "Night mode ${isNightMode.value ? 'enabled' : 'disabled'}");
  }

  String _getNightModeStyle() {
    return '''
    [
      {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
      {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
      {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
      {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
      {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
      {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
      {"featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [{"color": "#ffffff"}]},
      {"featureType": "road.highway", "elementType": "geometry.fill", "stylers": [{"color": "#3c3c3c"}]},
      {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#ffffff"}]},
      {"featureType": "water", "elementType": "geometry.fill", "stylers": [{"color": "#000000"}]}
    ]
    ''';
  }

  void recalculateRoute() {
    if (currentPosition.value == null ||
        (_lastRerouteTime != null &&
            DateTime.now().difference(_lastRerouteTime!).inSeconds < 10))
      return;

    _lastRerouteTime = DateTime.now();
    polyLines.clear();
    updateMarkersAndPolyline();
    isOffRoute.value = false;
  }

  void centerMapOnDriver() {
    isFollowingDriver.value = true;
    isNavigationView.value = true;
    polyLines.clear(); // Clear polylines when centering on driver
    updateNavigationView();
    updateMarkersAndPolyline();
  }

  void reportTraffic(int level) {
    trafficLevel.value = level.clamp(0, 2);
    updateTimeAndDistanceEstimates();
    if (isVoiceEnabled.value) {
      queueAnnouncement(getTrafficLevelText(), priority: 1);
    }
  }

  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) return "${(distanceInKm * 1000).round()}m";
    return "${distanceInKm.toStringAsFixed(1)}km";
  }

  String formatSpeed(double speedKmh) {
    return "${speedKmh.toStringAsFixed(0)} km/h";
  }

  String getTrafficLevelText() {
    return trafficLevel.value == 2
        ? "Heavy traffic ahead"
        : trafficLevel.value == 1
            ? "Moderate traffic ahead"
            : "Light traffic";
  }

  Color getTrafficLevelColor() {
    return trafficLevel.value == 2
        ? Colors.red
        : trafficLevel.value == 1
            ? Colors.orange
            : Colors.green;
  }

  void emergencyStop() async {
    await _flutterTts?.speak("Emergency stop activated");
    isAutoNavigationEnabled.value = false;
    ShowToastDialog.showToast("Emergency stop activated");
  }

  void shareLocation() {
    if (currentPosition.value != null) {
      String locationUrl =
          "https://maps.google.com/?q=${currentPosition.value!.latitude},${currentPosition.value!.longitude}";
      ShowToastDialog.showToast("Location shared: $locationUrl");
    }
  }

  Future<double?> testLiveBearing() async {
    try {
      CompassEvent? event =
          await FlutterCompass.events!.first.timeout(Duration(seconds: 5));
      if (event?.heading == null ||
          event!.heading! < 0 ||
          event.heading! > 360) {
        ShowToastDialog.showToast("Invalid compass data, please calibrate");
        return null;
      }
      return event.heading;
    } catch (e) {
      ShowToastDialog.showToast("Error accessing compass");
      return null;
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      updateDeviceLocation(position);
    } catch (e) {
      ShowToastDialog.showToast("Error getting current location");
    }
  }

  void simulateMovement() {
    if (currentPosition.value == null) return;

    Timer.periodic(Duration(seconds: 2), (timer) {
      if (currentPosition.value != null) {
        double newLat = currentPosition.value!.latitude +
            (Random().nextDouble() - 0.5) * 0.001;
        double newLng = currentPosition.value!.longitude +
            (Random().nextDouble() - 0.5) * 0.001;

        Position simulatedPosition = Position(
          latitude: newLat,
          longitude: newLng,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0,
          heading: _calculateBearing(
            LatLng(currentPosition.value!.latitude,
                currentPosition.value!.longitude),
            LatLng(newLat, newLng),
          ),
          speed: Random().nextDouble() * 20,
          speedAccuracy: 1.0,
          altitudeAccuracy: 1.0,
          headingAccuracy: 10.0,
        );

        updateDeviceLocation(simulatedPosition);
      }
    });
  }
}
