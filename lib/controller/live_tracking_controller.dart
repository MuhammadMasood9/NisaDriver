import 'dart:async';
import 'dart:convert';
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
import 'dart:io';
import 'package:retry/retry.dart';
import 'package:driver/services/realtime_location_service.dart';
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

/// Live tracking controller that uses phone GPS location only
/// No longer fetches location from real-time database
class LiveTrackingController extends GetxController {
  GoogleMapController? mapController;
  FlutterTts? _flutterTts;
  StreamSubscription<Position>? _positionStream;
  DateTime? _lastRerouteTime;
  StreamSubscription<CompassEvent>? _compassSubscription;
  final RealtimeLocationService _realtime = RealtimeLocationService();
  // Removed real-time database subscription - only using phone GPS
  // StreamSubscription<Map<String, dynamic>?>? _rtdbSubscription;
  // bool _isApplyingRemoteUpdate = false;
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
  LatLng? _displayLatLng; // Smoothed/map-matched position for display & publish

  RxList<String> currentLanes = <String>[].obs;
  RxString recommendedLane = "".obs;

  final List<Map<String, dynamic>> _ttsQueue = [];
  bool _isSpeaking = false;
  RxBool _betterRouteAvailable =
      false.obs; // New field for better route availability
  Map<String, dynamic>? _betterRouteData; // New field for better route data
  int _timeSaved = 0; // New field for time saved

  // Google Maps API for road-snapping
  static String get _googleMapsApiKey =>
      Constant.mapAPIKey; // Use your existing API key
  static const String _roadsApiBaseUrl =
      'https://roads.googleapis.com/v1/snapToRoads';

  // Enhanced location tracking
  double _lastBearing = 0.0;

  // User interaction tracking
  DateTime? _lastUserInteraction;

  // Off-route tracking
  int _consecutiveOffRouteChecks = 0;
  DateTime? _firstOffRouteTime;

  // Location update batching removed (live updates)

  // Track last accepted GPS update time for degraded fallback
  DateTime? _lastAcceptedUpdateTime;

