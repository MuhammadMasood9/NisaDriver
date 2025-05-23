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
  Rx<DriverUserModel> driverUserModel = DriverUserModel().obs;
  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<InterCityOrderModel> intercityOrderModel = InterCityOrderModel().obs;

  Rx<Position?> currentPosition = Rx<Position?>(null);
  RxDouble deviceBearing = 0.0.obs;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
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
  RxDouble navigationZoom = 18.0.obs;
  RxDouble navigationTilt = 70.0.obs; // Adjusted for better road visibility
  RxDouble navigationBearing = 0.0.obs;
  RxInt nextRoutePointIndex = 0.obs;

  Position? _previousPosition;
  DateTime? _previousTime;

  RxList<String> currentLanes = <String>[].obs;
  RxString recommendedLane = "".obs;

  RxDouble navigation3DTilt = 70.0.obs; // Adjusted for better road view
  RxDouble navigation3DZoom = 19.0.obs;
  RxBool is3DNavigationMode = true.obs;

  final List<Map<String, dynamic>> _ttsQueue = [];
  bool _isSpeaking = false;

  void onInit() {
    addMarkerSetup();
    initializeTTS();
    initializeLocationServices();
    getArgument();
    isFollowingDriver.value = true;
    isNavigationView.value = true;
    is3DNavigationMode.value = true;
    navigationTilt.value = 70.0;
    navigationZoom.value = 19.0;
    // bool? hasCompass = FlutterCompass.events?.first != null;
    // dev.log("Debug: Has compass: $hasCompass");
    // if (hasCompass != true) {
    //   ShowToastDialog.showToast("Compass not available on this device");
    //   return;
    // }
    // Start compass tracking

    dev.log("Debug: Device bearing: ");
    addDeviceMarker();
    startLocationTracking();
    startEstimationUpdates();
    startAutoNavigation();
    startTrafficUpdates();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateMarkersAndPolyline();
    });
    super.onInit();
  }

  @override
  void onClose() {
    _locationUpdateTimer?.cancel();
    _estimationUpdateTimer?.cancel();
    _autoNavigationTimer?.cancel();
    _trafficUpdateTimer?.cancel();
    _positionStream?.cancel();
    mapController?.dispose();
    _flutterTts?.stop();
    ShowToastDialog.closeLoader();
    super.onClose();
  }

  void initializeTTS() async {
    _flutterTts = FlutterTts();
    try {
      await _flutterTts?.setLanguage("en-US");
      await _flutterTts?.setSpeechRate(1);
      await _flutterTts?.setVolume(1.0);
      await _flutterTts?.setPitch(1.0);
      if (Platform.isAndroid) {
        await _flutterTts?.setQueueMode(1);
      }
    } catch (e) {
      print("Debug: Error initializing TTS: $e");
      ShowToastDialog.showToast("Failed to initialize voice guidance");
    }
  }

  Future<double?> testLiveBearing() async {
    try {
      CompassEvent? event =
          await FlutterCompass.events!.first.timeout(Duration(seconds: 5));
      if (event?.heading == null ||
          event!.heading! < 0 ||
          event.heading! > 360) {
        dev.log("Debug: Test bearing invalid: ${event?.heading}");
        ShowToastDialog.showToast("Invalid compass data, please calibrate");
        return null;
      }
      dev.log("Debug: Test live bearing: ${event.heading}");
      return event.heading;
    } catch (e) {
      dev.log("Debug: Test bearing error: $e");
      ShowToastDialog.showToast("Error accessing compass");
      return null;
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
    try {
      await _flutterTts?.speak(announcement['text']);
      await _flutterTts?.awaitSpeakCompletion(true);
    } catch (e) {
      print("Debug: TTS error: $e");
    }
    _isSpeaking = false;
    _processTtsQueue();
  }

  Future<void> initializeLocationServices() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ShowToastDialog.showToast("Please enable location services");
      return;
    }

    permission = await Geolocator.checkPermission();
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
  }

  void startLocationTracking() {
    if (!isLocationPermissionGranted.value) {
      initializeLocationServices().then((_) {
        if (isLocationPermissionGranted.value) {
          _startPositionStream();
        }
      });
    } else {
      _startPositionStream();
    }
  }

  void _startPositionStream() {
    optimizePerformance();
  }

  // void updateDeviceLocation(Position position) {
  //   Position previousPos = currentPosition.value ?? position;
  //   currentPosition.value = position;
  //   currentSpeed.value = position.speed * 3.6;

  //   if (_previousPosition != null && _previousTime != null) {
  //     dev.log("NULL");
  //     deviceBearing.value = position.heading;
  //     dev.log("Debug: position.heading: ${position.heading}");
  //     dev.log("Debug: Device bearing: ${deviceBearing.value}");
  //     double distanceMeters = Geolocator.distanceBetween(
  //       _previousPosition!.latitude,
  //       _previousPosition!.longitude,
  //       position.latitude,
  //       position.longitude,
  //     );

  //     if (distanceMeters > 2 && currentSpeed.value > 5) {
  //       dev.log("one");
  //       if (position.heading >= 0 && position.heading <= 360) {
  //         dev.log("2");
  //         if (position.headingAccuracy <= 45) {
  //           deviceBearing.value =
  //               position.heading; // Marker faces device heading

  //           dev.log("Debug: position.heading: ${position.heading}");
  //           dev.log("Debug: Device bearing: ${deviceBearing.value}");
  //         } else {
  //           ShowToastDialog.showToast("Please calibrate your compass");
  //         }
  //       } else {
  //         print("Debug: Invalid heading data");
  //       }

  //       if (is3DNavigationMode.value) {
  //         navigationBearing.value =
  //             position.heading; // Align map with device heading
  //       } else {
  //         navigationBearing.value =
  //             interpolateBearing(navigationBearing.value, position.heading);
  //       }
  //     }
  //   }

  //   _previousPosition = position;
  //   _previousTime = DateTime.now();

  //   addDeviceMarker();
  //   fetchSpeedLimit(LatLng(position.latitude, position.longitude));

  //   if (isFollowingDriver.value && isNavigationView.value) {
  //     updateNavigationViewAligned();
  //   }

  //   updateRouteVisibility();
  //   updateNavigationInstructions();
  //   updateNextRoutePoint();
  //   checkOffRoute();
  //   updateTimeAndDistanceEstimates();
  //   updateDynamicPolyline();
  // }

  void updateDeviceLocation(Position position) {
    currentPosition.value = position;
    currentSpeed.value = position.speed * 3.6;

    final now = DateTime.now();

    if (_previousPosition != null && _previousTime != null) {
      final double distanceMeters = Geolocator.distanceBetween(
        _previousPosition!.latitude,
        _previousPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      dev.log("Debug: Distance moved: $distanceMeters");
    }

    _previousPosition = position;
    _previousTime = now;

    // Marker update (rotation handled by compass)
    addDeviceMarker();
    fetchSpeedLimit(LatLng(position.latitude, position.longitude));

    if (isFollowingDriver.value && isNavigationView.value) {
      updateNavigationViewAligned();
    }

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
      rotation: deviceBearing.value, // Use compass heading for marker rotation
    );
  }

  double interpolateBearing3D(double currentBearing, double targetBearing) {
    double diff = targetBearing - currentBearing;

    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    double interpolationFactor = currentSpeed.value > 30 ? 0.15 : 0.4;
    double interpolated = currentBearing + diff * interpolationFactor;

    return (interpolated + 360) % 360;
  }

  void toggle3DNavigationMode() {
    is3DNavigationMode.value = !is3DNavigationMode.value;

    if (is3DNavigationMode.value) {
      navigationTilt.value = navigation3DTilt.value;
      navigationZoom.value = navigation3DZoom.value;
    } else {
      navigationTilt.value = 0.0;
      navigationZoom.value = 17.0;
    }

    if (isFollowingDriver.value) {
      updateNavigationViewAligned();
    }
  }

  LatLng getNextRoutePoint(LatLng devicePos) {
    if (routePoints.isEmpty) {
      return getTargetLocation();
    }

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
    int nextPointIndex =
        min(closestIndex + lookAheadDistance, routePoints.length - 1);

    return routePoints[nextPointIndex];
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

  double interpolateBearing(double currentBearing, double targetBearing) {
    double diff = targetBearing - currentBearing;

    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    double interpolationFactor = currentSpeed.value > 20 ? 0.3 : 0.6;
    double interpolated = currentBearing + diff * interpolationFactor;

    return (interpolated + 360) % 360;
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
        currentPosition.value == null) {
      return;
    }

    LatLng devicePos = LatLng(
      currentPosition.value!.latitude,
      currentPosition.value!.longitude,
    );

    checkUpcomingTurns(devicePos);
    adjustCameraForNavigation(devicePos);
    updateLaneGuidance();
    autoAdjust3DPerspective();
  }

  void autoAdjust3DPerspective() {
    if (!is3DNavigationMode.value) return;

    if (distanceToNextTurn.value < 100) {
      navigation3DTilt.value = 75.0; // Tighter angle for turns
    } else if (currentSpeed.value > 50) {
      navigation3DTilt.value = 60.0; // Lower angle for high speed
    } else {
      navigation3DTilt.value = 70.0; // Default for clear road view
    }

    navigation3DTilt.value = navigation3DTilt.value.clamp(60.0, 80.0);
  }

  void resetTo3DView() {
    is3DNavigationMode.value = true;
    isFollowingDriver.value = true;
    isNavigationView.value = true;

    navigation3DTilt.value = 70.0;
    navigation3DZoom.value = 19.0;

    updateNavigationViewAligned();
    updateMarkersAndPolyline();
  }

  void checkUpcomingTurns(LatLng devicePos) async {
    if (navigationSteps.isEmpty ||
        currentStepIndex.value >= navigationSteps.length) {
      return;
    }

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
      if (distanceToStep <= 200 && distanceToStep > 100) {
        queueAnnouncement("In 200 meters, ${currentStep.instruction}",
            priority: 2);
      } else if (distanceToStep <= 100 && distanceToStep > 50) {
        queueAnnouncement("In 100 meters, ${currentStep.instruction}",
            priority: 2);
      } else if (distanceToStep <= 50 && distanceToStep > 20) {
        queueAnnouncement("In 50 meters, ${currentStep.instruction}",
            priority: 2);
      } else if (distanceToStep <= 20) {
        queueAnnouncement("Now, ${currentStep.instruction}", priority: 2);
      }
    }

    if (distanceToStep < 10) {
      currentStepIndex.value =
          min(currentStepIndex.value + 1, navigationSteps.length - 1);
      updateNavigationInstructions();
    }
  }

  void adjustCameraForNavigation(LatLng devicePos) {
    if (!is3DNavigationMode.value) {
      adjustCameraForNavigationFlat(devicePos);
      return;
    }

    double zoom = 19.0; // Tighter zoom for road focus
    double tilt = 70.0; // Optimized for road visibility

    if (currentSpeed.value < 5) {
      zoom = 19.5;
      tilt = 75.0;
    } else if (currentSpeed.value < 20) {
      zoom = 19.0;
      tilt = 70.0;
    } else if (currentSpeed.value < 50) {
      zoom = 18.5;
      tilt = 65.0;
    } else {
      zoom = 18.0;
      tilt = 60.0;
    }

    if (distanceToNextTurn.value < 150) {
      zoom += 0.5;
      tilt += 5.0;
    }

    navigation3DZoom.value = zoom.clamp(18.0, 20.0);
    navigation3DTilt.value = tilt.clamp(60.0, 80.0); // Adjusted for road view
  }

  void adjustCameraForNavigationFlat(LatLng devicePos) {
    double zoom = 16.0;

    if (currentSpeed.value < 10) {
      zoom = 19.0;
    } else if (currentSpeed.value < 30) {
      zoom = 18.0;
    } else if (currentSpeed.value < 60) {
      zoom = 17.0;
    } else {
      zoom = 16.0;
    }

    if (distanceToNextTurn.value < 200) {
      zoom += 1.0;
    }

    navigationZoom.value = zoom.clamp(15.0, 20.0);
    navigationTilt.value = 0.0;
  }

  double getBearingToNextPoint(LatLng currentPos) {
    if (routePoints.isEmpty) return navigationBearing.value;

    LatLng nextPoint = getNextRoutePoint(currentPos);

    double bearing = getBearing(
      currentPos.latitude,
      currentPos.longitude,
      nextPoint.latitude,
      nextPoint.longitude,
    );

    return bearing;
  }

  void onMapTap(LatLng position) {
    isFollowingDriver.value = false;

    int timeoutSeconds = is3DNavigationMode.value ? 8 : 10;

    Timer(Duration(seconds: timeoutSeconds), () {
      if (!isFollowingDriver.value) {
        isFollowingDriver.value = true;
        updateNavigationViewAligned();
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
    if (routePoints.isEmpty || currentPosition.value == null) {
      return;
    }

    LatLng devicePos = LatLng(
      currentPosition.value!.latitude,
      currentPosition.value!.longitude,
    );

    double minDistanceToRoute = double.infinity;
    LatLng? closestPoint;
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
        closestPoint = routePoints[i];
        closestIndex = i;
      }
    }

    bool wasOffRoute = isOffRoute.value;
    isOffRoute.value = minDistanceToRoute > 25; // Trigger at 25 meters

    if (isOffRoute.value && !wasOffRoute) {
      queueAnnouncement("You are off route. Recalculating route.", priority: 3);
      polyLines.clear(); // Clear old route traces
      recalculateRoute(); // Immediately recalculate
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
      currentPosition.value!.latitude,
      currentPosition.value!.longitude,
    );

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
        showDriverToPickupRoute.value ? AppColors.primary : Colors.green;

    polyLines.clear(); // Clear previous polylines to avoid traces
    _addPolyLine(remainingPoints, polylineId, color);
  }

  void updateNextRoutePoint() {
    if (routePoints.isEmpty || currentPosition.value == null) {
      return;
    }

    LatLng devicePos = LatLng(
      currentPosition.value!.latitude,
      currentPosition.value!.longitude,
    );

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
    if (currentPosition.value == null) {
      print(
          "Debug: Skipping time/distance estimates due to null device location");
      return;
    }

    LatLng targetLocation;
    bool isGoingToPickup = false;

    if (type.value == "orderModel") {
      if (orderModel.value.status == Constant.rideInProgress) {
        if (orderModel.value.destinationLocationLAtLng == null) {
          ShowToastDialog.showToast("Invalid destination data");
          return;
        }
        targetLocation = LatLng(
            orderModel.value.destinationLocationLAtLng!.latitude!,
            orderModel.value.destinationLocationLAtLng!.longitude!);
        currentStep.value = "Heading to destination";
      } else {
        if (orderModel.value.sourceLocationLAtLng == null) {
          ShowToastDialog.showToast("Invalid pickup data");
          return;
        }
        targetLocation = LatLng(
            orderModel.value.sourceLocationLAtLng!.latitude!,
            orderModel.value.sourceLocationLAtLng!.longitude!);
        currentStep.value = "Heading to pickup";
        isGoingToPickup = true;
      }
    } else {
      if (intercityOrderModel.value.status == Constant.rideInProgress) {
        if (intercityOrderModel.value.destinationLocationLAtLng == null) {
          ShowToastDialog.showToast("Invalid destination data");
          return;
        }
        targetLocation = LatLng(
            intercityOrderModel.value.destinationLocationLAtLng!.latitude!,
            intercityOrderModel.value.destinationLocationLAtLng!.longitude!);
        currentStep.value = "Heading to destination";
      } else {
        if (intercityOrderModel.value.sourceLocationLAtLng == null) {
          ShowToastDialog.showToast("Invalid pickup data");
          return;
        }
        targetLocation = LatLng(
            intercityOrderModel.value.sourceLocationLAtLng!.latitude!,
            intercityOrderModel.value.sourceLocationLAtLng!.longitude!);
        currentStep.value = "Heading to pickup";
        isGoingToPickup = true;
      }
    }

    double distanceInMeters = await calculateDistance(
        currentPosition.value!.latitude,
        currentPosition.value!.longitude,
        targetLocation.latitude,
        targetLocation.longitude);

    distance.value = distanceInMeters / 1000;

    double baseSpeed = isGoingToPickup ? 35.0 : 40.0;
    double speedMultiplier = getTrafficSpeedMultiplier();
    double adjustedSpeed = baseSpeed * speedMultiplier;

    double timeInHours = distance.value / adjustedSpeed;
    int minutes = (timeInHours * 60).round();
    estimatedTime.value = minutes < 1 ? "Less than 1 min" : "$minutes min";

    DateTime now = DateTime.now();
    DateTime arrival = now.add(Duration(minutes: minutes));
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
        if (orderModel.value.sourceLocationLAtLng == null ||
            orderModel.value.destinationLocationLAtLng == null) {
          return;
        }
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
        if (intercityOrderModel.value.sourceLocationLAtLng == null ||
            intercityOrderModel.value.destinationLocationLAtLng == null) {
          return;
        }
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
    if (mapController == null || currentPosition.value == null) {
      print("Debug: Cannot update camera, mapController or location is null");
      return;
    }

    LatLng deviceLocation = LatLng(
      currentPosition.value!.latitude,
      currentPosition.value!.longitude,
    );

    await mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: deviceLocation,
          zoom: navigationZoom.value,
          tilt: 0.0,
          bearing: navigationBearing.value,
        ),
      ),
    );
  }

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

  // void updateNavigationInstructions() async {
  //   // Step 1: Get the current bearing (direction in degrees)
  //   try {
  //     Position position = await Geolocator.getCurrentPosition(
  //       desiredAccuracy: LocationAccuracy.high,
  //     );
  //     deviceBearing.value = position.heading;

  //     dev.log("SET DEVICE BEARING: ${deviceBearing.value} DEGREE");
  //   } catch (e) {
  //     dev.log("SET DEVICE BEARING: ${e} DEGREE");
  //     dev.log("SET DEVICE BEARING: ${deviceBearing.value} DEGREE");
  //     deviceBearing.value = 0.0; // fallback in case of error
  //   }

  //   // Step 2: Update navigation instructions as usual
  //   if (navigationSteps.isEmpty ||
  //       currentStepIndex.value >= navigationSteps.length) {
  //     navigationInstruction.value = "Follow the route";
  //     nextTurnInstruction.value = "";
  //     return;
  //   }
  //   dev.log("navigationInstruction.value: ${navigationInstruction.value}");

  //   NavigationStep currentStep = navigationSteps[currentStepIndex.value];

  //   if (isOffRoute.value) {
  //     navigationInstruction.value = "Off route! Recalculating...";
  //     nextTurnInstruction.value = "Please return to the highlighted route";
  //     return;
  //   }

  //   navigationInstruction.value = currentStep.instruction;

  //   if (currentStepIndex.value + 1 < navigationSteps.length) {
  //     NavigationStep nextStep = navigationSteps[currentStepIndex.value + 1];
  //     nextTurnInstruction.value = "Then ${nextStep.instruction}";
  //   } else {
  //     String target =
  //         showDriverToPickupRoute.value ? "pickup location" : "destination";
  //     nextTurnInstruction.value = "Approaching $target";
  //   }

  //   // (Optional) Log or show the bearing
  //   print("Current Device Bearing: ${deviceBearing.value}");
  // }




