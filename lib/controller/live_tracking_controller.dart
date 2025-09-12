import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:developer' as dev;
// Removed unnecessary import
// removed duplicate import
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
import 'package:driver/services/background_location_service.dart';
import 'package:driver/services/enhanced_realtime_location_service.dart';
import 'package:driver/model/enhanced_location_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/ui/review/review_screen.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:flutter/services.dart';
import 'package:driver/services/polyline_manager.dart';
import 'package:driver/model/polyline_models.dart';

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

// Enhanced off-route detection result
class OffRouteResult {
  final bool isOffRoute;
  final double distance;
  final int closestIndex;
  final double deviation;
  final OffRouteSeverity severity;

  OffRouteResult({
    required this.isOffRoute,
    required this.distance,
    required this.closestIndex,
    required this.deviation,
    required this.severity,
  });
}

// Off-route severity levels
enum OffRouteSeverity {
  low,
  medium,
  high,
  critical,
}

// Route health status
enum RouteHealthStatus {
  noRoute,
  offRoute,
  poor,
  fair,
  good,
  excellent,
}

// Custom Tween for LatLng interpolation
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end})
      : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}

/// Live tracking controller that uses phone GPS location only
/// No longer fetches location from real-time database
class LiveTrackingController extends GetxController {
  GoogleMapController? mapController;
  FlutterTts? _flutterTts;
  StreamSubscription<Position>? _positionStream;

  // Pixel offset for camera centering relative to the marker (X right+, Y down+)
  int _cameraOffsetXPx = 0;
  int _cameraOffsetYPx = 0;

  // Optional fixed zoom override; when set, camera uses this zoom instead of dynamic
  double? _fixedZoomLevel;

  // Track zoom gesture state for better behavior during pinches
  double? _lastCameraMoveZoom;

  // Update camera centering offset in pixels. Positive X moves the marker left on screen,
  // positive Y moves the marker up on screen (since we shift the camera the opposite way).
  void setCameraOffset({int xPx = 0, int yPx = 0}) {
    _cameraOffsetXPx = xPx;
    _cameraOffsetYPx = yPx;
  }

  // Set a fixed zoom level to keep while following the driver
  void setFixedZoom(double zoomLevel) {
    _fixedZoomLevel = zoomLevel;
  }

  // Clear fixed zoom and resume dynamic zoom behavior
  void clearFixedZoom() {
    _fixedZoomLevel = null;
  }

  // Convenience: center on current driver position with a specific zoom now
  Future<void> centerDriverWithZoom(double zoomLevel) async {
    setFixedZoom(zoomLevel);
    final LatLng target = _lastAnimatedPosition ??
        _displayLatLng ??
        (currentPosition.value != null
            ? LatLng(currentPosition.value!.latitude,
                currentPosition.value!.longitude)
            : LatLng(0, 0));
    _updateCameraSmooth(target: target);
  }

  DateTime? _lastRerouteTime;
  StreamSubscription<CompassEvent>? _compassSubscription;
  final RealtimeLocationService _realtime = RealtimeLocationService();
  final BackgroundLocationService _backgroundLocation =
      BackgroundLocationService();
  final EnhancedRealtimeLocationService _enhancedRealtime =
      EnhancedRealtimeLocationService();
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

  // Smart polyline management
  PolylineManager? _polylineManager;
  StreamSubscription<Set<Polyline>>? _polylineSubscription;

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
  final RxBool _betterRouteAvailable =
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
  Timer? _recenterTimer;
  static const Duration _recenterDelay = Duration(seconds: 5);

  // Enhanced off-route tracking
  int _consecutiveOffRouteChecks = 0;
  DateTime? _firstOffRouteTime;
  // Removed unused _lastOffRouteDistance
  final List<LatLng> _offRouteHistory = [];
  bool _isRerouting = false;
  Timer? _rerouteTimer;
  Timer? _trafficCheckTimer;

  // Location update batching removed (live updates)

  // Track last accepted GPS update time for degraded fallback
  DateTime? _lastAcceptedUpdateTime;
  
  // Debounce timer to prevent rapid updateMarkersAndPolyline calls
  Timer? _updateDebounceTimer;

  // Enhanced traffic-based rerouting
  RxBool hasAlternativeRoute = false.obs;
  Map<String, dynamic>? _alternativeRouteData;
  final List<Map<String, dynamic>> _routeAlternatives = [];
  int _currentRouteIndex = 0;
  double _routeQualityScore = 0.0;

  // Advanced rerouting parameters
  static const double _offRouteThreshold = 30.0; // meters
  static const double _criticalOffRouteThreshold = 100.0; // meters
  // Removed unused _maxRerouteAttempts
  static const Duration _rerouteCooldown = Duration(seconds: 3);
  static const Duration _trafficUpdateInterval = Duration(minutes: 2);

  // Animation system for smooth marker movement
  AnimationController? _animationController;
  Animation<LatLng>? _positionAnimation;
  LatLng? _lastAnimatedPosition;
  // Removed unused _tickerProvider

  @override
  void onInit() {
    super.onInit();
    
    // Initialize markers first
    addMarkerSetup();
    initializeTTS();

    // Initialize smart polyline management
    _initializePolylineManager();

    // Check if driver is online before initializing location services
    if (_isDriverOnline()) {
      initializeLocationServices(); // This now also starts location tracking
    } else {
      dev.log(
          'Driver is offline, location tracking will start when going online');
    }
    
    // Ensure driver is centered when screen loads
    _ensureDriverCentered();

    _initializeCompass();
    
    // Initialize arguments and data immediately
    getArgument();
    
    isFollowingDriver.value = true;
    isNavigationView.value = true;

    // Set camera offset to keep driver lower on screen for better road-ahead visibility
    setCameraOffset(xPx: 0, yPx: -140);

    // Initialize enhanced rerouting system
    _initializeEnhancedRerouting();

    // Initialize enhanced services
    _initializeEnhancedServices();

    // Listen to app lifecycle changes for background tracking
    _initializeAppLifecycleListener();

    // Start background tracking if driver is already online
    if (_isDriverOnline()) {
      _startBackgroundLocationTracking();
    }
  }

  // Initialize smart polyline management
  void _initializePolylineManager() {
    try {
      _polylineManager = PolylineManager();

      // Subscribe to polyline updates and sync with the reactive map
      _polylineSubscription =
          _polylineManager?.polylinesStream.listen((polylines) {
        // Convert Set<Polyline> to RxMap format for backward compatibility
        final Map<PolylineId, Polyline> polylineMap = {};
        for (final polyline in polylines) {
          polylineMap[polyline.polylineId] = polyline;
        }
        polyLines.value = polylineMap;
      });
    } catch (e) {
      dev.log('Failed to initialize PolylineManager: $e');
      // Continue without polyline manager
    }

    dev.log('PolylineManager initialized and connected to reactive streams');
  }

  // Initialize enhanced services
  void _initializeEnhancedServices() async {
    try {
      await _enhancedRealtime.initialize();
      dev.log('Enhanced realtime service initialized successfully');

      // Listen to connection state changes
      _enhancedRealtime.connectionState.listen((state) {
        dev.log('Enhanced realtime connection state: ${state.value}');
      });

      // Listen to service errors
      _enhancedRealtime.errors.listen((error) {
        dev.log('Enhanced realtime service error: $error');
      });
    } catch (e) {
      dev.log('Failed to initialize enhanced services: $e');
    }
  }

  // Initialize enhanced rerouting system
  void _initializeEnhancedRerouting() {
    // Enable predictive rerouting
    enablePredictiveRerouting();

    // Initialize route quality score
    _routeQualityScore = 100.0;

    // Set up periodic route health checks
    Timer.periodic(const Duration(minutes: 2), (timer) {
      if (routePoints.isNotEmpty && !_isRerouting) {
        _checkRouteHealth();
      }
    });
  }

  // Check route health and suggest optimizations
  void _checkRouteHealth() {
    RouteHealthStatus health = getRouteHealthStatus();

    switch (health) {
      case RouteHealthStatus.poor:
        if (isVoiceEnabled.value) {
          queueAnnouncement("Route quality is poor. Consider optimization.",
              priority: 2);
        }
        break;
      case RouteHealthStatus.fair:
        // Silent check, no announcement needed
        break;
      case RouteHealthStatus.good:
      case RouteHealthStatus.excellent:
        // Route is healthy
        break;
      default:
        break;
    }

    // Auto-optimize if route is poor and we're not in critical situations
    if (health == RouteHealthStatus.poor &&
        !isOffRoute.value &&
        currentSpeed.value > 5) {
      triggerRouteOptimization();
    }
  }

  @override
  void onClose() {
    // Cancel all timers
    _rerouteTimer?.cancel();
    _trafficCheckTimer?.cancel();
    _recenterTimer?.cancel();
    _positionStream?.cancel();
    _compassSubscription?.cancel();
    // Removed real-time database subscription cleanup
    // _rtdbSubscription?.cancel();
    mapController?.dispose();
    _flutterTts?.stop();
    _enhancedRealtime.dispose();

    // Clean up polyline manager
    _polylineSubscription?.cancel();
    _polylineManager?.dispose();

    // Stop background location tracking
    _stopBackgroundLocationTracking();

    // Clean up debounce timer
    _updateDebounceTimer?.cancel();

    // Clean up realtime location entries when leaving the screen
    _removeRealtimeLocationSafely(type.value == "orderModel"
        ? orderModel.value.id
        : intercityOrderModel.value.id);
    ShowToastDialog.closeLoader();
    super.onClose();
  }