  // Traffic-based rerouting
  RxBool hasAlternativeRoute = false.obs;
  Map<String, dynamic>? _alternativeRouteData;

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
  }

  @override
  void onClose() {
    // No timers to cancel (live updates)
    _positionStream?.cancel();
    _compassSubscription?.cancel();
    // Removed real-time database subscription cleanup
    // _rtdbSubscription?.cancel();
    mapController?.dispose();
    _flutterTts?.stop();
    // Clean up realtime location entries when leaving the screen
    _removeRealtimeLocationSafely(type.value == "orderModel"
        ? orderModel.value.id
        : intercityOrderModel.value.id);
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

  void _publishRealtimeLocation() {
    if (currentPosition.value == null) return;
    final String? driverId = FireStoreUtils.getCurrentUid();
    if (driverId == null || driverId.isEmpty) return;

    final String? orderId = type.value == "orderModel"
        ? orderModel.value.id
        : intercityOrderModel.value.id;
    if (orderId == null || orderId.isEmpty) return;

    final LatLng cur = LatLng(
      currentPosition.value!.latitude,
      currentPosition.value!.longitude,
    );

    final String rideStatus = status.value;
    final String phase = showDriverToPickupRoute.value
        ? 'to_pickup'
        : (showPickupToDestinationRoute.value ? 'to_destination' : 'idle');

    _realtime.publishDriverLocation(
      orderId: orderId,
      driverId: driverId,
      latitude: cur.latitude,
      longitude: cur.longitude,
      speedKmh: currentSpeed.value,
      bearing: mapBearing.value,
      accuracy: currentPosition.value!.accuracy,
      rideStatus: rideStatus,
      phase: phase,
    );
  }

  void _removeRealtimeLocationSafely(String? orderId) {
    if (orderId == null || orderId.isEmpty) return;
    final String? driverId = FireStoreUtils.getCurrentUid();
    if (driverId == null || driverId.isEmpty) return;
    _realtime.removeDriverLocation(orderId: orderId, driverId: driverId);
  }

  // Removed _ensureRealtimeSubscription method - no longer subscribing to database
  // void _ensureRealtimeSubscription(String? orderId, String? driverId) {
  //   // This method was used to subscribe to real-time database updates
  //   // Now we only use phone GPS location
  // }

  // Old method replaced by _applyIntelligentSmoothing

  // Simple holder for map-matching result
  // Kept private to this file scope

  Map<String, dynamic> _snapToRoute(LatLng p, List<LatLng> poly) {
    LatLng bestPoint = p;
    double bestDist = double.infinity;
    for (int i = 0; i < poly.length - 1; i++) {
      final LatLng a = poly[i];
      final LatLng b = poly[i + 1];
      final LatLng proj = _projectOnSegment(p, a, b);
      final double d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        proj.latitude,
        proj.longitude,
      );
      if (d < bestDist) {
        bestDist = d;
        bestPoint = proj;
      }
    }
    return {'point': bestPoint, 'distance': bestDist};
  }

  LatLng _projectOnSegment(LatLng p, LatLng a, LatLng b) {
    // Local planar approximation
    final double latRad = ((a.latitude + b.latitude) / 2) * pi / 180.0;
    final double mPerDegLat = 111320.0;
    final double mPerDegLng = 111320.0 * cos(latRad);
    final double bx = (b.longitude - a.longitude) * mPerDegLng;
    final double by = (b.latitude - a.latitude) * mPerDegLat;
    final double px = (p.longitude - a.longitude) * mPerDegLng;
    final double py = (p.latitude - a.latitude) * mPerDegLat;
    final double segLen2 = bx * bx + by * by;
    double t = segLen2 > 0 ? ((px * bx + py * by) / segLen2) : 0.0;
    t = t.clamp(0.0, 1.0);
    final double projX = bx * t;
    final double projY = by * t;
    final double projLng = (projX / mPerDegLng) + a.longitude;
    final double projLat = (projY / mPerDegLat) + a.latitude;
    return LatLng(projLat, projLng);
  }

  /// Start continuous GPS location updates from phone (no database)
  void _startLocationUpdates() {
    _positionStream?.cancel();

    // Optimized location settings for smooth tracking using phone GPS
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      // distanceFilter disabled for live updates
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        // Process location update immediately
        updateDeviceLocation(position);
      },
      onError: (error) {
        dev.log('Location error: $error');
      },
      cancelOnError: false, // Keep stream alive on errors
    );
  }

  void updateDeviceLocation(Position position) async {
    // Enhanced GPS filtering with degraded fallback
    const double strictAccuracy = 10.0;
    const double degradedAccuracy = 20.0;

    final DateTime now = DateTime.now();

    if (position.accuracy > strictAccuracy) {
      final Duration sinceLastAccept = _lastAcceptedUpdateTime == null
          ? const Duration(days: 1)
          : now.difference(_lastAcceptedUpdateTime!);

      if (sinceLastAccept > const Duration(seconds: 3) &&
          position.accuracy <= degradedAccuracy) {
        // Accept a degraded fix to avoid freezing when GPS is temporarily poor
        dev.log(
            'Accepting degraded accuracy ${position.accuracy}m after ${sinceLastAccept.inMilliseconds}ms without good fix');
      } else {
        dev.log('Position rejected: poor accuracy ${position.accuracy}m');
        return;
      }
    }

    // Calculate speed with smoothing
    double newSpeed = position.speed * 3.6;
    if (_previousPosition != null && _previousTime != null) {
      // Smooth speed changes to prevent jitter
      double speedDiff = (newSpeed - currentSpeed.value).abs();
      if (speedDiff > 20) {
        // Large speed change, smooth it
        newSpeed = currentSpeed.value + (newSpeed - currentSpeed.value) * 0.3;
      }
    }

    currentPosition.value = position;
    currentSpeed.value = newSpeed;

    // Fast road snapping with timeout and fallback
    final rawPosition = LatLng(position.latitude, position.longitude);
    LatLng displayPosition = rawPosition;

    // Try road snapping with quick timeout
    try {
      final roadSnapResult = await _snapToRoadsQuick(rawPosition);
      if (roadSnapResult != null) {
        final snappedLat = roadSnapResult['lat'] as double;
        final snappedLng = roadSnapResult['lng'] as double;
        displayPosition = LatLng(snappedLat, snappedLng);
      }
    } catch (e) {
      // Use raw position if snapping fails
      dev.log('Road snapping failed, using raw GPS: $e');
    }

    // Apply intelligent smoothing only when needed
    _displayLatLng = _applyIntelligentSmoothing(displayPosition, position);

    // Add position prediction to compensate for GPS lag
    _displayLatLng = _addPositionPrediction(_displayLatLng!, position);

    // Calculate bearing for marker rotation
    final markerBearing = _calculateSmoothBearing(position);
    mapBearing.value = markerBearing;

    // Store for next iteration
    _previousPosition = position;
    _previousTime = now;
    _lastAcceptedUpdateTime = now;

    // Update marker with smooth animation
    _updateMarkerSmoothly();

    // Immediately update polyline to remove traveled portion when marker moves
    if (routePoints.isNotEmpty) {
      updateDynamicPolyline();
    }

    // Only update camera view if user is not manually controlling the map
    if (isFollowingDriver.value &&
        isNavigationView.value &&
        !_isUserControllingMap()) {
      _updateCameraSmooth();
    }

    // Live refresh of navigation and ancillary info
    _liveRefresh();

    // Publish to Firebase Realtime Database
    _publishRealtimeLocation();

    // Update navigation elements when marker moves significantly
    _updateNavigationOnMovement();
  }

  // Fast road snapping with timeout
  Future<Map<String, dynamic>?> _snapToRoadsQuick(LatLng position) async {
    try {
      final url = Uri.parse(
          '$_roadsApiBaseUrl?key=$_googleMapsApiKey&path=${position.latitude},${position.longitude}&interpolate=true');

      final response =
          await http.get(url).timeout(const Duration(milliseconds: 500));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['snappedPoints'] != null && data['snappedPoints'].isNotEmpty) {
          final snappedPoint = data['snappedPoints'][0];
          final location = snappedPoint['location'];
          return {
            'lat': location['latitude'],
            'lng': location['longitude'],
          };
        }
      }
    } catch (e) {
      // Timeout or network error - fail fast
      return null;
    }
    return null;
  }

  // Intelligent smoothing that adapts to movement patterns
  LatLng _applyIntelligentSmoothing(LatLng newPosition, Position position) {
    if (_displayLatLng == null) {
      return newPosition; // First position, no smoothing needed
    }

    // Calculate distance from last position for potential future use
    // double distance = Geolocator.distanceBetween(
    //   _displayLatLng!.latitude,
    //   _displayLatLng!.longitude,
    //   newPosition.latitude,
    //   newPosition.longitude,
    // );

    // Adaptive smoothing based on movement and accuracy
    double smoothingFactor;

    if (currentSpeed.value < 2) {
      // Stationary or very slow - minimal smoothing to prevent drift
      smoothingFactor = 0.8;
    } else if (currentSpeed.value > 50) {
      // High speed - less smoothing for responsiveness
      smoothingFactor = 0.9;
    } else {
      // Normal speed - moderate smoothing
      smoothingFactor = 0.7;
    }

    // Adjust for GPS accuracy
    if (position.accuracy <= 3) {
      smoothingFactor += 0.1; // High accuracy, trust more
    } else if (position.accuracy > 6) {
      smoothingFactor -= 0.1; // Low accuracy, smooth more
    }

    // Apply route snapping if available
    if (routePoints.isNotEmpty) {
      final snap = _snapToRoute(newPosition, routePoints);
      final LatLng snapPoint = snap['point'] as LatLng;
      final double snapDist = (snap['distance'] as num).toDouble();

      if (snapDist <= 15) {
        // Closer threshold for better road adherence
        newPosition = snapPoint;
        smoothingFactor += 0.1; // Trust route snapping more
      }
    }

    smoothingFactor = smoothingFactor.clamp(0.3, 0.95);

    return LatLng(
      _displayLatLng!.latitude +
          smoothingFactor * (newPosition.latitude - _displayLatLng!.latitude),
      _displayLatLng!.longitude +
          smoothingFactor * (newPosition.longitude - _displayLatLng!.longitude),
    );
  }

  // Smooth bearing calculation
  double _calculateSmoothBearing(Position position) {
    double bearing = 0.0;

    // Use GPS heading if available and reliable
    if (currentSpeed.value > 3 &&
        position.headingAccuracy < 30 &&
        position.heading >= 0) {
      bearing = position.heading;
    }
    // Calculate bearing from movement
    else if (_previousPosition != null && _displayLatLng != null) {
      bearing = _calculateBearing(
        LatLng(_previousPosition!.latitude, _previousPosition!.longitude),
        _displayLatLng!,
      );
    }
    // Use route direction if available
    else if (routePoints.isNotEmpty && _displayLatLng != null) {
      LatLng nextPoint = getNextRoutePoint(_displayLatLng!);
      bearing = _calculateBearing(_displayLatLng!, nextPoint);
    }

    // Smooth bearing transitions to prevent marker spinning
    if (_lastBearing != 0.0) {
      double diff = (bearing - _lastBearing) % 360;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;

      // Adaptive smoothing - less smoothing at higher speeds
      double smoothFactor = currentSpeed.value > 20 ? 0.4 : 0.2;
      bearing = (_lastBearing + smoothFactor * diff) % 360;
    }

    _lastBearing = bearing;
    return bearing;
  }

  // Smooth marker updates without complex animations
  void _updateMarkerSmoothly() {
    if (_displayLatLng == null) return;

    addMarker(
      latitude: _displayLatLng!.latitude,
      longitude: _displayLatLng!.longitude,
      id: "Device",
      descriptor: driverIcon!,
      rotation: compassHeading
          .value, // Use compass heading for marker rotation instead of mapBearing
    );
  }

  // Smooth camera updates
  void _updateCameraSmooth() async {
    if (mapController == null || _displayLatLng == null) return;

    mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _displayLatLng!,
          zoom: _calculateDynamicZoom(),
          tilt: _calculateOptimalTilt(),
        ),
      ),
    );
  }

  // Live per-update refresh – lightweight ops every update, heavier ops gated
  void _liveRefresh() {
    updateRouteVisibility();
    updateNavigationInstructions();
    updateNextRoutePoint();
    updateTimeAndDistanceEstimates();
    checkOffRoute();
    fetchSpeedLimit(_displayLatLng ??
        LatLng(
            currentPosition.value!.latitude, currentPosition.value!.longitude));
  }

  // Position prediction to compensate for GPS lag
  LatLng _addPositionPrediction(LatLng currentPos, Position position) {
    // Only predict if we're moving at a reasonable speed
    if (currentSpeed.value < 5 || _previousPosition == null) {
      return currentPos; // No prediction for stationary or first position
    }

    // Calculate time since last position update
    final timeDiff = DateTime.now().difference(_previousTime ?? DateTime.now());
    final secondsAhead = timeDiff.inMilliseconds / 1000.0;

    // Don't predict too far ahead (max 2 seconds)
    if (secondsAhead > 2.0) {
      return currentPos;
    }

    // Use bearing to predict forward position
    final bearing = mapBearing.value * pi / 180;
    final speedMps = currentSpeed.value / 3.6; // Convert km/h to m/s
    final predictDistance =
        speedMps * secondsAhead * 0.5; // Conservative prediction

    // Calculate predicted coordinates
    final latChange = predictDistance *
        cos(bearing) /
        111320; // Approximate meters to degrees
    final lngChange = predictDistance *
        sin(bearing) /
        (111320 * cos(currentPos.latitude * pi / 180));

    final predictedLat = currentPos.latitude + latChange;
    final predictedLng = currentPos.longitude + lngChange;

    return LatLng(predictedLat, predictedLng);
  }

  void addDeviceMarker() {
    // This method is now handled by _updateMarkerSmoothly()
    // Keeping for backward compatibility
    _updateMarkerSmoothly();
  }

  // Old bearing methods replaced by _calculateSmoothBearing

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

  // Timers removed – all updates happen live on location/compass stream

  // Removed periodic better route checks (no timers); could be triggered manually if needed

  // Removed unused current route duration calculation

  // Removed unused suggest route change helper

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
    // Don't adjust camera if user is manually controlling the map
    if (_isUserControllingMap()) return;

    // Dynamic zoom based on speed and context
    navigationZoom.value = _calculateDynamicZoom();

    // Smooth camera movement
    if (mapController != null && isFollowingDriver.value) {
      try {
        mapController!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _displayLatLng ?? devicePos,
              zoom: navigationZoom.value,
              tilt: _calculateOptimalTilt(),
            ),
          ),
        );
      } catch (_) {}
    }
  }

  void onMapTap(LatLng position) {
    _onUserInteraction();
  }

  void onMapDrag() {
    _onUserInteraction();
  }

  void onMapPinch() {
    _onUserInteraction();
  }

  void _onUserInteraction() {
    // User is manually controlling the map
    isFollowingDriver.value = false;
    _lastUserInteraction = DateTime.now();
  }

  // Removed auto re-center timer; user can trigger centering via UI actions

  bool _isUserControllingMap() {
    if (_lastUserInteraction == null) return false;
    final timeSinceInteraction =
        DateTime.now().difference(_lastUserInteraction!);
    return timeSinceInteraction.inSeconds < 5;
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
    // More intelligent off-route detection
    bool currentlyOffRoute =
        minDistanceToRoute > 50; // Increased threshold for major deviation

    if (currentlyOffRoute) {
      _consecutiveOffRouteChecks++;
      if (_firstOffRouteTime == null) {
        _firstOffRouteTime = DateTime.now();
      }

      // Only trigger reroute if consistently off route for 10 seconds AND moved significantly
      final timeSinceFirstOffRoute =
          DateTime.now().difference(_firstOffRouteTime!);
      if (_consecutiveOffRouteChecks >= 5 &&
          timeSinceFirstOffRoute.inSeconds >= 10) {
        if (!wasOffRoute) {
          isOffRoute.value = true;
          queueAnnouncement("Recalculating route to get back on track.",
              priority: 3);
          _clearRoutePolylines();
          recalculateRoute();
        }
      }
    } else {
      // Reset off-route tracking
      _consecutiveOffRouteChecks = 0;
      _firstOffRouteTime = null;

      if (wasOffRoute) {
        isOffRoute.value = false;
        queueAnnouncement("Back on route. Continue following the path.",
            priority: 3);
        polyLines.remove(const PolylineId("ReturnToRoute"));
        nextRoutePointIndex.value = closestIndex;
        updateDynamicPolyline();
      }
    }
  }

  void _clearRoutePolylines() {
    // Clear all route-related polylines
    polyLines.removeWhere((key, value) =>
        key.value.contains('route') ||
        key.value.contains('Route') ||
        key.value == 'polyline_id_0');
  }

  // Clear old breadcrumb trails and optimize polyline display
  void _cleanupOldPolylines() {
    // Remove breadcrumb trail if it's too old or if we're off route
    if (isOffRoute.value || polyLines.length > 3) {
      polyLines.removeWhere((key, value) =>
          key.value == "BreadcrumbTrail" ||
          key.value.contains("old") ||
          key.value.contains("trail"));
    }
  }

  void updateDynamicPolyline() {
    if (routePoints.isEmpty || currentPosition.value == null) return;

    // Clean up old polylines first
    _cleanupOldPolylines();

    LatLng devicePos = LatLng(
        currentPosition.value!.latitude, currentPosition.value!.longitude);
    int closestIndex = 0;
    double minDistance = double.infinity;

    // Find the closest route point to current position
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

    // Only update if we've moved significantly (more than 5 meters from last update)
    if (_lastAcceptedUpdateTime != null &&
        _previousPosition != null &&
        minDistance < 5) {
      return; // Skip update if movement is minimal
    }

    // Get remaining route points from current position onwards
    List<LatLng> remainingPoints = routePoints.sublist(closestIndex);

    // Add current position as the starting point for smoother polyline
    if (remainingPoints.isNotEmpty) {
      remainingPoints.insert(0, devicePos);
    }

    String polylineId = showDriverToPickupRoute.value
        ? "DeviceToPickup"
        : "DeviceToDestination";
    Color color =
        showDriverToPickupRoute.value ? AppColors.primary : Colors.black;

    // Clear existing route polylines but keep breadcrumb trail
    polyLines.removeWhere((key, value) =>
        key.value == "DeviceToPickup" ||
        key.value == "DeviceToDestination" ||
        key.value == "polyline_id_0");

    if (remainingPoints.length > 1) {
      _addPolyLine(remainingPoints, polylineId, color);
    }

    // Update next route point index for navigation
    nextRoutePointIndex.value = min(closestIndex + 5, routePoints.length - 1);

    // Create breadcrumb trail showing recent travel path
    _addBreadcrumbTrail(devicePos, closestIndex);
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

    LatLng base = _displayLatLng ??
        LatLng(
            currentPosition.value!.latitude, currentPosition.value!.longitude);
    LatLng targetLocation = base;

    // Smooth camera animation with easing
    mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: targetLocation,
          zoom: navigationZoom.value,
          tilt: _calculateOptimalTilt(),
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
            // Removed real-time database subscription - only using phone GPS
            // _ensureRealtimeSubscription(
            //     orderModel.value.id, FireStoreUtils.getCurrentUid());
            if (orderModel.value.status == Constant.rideComplete) {
              _removeRealtimeLocationSafely(orderModel.value.id);
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
            // Removed real-time database subscription - only using phone GPS
            // _ensureRealtimeSubscription(
            //     intercityOrderModel.value.id, FireStoreUtils.getCurrentUid());
            if (intercityOrderModel.value.status == Constant.rideComplete) {
              _removeRealtimeLocationSafely(intercityOrderModel.value.id);
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
        await Constant().getBytesFromAsset('assets/images/ic_cab.png', 50);
    departureIcon = BitmapDescriptor.fromBytes(departure);
    destinationIcon = BitmapDescriptor.fromBytes(destination);
    driverIcon = BitmapDescriptor.fromBytes(driver);
  }

  void _addPolyLine(
      List<LatLng> polylineCoordinates, String polylineId, Color color) {
    if (polylineCoordinates.isEmpty) return;

    // Use smooth transition for better visual experience
    _smoothPolylineTransition(polylineId, polylineCoordinates, color);
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
    mapController!.moveCamera(cameraUpdate);
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

  /// Get current location using phone GPS only (no database fetching)
  Future<void> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      updateDeviceLocation(position);
    } catch (e) {
      ShowToastDialog.showToast("Error getting current location from GPS");
    }
  }

  void simulateMovement() {
    if (currentPosition.value == null) return;

    Timer.periodic(Duration(milliseconds: 100), (timer) {
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

  // Traffic optimization removed - handled by existing better route detection

  // Alternative route methods removed - handled by existing route optimization

  void acceptAlternativeRoute() {
    if (_alternativeRouteData != null) {
      _updateRouteWithAlternative(_alternativeRouteData!);
      hasAlternativeRoute.value = false;
      _alternativeRouteData = null;

      // Remove alternative route preview
      polyLines.remove(const PolylineId("alternative_route"));

      if (isVoiceEnabled.value) {
        queueAnnouncement("Route updated. Following new path.", priority: 2);
      }
    }
  }

  void rejectAlternativeRoute() {
    hasAlternativeRoute.value = false;
    _alternativeRouteData = null;

    // Remove alternative route preview
    polyLines.remove(const PolylineId("alternative_route"));
  }

  // Removed periodic traffic checks (no timers)

  // Removed unused traffic area heuristic

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

  // Old road snapping and bearing methods replaced by optimized versions

  // Create breadcrumb trail showing recent travel path
  void _addBreadcrumbTrail(LatLng currentPos, int startIndex) {
    if (startIndex <= 0 || routePoints.isEmpty) return;

    // Show last 100-200 meters of traveled route as a subtle trail
    int trailStartIndex = max(0, startIndex - 3);
    List<LatLng> trailPoints = routePoints.sublist(trailStartIndex, startIndex);

    if (trailPoints.length > 1) {
      // Add current position to complete the trail
      trailPoints.add(currentPos);

      // Create a subtle breadcrumb trail
      PolylineId trailId = const PolylineId("BreadcrumbTrail");
      Polyline breadcrumbTrail = Polyline(
        polylineId: trailId,
        points: trailPoints,
        color: Colors.grey.withOpacity(0.3),
        width: 2,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        patterns: [PatternItem.dash(5), PatternItem.gap(3)],
      );

      polyLines[trailId] = breadcrumbTrail;
    }
  }

  // Handle smooth polyline transitions when route changes
  void _smoothPolylineTransition(
      String newPolylineId, List<LatLng> newPoints, Color color) {
    // Remove old polyline with the same ID
    polyLines.remove(PolylineId(newPolylineId));

    // Add new polyline with smooth animation effect
    if (newPoints.length > 1) {
      PolylineId id = PolylineId(newPolylineId);
      Polyline polyline = Polyline(
        polylineId: id,
        points: newPoints,
        color: color,
        width: 3,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        patterns:
            isOffRoute.value ? [PatternItem.dash(10), PatternItem.gap(5)] : [],
        geodesic: true,
      );

      polyLines[id] = polyline;
    }
  }

  // Update navigation elements when marker moves significantly
  void _updateNavigationOnMovement() {
    if (routePoints.isEmpty || currentPosition.value == null) return;

    // Update navigation instructions
    updateNavigationInstructions();

    // Update next route point
    updateNextRoutePoint();

    // Update time and distance estimates
    updateTimeAndDistanceEstimates();

    // Check if we're approaching a turn
    if (distanceToNextTurn.value < 100) {
      checkUpcomingTurns(LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude));
    }
  }
}
