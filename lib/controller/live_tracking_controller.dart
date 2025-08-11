import 'dart:async';
import 'dart:math';
import 'dart:developer' as dev;
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
  RxBool isLaneGuidanceEnabled = true.obs; // Add lane guidance toggle
  RxDouble currentSpeed = 0.0.obs;
  RxString speedLimit = "".obs;
  RxBool isOffRoute = false.obs;
  RxInt trafficLevel = 0.obs;
  RxString currentLaneGuidance = "".obs; // Add current lane guidance text
  RxDouble currentSpeedLimit = 50.0.obs; // Add current speed limit

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
  LatLng? _predictedPosition; // New field for predictive positioning

  RxList<String> currentLanes = <String>[].obs;
  RxString recommendedLane = "".obs;

  final List<Map<String, dynamic>> _ttsQueue = [];
  bool _isSpeaking = false;
  RxBool _betterRouteAvailable =
      false.obs; // New field for better route availability
  Map<String, dynamic>? _betterRouteData; // New field for better route data
  int _timeSaved = 0; // New field for time saved

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
    // Use high accuracy without an aggressive time limit to avoid frequent timeouts
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      // Slightly relaxed distance filter for stability; still very responsive
      distanceFilter:
          currentSpeed.value > 80 ? 10 : (currentSpeed.value > 40 ? 5 : 3),
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) => updateDeviceLocation(position),
      onError: (error) {
        // Avoid noisy toasts on benign timeouts; just restart with a short delay
        if (error is TimeoutException) {
          dev.log('Position stream timeout; restarting location updates');
        } else {
          ShowToastDialog.showToast(
              "Error tracking location. Please check GPS.");
          print("Error tracking location. Please check GPS.$error");
        }
        Future.delayed(const Duration(seconds: 2), _startLocationUpdates);
      },
    );
  }

  void updateDeviceLocation(Position position) {
    // Validate position accuracy
    if (position.accuracy > 20) {
      // Skip low accuracy positions to prevent jitter
      return;
    }

    currentPosition.value = position;
    currentSpeed.value = position.speed * 3.6;

    // Calculate acceleration for predictive movement
    double? acceleration;
    if (_previousPosition != null && _previousTime != null) {
      double timeDiff =
          DateTime.now().difference(_previousTime!).inMilliseconds / 1000.0;
      if (timeDiff > 0) {
        double speedDiff =
            (currentSpeed.value - (_previousPosition!.speed * 3.6));
        acceleration = speedDiff / timeDiff;
      }
    }

    _previousPosition = position;
    _previousTime = DateTime.now();

    _updateMapBearing(); // Calculate bearing for the map camera
    _updatePredictivePosition(acceleration); // Add predictive positioning

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

    // Real-time traffic and route optimization
    if (currentSpeed.value < 5 && trafficLevel.value > 0) {
      _optimizeRouteForTraffic();
    }
  }

  // Add predictive positioning for smoother camera movement
  void _updatePredictivePosition(double? acceleration) {
    if (currentPosition.value == null || acceleration == null) return;

    // Predict position 2 seconds ahead based on current speed and acceleration
    double predictedLat = currentPosition.value!.latitude;
    double predictedLng = currentPosition.value!.longitude;

    if (currentSpeed.value > 5) {
      double timeAhead = 2.0; // 2 seconds ahead
      double distance =
          (currentSpeed.value / 3.6) * timeAhead; // Convert km/h to m/s

      // Calculate predicted position based on bearing
      double bearingRad = mapBearing.value * pi / 180;
      double latChange =
          distance * cos(bearingRad) / 111320; // Approximate meters to degrees
      double lngChange = distance *
          sin(bearingRad) /
          (111320 * cos(currentPosition.value!.latitude * pi / 180));

      predictedLat += latChange;
      predictedLng += lngChange;
    }

    // Store predicted position for camera movement
    _predictedPosition = LatLng(predictedLat, predictedLng);
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
        Timer.periodic(const Duration(milliseconds: 200), (timer) {
      // Increased frequency
      if (isAutoNavigationEnabled.value) {
        updateAutoNavigation();
      }
    });
  }

  void startTrafficUpdates() {
    _trafficUpdateTimer?.cancel();
    _trafficUpdateTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      // More frequent updates
      updateMarkersAndPolyline();
      _checkRealTimeTrafficConditions();
      _checkForBetterRoutes(); // Add route optimization check
    });
  }

  // Check for better routes continuously
  void _checkForBetterRoutes() async {
    if (currentPosition.value == null || routePoints.isEmpty) return;

    try {
      LatLng source = LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude);
      LatLng destination = getTargetLocation();

      // Only check for better routes if we're not in heavy traffic
      if (trafficLevel.value < 2) {
        final String url =
            'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${source.latitude},${source.longitude}&'
            'destination=${destination.latitude},${destination.longitude}&'
            'alternatives=true&'
            'departure_time=now&'
            'traffic_model=best_guess&'
            'key=${Constant.mapAPIKey}';

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          Map<String, dynamic> data = json.decode(response.body);
          if (data['status'] == 'OK' && data['routes'].length > 1) {
            // Find the fastest route
            Map<String, dynamic> fastestRoute = data['routes'][0];
            int fastestDuration = fastestRoute['legs'][0]['duration_in_traffic']
                    ?['value'] ??
                fastestRoute['legs'][0]['duration']['value'];

            for (var route in data['routes']) {
              int duration = route['legs'][0]['duration_in_traffic']
                      ?['value'] ??
                  route['legs'][0]['duration']['value'];
              if (duration < fastestDuration) {
                fastestDuration = duration;
                fastestRoute = route;
              }
            }

            // Check if the new route is significantly better (at least 2 minutes faster)
            int currentDuration = _calculateCurrentRouteDuration();
            if (fastestDuration < (currentDuration - 120)) {
              // 2 minutes = 120 seconds
              _suggestRouteChange(
                  fastestRoute, fastestDuration, currentDuration);
            }
          }
        }
      }
    } catch (e) {
      // Handle errors silently
    }
  }

  // Calculate current route duration
  int _calculateCurrentRouteDuration() {
    if (routePoints.isEmpty) return 0;

    // Estimate based on distance and current traffic
    double totalDistance = 0;
    for (int i = 0; i < routePoints.length - 1; i++) {
      totalDistance += calculateDistanceBetweenPoints(
        routePoints[i].latitude,
        routePoints[i].longitude,
        routePoints[i + 1].latitude,
        routePoints[i + 1].longitude,
      );
    }

    double adjustedSpeed = _calculateAdjustedSpeed();
    return (totalDistance / adjustedSpeed * 3600).round(); // Convert to seconds
  }

  // Suggest route change to user
  void _suggestRouteChange(
      Map<String, dynamic> newRoute, int newDuration, int currentDuration) {
    int timeSaved = currentDuration - newDuration;
    int minutesSaved = (timeSaved / 60).round();

    if (isVoiceEnabled.value) {
      queueAnnouncement(
          "Faster route available. You can save $minutesSaved minutes by taking an alternative route.",
          priority: 2);
    }

    // Store the better route for user to accept
    _betterRouteAvailable.value = true;
    _betterRouteData = newRoute;
    _timeSaved = minutesSaved;
  }

  // Accept the better route
  void acceptBetterRoute() {
    if (_betterRouteAvailable.value && _betterRouteData != null) {
      _updateRouteWithAlternative(_betterRouteData!);
      _betterRouteAvailable.value = false;
      _betterRouteData = null;
      _timeSaved = 0;

      if (isVoiceEnabled.value) {
        queueAnnouncement("Route updated to faster alternative.", priority: 1);
      }
    }
  }

  // Check if better route is available
  bool get isBetterRouteAvailable => _betterRouteAvailable.value;

  // Get time saved with better route
  int get timeSavedWithBetterRoute => _timeSaved;

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
    // Dynamic zoom based on speed and context
    navigationZoom.value = _calculateDynamicZoom();

    // Smooth camera movement
    if (mapController != null && isFollowingDriver.value) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _predictedPosition ?? devicePos,
            zoom: navigationZoom.value,
            tilt: _calculateOptimalTilt(),
            bearing: mapBearing.value,
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
        currentLaneGuidance.value = "Stay in right lane for upcoming turn";
      } else if (currentManeuver.value.contains("left")) {
        currentLanes.value = ["left", "left", "straight", "straight"];
        recommendedLane.value = "left";
        currentLaneGuidance.value = "Stay in left lane for upcoming turn";
      } else if (currentManeuver.value.contains("roundabout")) {
        currentLanes.value = ["roundabout", "roundabout"];
        recommendedLane.value = "roundabout";
        currentLaneGuidance.value = "Use roundabout lane";
      } else {
        currentLanes.value = ["straight", "straight"];
        recommendedLane.value = "straight";
        currentLaneGuidance.value = "Continue in current lane";
      }
    } else {
      currentLanes.clear();
      recommendedLane.value = "";
      currentLaneGuidance.value = "No lane guidance needed";
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
    // Reduced threshold for faster off-route detection
    isOffRoute.value = minDistanceToRoute > 20; // Reduced from 25m to 20m

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

    // Enhanced ETA calculation with real-time factors
    double adjustedSpeed = _calculateAdjustedSpeed();
    int minutes = (distance.value / adjustedSpeed * 60).round();

    // Add buffer time for traffic and stops
    int bufferMinutes = _calculateBufferTime();
    minutes += bufferMinutes;

    estimatedTime.value = minutes < 1 ? "Less than 1 min" : "$minutes min";

    DateTime arrival = DateTime.now().add(Duration(minutes: minutes));
    estimatedArrival.value = DateFormat('hh:mm a').format(arrival);

    updateTripProgress();
  }

  // Calculate adjusted speed based on multiple factors
  double _calculateAdjustedSpeed() {
    double baseSpeed = 40.0; // Base speed in km/h

    // Traffic adjustment
    double trafficMultiplier = getTrafficSpeedMultiplier();

    // Time of day adjustment
    double timeMultiplier = _getTimeOfDayMultiplier();

    // Weather adjustment (could be enhanced with real weather API)
    double weatherMultiplier = _getWeatherMultiplier();

    // Road type adjustment
    double roadMultiplier = _getRoadTypeMultiplier();

    return baseSpeed *
        trafficMultiplier *
        timeMultiplier *
        weatherMultiplier *
        roadMultiplier;
  }

  // Get time of day speed multiplier
  double _getTimeOfDayMultiplier() {
    int hour = DateTime.now().hour;

    // Rush hour periods
    if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
      return 0.7; // 30% slower during rush hour
    }

    // Night time
    if (hour >= 22 || hour <= 6) {
      return 0.9; // 10% slower at night
    }

    // Normal hours
    return 1.0;
  }

  // Get weather multiplier (placeholder for real weather API)
  double _getWeatherMultiplier() {
    // This could be enhanced with real weather data
    // For now, return a default value
    return 1.0;
  }

  // Get road type multiplier
  double _getRoadTypeMultiplier() {
    // This could be enhanced with real road data
    // For now, return a default value
    return 1.0;
  }

  // Calculate buffer time for ETA
  int _calculateBufferTime() {
    int bufferMinutes = 0;

    // Add buffer for heavy traffic
    if (trafficLevel.value == 2) {
      bufferMinutes += 5;
    } else if (trafficLevel.value == 1) {
      bufferMinutes += 2;
    }

    // Add buffer for multiple turns
    if (navigationSteps.length > 5) {
      bufferMinutes += 3;
    }

    // Add buffer for current speed
    if (currentSpeed.value < 10) {
      bufferMinutes += 2; // Extra time if moving slowly
    }

    return bufferMinutes;
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

    LatLng targetLocation = _predictedPosition ??
        LatLng(
            currentPosition.value!.latitude, currentPosition.value!.longitude);

    // Smooth camera animation with easing
    await mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: targetLocation,
          zoom: navigationZoom.value,
          tilt: _calculateOptimalTilt(), // Dynamic tilt based on speed
          bearing: mapBearing.value,
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
    // Using retry() directly below; no need to keep a local RetryOptions var here
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
    // This could be enhanced with real speed limit API data
    // For now, we'll use a simple heuristic based on location
    double speedLimit = 50.0; // Default speed limit

    // Simple speed limit logic (could be enhanced with real data)
    if (currentSpeed.value > 0) {
      // Adjust speed limit based on current speed and context
      if (currentSpeed.value > 80) {
        speedLimit = 80.0; // Highway
      } else if (currentSpeed.value > 50) {
        speedLimit = 60.0; // Main road
      } else {
        speedLimit = 40.0; // City street
      }
    }

    currentSpeedLimit.value = speedLimit;

    if (currentSpeed.value > speedLimit) {
      queueAnnouncement(
          "You are exceeding the speed limit of ${speedLimit.toStringAsFixed(0)} km/h.",
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
      // Keep simplified instruction generation only
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

  // Removed unused _stripHtmlTags

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

  void toggleLaneGuidance() {
    isLaneGuidanceEnabled.value = !isLaneGuidanceEnabled.value;
    ShowToastDialog.showToast(
        "Lane guidance ${isLaneGuidanceEnabled.value ? 'enabled' : 'disabled'}");
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
            DateTime.now().difference(_lastRerouteTime!).inSeconds <
                5)) // Reduced from 10s to 5s
      return;

    _lastRerouteTime = DateTime.now();
    polyLines.clear();

    // Try to recalculate with different parameters
    _recalculateWithAlternatives();
  }

  // Recalculate route with alternatives
  void _recalculateWithAlternatives() async {
    if (currentPosition.value == null) return;

    try {
      LatLng source = LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude);
      LatLng destination = getTargetLocation();

      // Try different routing modes
      List<String> modes = [
        'driving',
        'driving',
        'driving'
      ]; // Multiple attempts

      for (String mode in modes) {
        final String url =
            'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${source.latitude},${source.longitude}&'
            'destination=${destination.latitude},${destination.longitude}&'
            'mode=$mode&'
            'alternatives=true&'
            'departure_time=now&'
            'traffic_model=best_guess&'
            'key=${Constant.mapAPIKey}';

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          Map<String, dynamic> data = json.decode(response.body);
          if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
            // Use the first available route
            _updateRouteWithAlternative(data['routes'][0]);
            isOffRoute.value = false;
            return;
          }
        }
      }

      // If all attempts fail, fall back to direct route
      _createDirectRoute(source, destination);
    } catch (e) {
      // Create direct route as fallback
      if (currentPosition.value != null) {
        LatLng source = LatLng(
            currentPosition.value!.latitude, currentPosition.value!.longitude);
        LatLng destination = getTargetLocation();
        _createDirectRoute(source, destination);
      }
    }
  }

  // Create direct route as fallback
  void _createDirectRoute(LatLng source, LatLng destination) {
    List<LatLng> directRoute = [source, destination];
    routePoints.value = directRoute;

    polyLines.clear();
    _addPolyLine(directRoute, "DirectRoute", Colors.red);

    if (isVoiceEnabled.value) {
      queueAnnouncement("Using direct route due to navigation issues.",
          priority: 3);
    }
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
      CompassEvent event = await FlutterCompass.events!.first
          .timeout(const Duration(seconds: 5));
      if (event.heading == null || event.heading! < 0 || event.heading! > 360) {
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

  // Real-time traffic and route optimization
  void _optimizeRouteForTraffic() async {
    if (currentPosition.value == null || routePoints.isEmpty) return;

    try {
      // Get alternative routes
      LatLng source = LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude);
      LatLng destination = getTargetLocation();

      // Request alternative routes from Google Directions API
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${source.latitude},${source.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'alternatives=true&'
          'departure_time=now&'
          'traffic_model=best_guess&'
          'key=${Constant.mapAPIKey}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].length > 1) {
          // Find the fastest alternative route
          Map<String, dynamic> fastestRoute = data['routes'][0];
          int fastestDuration = fastestRoute['legs'][0]['duration_in_traffic']
                  ?['value'] ??
              fastestRoute['legs'][0]['duration']['value'];

          for (var route in data['routes']) {
            int duration = route['legs'][0]['duration_in_traffic']?['value'] ??
                route['legs'][0]['duration']['value'];
            if (duration < fastestDuration) {
              fastestDuration = duration;
              fastestRoute = route;
            }
          }

          // Update route if we found a faster alternative
          if (fastestRoute != data['routes'][0]) {
            _updateRouteWithAlternative(fastestRoute);
          }
        }
      }
    } catch (e) {
      // Handle errors silently
    }
  }

  // Real-time traffic condition checking
  void _checkRealTimeTrafficConditions() async {
    if (currentPosition.value == null || routePoints.isEmpty) return;

    try {
      // Check if we're approaching known traffic areas
      LatLng devicePos = LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude);

      // Look ahead 2km for traffic conditions
      double lookAheadDistance = 2000;
      bool hasTrafficAhead = false;

      for (int i = 0; i < routePoints.length; i++) {
        double distance = await calculateDistance(
          devicePos.latitude,
          devicePos.longitude,
          routePoints[i].latitude,
          routePoints[i].longitude,
        );

        if (distance <= lookAheadDistance) {
          // Check if this route segment has traffic
          if (_isHighTrafficArea(routePoints[i])) {
            hasTrafficAhead = true;
            break;
          }
        }
      }

      if (hasTrafficAhead && trafficLevel.value < 2) {
        trafficLevel.value = 2;
        if (isVoiceEnabled.value) {
          queueAnnouncement(
              "Heavy traffic detected ahead. Consider alternative route.",
              priority: 2);
        }
      }
    } catch (e) {
      // Handle errors silently to avoid disrupting navigation
    }
  }

  // Check if a location is in a high traffic area
  bool _isHighTrafficArea(LatLng location) {
    // This could be enhanced with real traffic API data
    // For now, we'll use a simple heuristic based on time and location
    int hour = DateTime.now().hour;

    // Rush hour periods
    bool isRushHour = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);

    // Weekend vs weekday
    bool isWeekend = DateTime.now().weekday >= 6;

    // Simple traffic prediction (could be enhanced with real data)
    return isRushHour && !isWeekend;
  }

  // Calculate optimal camera tilt based on speed and context
  double _calculateOptimalTilt() {
    if (currentSpeed.value < 10) return 0.0; // Flat view when slow/stopped
    if (currentSpeed.value < 30) return 15.0; // Slight tilt for city driving
    if (currentSpeed.value < 60) return 25.0; // Medium tilt for highway
    return 35.0; // High tilt for fast highway driving
  }

  // Calculate dynamic zoom based on multiple factors
  double _calculateDynamicZoom() {
    double baseZoom = showDriverToPickupRoute.value ? 16.0 : 15.0;

    // Speed-based adjustments
    if (currentSpeed.value < 5)
      baseZoom += 0.8; // Closer view when slow
    else if (currentSpeed.value > 80) baseZoom -= 0.8; // Wider view when fast

    // Turn-based adjustments
    if (distanceToNextTurn.value < 100)
      baseZoom += 0.5; // Closer view for turns
    else if (distanceToNextTurn.value > 500)
      baseZoom -= 0.3; // Wider view for straight roads

    // Traffic-based adjustments
    if (trafficLevel.value > 1) baseZoom += 0.3; // Closer view in heavy traffic

    return baseZoom.clamp(14.0, 18.0);
  }

  // Update route with alternative
  void _updateRouteWithAlternative(Map<String, dynamic> routeData) {
    try {
      String encodedPolyline = routeData['overview_polyline']['points'];
      List<PointLatLng> decodedPoints =
          polylinePoints.decodePolyline(encodedPolyline);
      List<LatLng> newRoutePoints = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      // Update route points
      routePoints.value = newRoutePoints;

      // Parse new navigation steps
      parseNavigationSteps(routeData);

      // Update polylines
      polyLines.clear();
      _addPolyLine(newRoutePoints, "OptimizedRoute", AppColors.primary);

      // Announce route change
      if (isVoiceEnabled.value) {
        queueAnnouncement("Route optimized for traffic conditions.",
            priority: 1);
      }
    } catch (e) {
      // Handle errors silently
    }
  }

  // Enhanced marker updates with smooth animations
  // Removed unused _enhancedAddDeviceMarker

  // Smooth marker animation
  // Removed unused _animateMarkerSmoothly
}
