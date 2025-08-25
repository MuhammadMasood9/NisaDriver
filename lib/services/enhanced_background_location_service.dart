// Enhanced Background Location Service for Driver App
// This service provides intelligent location tracking with ride phase awareness,
// GPS noise reduction, adaptive frequency, and robust error handling

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:driver/model/enhanced_location_data.dart';
import 'package:driver/services/enhanced_realtime_location_service.dart';

/// Enhanced Background Location Service with intelligent tracking capabilities
class EnhancedBackgroundLocationService {
  static final EnhancedBackgroundLocationService _instance =
      EnhancedBackgroundLocationService._internal();
  factory EnhancedBackgroundLocationService() => _instance;
  EnhancedBackgroundLocationService._internal();

  // Core services
  final EnhancedRealtimeLocationService _realtimeService = EnhancedRealtimeLocationService();

  // Location tracking
  StreamSubscription<Position>? _locationStream;
  
  // State management
  bool _isTracking = false;
  String? _currentOrderId;
  String? _currentDriverId;
  RidePhase _currentPhase = RidePhase.enRouteToPickup;
  NetworkQuality _networkQuality = NetworkQuality.good;
  double _batteryLevel = 100.0;
  
  // Location data
  Position? _lastKnownPosition;
  Position? _lastPublishedPosition;
  DateTime? _lastPublishTime;
  int _sequenceNumber = 0;
  
  // Adaptive frequency management
  Timer? _adaptiveUpdateTimer;
  Duration _currentUpdateInterval = Duration(seconds: 3);
  
  // GPS noise reduction
  final List<Position> _recentPositions = [];
  static const int _maxRecentPositions = 5;
  static const double _minAccuracyThreshold = 50.0; // meters
  static const double _minMovementThreshold = 3.0; // meters
  
  // Error handling and retry
  final List<EnhancedLocationData> _pendingUpdates = [];
  Timer? _retryTimer;
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 5;
  
  // Metrics
  DateTime? _trackingStartTime;
  int _totalUpdates = 0;
  int _successfulUpdates = 0;
  int _filteredUpdates = 0;
  final List<double> _accuracyHistory = [];

  /// Stream of tracking status updates
  final StreamController<LocationTrackingStatus> _statusController = 
      StreamController<LocationTrackingStatus>.broadcast();
  Stream<LocationTrackingStatus> get trackingStatus => _statusController.stream;

  /// Current tracking metrics
  LocationTrackingMetrics get metrics {
    final now = DateTime.now();
    final trackingTime = _trackingStartTime != null 
        ? now.difference(_trackingStartTime!) 
        : Duration.zero;
    
    return LocationTrackingMetrics(
      totalUpdates: _totalUpdates,
      averageAccuracy: _accuracyHistory.isNotEmpty 
          ? _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length
          : 0.0,
      averageInterval: _currentUpdateInterval,
      failedUpdates: _totalUpdates - _successfulUpdates,
      batteryUsagePercent: 100.0 - _batteryLevel,
      networkUsageMB: _totalUpdates * 0.001, // Rough estimate
      trackingStartTime: _trackingStartTime ?? now,
      totalTrackingTime: trackingTime,
    );
  }

  /// Start enhanced background location tracking
  Future<bool> startTracking({
    required String orderId,
    required String driverId,
    required RidePhase phase,
  }) async {
    try {
      if (_isTracking) {
        dev.log('EnhancedBackgroundLocationService: Already tracking');
        return true;
      }

      dev.log('EnhancedBackgroundLocationService: Starting tracking for order $orderId, phase: ${phase.value}');

      // Initialize services
      await _realtimeService.initialize();

      // Check permissions and services
      if (!await _checkPermissionsAndServices()) {
        return false;
      }

      // Initialize state
      _currentOrderId = orderId;
      _currentDriverId = driverId;
      _currentPhase = phase;
      _isTracking = true;
      _trackingStartTime = DateTime.now();
      _sequenceNumber = 0;
      _consecutiveFailures = 0;
      
      // Get initial location
      final initialPosition = await _getCurrentPosition();
      if (initialPosition == null) {
        dev.log('EnhancedBackgroundLocationService: Failed to get initial position');
        _isTracking = false;
        return false;
      }

      _lastKnownPosition = initialPosition;
      _lastPublishedPosition = initialPosition;
      _lastPublishTime = DateTime.now();

      // Start monitoring services
      await _startLocationTracking();
      _startAdaptiveUpdates();

      // Publish initial location
      await _publishLocationUpdate(initialPosition, isInitial: true);

      _emitStatus('Tracking started', isActive: true);
      dev.log('EnhancedBackgroundLocationService: Tracking started successfully');
      
      return true;
    } catch (e) {
      dev.log('EnhancedBackgroundLocationService: Failed to start tracking: $e');
      _isTracking = false;
      _emitStatus('Failed to start tracking: $e', isActive: false, issues: ['startup_error']);
      return false;
    }
  }