void updateNavigationInstructions() async {
  // Step 1: Get device bearing
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    deviceBearing.value = position.heading;
  } catch (e) {
    deviceBearing.value = 0.0;
  }

  // Step 2: Check step availability
  if (navigationSteps.isEmpty ||
      currentStepIndex.value >= navigationSteps.length) {
    navigationInstruction.value = "Follow the route";
    nextTurnInstruction.value = "";
    return;
  }

  NavigationStep currentStep = navigationSteps[currentStepIndex.value];

  // Step 3: Handle off-route
  if (isOffRoute.value) {
    navigationInstruction.value = "Off route! Recalculating...";
    nextTurnInstruction.value = "Please return to the highlighted route";
    return;
  }

  // Step 4: Set current instruction
  navigationInstruction.value = currentStep.instruction;

  // Step 5: Extract compass heading (e.g., "Head southeast") and convert to angle
  double? extractedBearing = extractBearingFromInstruction(currentStep.instruction);
  if (extractedBearing != null) {
    deviceBearing.value = extractedBearing;
    print("Step Bearing: $extractedBearing°");
  }

  // Step 6: Set next instruction
  if (currentStepIndex.value + 1 < navigationSteps.length) {
    NavigationStep nextStep = navigationSteps[currentStepIndex.value + 1];
    nextTurnInstruction.value = "Then ${nextStep.instruction}";
  } else {
    String target =
        showDriverToPickupRoute.value ? "pickup location" : "destination";
    nextTurnInstruction.value = "Approaching $target";
  }
}
double? extractBearingFromInstruction(String instruction) {
  final directions = {
    "north": 0.0,
    "northeast": 45.0,
    "east": 90.0,
    "southeast": 135.0,
    "south": 180.0,
    "southwest": 225.0,
    "west": 270.0,
    "northwest": 315.0,
  };

  final regex = RegExp(r'Head (north|northeast|east|southeast|south|southwest|west|northwest)', caseSensitive: false);
  final match = regex.firstMatch(instruction);
  if (match != null) {
    final direction = match.group(1)!.toLowerCase();
    return directions[direction];
  }
  return null; // No direction found
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
      getCurrentLocation().then((_) {
        if (currentPosition.value != null) {
          updateMarkersAndPolyline(); // Retry after getting location
        }
      });
      return;
    }

    addDeviceMarker();

    if (type.value == "orderModel") {
      if (orderModel.value.sourceLocationLAtLng == null ||
          orderModel.value.destinationLocationLAtLng == null) {
        ShowToastDialog.showToast(
            "Invalid order data. Please check ride details.");
        return;
      }

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
          color: Colors.green,
        );
      }
    } else {
      if (intercityOrderModel.value.sourceLocationLAtLng == null ||
          intercityOrderModel.value.destinationLocationLAtLng == null) {
        ShowToastDialog.showToast(
            "Invalid intercity order data. Please check ride details.");
        return;
      }

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
          color: Colors.green,
        );
      }
    }

    updateTimeAndDistanceEstimates();
    updateNavigationViewAligned();
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
      maxDelay: Duration(seconds: 5),
    );

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
      try {
        return json.decode(cachedDirections);
      } catch (e) {
        print("Debug: Error decoding cached directions: $e");
      }
    }

    try {
      return await retry(
        () async {
          final String url =
              'https://maps.googleapis.com/maps/api/directions/json?'
              'origin=$sourceLatitude,$sourceLongitude&'
              'destination=$destinationLatitude,$destinationLongitude&'
              'mode=driving&'
              'departure_time=now&'
              'traffic_model=best_guess&'
              'interpolate=true&'
              'alternatives=true&'
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
        },
        retryIf: (e) => e is SocketException || e is TimeoutException,
        onRetry: (e) => print("Retrying directions API: $e"),
      );
    } catch (e) {
      print("Debug: Error fetching directions: $e");
      ShowToastDialog.showToast(
          "Failed to load route. Using last known route.");
      if (cachedDirections != null) {
        try {
          return json.decode(cachedDirections);
        } catch (decodeError) {
          print("Debug: Error decoding cached directions: $decodeError");
        }
      }
      return null;
    }
  }

  Future<void> fetchSpeedLimit(LatLng position) async {
    try {
      speedLimit.value = "50";
      if (currentSpeed.value > double.parse(speedLimit.value)) {
        queueAnnouncement(
            "You are exceeding the speed limit of ${speedLimit.value} km/h.",
            priority: 3);
      }
    } catch (e) {
      print("Debug: Error fetching speed limit: $e");
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
        destinationLongitude == null) {
      ShowToastDialog.showToast("Invalid route coordinates");
      return;
    }

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
      print("Debug: No valid routes found for polyline $polylineId");
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
    if (steps.isNotEmpty) {
      for (var step in steps) {
        String instruction =
            _stripHtmlTags(step['html_instructions'] ?? "Continue");
        double distance = (step['distance']['value'] ?? 0).toDouble();
        String maneuver = step['maneuver'] ?? "straight";
        double duration = (step['duration']['value'] ?? 0).toDouble();
        LatLng location = LatLng(
          step['end_location']['lat'],
          step['end_location']['lng'],
        );

        navigationSteps.add(NavigationStep(
          instruction: instruction,
          distance: distance,
          maneuver: maneuver,
          location: location,
          duration: duration,
        ));
      }
    } else {
      navigationInstruction.value = "No navigation steps available";
      ShowToastDialog.showToast("No navigation steps available");
    }

    updateNavigationInstructions();
  }

  String _stripHtmlTags(String htmlText) {
    final RegExp exp = RegExp(r'<[^>]+>', multiLine: true);
    return htmlText.replaceAll(exp, '').trim();
  }

  void updateTrafficLevel(Map<String, dynamic> directionsData) {
    double duration = 0.0;
    double durationInTraffic = 0.0;

    var leg = directionsData['routes'][0]['legs'][0];
    duration = (leg['duration']['value'] ?? 0).toDouble();
    durationInTraffic =
        (leg['duration_in_traffic']?['value'] ?? duration).toDouble();

    if (duration > 0) {
      double trafficRatio = durationInTraffic / duration;

      if (trafficRatio > 1.5) {
        trafficLevel.value = 2;
      } else if (trafficRatio > 1.2) {
        trafficLevel.value = 1;
      } else {
        trafficLevel.value = 0;
      }

      if (isVoiceEnabled.value && trafficLevel.value > 0) {
        queueAnnouncement(getTrafficLevelText(), priority: 1);
      }
    } else {
      trafficLevel.value = 0;
    }
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
      width: 6,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      patterns:
          isOffRoute.value ? [PatternItem.dash(10), PatternItem.gap(5)] : [],
    );
    polyLines[id] = polyline;
  }

  void updateCameraLocation(LatLng source, LatLng destination) async {
    if (mapController == null) {
      return;
    }

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
    is3DNavigationMode.value = true;

    updateNavigationViewAligned();
    updateMarkersAndPolyline();
  }

  void updateNavigationViewAligned() async {
    try {
      LatLng deviceLocation = LatLng(
        currentPosition.value!.latitude,
        currentPosition.value!.longitude,
      );

      const double alpha = 0.8; // Smoothing factor
      double filteredBearing = 0.0;
      // Listen to magnetometer events for compass bearing
      _magnetometerSubscription?.cancel(); // Cancel any existing subscription
      dev.log("Debug: Entering event1");
      _magnetometerSubscription = magnetometerEventStream().listen(
        (MagnetometerEvent event) {
          dev.log("Debug: Magnetometer event: $event");
          double rawBearing = atan2(event.y, event.x) * (180.0 / pi);
          if (rawBearing < 0) rawBearing += 360.0;
          filteredBearing = alpha * filteredBearing + (1 - alpha) * rawBearing;
          deviceBearing.value = filteredBearing;
        },
        onError: (error) {
          dev.log("Debug: Magnetometer error: $error");
        },
      );

      // Update camera with bearing
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: deviceLocation,
            zoom: is3DNavigationMode.value
                ? navigation3DZoom.value
                : navigationZoom.value,
            tilt: is3DNavigationMode.value ? navigation3DTilt.value : 0.0,
            bearing: deviceBearing.value, // Align map with compass bearing
          ),
        ),
      );

      dev.log("Debug: Map bearing: ${deviceBearing.value.toStringAsFixed(1)}°");

      // Cancel subscription after use
      await Future.delayed(Duration(milliseconds: 100));
      _magnetometerSubscription?.cancel();
    } catch (e) {
      dev.log("Debug: Error updating navigation view: $e");
    }
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
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "elementType": "labels.icon",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#212121"
          }
        ]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#757575"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#2c2c2c"
          }
        ]
      },
      {
        "featureType": "road.arterial",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#3c3c3c"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#ffffff"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry.fill",
        "stylers": [
          {
            "color": "#000000"
          }
        ]
      }
    ]
    ''';
  }

  void recalculateRoute() {
    if (currentPosition.value == null) return;

    if (_lastRerouteTime != null &&
        DateTime.now().difference(_lastRerouteTime!).inSeconds < 30) {
      return;
    }

    _lastRerouteTime = DateTime.now();
    polyLines.clear(); // Clear old route traces
    updateMarkersAndPolyline();
    isOffRoute.value = false;
  }

  void reportTraffic(int level) {
    trafficLevel.value = level.clamp(0, 2);
    updateTimeAndDistanceEstimates();
    if (isVoiceEnabled.value) {
      queueAnnouncement(getTrafficLevelText(), priority: 1);
    }
  }

  String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      int meters = (distanceInKm * 1000).round();
      return "$meters m";
    }
    return "${distanceInKm.toStringAsFixed(1)} km";
  }

  String formatSpeed(double speedKmh) {
    return "${speedKmh.toStringAsFixed(0)} km/h";
  }

  String getTrafficLevelText() {
    switch (trafficLevel.value) {
      case 0:
        return "Light traffic";
      case 1:
        return "Moderate traffic ahead";
      case 2:
        return "Heavy traffic ahead";
      default:
        return "Unknown traffic";
    }
  }

  Color getTrafficLevelColor() {
    switch (trafficLevel.value) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.red;
      default:
        return Colors.grey;
    }
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
      print("Sharing location: $locationUrl");
      ShowToastDialog.showToast("Location shared: $locationUrl");
    }
  }

  void optimizePerformance() {
    _positionStream?.cancel();

    int distanceFilter = 1;
    if (currentSpeed.value < 5) {
      distanceFilter = 5;
    } else if (distanceToNextTurn.value < 100) {
      distanceFilter = 1;
    } else if (currentSpeed.value > 50) {
      distanceFilter = 2;
    } else if (trafficLevel.value == 2) {
      distanceFilter = 3;
    }

    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        updateDeviceLocation(position);
      },
      onError: (error) {
        print('Location stream error: $error');
        ShowToastDialog.showToast("Error tracking location. Please check GPS.");
        Future.delayed(Duration(seconds: 5), () {
          if (_positionStream == null || _positionStream!.isPaused) {
            optimizePerformance();
          }
        });
      },
      onDone: () {
        print('Location stream closed');
        ShowToastDialog.showToast("Location tracking stopped.");
      },
    );
  }

  void _startLessFrequentPositionStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        updateDeviceLocation(position);
      },
      onError: (error) {
        print('Location stream error: $error');
      },
    );
  }

  Future<void> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      updateDeviceLocation(position);
    } catch (e) {
      print('Error getting current location: $e');
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
          heading: Random().nextDouble() * 360,
          speed: Random().nextDouble() * 20,
          speedAccuracy: 1.0,
          altitudeAccuracy: 1.0,
          headingAccuracy: 45.0,
        );

        updateDeviceLocation(simulatedPosition);
      }
    });
  }
}