  // Initialize animation system with TickerProvider
  void initAnimation(TickerProvider tickerProvider) {
    _animationController = AnimationController(
      vsync: tickerProvider,
      duration: const Duration(milliseconds: 800), // Controls animation speed
    )..addListener(() {
        // This listener is called on every animation frame
        if (_positionAnimation != null) {
          _lastAnimatedPosition = _positionAnimation!.value;
          _updateMarkerWithAnimatedValue();
        }
      });
  }

  // Clean up animation controller
  void disposeAnimation() {
    _animationController?.dispose();
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
        // Bearing on marker disabled: do not rotate marker with compass
      }
    });
  }

  void _publishRealtimeLocation() {
    if (currentPosition.value == null) return;

    // Check if driver is online before publishing location
    if (!_isDriverOnline()) {
      dev.log('Driver is offline, skipping location update');
      return;
    }

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

    // Legacy realtime service
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

    // Enhanced realtime service with better data structure
    _publishEnhancedLocation(orderId, driverId, cur, rideStatus, phase);
  }

  void _publishEnhancedLocation(String orderId, String driverId,
      LatLng position, String rideStatus, String phase) {
    try {
      // Determine ride phase
      RidePhase ridePhase;
      switch (phase) {
        case 'to_pickup':
          ridePhase = RidePhase.enRouteToPickup;
          break;
        case 'to_destination':
          ridePhase = RidePhase.rideInProgress;
          break;
        default:
          ridePhase = RidePhase.enRouteToPickup;
      }

      // Get battery level (placeholder - would need actual battery API)
      double batteryLevel = 100.0;

      // Determine network quality based on connection
      NetworkQuality networkQuality = NetworkQuality.good;

      // Create enhanced location data
      final enhancedData = EnhancedLocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: currentSpeed.value,
        bearing: mapBearing.value,
        accuracy: currentPosition.value!.accuracy,
        status: rideStatus,
        phase: ridePhase,
        timestamp: DateTime.now(),
        sequenceNumber: DateTime.now().millisecondsSinceEpoch,
        batteryLevel: batteryLevel,
        networkQuality: networkQuality,
        metadata: {
          'orderId': orderId,
          'driverId': driverId,
          'appVersion': '1.0.0',
          'deviceType': 'driver',
        },
      );

      // Publish enhanced location data
      _enhancedRealtime.publishLocation(enhancedData);
    } catch (e) {
      dev.log('Error publishing enhanced location: $e');
    }
  }

  /// Check if the driver is currently online
  bool _isDriverOnline() {
    try {
      // Get the dashboard controller to check online status
      final dashBoardController = Get.find<DashBoardController>();
      return dashBoardController.isOnline.value;
    } catch (e) {
      // If dashboard controller is not found, assume offline for safety
      dev.log('Dashboard controller not found, assuming offline: $e');
      return false;
    }
  }

  /// Public method to manually start location tracking (useful for external calls)
  void startLocationTracking() {
    if (_isDriverOnline()) {
      dev.log('Manually starting location tracking');
      initializeLocationServices();
    } else {
      dev.log('Cannot start location tracking: driver is offline');
    }
  }

  /// Public method to manually stop location tracking
  void stopLocationTracking() {
    dev.log('Manually stopping location tracking');
    _positionStream?.pause();
    _removeAllRealtimeLocations();
  }

  /// Check if background location tracking is active
  bool get isBackgroundTrackingActive => _backgroundLocation.isTracking;

  /// Get background tracking status information
  Map<String, String?> get backgroundTrackingInfo =>
      _backgroundLocation.trackingInfo;

  /// Force start background tracking (for testing)
  Future<void> forceStartBackgroundTracking() async {
    dev.log('Force starting background tracking');
    await _startBackgroundLocationTracking();
  }

  /// Trigger manual location update (for testing)
  Future<void> triggerManualLocationUpdate() async {
    dev.log('Triggering manual location update');
    if (_backgroundLocation.isTracking) {
      await _backgroundLocation.triggerManualLocationUpdate();
    } else {
      dev.log('Background tracking not active, cannot trigger manual update');
    }
  }

  /// Force immediate location update (for testing)
  Future<void> forceImmediateLocationUpdate() async {
    dev.log('Forcing immediate location update');
    if (_backgroundLocation.isTracking) {
      await _backgroundLocation.forceImmediateUpdate();
    } else {
      dev.log('Background tracking not active, cannot force update');
    }
  }

  /// Get detailed background tracking status
  Map<String, dynamic> getDetailedBackgroundTrackingStatus() {
    if (_backgroundLocation.isTracking) {
      return _backgroundLocation.getDetailedTrackingStatus();
    } else {
      return {
        'isTracking': false,
        'message': 'Background tracking not active',
      };
    }
  }

  /// Check if background tracking is working and get status
  Map<String, dynamic> getBackgroundTrackingStatus() {
    return {
      'isOnline': _isDriverOnline(),
      'hasCurrentPosition': currentPosition.value != null,
      'isBackgroundTrackingActive': _backgroundLocation.isTracking,
      'backgroundTrackingInfo': _backgroundLocation.trackingInfo,
      'foregroundStreamActive':
          _positionStream != null && !_positionStream!.isPaused,
    };
  }

  /// Handle driver online/offline status changes
  void onDriverStatusChanged(bool isOnline) {
    if (isOnline) {
      dev.log('Driver went online, resuming location tracking');
      // Resume location updates if not already running
      if (_positionStream == null || _positionStream!.isPaused) {
        _startLocationUpdates();
      }

      // Start background location tracking if there's an active order
      _startBackgroundLocationTracking();
    } else {
      dev.log('Driver went offline, pausing location tracking');
      // Pause location updates but keep the stream alive
      _positionStream?.pause();
      // Remove any existing location data from Firebase
      _removeAllRealtimeLocations();

      // Stop background location tracking
      _stopBackgroundLocationTracking();
    }
  }

  /// Remove all realtime location entries for the current driver
  void _removeAllRealtimeLocations() {
    try {
      final String? driverId = FireStoreUtils.getCurrentUid();
      if (driverId == null || driverId.isEmpty) return;

      // Remove location for current order if exists
      if (type.value == "orderModel" && orderModel.value.id != null) {
        _removeRealtimeLocationSafely(orderModel.value.id);
      } else if (type.value == "interCityOrderModel" &&
          intercityOrderModel.value.id != null) {
        _removeRealtimeLocationSafely(intercityOrderModel.value.id);
      }
    } catch (e) {
      dev.log('Error removing realtime locations: $e');
    }
  }

  void _removeRealtimeLocationSafely(String? orderId) {
    if (orderId == null || orderId.isEmpty) return;
    final String? driverId = FireStoreUtils.getCurrentUid();
    if (driverId == null || driverId.isEmpty) return;
    _realtime.removeDriverLocation(orderId: orderId, driverId: driverId);
  }

  /// Start background location tracking for the current order
  Future<void> _startBackgroundLocationTracking() async {
    try {
      if (!_isDriverOnline()) {
        dev.log('Driver is offline, not starting background tracking');
        return;
      }

      final String? driverId = FireStoreUtils.getCurrentUid();
      if (driverId == null || driverId.isEmpty) return;

      String? orderId;
      if (type.value == "orderModel" && orderModel.value.id != null) {
        orderId = orderModel.value.id;
      } else if (type.value == "interCityOrderModel" &&
          intercityOrderModel.value.id != null) {
        orderId = intercityOrderModel.value.id;
      }

      // If no active order, create a temporary tracking session for background
      if (orderId == null || orderId.isEmpty) {
        orderId =
            "background_tracking_${DateTime.now().millisecondsSinceEpoch}";
        dev.log('No active order, using temporary order ID: $orderId');
      }

      // Get current position for initial location
      if (currentPosition.value != null) {
        final success = await _backgroundLocation.startBackgroundTracking(
          orderId: orderId,
          driverId: driverId,
          initialLatitude: currentPosition.value!.latitude,
          initialLongitude: currentPosition.value!.longitude,
        );

        if (success) {
          dev.log('Background location tracking started for order: $orderId');
        } else {
          dev.log('Failed to start background location tracking');
        }
      } else {
        dev.log('No current position available for background tracking');
      }
    } catch (e) {
      dev.log('Error starting background location tracking: $e');
    }
  }

  /// Stop background location tracking
  Future<void> _stopBackgroundLocationTracking() async {
    try {
      await _backgroundLocation.stopBackgroundTracking();
      dev.log('Background location tracking stopped');
    } catch (e) {
      dev.log('Error stopping background location tracking: $e');
    }
  }

  /// Initialize app lifecycle listener for background tracking
  void _initializeAppLifecycleListener() {
    // Listen to app lifecycle changes
    SystemChannels.lifecycle.setMessageHandler((msg) async {
      dev.log('App lifecycle message: $msg');

      if (msg == AppLifecycleState.paused.toString()) {
        // App going to background - start background tracking if driver is online
        _onAppGoingToBackground();
      } else if (msg == AppLifecycleState.resumed.toString()) {
        // App coming to foreground - stop background tracking, resume foreground
        _onAppComingToForeground();
      }

      return null;
    });

    dev.log('App lifecycle listener initialized for background tracking');
  }

  /// Handle app going to background
  void _onAppGoingToBackground() {
    dev.log('App going to background - starting background location tracking');

    if (_isDriverOnline() && currentPosition.value != null) {
      // Start background tracking immediately
      _startBackgroundLocationTracking();

      // Also pause foreground tracking to save resources
      _positionStream?.pause();
      dev.log('Foreground tracking paused, background tracking active');
    }
  }

  /// Handle app coming to foreground
  void _onAppComingToForeground() {
    dev.log('App coming to foreground - stopping background tracking');

    // Stop background tracking since we're back in foreground
    _stopBackgroundLocationTracking();

    // Resume foreground tracking if it was paused
    if (_positionStream != null && _positionStream!.isPaused) {
      _positionStream!.resume();
      dev.log('Foreground tracking resumed');
    }
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
    // Check if driver is online before starting location updates
    if (!_isDriverOnline()) {
      dev.log('Driver is offline, not starting location updates');
      return;
    }

    _positionStream?.cancel();

    // Optimized location settings for smooth tracking using phone GPS
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      // Continuous updates without distance filtering
      distanceFilter: 0,
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
        if (error is TimeoutException) {
          // Silently retry on timeout to avoid spam
          Future.delayed(const Duration(seconds: 2), () {
            if (!_positionStream!.isPaused) {
              _startLocationUpdates();
            }
          });
        } else {
          ShowToastDialog.showToast(
              "Error tracking location. Please check GPS.");
        }
      },
      cancelOnError: false, // Keep stream alive on errors
    );

    // Start traffic monitoring
    _startTrafficMonitoring();
  }

  void updateDeviceLocation(Position position) async {
    // Check if driver is online before processing location updates
    if (!_isDriverOnline()) {
      dev.log('Driver is offline, skipping location processing');
      return;
    }

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

    // The smoothed/predicted position is now our ANIMATION TARGET
    final LatLng animationTarget = _displayLatLng!;

    // --- [NEW] The Animation Driving Logic ---
    if (_animationController != null) {
      // If this is the first point, jump directly to it
      if (_lastAnimatedPosition == null) {
        _lastAnimatedPosition = animationTarget;
        _updateMarkerWithAnimatedValue();
      } else {
        // Create a new animation from the last animated position to the new target
        _positionAnimation = LatLngTween(
          begin: _lastAnimatedPosition!,
          end: animationTarget,
        ).animate(
          CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
        );
        _animationController!.forward(from: 0.0);
      }
    } else {
      // Fallback to old method if animation is not initialized
      _updateMarkerSmoothly();
    }

    // Calculate bearing for marker rotation
    final markerBearing = _calculateSmoothBearing(position);
    mapBearing.value = markerBearing;

    // Store for next iteration
    _previousPosition = position;
    _previousTime = now;
    _lastAcceptedUpdateTime = now;

    // Only update camera view if user is not manually controlling the map
    if (isFollowingDriver.value &&
        isNavigationView.value &&
        !_isUserControllingMap()) {
      // Use animated position for smoother camera following
      _updateCameraSmooth(target: _lastAnimatedPosition ?? animationTarget);
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
      rotation: 0.0, // Keep marker straight (no rotation) in all conditions
    );
  }

  // Smooth camera updates
  void _updateCameraSmooth({LatLng? target}) async {
    if (mapController == null) return;

    // Use the provided target or fallback to the last animated position
    final LatLng cameraTarget = target ??
        _lastAnimatedPosition ??
        _displayLatLng ??
        LatLng(
            currentPosition.value!.latitude, currentPosition.value!.longitude);

    // Apply screen offset so the marker is not exactly at the visual center
    final LatLng adjustedTarget =
        await _applyCameraOffsetToTarget(cameraTarget);

    mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: adjustedTarget,
          zoom: _getTargetZoom(),
          tilt: _calculateOptimalTilt(),
        ),
      ),
    );
  }

  // Determine the zoom to use: fixed override if present, otherwise dynamic
  double _getTargetZoom() {
    final double zoom = _fixedZoomLevel ?? _calculateDynamicZoom();
    // Reasonable clamp for Google Maps zoom levels
    if (zoom < 2.0) return 2.0;
    if (zoom > 21.0) return 21.0;
    return zoom;
  }

  // Convert the desired target to an off-centered LatLng using screen pixel offsets
  Future<LatLng> _applyCameraOffsetToTarget(LatLng target) async {
    if (mapController == null) return target;
    if (_cameraOffsetXPx == 0 && _cameraOffsetYPx == 0) return target;
    try {
      final ScreenCoordinate screen =
          await mapController!.getScreenCoordinate(target);
      // Shift by configured pixels
      final ScreenCoordinate shifted = ScreenCoordinate(
        x: screen.x + _cameraOffsetXPx,
        y: screen.y + _cameraOffsetYPx,
      );
      final LatLng shiftedLatLng = await mapController!.getLatLng(shifted);
      return shiftedLatLng;
    } catch (_) {
      // If projection is not ready or fails, fall back to original target
      return target;
    }
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
    // Ensure driver icon is loaded before adding marker
    if (driverIcon == null) {
      addMarkerSetup().then((_) {
        addDeviceMarker();
      });
      return;
    }
    
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

      // Update progress with new route
      updateTripProgress();
    }
  }

  // Public method to trigger route optimization
  void triggerRouteOptimization() {
    if (!_isRerouting && routePoints.isNotEmpty) {
      optimizeRouteForConditions();
    }
  }

  // Public method to force reroute
  void forceReroute() {
    if (!_isRerouting) {
      recalculateRoute();
    }
  }

  // Public method to check route health
  RouteHealthStatus getRouteHealthStatus() {
    if (routePoints.isEmpty) return RouteHealthStatus.noRoute;

    if (isOffRoute.value) return RouteHealthStatus.offRoute;

    if (_routeQualityScore < 30) return RouteHealthStatus.poor;
    if (_routeQualityScore < 60) return RouteHealthStatus.fair;
    if (_routeQualityScore < 80) return RouteHealthStatus.good;

    return RouteHealthStatus.excellent;
  }

  // Get route statistics
  Map<String, dynamic> getRouteStatistics() {
    return {
      'totalDistance': _calculateTotalRouteDistance(routePoints),
      'estimatedDuration': _getCurrentRouteDuration(),
      'qualityScore': _routeQualityScore,
      'trafficLevel': trafficLevel.value,
      'isOffRoute': isOffRoute.value,
      'hasAlternatives': _routeAlternatives.isNotEmpty,
      'lastOptimization': _lastRerouteTime?.toIso8601String(),
    };
  }

  // Predictive rerouting based on traffic patterns
  void enablePredictiveRerouting() {
    // This could be enhanced with machine learning models
    // For now, we'll use simple heuristics
    Timer.periodic(const Duration(minutes: 2), (timer) {
      if (routePoints.isNotEmpty && !_isRerouting) {
        _predictAndPreventTrafficIssues();
      }
    });
  }

  // Predict and prevent traffic issues
  void _predictAndPreventTrafficIssues() async {
    try {
      if (currentPosition.value == null) return;

      LatLng source = LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude);
      LatLng destination = getTargetLocation();

      // Check traffic conditions ahead
      Map<String, dynamic>? trafficData =
          await _fetchTrafficData(source, destination);
      if (trafficData != null) {
        _analyzeTrafficPredictions(trafficData);
      }
    } catch (e) {
      dev.log('Traffic prediction failed: $e');
    }
  }

  // Analyze traffic predictions
  void _analyzeTrafficPredictions(Map<String, dynamic> trafficData) {
    try {
      if (trafficData['routes'] == null || trafficData['routes'].isEmpty) {
        return;
      }

      var route = trafficData['routes'][0];
      if (route['legs'] == null || route['legs'].isEmpty) {
        return;
      }

      var leg = route['legs'][0];
      double duration = (leg['duration']?['value'] ?? 0).toDouble();
      double durationInTraffic =
          (leg['duration_in_traffic']?['value'] ?? duration).toDouble();

      // If traffic is significantly worse, suggest proactive reroute
      if (durationInTraffic > duration * 1.3) {
        if (isVoiceEnabled.value) {
          queueAnnouncement("Heavy traffic ahead. Consider alternative route.",
              priority: 2);
        }

        // Show traffic warning
        _showTrafficWarning();
      }
    } catch (e) {
      dev.log('Traffic prediction analysis failed: $e');
    }
  }

  // Show traffic warning
  void _showTrafficWarning() {
    // This could show a visual warning on the map
    // For now, we'll just log it
    dev.log('Traffic warning: Heavy traffic detected ahead');
  }

  // Check if better route is available
  bool get isBetterRouteAvailable => _betterRouteAvailable.value;

  // Get time saved with better route
  int get timeSavedWithBetterRoute => _timeSaved;

  void updateAutoNavigation() {
    if (!isAutoNavigationEnabled.value ||
        routePoints.isEmpty ||
        currentPosition.value == null) {
      return;
    }

    LatLng devicePos = LatLng(
        currentPosition.value!.latitude, currentPosition.value!.longitude);
    checkUpcomingTurns(devicePos);
    adjustCameraForNavigation(devicePos);
    updateLaneGuidance();
  }

  void resetToDefaultView() {
    isFollowingDriver.value = true;
    isNavigationView.value = true;
    // Smart polyline management - only clear if needed, not brute force
    _polylineManager?.clearAllRoutes();
    updateNavigationView();
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

    // Smooth camera movement using animated position
    if (mapController != null && isFollowingDriver.value) {
      try {
        _updateCameraSmooth(
            target: _lastAnimatedPosition ?? _displayLatLng ?? devicePos);
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
    // Do not disable following; just lock current zoom so user controls zoom
    _lockZoomToCurrent();
    _onUserInteraction();
  }

  // Capture user zoom during camera movement (e.g., pinch) and lock it
  void onCameraMoveUpdate(CameraPosition position) {
    final double previousZoom = _lastCameraMoveZoom ?? position.zoom;
    _lastCameraMoveZoom = position.zoom;
    final bool isZoomGesture = (position.zoom - previousZoom).abs() > 0.02;

    if (isZoomGesture) {
      // User is pinching to zoom; keep following but lock zoom to user's choice
      navigationZoom.value = position.zoom;
      setFixedZoom(position.zoom);
    } else {
      // Likely a drag/pan; treat as manual control
      _onUserInteraction();
      navigationZoom.value = position.zoom;
    }
  }

  Future<void> _lockZoomToCurrent() async {
    if (mapController == null) return;
    try {
      final double zoom = await mapController!.getZoomLevel();
      setFixedZoom(zoom);
    } catch (_) {
      // ignore
    }
  }

  // Re-center on driver after user interaction ends
  void onMapIdle() {
    // Do not auto-recenter immediately after interaction; wait for explicit recenter
    if (mapController == null) return;

    // If following is enabled, keep camera aligned smoothly
    if (isFollowingDriver.value) {
      LatLng target = _lastAnimatedPosition ??
          _displayLatLng ??
          (currentPosition.value != null
              ? LatLng(currentPosition.value!.latitude,
                  currentPosition.value!.longitude)
              : LatLng(0, 0));
      _updateCameraSmooth(target: target);
    }
  }

  void _onUserInteraction() {
    // User is manually controlling the map
    isFollowingDriver.value = false;
    _lastUserInteraction = DateTime.now();
    // Schedule auto-recenter after a delay of no interaction
    _recenterTimer?.cancel();
    _recenterTimer = Timer(_recenterDelay, () {
      // If there has been no new interaction since scheduling, recenter
      if (_lastUserInteraction != null &&
          DateTime.now().difference(_lastUserInteraction!) >= _recenterDelay) {
        isFollowingDriver.value = true;
        clearFixedZoom();
        updateNavigationView();
      }
    });
  }

  // Removed auto re-center timer; user can trigger centering via UI actions

  bool _isUserControllingMap() {
    if (_lastUserInteraction == null) return false;
    final timeSinceInteraction =
        DateTime.now().difference(_lastUserInteraction!);
    return timeSinceInteraction < _recenterDelay;
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
    if (routePoints.isEmpty || currentPosition.value == null || _isRerouting) {
      return;
    }

    LatLng devicePos = LatLng(
        currentPosition.value!.latitude, currentPosition.value!.longitude);

    // Enhanced off-route detection with multiple algorithms
    OffRouteResult result = await _analyzeOffRouteStatus(devicePos);

    bool wasOffRoute = isOffRoute.value;
    bool currentlyOffRoute = result.isOffRoute;

    if (currentlyOffRoute) {
      _consecutiveOffRouteChecks++;
      _offRouteHistory.add(devicePos);

      _firstOffRouteTime ??= DateTime.now();

      // Enhanced rerouting logic
      if (_shouldTriggerReroute(result)) {
        if (!wasOffRoute) {
          isOffRoute.value = true;
          _triggerIntelligentReroute(result);
        }
      }
    } else {
      // Reset off-route tracking
      _consecutiveOffRouteChecks = 0;
      _firstOffRouteTime = null;
      _offRouteHistory.clear();

      if (wasOffRoute) {
        isOffRoute.value = false;
        queueAnnouncement("Back on route. Continue following the path.",
            priority: 3);
        _restoreRouteDisplay();
      }
    }
  }

  // Enhanced off-route analysis
  Future<OffRouteResult> _analyzeOffRouteStatus(LatLng devicePos) async {
    double minDistanceToRoute = double.infinity;
    int closestIndex = 0;
    double routeDeviation = 0.0;

    // Find closest route point
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

    // Calculate route deviation pattern
    if (_offRouteHistory.length >= 3) {
      routeDeviation = _calculateRouteDeviationPattern();
    }

    // Multi-factor off-route detection
    bool isOffRoute = _evaluateOffRouteStatus(
        minDistanceToRoute, closestIndex, routeDeviation);

    return OffRouteResult(
      isOffRoute: isOffRoute,
      distance: minDistanceToRoute,
      closestIndex: closestIndex,
      deviation: routeDeviation,
      severity: _calculateOffRouteSeverity(minDistanceToRoute, routeDeviation),
    );
  }

  // Evaluate off-route status using multiple factors
  bool _evaluateOffRouteStatus(
      double distance, int closestIndex, double deviation) {
    // Base threshold
    if (distance <= _offRouteThreshold) return false;

    // Critical threshold - immediate reroute
    if (distance >= _criticalOffRouteThreshold) return true;

    // Pattern-based detection
    if (deviation > 0.7 && distance > _offRouteThreshold * 0.8) return true;

    // Speed-based detection
    if (currentSpeed.value > 20 && distance > _offRouteThreshold * 0.6) {
      return true;
    }

    // Time-based detection
    if (_consecutiveOffRouteChecks >= 3) return true;

    return false;
  }

  // Calculate off-route severity
  OffRouteSeverity _calculateOffRouteSeverity(
      double distance, double deviation) {
    if (distance >= _criticalOffRouteThreshold) {
      return OffRouteSeverity.critical;
    }
    if (distance >= _offRouteThreshold * 1.5) return OffRouteSeverity.high;
    if (deviation > 0.5) return OffRouteSeverity.medium;
    return OffRouteSeverity.low;
  }

  // Calculate route deviation pattern
  double _calculateRouteDeviationPattern() {
    if (_offRouteHistory.length < 3) return 0.0;

    double totalDeviation = 0.0;
    for (int i = 1; i < _offRouteHistory.length; i++) {
      LatLng prev = _offRouteHistory[i - 1];
      LatLng curr = _offRouteHistory[i];

      // Calculate if movement is away from route
      double distance = Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );

      if (distance > 0) {
        totalDeviation += distance;
      }
    }

    return totalDeviation / (_offRouteHistory.length - 1);
  }

  // Determine if reroute should be triggered
  bool _shouldTriggerReroute(OffRouteResult result) {
    // Critical off-route - immediate reroute
    if (result.severity == OffRouteSeverity.critical) return true;

    // Consistent off-route pattern
    if (_consecutiveOffRouteChecks >= 3 &&
        result.distance > _offRouteThreshold) {
      return true;
    }

    // Significant deviation pattern
    if (result.deviation > 0.6 && result.distance > _offRouteThreshold * 0.8) {
      return true;
    }

    // Time-based trigger
    if (_firstOffRouteTime != null) {
      final timeSinceFirstOffRoute =
          DateTime.now().difference(_firstOffRouteTime!);
      if (timeSinceFirstOffRoute.inSeconds >= 8) return true;
    }

    return false;
  }

  // Trigger intelligent rerouting
  void _triggerIntelligentReroute(OffRouteResult result) {
    if (_isRerouting) return;

    _isRerouting = true;
    queueAnnouncement("Recalculating route to get back on track.", priority: 3);

    // Clear current route display
    _clearRoutePolylines();

    // Choose rerouting strategy based on severity
    switch (result.severity) {
      case OffRouteSeverity.critical:
        _emergencyReroute();
        break;
      case OffRouteSeverity.high:
        _aggressiveReroute();
        break;
      case OffRouteSeverity.medium:
        _standardReroute();
        break;
      case OffRouteSeverity.low:
        _conservativeReroute();
        break;
    }
  }

  // Emergency reroute for critical situations
  void _emergencyReroute() {
    _rerouteTimer?.cancel();
    _rerouteTimer = Timer(const Duration(seconds: 1), () {
      recalculateRoute();
      _isRerouting = false;
    });
  }

  // Aggressive reroute for high severity
  void _aggressiveReroute() {
    _rerouteTimer?.cancel();
    _rerouteTimer = Timer(const Duration(seconds: 2), () {
      recalculateRoute();
      _isRerouting = false;
    });
  }

  // Standard reroute
  void _standardReroute() {
    _rerouteTimer?.cancel();
    _rerouteTimer = Timer(const Duration(seconds: 3), () {
      recalculateRoute();
      _isRerouting = false;
    });
  }

  // Conservative reroute
  void _conservativeReroute() {
    _rerouteTimer?.cancel();
    _rerouteTimer = Timer(const Duration(seconds: 5), () {
      recalculateRoute();
      _isRerouting = false;
    });
  }

  // Restore route display after getting back on track
  void _restoreRouteDisplay() {
    polyLines.remove(const PolylineId("ReturnToRoute"));
    polyLines.remove(const PolylineId("OffRoutePath"));
    updateDynamicPolyline();

    // Update progress when back on route
    updateTripProgress();
  }

  // Clear route polylines
  void _clearRoutePolylines() {
    try {
      _polylineManager?.clearAllRoutes();
    } catch (e) {
      dev.log('Error clearing route polylines: $e');
    }
    
    // Fallback: clear polylines manually
    polyLines.removeWhere((key, value) =>
        key.value.contains("route") || 
        key.value == "DeviceToPickup" || 
        key.value == "DeviceToDestination");
  }

  void updateDynamicPolyline({bool force = false}) {
    if (routePoints.isEmpty) return;

    // Use animated position if available, otherwise fallback to current position
    LatLng devicePos = _lastAnimatedPosition ??
        _displayLatLng ??
        LatLng(
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

    // Only update if we've moved significantly (more than 3 meters) unless forced
    if (!force &&
        _lastAcceptedUpdateTime != null &&
        _previousPosition != null &&
        minDistance < 3) {
      return; // Skip update if movement is minimal
    }

    // Get remaining route points from current position onwards
    List<LatLng> remainingPoints = routePoints.sublist(closestIndex);

    // Add current position as the starting point for smoother polyline
    if (remainingPoints.isNotEmpty) {
      remainingPoints.insert(0, devicePos);
    }

    if (remainingPoints.length > 1) {
      // Smart polyline update using PolylineManager - no more clearing!
      String routeId = showDriverToPickupRoute.value
          ? RoutePhase.toPickup.routeId
          : RoutePhase.toDestination.routeId;

      PolylineStyle style = showDriverToPickupRoute.value
          ? PolylineStyle.pickup()
          : PolylineStyle.destination();

      // Let PolylineManager handle intelligent diffing and updates
      _polylineManager?.updateRoute(
        routeId: routeId,
        points: remainingPoints,
        style: style,
        metadata: {
          'closestIndex': closestIndex,
          'devicePosition': '${devicePos.latitude},${devicePos.longitude}',
          'lastUpdate': DateTime.now().toIso8601String(),
        },
      );
    }

    // Update next route point index for navigation
    nextRoutePointIndex.value = min(closestIndex + 5, routePoints.length - 1);

    // Update progress when route polyline is updated
    updateTripProgress();
  }

  void updateNextRoutePoint() {
    if (routePoints.isEmpty) return;

    // Use animated position if available, otherwise fallback to current position
    LatLng devicePos = _lastAnimatedPosition ??
        _displayLatLng ??
        LatLng(
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
    double progressPercentage = 0.0;

    if (currentPosition.value == null) {
      tripProgressValue.value = 0.0;
      tripProgress.value = "0%";
      return;
    }

    if (type.value == "orderModel") {
      if (orderModel.value.status == Constant.rideInProgress) {
        // Calculate progress based on route completion
        progressPercentage = _calculateRouteProgress(
          LatLng(currentPosition.value!.latitude,
              currentPosition.value!.longitude),
          LatLng(orderModel.value.sourceLocationLAtLng!.latitude!,
              orderModel.value.sourceLocationLAtLng!.longitude!),
          LatLng(orderModel.value.destinationLocationLAtLng!.latitude!,
              orderModel.value.destinationLocationLAtLng!.longitude!),
        );
      } else if (orderModel.value.status == Constant.rideActive) {
        // Going to pickup - calculate progress from current position to pickup
        progressPercentage = _calculatePickupProgress(
          LatLng(currentPosition.value!.latitude,
              currentPosition.value!.longitude),
          LatLng(orderModel.value.sourceLocationLAtLng!.latitude!,
              orderModel.value.sourceLocationLAtLng!.longitude!),
        );
      } else {
        progressPercentage = 0.0;
      }
    } else {
      if (intercityOrderModel.value.status == Constant.rideInProgress) {
        // Calculate progress based on route completion
        progressPercentage = _calculateRouteProgress(
          LatLng(currentPosition.value!.latitude,
              currentPosition.value!.longitude),
          LatLng(intercityOrderModel.value.sourceLocationLAtLng!.latitude!,
              intercityOrderModel.value.sourceLocationLAtLng!.longitude!),
          LatLng(intercityOrderModel.value.destinationLocationLAtLng!.latitude!,
              intercityOrderModel.value.destinationLocationLAtLng!.longitude!),
        );
      } else if (intercityOrderModel.value.status == Constant.rideActive) {
        // Going to pickup - calculate progress from current position to pickup
        progressPercentage = _calculatePickupProgress(
          LatLng(currentPosition.value!.latitude,
              currentPosition.value!.longitude),
          LatLng(intercityOrderModel.value.sourceLocationLAtLng!.latitude!,
              intercityOrderModel.value.sourceLocationLAtLng!.longitude!),
        );
      } else {
        progressPercentage = 0.0;
      }
    }

    progressPercentage = progressPercentage.clamp(0.0, 100.0);
    tripProgressValue.value = progressPercentage / 100;
    tripProgress.value = "${progressPercentage.toStringAsFixed(0)}%";
  }

  // Calculate progress when going to pickup location
  double _calculatePickupProgress(LatLng currentPos, LatLng pickupLocation) {
    // For pickup progress, we'll use a simple distance-based calculation
    // This could be enhanced with actual route progress if route is available
    double totalDistance = calculateDistanceBetweenPoints(
      currentPos.latitude,
      currentPos.longitude,
      pickupLocation.latitude,
      pickupLocation.longitude,
    );

    // If we're very close to pickup, show high progress
    if (totalDistance < 0.1) {
      // Less than 100 meters
      return 95.0;
    }

    // Simple linear progress based on distance
    // This is a rough approximation - could be improved with actual route progress
    return (1.0 - (totalDistance / 10.0)) * 100; // Assume max 10km to pickup
  }

  // Calculate progress when traveling from pickup to destination
  double _calculateRouteProgress(
      LatLng currentPos, LatLng pickupLocation, LatLng destinationLocation) {
    if (routePoints.isEmpty) {
      // Fallback to simple distance-based calculation
      double totalTripDistance = calculateDistanceBetweenPoints(
        pickupLocation.latitude,
        pickupLocation.longitude,
        destinationLocation.latitude,
        destinationLocation.longitude,
      );

      double remainingDistance = calculateDistanceBetweenPoints(
        currentPos.latitude,
        currentPos.longitude,
        destinationLocation.latitude,
        destinationLocation.longitude,
      );

      if (totalTripDistance <= 0) return 0.0;

      double coveredDistance = totalTripDistance - remainingDistance;
      return (coveredDistance / totalTripDistance) * 100;
    } else {
      // Use route-based progress calculation
      return _calculateRouteBasedProgress(currentPos);
    }
  }

  // Calculate progress based on actual route points
  double _calculateRouteBasedProgress(LatLng currentPos) {
    if (routePoints.isEmpty) return 0.0;

    // Find the closest route point to current position
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length; i++) {
      double distance = calculateDistanceBetweenPoints(
        currentPos.latitude,
        currentPos.longitude,
        routePoints[i].latitude,
        routePoints[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    // Calculate progress based on position along the route
    double progress = (closestIndex / (routePoints.length - 1)) * 100;

    // Ensure we don't show 100% until we're very close to destination
    if (closestIndex >= routePoints.length - 1) {
      // Check if we're actually at the destination
      double distanceToDestination = calculateDistanceBetweenPoints(
        currentPos.latitude,
        currentPos.longitude,
        routePoints.last.latitude,
        routePoints.last.longitude,
      );

      if (distanceToDestination < 0.05) {
        // Within 50 meters
        progress = 100.0;
      } else {
        progress = 95.0; // Close but not quite there
      }
    }

    return progress;
  }

  Future<double> calculateDistance(
      double startLat, double startLng, double endLat, double endLng) async {
    try {
      return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
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

    // Smooth camera animation with easing using animated position
    _updateCameraSmooth(target: _lastAnimatedPosition ?? targetLocation);
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
      // Smart route phase transition - switch phases instead of clearing everything
      final newPhase = showDriverToPickupRoute.value
          ? RoutePhase.toPickup
          : showPickupToDestinationRoute.value
              ? RoutePhase.toDestination
              : RoutePhase.completed;
      _polylineManager?.switchRoutePhase(newPhase);
      updateMarkersAndPolyline();
      // Update progress when route phase changes
      updateTripProgress();
    }
  }

  getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      type.value = argumentData['type'];
      
      // Set loading to true to prevent flickering
      isLoading.value = true;
      
      // Initialize markers and trip progress immediately
      await _initializeMarkersAndProgress();
      
      if (type.value == "orderModel") {
        OrderModel argumentOrderModel = argumentData['orderModel'];
        
        // Set initial order model data
        orderModel.value = argumentOrderModel;
        status.value = orderModel.value.status ?? "";
        
        // Initialize markers and routes immediately
        updateRouteVisibility();
        updateTripProgress();
        
        // Set up Firestore listener for real-time updates
        FireStoreUtils.fireStore
            .collection(CollectionName.orders)
            .doc(argumentOrderModel.id)
            .snapshots()
            .listen((event) {
          if (event.data() != null) {
            orderModel.value = OrderModel.fromJson(event.data()!);
            status.value = orderModel.value.status ?? "";
            updateRouteVisibility();
            // Update progress when order status changes
            updateTripProgress();
            
            if (orderModel.value.status == Constant.rideComplete) {
              _removeRealtimeLocationSafely(orderModel.value.id);
              // Navigate to review screen
              Get.to(() => const ReviewScreen(), arguments: {
                "type": "orderModel",
                "orderModel": orderModel.value,
              });
            } else if (orderModel.value.status == Constant.rideActive ||
                orderModel.value.status == Constant.rideInProgress) {
              // Start background tracking for active rides
              _startBackgroundLocationTracking();
            }
          }
        });
      } else {
        InterCityOrderModel argumentOrderModel =
            argumentData['interCityOrderModel'];
            
        // Set initial intercity order model data
        intercityOrderModel.value = argumentOrderModel;
        status.value = intercityOrderModel.value.status ?? "";
        
        // Initialize markers and routes immediately
        updateRouteVisibility();
        updateTripProgress();
        
        // Set up Firestore listener for real-time updates
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
            // Update progress when order status changes
            updateTripProgress();
            
            if (intercityOrderModel.value.status == Constant.rideComplete) {
              _removeRealtimeLocationSafely(intercityOrderModel.value.id);
              // Navigate to review screen
              Get.to(() => const ReviewScreen(), arguments: {
                "type": "intercityOrderModel",
                "orderModel": intercityOrderModel.value,
              });
            } else if (intercityOrderModel.value.status ==
                    Constant.rideActive ||
                intercityOrderModel.value.status == Constant.rideInProgress) {
              // Start background tracking for active rides
              _startBackgroundLocationTracking();
            }
          }
        });
      }
    }
    
    // Add a small delay to ensure everything is properly initialized
    await Future.delayed(const Duration(milliseconds: 100));
    
    isLoading.value = false;
    update();
    updateRouteVisibility();
  }

  void updateMarkersAndPolyline() {
    // Cancel any existing debounce timer
    _updateDebounceTimer?.cancel();
    
    // Debounce the update to prevent rapid calls
    _updateDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _updateMarkersAndPolylineDebounced();
    });
  }
  
  void _updateMarkersAndPolylineDebounced() {
    markers.clear();
    // Smart polyline management - don't clear everything, let PolylineManager handle updates
    // polyLines.clear(); // REMOVED - replaced with smart management

    if (currentPosition.value == null) {
      // Only show the toast once to prevent flickering
      if (!isLoading.value) {
        ShowToastDialog.showToast("Waiting for location...");
        isLoading.value = true;
        
        // Get current location and update markers
        getCurrentLocation().then((_) {
          isLoading.value = false;
          // Only call updateMarkersAndPolyline if we still don't have a position
          if (currentPosition.value == null) {
            Future.delayed(const Duration(milliseconds: 1000), () {
              updateMarkersAndPolyline();
            });
          } else {
            // We have a position now, update markers normally
            _updateMarkersAndPolylineInternal();
          }
        }).catchError((error) {
          isLoading.value = false;
          ShowToastDialog.showToast("Failed to get location. Please try again.");
        });
      }
      return;
    }
    
    _updateMarkersAndPolylineInternal();
  }
  
  void _updateMarkersAndPolylineInternal() {

    // Ensure markers are loaded before proceeding
    if (driverIcon == null || departureIcon == null || destinationIcon == null) {
      addMarkerSetup().then((_) {
        _updateMarkersAndPolylineInternal();
      });
      return;
    }

    addDeviceMarker();

    if (type.value == "orderModel") {
      if (showDriverToPickupRoute.value && orderModel.value.sourceLocationLAtLng != null) {
        addMarker(
          latitude: orderModel.value.sourceLocationLAtLng!.latitude,
          longitude: orderModel.value.sourceLocationLAtLng!.longitude,
          id: "Departure",
          descriptor: departureIcon!,
          rotation: 0.0,
        );
        // Ensure no stale route polylines before drawing new
        polyLines.removeWhere((key, value) => key.value == "DeviceToPickup");
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
      if (showPickupToDestinationRoute.value && orderModel.value.destinationLocationLAtLng != null) {
        addMarker(
          latitude: orderModel.value.destinationLocationLAtLng!.latitude,
          longitude: orderModel.value.destinationLocationLAtLng!.longitude,
          id: "Destination",
          descriptor: destinationIcon!,
          rotation: 0.0,
        );
        polyLines
            .removeWhere((key, value) => key.value == "DeviceToDestination");
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
      if (showDriverToPickupRoute.value && intercityOrderModel.value.sourceLocationLAtLng != null) {
        addMarker(
          latitude: intercityOrderModel.value.sourceLocationLAtLng!.latitude,
          longitude: intercityOrderModel.value.sourceLocationLAtLng!.longitude,
          id: "Departure",
          descriptor: departureIcon!,
          rotation: 0.0,
        );
        polyLines.removeWhere((key, value) => key.value == "DeviceToPickup");
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
      if (showPickupToDestinationRoute.value && intercityOrderModel.value.destinationLocationLAtLng != null) {
        addMarker(
          latitude:
              intercityOrderModel.value.destinationLocationLAtLng!.latitude,
          longitude:
              intercityOrderModel.value.destinationLocationLAtLng!.longitude,
          id: "Destination",
          descriptor: destinationIcon!,
          rotation: 0.0,
        );
        polyLines
            .removeWhere((key, value) => key.value == "DeviceToDestination");
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
    updateTripProgress();
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
        destinationLongitude == null) {
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
      // Smart polyline update from cache using PolylineManager
      _updateRouteWithPolylineManager(polylineId, polylineCoordinates, color);
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
      // Update progress when route is loaded
      updateTripProgress();
    }

    // Smart polyline update using PolylineManager
    _updateRouteWithPolylineManager(polylineId, polylineCoordinates, color);
  }

  // Helper method to update routes using PolylineManager
  void _updateRouteWithPolylineManager(
      String polylineId, List<LatLng> points, Color color) {
    // Map legacy polylineId to RoutePhase
    String routeId;
    PolylineStyle style;

    if (polylineId == "DeviceToPickup") {
      routeId = RoutePhase.toPickup.routeId;
      style = PolylineStyle.pickup();
    } else if (polylineId == "DeviceToDestination") {
      routeId = RoutePhase.toDestination.routeId;
      style = PolylineStyle.destination();
    } else {
      // Generic route
      routeId = polylineId;
      style = PolylineStyle(color: color, width: 4.0);
    }

    // Use PolylineManager for smart updates
    _polylineManager?.updateRoute(
      routeId: routeId,
      points: points,
      style: style,
      metadata: {
        'source': 'getPolyline',
        'originalId': polylineId,
        'fetchTime': DateTime.now().toIso8601String(),
      },
    );

    // Trigger dynamic polyline update for current position
    updateDynamicPolyline(force: true);
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

  Future<void> addMarkerSetup() async {
    final Uint8List departure =
        await Constant().getBytesFromAsset('assets/images/pickup.png', 50);
    final Uint8List destination =
        await Constant().getBytesFromAsset('assets/images/dropoff.png', 50);
    final Uint8List driver =
        await Constant().getBytesFromAsset('assets/images/ic_cab.png', 70);
    departureIcon = BitmapDescriptor.fromBytes(departure);
    destinationIcon = BitmapDescriptor.fromBytes(destination);
    driverIcon = BitmapDescriptor.fromBytes(driver);
  }

  // Initialize markers and trip progress immediately when screen loads
  Future<void> _initializeMarkersAndProgress() async {
    try {
      dev.log('Starting marker and progress initialization...');
      
      // Ensure markers are loaded
      if (departureIcon == null || destinationIcon == null || driverIcon == null) {
        dev.log('Loading marker icons...');
        await addMarkerSetup();
      }

      // Get current location if not available
      if (currentPosition.value == null) {
        dev.log('Getting current location...');
        await getCurrentLocation();
      }

      // Initialize trip progress immediately
      dev.log('Updating trip progress...');
      updateTripProgress();
      
      // Force update markers and polylines
      dev.log('Updating markers and polylines...');
      updateMarkersAndPolyline();
      
      // Update navigation view
      dev.log('Updating navigation view...');
      updateNavigationView();
      
      dev.log('Markers and progress initialized successfully');
    } catch (e) {
      dev.log('Error initializing markers and progress: $e');
      // Don't retry automatically to prevent infinite loops and flickering
      // The UI will handle the error state gracefully
    }
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
    // Reset zoom to dynamic when toggling view
    clearFixedZoom();
    isFollowingDriver.value = true;
    isNavigationView.value = true;
    // Smart polyline management - refresh routes instead of clearing
    _refreshCurrentRoutes();
    updateNavigationView();
    updateMarkersAndPolyline();

    // Re-center with dynamic zoom after toggling
    final LatLng target = _lastAnimatedPosition ??
        _displayLatLng ??
        (currentPosition.value != null
            ? LatLng(currentPosition.value!.latitude,
                currentPosition.value!.longitude)
            : LatLng(0, 0));
    _updateCameraSmooth(target: target);
  }

  // Helper method to refresh current routes without clearing everything
  void _refreshCurrentRoutes() {
    // Only refresh if we have active routes
    if (showDriverToPickupRoute.value || showPickupToDestinationRoute.value) {
      // Let the existing route fetching logic handle the refresh
      updateMarkersAndPolyline();
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
                _rerouteCooldown.inSeconds) ||
        _isRerouting) {
      return;
    }

    _lastRerouteTime = DateTime.now();
    _isRerouting = true;

    // Smart route recalculation - clear only current route, not everything
    final currentPhase = showDriverToPickupRoute.value
        ? RoutePhase.toPickup
        : RoutePhase.toDestination;
    _polylineManager?.removeRoute(currentPhase.routeId);

    // Show rerouting indicator
    _showReroutingIndicator();

    // Try to recalculate with different parameters
    _recalculateWithAlternatives();
  }

  // Show rerouting indicator
  void _showReroutingIndicator() {
    if (currentPosition.value == null) return;

    // Create a simple rerouting indicator
    List<LatLng> indicatorPoints = [
      LatLng(currentPosition.value!.latitude, currentPosition.value!.longitude),
      getTargetLocation(),
    ];

    _addPolyLine(indicatorPoints, "rerouting_indicator",
        Colors.orange.withValues(alpha: 0.5));

    if (isVoiceEnabled.value) {
      queueAnnouncement("Calculating new route...", priority: 2);
    }
  }

  // Enhanced route recalculation with alternatives
  void _recalculateWithAlternatives() async {
    if (currentPosition.value == null) return;

    try {
      LatLng source = LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude);
      LatLng destination = getTargetLocation();

      // Try multiple routing strategies
      List<Map<String, dynamic>> routingStrategies = [
        {
          'mode': 'driving',
          'alternatives': true,
          'avoid': 'tolls',
          'traffic_model': 'best_guess',
        },
        {
          'mode': 'driving',
          'alternatives': true,
          'avoid': 'highways',
          'traffic_model': 'best_guess',
        },
        {
          'mode': 'driving',
          'alternatives': false,
          'traffic_model': 'best_guess',
        },
      ];

      for (int i = 0; i < routingStrategies.length; i++) {
        var strategy = routingStrategies[i];

        try {
          Map<String, dynamic>? routeData =
              await _fetchRouteWithStrategy(source, destination, strategy);
          if (routeData != null) {
            _updateRouteWithAlternative(routeData);
            isOffRoute.value = false;
            _isRerouting = false;

            // Remove rerouting indicator
            polyLines.remove(const PolylineId("rerouting_indicator"));

            if (isVoiceEnabled.value) {
              queueAnnouncement("New route calculated successfully.",
                  priority: 2);
            }

            // Update progress with new route
            updateTripProgress();
            return;
          }
        } catch (e) {
          dev.log('Routing strategy $i failed: $e');
          continue;
        }
      }

      // If all strategies fail, create direct route
      _createDirectRoute(source, destination);
      _isRerouting = false;
    } catch (e) {
      dev.log('Route recalculation failed: $e');
      // Create direct route as fallback
      if (currentPosition.value != null) {
        LatLng source = LatLng(
            currentPosition.value!.latitude, currentPosition.value!.longitude);
        LatLng destination = getTargetLocation();
        _createDirectRoute(source, destination);
      }
      _isRerouting = false;
    }
  }

  // Fetch route with specific strategy
  Future<Map<String, dynamic>?> _fetchRouteWithStrategy(
      LatLng source, LatLng destination, Map<String, dynamic> strategy) async {
    try {
      String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${source.latitude},${source.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=${strategy['mode']}&'
          'key=${Constant.mapAPIKey}';

      if (strategy['alternatives'] == true) {
        url += '&alternatives=true';
      }

      if (strategy['avoid'] != null) {
        url += '&avoid=${strategy['avoid']}';
      }

      if (strategy['traffic_model'] != null) {
        url += '&traffic_model=${strategy['traffic_model']}&departure_time=now';
      }

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          return data['routes'][0];
        }
      }
    } catch (e) {
      dev.log('Route fetch with strategy failed: $e');
    }
    return null;
  }

  // Create direct route as fallback
  void _createDirectRoute(LatLng source, LatLng destination) {
    List<LatLng> directRoute = [source, destination];
    routePoints.value = directRoute;

    // Smart direct route creation using PolylineManager
    _polylineManager?.updateRoute(
      routeId: "DirectRoute",
      points: directRoute,
      style: PolylineStyle(color: Colors.red, width: 4.0),
    );

    if (isVoiceEnabled.value) {
      queueAnnouncement("Using direct route due to navigation issues.",
          priority: 3);
    }

    // Update progress with direct route
    updateTripProgress();
  }

  void centerMapOnDriver() {
    isFollowingDriver.value = true;
    isNavigationView.value = true;
    // Smart centering - refresh routes instead of clearing
    _refreshCurrentRoutes();
    updateNavigationView();
    updateMarkersAndPolyline();
  }

  /// Ensure driver is centered when screen first loads
  Future<void> _ensureDriverCentered() async {
    // Wait a bit for the map to be ready
    await Future.delayed(const Duration(milliseconds: 500));
    
    // If we have a current position, center on it
    if (currentPosition.value != null) {
      centerMapOnDriver();
    } else {
      // Try to get current location and then center
      try {
        await getCurrentLocation();
        if (currentPosition.value != null) {
          centerMapOnDriver();
        }
      } catch (e) {
        dev.log('Failed to get initial location for centering: $e');
      }
    }
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

      // Update progress with new route
      updateTripProgress();
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
    if (currentSpeed.value < 5) {
      baseZoom += 0.8; // Closer view when slow
    } else if (currentSpeed.value > 80) {
      baseZoom -= 0.8; // Wider view when fast
    }

    // Turn-based adjustments
    if (distanceToNextTurn.value < 100) {
      baseZoom += 0.5; // Closer view for turns
    } else if (distanceToNextTurn.value > 500) {
      baseZoom -= 0.3; // Wider view for straight roads
    }

    // Traffic-based adjustments
    if (trafficLevel.value > 1) {
      baseZoom += 0.3; // Closer view in heavy traffic
    }

    return baseZoom.clamp(14.0, 18.0);
  }

  // Enhanced route update with alternative
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

      // Update polylines with smart transition using PolylineManager
      _polylineManager?.updateRoute(
        routeId: "OptimizedRoute",
        points: newRoutePoints,
        style: PolylineStyle(color: AppColors.primary, width: 4.0),
      );

      // Update route quality score
      _routeQualityScore = _calculateRouteQualityScore(
          _getCurrentRouteDuration(),
          _getCurrentRouteDuration(), // Assuming no traffic data in routeData
          _calculateTotalRouteDistance(newRoutePoints),
          0);

      // Announce route change
      if (isVoiceEnabled.value) {
        queueAnnouncement("Route optimized and updated successfully.",
            priority: 1);
      }

      // Update navigation elements
      updateNavigationInstructions();
      updateNextRoutePoint();
      updateTimeAndDistanceEstimates();
      updateTripProgress();
    } catch (e) {
      dev.log('Route update failed: $e');
      if (isVoiceEnabled.value) {
        queueAnnouncement("Route update failed. Using current route.",
            priority: 3);
      }
    }
  }

  // Calculate total route distance
  double _calculateTotalRouteDistance(List<LatLng> points) {
    if (points.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return totalDistance;
  }

  // Optimize route for current conditions
  void optimizeRouteForConditions() async {
    if (currentPosition.value == null || routePoints.isEmpty) return;

    try {
      LatLng source = LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude);
      LatLng destination = getTargetLocation();

      // Check if optimization is needed
      if (_shouldOptimizeRoute()) {
        Map<String, dynamic>? optimizedRoute =
            await _fetchOptimizedRoute(source, destination);
        if (optimizedRoute != null) {
          _updateRouteWithAlternative(optimizedRoute);
          if (isVoiceEnabled.value) {
            queueAnnouncement("Route optimized for current conditions.",
                priority: 2);
          }

          // Update progress with optimized route
          updateTripProgress();
        }
      }
    } catch (e) {
      dev.log('Route optimization failed: $e');
    }
  }

  // Check if route should be optimized
  bool _shouldOptimizeRoute() {
    // Optimize if traffic is heavy
    if (trafficLevel.value >= 2) return true;

    // Optimize if we're moving slowly
    if (currentSpeed.value < 10 && currentSpeed.value > 0) return true;

    // Optimize if route quality is poor
    if (_routeQualityScore < 50) return true;

    // Optimize if we've been on the same route for a while
    if (_lastRerouteTime != null) {
      final timeSinceLastReroute = DateTime.now().difference(_lastRerouteTime!);
      if (timeSinceLastReroute.inMinutes > 10) return true;
    }

    return false;
  }

  // Fetch optimized route
  Future<Map<String, dynamic>?> _fetchOptimizedRoute(
      LatLng source, LatLng destination) async {
    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${source.latitude},${source.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=driving&'
          'alternatives=true&'
          'departure_time=now&'
          'traffic_model=best_guess&'
          'key=${Constant.mapAPIKey}';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          // Return the best route based on current conditions
          return _selectBestRouteForConditions(data['routes']);
        }
      }
    } catch (e) {
      dev.log('Optimized route fetch failed: $e');
    }
    return null;
  }

  // Select best route for current conditions
  Map<String, dynamic> _selectBestRouteForConditions(List<dynamic> routes) {
    if (routes.isEmpty) return routes.first;

    // Score each route based on current conditions
    List<Map<String, dynamic>> scoredRoutes = [];

    for (var route in routes) {
      var leg = route['legs'][0];
      double duration = (leg['duration']?['value'] ?? 0).toDouble();
      double durationInTraffic =
          (leg['duration_in_traffic']?['value'] ?? duration).toDouble();
      double distance = (leg['distance']?['value'] ?? 0).toDouble();

      double score =
          _calculateRouteScore(duration, durationInTraffic, distance);
      scoredRoutes.add({
        'route': route,
        'score': score,
      });
    }

    // Sort by score and return the best
    scoredRoutes.sort((a, b) => b['score'].compareTo(a['score']));
    return scoredRoutes.first['route'];
  }

  // Calculate route score for current conditions
  double _calculateRouteScore(
      double duration, double durationInTraffic, double distance) {
    double baseScore = 100.0;

    // Traffic penalty
    double trafficPenalty = (durationInTraffic - duration) / duration * 60;

    // Distance penalty (prefer shorter routes in heavy traffic)
    double distancePenalty = distance / 1000 * (trafficLevel.value + 1);

    // Speed penalty (prefer faster routes when moving slowly)
    if (currentSpeed.value < 20) {
      double speedPenalty = (20 - currentSpeed.value) * 2;
      baseScore -= speedPenalty;
    }

    return baseScore - trafficPenalty - distancePenalty;
  }

  // Enhanced marker updates with smooth animations
  // Removed unused _enhancedAddDeviceMarker

  // Smooth marker animation
  // Removed unused _animateMarkerSmoothly

  // Update marker with animated value
  void _updateMarkerWithAnimatedValue() {
    if (_lastAnimatedPosition == null || driverIcon == null) return;

    addMarker(
      latitude: _lastAnimatedPosition!.latitude,
      longitude: _lastAnimatedPosition!.longitude,
      id: "Device",
      descriptor: driverIcon!,
      rotation: 0.0, // Keep marker straight (no rotation) in all conditions
    );

    // Remove any existing route polylines immediately to prevent traces
    _clearRoutePolylines();
    polyLines.removeWhere((key, value) =>
        key.value == "DeviceToPickup" || key.value == "DeviceToDestination");
    polyLines.remove(const PolylineId("BreadcrumbTrail"));

    // Rebuild the active route polyline from the new position only
    if (routePoints.isNotEmpty) {
      updateDynamicPolyline(force: true);
    }

    // Update progress when marker position changes
    updateTripProgress();
  }

  // Start traffic monitoring
  void _startTrafficMonitoring() {
    _trafficCheckTimer?.cancel();
    _trafficCheckTimer = Timer.periodic(_trafficUpdateInterval, (timer) {
      if (routePoints.isNotEmpty && currentPosition.value != null) {
        _checkRealTimeTrafficConditions();
        _checkForBetterRoutes();
      }
    });
  }

  // Check real-time traffic conditions
  void _checkRealTimeTrafficConditions() async {
    try {
      if (currentPosition.value == null) return;

      LatLng source = LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude);
      LatLng destination = getTargetLocation();

      // Fetch updated traffic data
      Map<String, dynamic>? trafficData =
          await _fetchTrafficData(source, destination);
      if (trafficData != null) {
        _updateTrafficLevelFromData(trafficData);
      }
    } catch (e) {
      dev.log('Traffic check failed: $e');
    }
  }

  // Fetch traffic data from Google Directions API
  Future<Map<String, dynamic>?> _fetchTrafficData(
      LatLng source, LatLng destination) async {
    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${source.latitude},${source.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=driving&'
          'departure_time=now&'
          'traffic_model=best_guess&'
          'key=${Constant.mapAPIKey}';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return data;
        }
      }
    } catch (e) {
      dev.log('Traffic data fetch failed: $e');
    }
    return null;
  }

  // Update traffic level from API data
  void _updateTrafficLevelFromData(Map<String, dynamic> trafficData) {
    try {
      if (trafficData['routes'] == null || trafficData['routes'].isEmpty) {
        return;
      }

      var route = trafficData['routes'][0];
      if (route['legs'] == null || route['legs'].isEmpty) {
        return;
      }

      var leg = route['legs'][0];
      double duration = (leg['duration']?['value'] ?? 0).toDouble();
      double durationInTraffic =
          (leg['duration_in_traffic']?['value'] ?? duration).toDouble();

      if (duration > 0) {
        double trafficRatio = durationInTraffic / duration;
        int newTrafficLevel = trafficRatio > 1.5
            ? 2
            : trafficRatio > 1.2
                ? 1
                : 0;

        if (newTrafficLevel != trafficLevel.value) {
          trafficLevel.value = newTrafficLevel;
          if (isVoiceEnabled.value && newTrafficLevel > 0) {
            queueAnnouncement(
                "Traffic conditions updated: ${getTrafficLevelText()}",
                priority: 1);
          }
        }
      }
    } catch (e) {
      dev.log('Traffic level update failed: $e');
    }
  }

  // Check for better routes
  void _checkForBetterRoutes() async {
    try {
      if (currentPosition.value == null || routePoints.isEmpty) return;

      LatLng source = LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude);
      LatLng destination = getTargetLocation();

      // Fetch alternative routes
      Map<String, dynamic>? alternativesData =
          await _fetchAlternativeRoutes(source, destination);
      if (alternativesData != null) {
        _evaluateRouteAlternatives(alternativesData);
      }
    } catch (e) {
      dev.log('Better route check failed: $e');
    }
  }

  // Fetch alternative routes
  Future<Map<String, dynamic>?> _fetchAlternativeRoutes(
      LatLng source, LatLng destination) async {
    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${source.latitude},${source.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=driving&'
          'alternatives=true&'
          'departure_time=now&'
          'traffic_model=best_guess&'
          'key=${Constant.mapAPIKey}';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].length > 1) {
          return data;
        }
      }
    } catch (e) {
      dev.log('Alternative routes fetch failed: $e');
    }
    return null;
  }

  // Evaluate route alternatives
  void _evaluateRouteAlternatives(Map<String, dynamic> alternativesData) {
    try {
      List<dynamic> routes = alternativesData['routes'];
      if (routes.length <= 1) return;

      _routeAlternatives.clear();
      _currentRouteIndex = 0;

      // Find current route index
      for (int i = 0; i < routes.length; i++) {
        var route = routes[i];
        if (_isCurrentRoute(route)) {
          _currentRouteIndex = i;
          break;
        }
      }

      // Evaluate alternatives
      for (int i = 0; i < routes.length; i++) {
        if (i == _currentRouteIndex) continue;

        var route = routes[i];
        var leg = route['legs'][0];

        double duration = (leg['duration']?['value'] ?? 0).toDouble();
        double durationInTraffic =
            (leg['duration_in_traffic']?['value'] ?? duration).toDouble();
        double distance = (leg['distance']?['value'] ?? 0).toDouble();

        // Calculate route quality score
        double qualityScore = _calculateRouteQualityScore(
            duration, durationInTraffic, distance, i);

        _routeAlternatives.add({
          'route': route,
          'index': i,
          'qualityScore': qualityScore,
          'duration': duration,
          'durationInTraffic': durationInTraffic,
          'distance': distance,
        });
      }

      // Sort by quality score
      _routeAlternatives
          .sort((a, b) => b['qualityScore'].compareTo(a['qualityScore']));

      // Check if better route is available
      if (_routeAlternatives.isNotEmpty) {
        var bestAlternative = _routeAlternatives.first;
        double currentDuration = _getCurrentRouteDuration();
        double timeSaved =
            (currentDuration - bestAlternative['durationInTraffic']) /
                60; // Convert to minutes

        if (timeSaved > 2 &&
            bestAlternative['qualityScore'] > _routeQualityScore * 1.1) {
          _suggestBetterRoute(bestAlternative, timeSaved);
        }
      }
    } catch (e) {
      dev.log('Route alternatives evaluation failed: $e');
    }
  }

  // Check if route is current route
  bool _isCurrentRoute(Map<String, dynamic> route) {
    try {
      String encodedPolyline = route['overview_polyline']['points'];
      List<PointLatLng> decodedPoints =
          polylinePoints.decodePolyline(encodedPolyline);

      if (decodedPoints.length != routePoints.length) return false;

      // Compare first and last points
      if (decodedPoints.isNotEmpty && routePoints.isNotEmpty) {
        double firstPointDiff = Geolocator.distanceBetween(
          decodedPoints.first.latitude,
          decodedPoints.first.longitude,
          routePoints.first.latitude,
          routePoints.first.longitude,
        );

        double lastPointDiff = Geolocator.distanceBetween(
          decodedPoints.last.latitude,
          decodedPoints.last.longitude,
          routePoints.last.latitude,
          routePoints.last.longitude,
        );

        return firstPointDiff < 50 && lastPointDiff < 50; // 50m tolerance
      }
    } catch (e) {
      dev.log('Route comparison failed: $e');
    }
    return false;
  }

  // Calculate route quality score
  double _calculateRouteQualityScore(double duration, double durationInTraffic,
      double distance, int routeIndex) {
    double baseScore = 100.0;

    // Duration penalty
    double durationPenalty = (durationInTraffic - duration) / duration * 50;

    // Distance penalty (prefer shorter routes)
    double distancePenalty = distance / 1000 * 2; // 2 points per km

    // Route index penalty (prefer lower index routes)
    double indexPenalty = routeIndex * 5;

    return baseScore - durationPenalty - distancePenalty - indexPenalty;
  }

  // Get current route duration
  double _getCurrentRouteDuration() {
    if (navigationSteps.isEmpty) return 0.0;

    double totalDuration = 0.0;
    for (var step in navigationSteps) {
      totalDuration += step.duration;
    }
    return totalDuration;
  }

  // Suggest better route
  void _suggestBetterRoute(Map<String, dynamic> alternative, double timeSaved) {
    _betterRouteAvailable.value = true;
    _betterRouteData = alternative['route'];
    _timeSaved = timeSaved.round();

    if (isVoiceEnabled.value) {
      queueAnnouncement(
          "Better route available. Save ${timeSaved.toStringAsFixed(0)} minutes.",
          priority: 2);
    }

    // Show alternative route preview
    _showAlternativeRoutePreview(alternative['route']);
  }

  // Show alternative route preview
  void _showAlternativeRoutePreview(Map<String, dynamic> route) {
    try {
      String encodedPolyline = route['overview_polyline']['points'];
      List<PointLatLng> decodedPoints =
          polylinePoints.decodePolyline(encodedPolyline);
      List<LatLng> alternativePoints = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      if (alternativePoints.length > 1) {
        _addPolyLine(alternativePoints, "alternative_route",
            Colors.blue.withValues(alpha: 0.6));
        hasAlternativeRoute.value = true;
        _alternativeRouteData = route;
      }
    } catch (e) {
      dev.log('Alternative route preview failed: $e');
    }
  }

  // Old road snapping and bearing methods replaced by optimized versions

  // Create breadcrumb trail showing recent travel path
  // Breadcrumb trail intentionally disabled to prevent lingering traces

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

    // Update trip progress
    updateTripProgress();

    // Check if we're approaching a turn
    if (distanceToNextTurn.value < 100) {
      checkUpcomingTurns(LatLng(
          currentPosition.value!.latitude, currentPosition.value!.longitude));
    }
  }
}