  /// Stop background location tracking
  Future<void> stopTracking() async {
    try {
      if (!_isTracking) return;

      dev.log('EnhancedBackgroundLocationService: Stopping tracking');

      // Cancel all streams and timers
      await _locationStream?.cancel();
      _adaptiveUpdateTimer?.cancel();
      _retryTimer?.cancel();

      // Clean up Firebase data
      if (_currentOrderId != null) {
        await _realtimeService.cleanupLocationData(_currentOrderId!);
      }

      // Reset state
      _isTracking = false;
      _currentOrderId = null;
      _currentDriverId = null;
      _lastKnownPosition = null;
      _lastPublishedPosition = null;
      _lastPublishTime = null;
      _recentPositions.clear();
      _pendingUpdates.clear();
      _accuracyHistory.clear();

      _emitStatus('Tracking stopped', isActive: false);
      dev.log('EnhancedBackgroundLocationService: Tracking stopped');
    } catch (e) {
      dev.log('EnhancedBackgroundLocationService: Error stopping tracking: $e');
    }
  }

  /// Update the current ride phase
  void updateRidePhase(RidePhase phase) {
    if (_currentPhase != phase) {
      dev.log('EnhancedBackgroundLocationService: Ride phase changed: ${_currentPhase.value} -> ${phase.value}');
      _currentPhase = phase;
      _updateAdaptiveFrequency();
      _emitStatus('Ride phase updated: ${phase.value}', isActive: _isTracking);
    }
  }

  /// Update network conditions
  void updateNetworkConditions(NetworkQuality quality) {
    if (_networkQuality != quality) {
      dev.log('EnhancedBackgroundLocationService: Network quality changed: ${_networkQuality.value} -> ${quality.value}');
      _networkQuality = quality;
      _updateAdaptiveFrequency();
      _emitStatus('Network quality updated: ${quality.value}', isActive: _isTracking);
    }
  }

  /// Update battery level
  void updateBatteryLevel(double batteryLevel) {
    if ((_batteryLevel - batteryLevel).abs() > 5.0) { // Only update on significant changes
      dev.log('EnhancedBackgroundLocationService: Battery level changed: ${_batteryLevel.toStringAsFixed(1)}% -> ${batteryLevel.toStringAsFixed(1)}%');
      _batteryLevel = batteryLevel;
      _updateAdaptiveFrequency();
      _emitStatus('Battery level updated: ${batteryLevel.toStringAsFixed(1)}%', isActive: _isTracking);
    }
  }

  /// Force immediate location update
  Future<void> forceLocationUpdate() async {
    if (!_isTracking) return;

    try {
      dev.log('EnhancedBackgroundLocationService: Forcing location update');
      final position = await _getCurrentPosition();
      if (position != null) {
        await _publishLocationUpdate(position, isForced: true);
      }
    } catch (e) {
      dev.log('EnhancedBackgroundLocationService: Failed to force location update: $e');
    }
  }

  /// Pause tracking temporarily
  Future<void> pauseTracking() async {
    if (_isTracking && _locationStream != null) {
      _locationStream!.pause();
      _adaptiveUpdateTimer?.cancel();
      _emitStatus('Tracking paused', isActive: false);
      dev.log('EnhancedBackgroundLocationService: Tracking paused');
    }
  }

  /// Resume tracking
  Future<void> resumeTracking() async {
    if (_isTracking && _locationStream != null) {
      _locationStream!.resume();
      _startAdaptiveUpdates();
      _emitStatus('Tracking resumed', isActive: true);
      dev.log('EnhancedBackgroundLocationService: Tracking resumed');
    }
  }

  /// Check permissions and location services
  Future<bool> _checkPermissionsAndServices() async {
    // Check location services
    if (!await Geolocator.isLocationServiceEnabled()) {
      dev.log('EnhancedBackgroundLocationService: Location services disabled');
      _emitStatus('Location services disabled', isActive: false, issues: ['location_services_disabled']);
      return false;
    }

    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      dev.log('EnhancedBackgroundLocationService: Location permission denied');
      _emitStatus('Location permission denied', isActive: false, issues: ['permission_denied']);
      return false;
    }

    return true;
  }

  /// Start location tracking with appropriate settings
  Future<void> _startLocationTracking() async {
    final locationSettings = _getLocationSettings();
    
    _locationStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onLocationUpdate,
      onError: _onLocationError,
      cancelOnError: false,
    );

    dev.log('EnhancedBackgroundLocationService: Location stream started');
  }

  /// Get appropriate location settings based on platform and phase
  LocationSettings _getLocationSettings() {
    final accuracy = _getRequiredAccuracy();
    final distanceFilter = _getDistanceFilter();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: _currentUpdateInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Driver Location Tracking',
          notificationText: 'Sharing your location for ride tracking',
          enableWakeLock: true,
          setOngoing: true,
        ),
        forceLocationManager: false,
      );
    } else if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.automotiveNavigation,
      );
    } else {
      return LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: _currentUpdateInterval,
      );
    }
  }

  /// Get required location accuracy based on ride phase
  LocationAccuracy _getRequiredAccuracy() {
    switch (_currentPhase) {
      case RidePhase.atPickupLocation:
      case RidePhase.atDropoffLocation:
        return LocationAccuracy.best; // Highest accuracy for pickup/dropoff
      case RidePhase.rideInProgress:
        return LocationAccuracy.bestForNavigation; // High accuracy during ride
      case RidePhase.enRouteToPickup:
        return LocationAccuracy.high; // Good accuracy en route
      case RidePhase.rideCompleted:
        return LocationAccuracy.medium; // Lower accuracy when completed
    }
  }

  /// Get distance filter based on ride phase and speed
  int _getDistanceFilter() {
    final speed = _lastKnownPosition?.speed ?? 0.0;
    final speedKmh = speed * 3.6;

    // Critical phases need minimal distance filtering
    if (_currentPhase == RidePhase.atPickupLocation || _currentPhase == RidePhase.atDropoffLocation) {
      return 0; // No filtering for pickup/dropoff
    }

    // Adjust based on speed
    if (speedKmh < 5.0) {
      return 2; // Very sensitive when stationary/slow
    } else if (speedKmh < 20.0) {
      return 3; // Moderate filtering for city driving
    } else {
      return 5; // More filtering for highway speeds
    }
  }

  /// Handle location updates with noise reduction
  void _onLocationUpdate(Position position) async {
    try {
      if (!_isTracking) return;

      _totalUpdates++;
      _recordAccuracy(position.accuracy);

      // Apply GPS noise reduction
      if (!_isLocationUpdateValid(position)) {
        _filteredUpdates++;
        dev.log('EnhancedBackgroundLocationService: Location update filtered (accuracy: ${position.accuracy.toStringAsFixed(1)}m)');
        return;
      }

      // Update recent positions for smoothing
      _updateRecentPositions(position);
      
      // Apply local smoothing
      final smoothedPosition = _applySmoothingFilter(position);
      _lastKnownPosition = smoothedPosition;

      // Check if we should publish this update
      if (_shouldPublishUpdate(smoothedPosition)) {
        await _publishLocationUpdate(smoothedPosition);
      }

    } catch (e) {
      dev.log('EnhancedBackgroundLocationService: Error processing location update: $e');
      _onLocationError(e);
    }
  }

  /// Validate location update quality
  bool _isLocationUpdateValid(Position position) {
    // Check accuracy threshold
    if (position.accuracy > _minAccuracyThreshold) {
      return false;
    }

    // Check for reasonable coordinates
    if (position.latitude.abs() > 90 || position.longitude.abs() > 180) {
      return false;
    }

    // Check for significant movement (avoid GPS noise when stationary)
    if (_lastKnownPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastKnownPosition!.latitude,
        _lastKnownPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // If very close and accuracy is poor, likely GPS noise
      if (distance < _minMovementThreshold && position.accuracy > 10.0) {
        return false;
      }
    }

    return true;
  }

  /// Update recent positions buffer
  void _updateRecentPositions(Position position) {
    _recentPositions.add(position);
    if (_recentPositions.length > _maxRecentPositions) {
      _recentPositions.removeAt(0);
    }
  }

  /// Apply smoothing filter to reduce GPS noise
  Position _applySmoothingFilter(Position position) {
    if (_recentPositions.length < 2) {
      return position; // Not enough data for smoothing
    }

    // Calculate weighted average based on accuracy
    double totalWeight = 0.0;
    double weightedLat = 0.0;
    double weightedLng = 0.0;
    double weightedSpeed = 0.0;
    double weightedBearing = 0.0;

    for (final pos in _recentPositions) {
      // Weight inversely proportional to accuracy (lower accuracy = lower weight)
      final weight = 1.0 / (pos.accuracy + 1.0);
      totalWeight += weight;
      
      weightedLat += pos.latitude * weight;
      weightedLng += pos.longitude * weight;
      weightedSpeed += pos.speed * weight;
      weightedBearing += pos.heading * weight;
    }

    if (totalWeight == 0.0) return position;

    // Create smoothed position
    return Position(
      latitude: weightedLat / totalWeight,
      longitude: weightedLng / totalWeight,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      heading: weightedBearing / totalWeight,
      headingAccuracy: position.headingAccuracy,
      speed: weightedSpeed / totalWeight,
      speedAccuracy: position.speedAccuracy,
    );
  }

  /// Determine if location update should be published
  bool _shouldPublishUpdate(Position position) {
    final now = DateTime.now();

    // Always publish if it's been too long since last update
    if (_lastPublishTime == null || now.difference(_lastPublishTime!).inSeconds >= _currentUpdateInterval.inSeconds) {
      return true;
    }

    // Publish if significant movement occurred
    if (_lastPublishedPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPublishedPosition!.latitude,
        _lastPublishedPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      final minDistance = _getMinPublishDistance();
      if (distance >= minDistance) {
        return true;
      }
    }

    // Publish if speed changed significantly
    if (_lastPublishedPosition != null) {
      final speedDiff = (position.speed - _lastPublishedPosition!.speed).abs() * 3.6; // km/h
      if (speedDiff > 10.0) { // 10 km/h difference
        return true;
      }
    }

    return false;
  }

  /// Get minimum distance for publishing based on speed and phase
  double _getMinPublishDistance() {
    final speed = _lastKnownPosition?.speed ?? 0.0;
    final speedKmh = speed * 3.6;

    // Critical phases need frequent updates
    if (_currentPhase == RidePhase.atPickupLocation || _currentPhase == RidePhase.atDropoffLocation) {
      return 2.0; // 2 meters
    }

    // Adjust based on speed
    if (speedKmh < 5.0) {
      return 3.0; // 3 meters when slow/stationary
    } else if (speedKmh < 30.0) {
      return 5.0; // 5 meters for city driving
    } else {
      return 10.0; // 10 meters for highway speeds
    }
  }

  /// Publish location update to Firebase
  Future<void> _publishLocationUpdate(Position position, {bool isInitial = false, bool isForced = false}) async {
    try {
      final locationData = EnhancedLocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: position.speed * 3.6,
        bearing: position.heading,
        accuracy: position.accuracy,
        status: 'active',
        phase: _currentPhase,
        timestamp: DateTime.now(),
        sequenceNumber: ++_sequenceNumber,
        batteryLevel: _batteryLevel,
        networkQuality: _networkQuality,
        metadata: {
          'orderId': _currentOrderId,
          'driverId': _currentDriverId,
          'isInitial': isInitial,
          'isForced': isForced,
        },
      );

      final result = await _realtimeService.publishLocation(locationData);
      
      if (result.success) {
        _successfulUpdates++;
        _consecutiveFailures = 0;
        _lastPublishedPosition = position;
        _lastPublishTime = DateTime.now();
        
        dev.log('EnhancedBackgroundLocationService: Location published successfully (${result.latency.inMilliseconds}ms)');
        _emitStatus('Location updated', isActive: true);
      } else {
        _handlePublishFailure(locationData, result.error);
      }

    } catch (e) {
      dev.log('EnhancedBackgroundLocationService: Failed to publish location: $e');
      _handlePublishFailure(null, e.toString());
    }
  }

  /// Handle location publish failures
  void _handlePublishFailure(EnhancedLocationData? locationData, String? error) {
    _consecutiveFailures++;
    
    if (locationData != null) {
      _pendingUpdates.add(locationData);
      
      // Limit pending updates to prevent memory issues
      if (_pendingUpdates.length > 50) {
        _pendingUpdates.removeAt(0);
      }
    }

    final issues = ['publish_failed'];
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      issues.add('consecutive_failures');
    }

    _emitStatus('Failed to publish location: $error', 
        isActive: _isTracking, 
        issues: issues);

    // Schedule retry
    _scheduleRetry();
  }

  /// Handle location stream errors
  void _onLocationError(dynamic error) {
    dev.log('EnhancedBackgroundLocationService: Location stream error: $error');
    _emitStatus('Location error: $error', isActive: _isTracking, issues: ['location_error']);
    
    // Try to restart location stream after delay
    Future.delayed(Duration(seconds: 5), () {
      if (_isTracking) {
        _restartLocationStream();
      }
    });
  }

  /// Restart location stream after error
  Future<void> _restartLocationStream() async {
    try {
      dev.log('EnhancedBackgroundLocationService: Restarting location stream');
      
      await _locationStream?.cancel();
      await _startLocationTracking();
      
      _emitStatus('Location stream restarted', isActive: _isTracking);
    } catch (e) {
      dev.log('EnhancedBackgroundLocationService: Failed to restart location stream: $e');
    }
  }

  /// Get current position with timeout and error handling
  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: _getRequiredAccuracy(),
        timeLimit: Duration(seconds: 10),
      );
    } catch (e) {
      dev.log('EnhancedBackgroundLocationService: Failed to get current position: $e');
      return null;
    }
  }

  /// Simulate network quality monitoring (simplified version)
  void _simulateNetworkMonitoring() {
    // In a real implementation, this would monitor actual network conditions
    // For now, we'll assume good network quality
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      
      // Simulate network quality changes
      // In practice, this would use actual network monitoring
      updateNetworkConditions(NetworkQuality.good);
    });
  }

  /// Simulate battery level monitoring (simplified version)
  void _simulateBatteryMonitoring() {
    // In a real implementation, this would monitor actual battery level
    // For now, we'll simulate battery drain
    Timer.periodic(Duration(minutes: 5), (timer) {
      if (!_isTracking) {
        timer.cancel();
        return;
      }
      
      // Simulate battery drain (1% every 5 minutes during tracking)
      if (_batteryLevel > 0) {
        updateBatteryLevel(_batteryLevel - 1.0);
      }
    });
  }

  /// Start adaptive update frequency management
  void _startAdaptiveUpdates() {
    _updateAdaptiveFrequency();
    
    // Periodically review and adjust frequency
    _adaptiveUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _updateAdaptiveFrequency();
    });
  }

  /// Update adaptive frequency based on current conditions
  void _updateAdaptiveFrequency() {
    final newInterval = _calculateOptimalUpdateInterval();
    
    if (newInterval != _currentUpdateInterval) {
      dev.log('EnhancedBackgroundLocationService: Update interval changed: ${_currentUpdateInterval.inSeconds}s -> ${newInterval.inSeconds}s');
      _currentUpdateInterval = newInterval;
      
      // Restart location stream with new settings if needed
      if (_isTracking) {
        _restartLocationStream();
      }
    }
  }

  /// Calculate optimal update interval based on current conditions
  Duration _calculateOptimalUpdateInterval() {
    int baseSeconds = 3; // Default 3 seconds

    // Adjust based on ride phase
    switch (_currentPhase) {
      case RidePhase.enRouteToPickup:
        baseSeconds = 4; // Slightly less frequent
        break;
      case RidePhase.atPickupLocation:
      case RidePhase.atDropoffLocation:
        baseSeconds = 2; // More frequent for critical phases
        break;
      case RidePhase.rideInProgress:
        baseSeconds = 3; // Standard frequency
        break;
      case RidePhase.rideCompleted:
        baseSeconds = 10; // Much less frequent
        break;
    }

    // Adjust based on network quality
    switch (_networkQuality) {
      case NetworkQuality.excellent:
        break; // No adjustment
      case NetworkQuality.good:
        baseSeconds = (baseSeconds * 1.1).round();
        break;
      case NetworkQuality.fair:
        baseSeconds = (baseSeconds * 1.3).round();
        break;
      case NetworkQuality.poor:
        baseSeconds = (baseSeconds * 1.5).round();
        break;
      case NetworkQuality.offline:
        baseSeconds = (baseSeconds * 2.0).round();
        break;
    }

    // Adjust based on battery level
    if (_batteryLevel < 20.0) {
      baseSeconds = (baseSeconds * 1.5).round(); // Reduce frequency when battery low
    } else if (_batteryLevel < 50.0) {
      baseSeconds = (baseSeconds * 1.2).round();
    }

    // Adjust based on movement (if we have speed data)
    if (_lastKnownPosition != null) {
      final speedKmh = _lastKnownPosition!.speed * 3.6;
      if (speedKmh < 2.0) {
        // Stationary - reduce frequency
        baseSeconds = max(baseSeconds, 10);
      } else if (speedKmh > 60.0) {
        // High speed - increase frequency for better tracking
        baseSeconds = max(2, (baseSeconds * 0.8).round());
      }
    }

    // Ensure reasonable bounds
    baseSeconds = baseSeconds.clamp(2, 30);
    
    return Duration(seconds: baseSeconds);
  }

  /// Schedule retry for failed operations
  void _scheduleRetry() {
    if (_retryTimer?.isActive == true) return;
    
    final delay = Duration(seconds: min(30, pow(2, _consecutiveFailures).toInt()));
    dev.log('EnhancedBackgroundLocationService: Scheduling retry in ${delay.inSeconds} seconds');
    
    _retryTimer = Timer(delay, () {
      _retryPendingUpdates();
    });
  }

  /// Retry pending location updates
  Future<void> _retryPendingUpdates() async {
    if (_pendingUpdates.isEmpty) return;
    
    dev.log('EnhancedBackgroundLocationService: Retrying ${_pendingUpdates.length} pending updates');
    
    final updates = List<EnhancedLocationData>.from(_pendingUpdates);
    _pendingUpdates.clear();
    
    final results = await _realtimeService.batchPublishLocations(updates);
    
    int successCount = 0;
    for (int i = 0; i < results.length; i++) {
      if (results[i].success) {
        successCount++;
      } else {
        // Re-queue failed updates (with limit)
        if (_pendingUpdates.length < 20) {
          _pendingUpdates.add(updates[i]);
        }
      }
    }
    
    if (successCount > 0) {
      _successfulUpdates += successCount;
      _consecutiveFailures = 0;
      dev.log('EnhancedBackgroundLocationService: Successfully retried $successCount updates');
    }
    
    if (_pendingUpdates.isNotEmpty) {
      _scheduleRetry(); // Schedule another retry if needed
    }
  }

  /// Record accuracy for metrics
  void _recordAccuracy(double accuracy) {
    _accuracyHistory.add(accuracy);
    if (_accuracyHistory.length > 100) {
      _accuracyHistory.removeAt(0);
    }
  }

  /// Emit status update to listeners
  void _emitStatus(String status, {required bool isActive, List<String>? issues}) {
    final trackingStatus = LocationTrackingStatus(
      isActive: isActive,
      lastUpdate: DateTime.now(),
      accuracy: _lastKnownPosition?.accuracy ?? 0.0,
      status: status,
      issues: issues ?? [],
    );
    
    _statusController.add(trackingStatus);
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    dev.log('EnhancedBackgroundLocationService: Disposing service');
    
    stopTracking();
    _statusController.close();
    _realtimeService.dispose();
  }
}