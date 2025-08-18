import 'dart:async';
import 'dart:developer' as dev;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:driver/services/realtime_location_service.dart';
// Removed unused import

/// Service for tracking driver location in the background
class BackgroundLocationService {
  static final BackgroundLocationService _instance =
      BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  StreamSubscription<Position>? _backgroundLocationStream;
  final RealtimeLocationService _realtime = RealtimeLocationService();

  // Current tracking state
  bool _isTracking = false;
  String? _currentOrderId;
  String? _currentDriverId;

  // Background location settings
  static const LocationAccuracy _backgroundAccuracy =
      LocationAccuracy.bestForNavigation;
  static const int _backgroundDistanceFilter =
      0; // no distance filter - continuous updates
  static const Duration _backgroundInterval =
      Duration(seconds: 30); // minimum interval

  // Additional tracking mechanisms
  Timer? _periodicLocationTimer;
  Timer? _fallbackTimer;
  Position? _lastKnownPosition;
  static const Duration _periodicUpdateInterval =
      Duration(seconds: 4); // Very frequent
  static const Duration _fallbackCheckInterval =
      Duration(seconds: 3); // Very frequent

  /// Start background location tracking
  Future<bool> startBackgroundTracking({
    required String orderId,
    required String driverId,
    required double initialLatitude,
    required double initialLongitude,
  }) async {
    try {
      // Check if already tracking
      if (_isTracking) {
        dev.log('Background tracking already active');
        return true;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        dev.log('Location permission denied for background tracking');
        return false;
      }

      // Check if background location is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        dev.log('Location services disabled for background tracking');
        return false;
      }

      // Store current tracking info
      _currentOrderId = orderId;
      _currentDriverId = driverId;
      _isTracking = true;

      dev.log('Starting background location tracking for order: $orderId');
      dev.log('Driver ID: $driverId');
      dev.log('Initial coordinates: $initialLatitude, $initialLongitude');

      // Print Firebase database info for debugging
      final dbInfo = _realtime.getDatabaseInfo();
      dev.log('Firebase database info: $dbInfo');

      // Test Firebase database access first
      bool databaseAccess = await _realtime.testDatabaseAccess();
      if (!databaseAccess) {
        dev.log(
            'Firebase database access test failed - cannot start background tracking');
        _isTracking = false;
        return false;
      }
      dev.log('Firebase database access test passed');

      // Start background location stream (keep alive in background)
      final LocationSettings locationSettings;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: _backgroundAccuracy,
          distanceFilter: _backgroundDistanceFilter,
          intervalDuration:
              const Duration(seconds: 3), // Very aggressive updates
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Driver tracking active',
            notificationText: 'Sharing your live location for trips',
            enableWakeLock: true,
            setOngoing: true,
          ),
          // Additional Android-specific settings for better background tracking
          forceLocationManager:
              false, // Use Google Play Services when available
        );
      } else if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        locationSettings = AppleSettings(
          accuracy: _backgroundAccuracy,
          distanceFilter: _backgroundDistanceFilter,
          allowBackgroundLocationUpdates: true,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          // Additional iOS settings for better background tracking
          activityType: ActivityType.fitness,
        );
      } else {
        locationSettings = LocationSettings(
          accuracy: _backgroundAccuracy,
          distanceFilter: _backgroundDistanceFilter,
          timeLimit: const Duration(seconds: 3), // Very aggressive updates
        );
      }

      _backgroundLocationStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onBackgroundLocationUpdate,
        onError: _onBackgroundLocationError,
        cancelOnError: false,
      );

      // Start periodic location updates as fallback
      _startPeriodicLocationUpdates();

      // Start fallback timer to check if location updates are working
      _startFallbackTimer();

      // Start heartbeat timer for continuous Firebase updates
      _startHeartbeatTimer();

      // Start background monitoring to ensure all timers and stream are active
      _startBackgroundMonitoring();

      // Start Android-specific background limitation handler
      _handleAndroidBackgroundLimitations();

      // Publish initial location
      await _publishBackgroundLocation(
        latitude: initialLatitude,
        longitude: initialLongitude,
        speedKmh: 0.0,
        bearing: 0.0,
        accuracy: 10.0,
        rideStatus: 'active',
        phase: 'tracking',
      );

      dev.log('Background location tracking started for order: $orderId');
      return true;
    } catch (e) {
      dev.log('Error starting background tracking: $e');
      _isTracking = false;
      return false;
    }
  }

  /// Stop background location tracking
  Future<void> stopBackgroundTracking() async {
    try {
      if (!_isTracking) return;

      dev.log('Stopping background location tracking');

      // Cancel the location stream
      await _backgroundLocationStream?.cancel();
      _backgroundLocationStream = null;

      // Cancel periodic timers
      _periodicLocationTimer?.cancel();
      _periodicLocationTimer = null;
      _fallbackTimer?.cancel();
      _fallbackTimer = null;

      // Remove location data from Firebase
      if (_currentOrderId != null && _currentDriverId != null) {
        await _realtime.removeDriverLocation(
          orderId: _currentOrderId!,
          driverId: _currentDriverId!,
        );
      }

      // Reset state
      _isTracking = false;
      _currentOrderId = null;
      _currentDriverId = null;
      _lastKnownPosition = null;

      dev.log('Background location tracking stopped');
    } catch (e) {
      dev.log('Error stopping background tracking: $e');
    }
  }

  /// Handle background location updates
  void _onBackgroundLocationUpdate(Position position) async {
    try {
      if (!_isTracking || _currentOrderId == null || _currentDriverId == null) {
        return;
      }

      // Calculate speed in km/h
      double speedKmh = position.speed * 3.6;

      // Calculate bearing (direction of travel)
      double bearing = position.heading;

      dev.log(
          'Background location update: ${position.latitude}, ${position.longitude}, Speed: ${speedKmh.toStringAsFixed(1)} km/h');

      // Publish to Firebase
      await _publishBackgroundLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: speedKmh,
        bearing: bearing,
        accuracy: position.accuracy,
        rideStatus: 'active',
        phase: 'tracking',
      );
    } catch (e) {
      dev.log('Error processing background location update: $e');
    }
  }

  /// Handle background location errors
  void _onBackgroundLocationError(error) {
    dev.log('Background location error: $error');

    // Try to restart tracking after a delay
    if (_isTracking) {
      Future.delayed(const Duration(seconds: 5), () {
        if (_isTracking) {
          dev.log('Attempting to restart background tracking after error');
          _restartBackgroundTracking();
        }
      });
    }
  }

  /// Enhanced error handling for Android background process limitations
  void _handleAndroidBackgroundLimitations() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android-specific background handling
      Timer.periodic(const Duration(seconds: 15), (timer) async {
        if (_isTracking &&
            _currentOrderId != null &&
            _currentDriverId != null) {
          try {
            dev.log('Android background limitation check');

            // Check if we can still get location
            try {
              final position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.bestForNavigation,
                timeLimit: const Duration(seconds: 5),
              );

              // If we can get location, ensure Firebase is updated
              await _publishBackgroundLocation(
                latitude: position.latitude,
                longitude: position.longitude,
                speedKmh: position.speed * 3.6,
                bearing: position.heading,
                accuracy: position.accuracy,
                rideStatus: 'active',
                phase: 'android_background_check',
              );

              dev.log(
                  'Android background check - location published successfully');
            } catch (e) {
              dev.log('Android background check - location failed: $e');
              // Try to restart tracking
              await _restartBackgroundTracking();
            }
          } catch (e) {
            dev.log('Error in Android background limitation handler: $e');
          }
        } else {
          timer.cancel();
        }
      });

      dev.log('Android background limitation handler started');
    }
  }

  /// Restart background tracking after an error
  Future<void> _restartBackgroundTracking() async {
    if (_currentOrderId == null || _currentDriverId == null) return;

    try {
      // Get current position to restart with
      final Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 10));

      await startBackgroundTracking(
        orderId: _currentOrderId!,
        driverId: _currentDriverId!,
        initialLatitude: currentPosition.latitude,
        initialLongitude: currentPosition.longitude,
      );
    } catch (e) {
      dev.log('Error restarting background tracking: $e');
    }
  }

  /// Publish location data to Firebase
  Future<void> _publishBackgroundLocation({
    required double latitude,
    required double longitude,
    required double speedKmh,
    required double bearing,
    required double accuracy,
    required String rideStatus,
    required String phase,
  }) async {
    try {
      if (_currentOrderId == null || _currentDriverId == null) {
        dev.log('Cannot publish: orderId or driverId is null');
        return;
      }

      dev.log(
          'Publishing background location to Firebase: $_currentOrderId, $_currentDriverId');

      // Always publish to Firebase, including temporary background sessions
      await _realtime.publishDriverLocation(
        orderId: _currentOrderId!,
        driverId: _currentDriverId!,
        latitude: latitude,
        longitude: longitude,
        speedKmh: speedKmh,
        bearing: bearing,
        accuracy: accuracy,
        rideStatus: rideStatus,
        phase: phase,
      );

      dev.log('Successfully published background location to Firebase');
    } catch (e) {
      dev.log('Error publishing background location: $e');

      // Retry logic for failed Firebase operations
      if (_isTracking) {
        dev.log('Retrying Firebase publish in 5 seconds...');
        Future.delayed(const Duration(seconds: 5), () async {
          if (_isTracking) {
            try {
              await _realtime.publishDriverLocation(
                orderId: _currentOrderId!,
                driverId: _currentDriverId!,
                latitude: latitude,
                longitude: longitude,
                speedKmh: speedKmh,
                bearing: bearing,
                accuracy: accuracy,
                rideStatus: rideStatus,
                phase: phase,
              );
              dev.log('Retry successful for background location publish');
            } catch (retryError) {
              dev.log(
                  'Retry failed for background location publish: $retryError');
            }
          }
        });
      }
    }
  }

  /// Check if background tracking is currently active
  bool get isTracking => _isTracking;

  /// Get current tracking info
  Map<String, String?> get trackingInfo => {
        'orderId': _currentOrderId,
        'driverId': _currentDriverId,
        'isTracking': _isTracking.toString(),
      };

  /// Get detailed tracking status for debugging
  Map<String, dynamic> getDetailedTrackingStatus() {
    return {
      'isTracking': _isTracking,
      'orderId': _currentOrderId,
      'driverId': _currentDriverId,
      'hasBackgroundStream': _backgroundLocationStream != null,
      'hasPeriodicTimer': _periodicLocationTimer != null,
      'hasFallbackTimer': _fallbackTimer != null,
      'lastKnownPosition': _lastKnownPosition != null
          ? {
              'lat': _lastKnownPosition!.latitude,
              'lng': _lastKnownPosition!.longitude,
              'timestamp':
                  _lastKnownPosition!.timestamp?.millisecondsSinceEpoch,
            }
          : null,
      'updateIntervals': {
        'mainStream': 3,
        'periodic': _periodicUpdateInterval.inSeconds,
        'fallback': _fallbackCheckInterval.inSeconds,
        'heartbeat': 2,
        'monitoring': 10,
        'androidCheck': 15,
      },
      'platform': defaultTargetPlatform.toString(),
      'isAndroid': !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    };
  }

  /// Test all background tracking mechanisms
  Future<void> testAllTrackingMechanisms() async {
    if (!_isTracking || _currentOrderId == null || _currentDriverId == null) {
      dev.log('Cannot test: tracking not active');
      return;
    }

    try {
      dev.log('Testing all background tracking mechanisms...');

      // Test main stream
      dev.log('1. Testing main location stream...');
      final position1 = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 5),
      );

      // Test periodic updates
      dev.log('2. Testing periodic updates...');
      await _publishBackgroundLocation(
        latitude: position1.latitude,
        longitude: position1.longitude,
        speedKmh: position1.speed * 3.6,
        bearing: position1.heading,
        accuracy: position1.accuracy,
        rideStatus: 'active',
        phase: 'test_periodic',
      );

      // Test fallback timer
      dev.log('3. Testing fallback timer...');
      await _publishBackgroundLocation(
        latitude: position1.latitude,
        longitude: position1.longitude,
        speedKmh: position1.speed * 3.6,
        bearing: position1.heading,
        accuracy: position1.accuracy,
        rideStatus: 'active',
        phase: 'test_fallback',
      );

      // Test heartbeat
      dev.log('4. Testing heartbeat...');
      await _publishBackgroundLocation(
        latitude: position1.latitude,
        longitude: position1.longitude,
        speedKmh: position1.speed * 3.6,
        bearing: position1.heading,
        accuracy: position1.accuracy,
        rideStatus: 'active',
        phase: 'test_heartbeat',
      );

      dev.log('All background tracking mechanisms tested successfully');
    } catch (e) {
      dev.log('Error testing background tracking mechanisms: $e');
    }
  }

  /// Pause background tracking temporarily
  Future<void> pauseTracking() async {
    if (_isTracking && _backgroundLocationStream != null) {
      _backgroundLocationStream!.pause();
      dev.log('Background tracking paused');
    }
  }

  /// Resume background tracking
  Future<void> resumeTracking() async {
    if (_isTracking && _backgroundLocationStream != null) {
      _backgroundLocationStream!.resume();
      dev.log('Background tracking resumed');
    }
  }

  /// Manually trigger a location update (for testing)
  Future<void> triggerManualLocationUpdate() async {
    if (!_isTracking || _currentOrderId == null || _currentDriverId == null) {
      dev.log('Cannot trigger manual update: tracking not active');
      return;
    }

    try {
      dev.log('Manual location update triggered');

      final Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );

      await _publishBackgroundLocation(
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        speedKmh: currentPosition.speed * 3.6,
        bearing: currentPosition.heading,
        accuracy: currentPosition.accuracy,
        rideStatus: 'active',
        phase: 'manual_update',
      );

      dev.log('Manual location update published to Firebase');
    } catch (e) {
      dev.log('Error in manual location update: $e');
    }
  }

  /// Force immediate location update (for testing)
  Future<void> forceImmediateUpdate() async {
    if (!_isTracking || _currentOrderId == null || _currentDriverId == null) {
      dev.log('Cannot force update: tracking not active');
      return;
    }

    try {
      dev.log('Forcing immediate location update');

      // Get current position
      final Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 5),
      );

      // Update last known position
      _lastKnownPosition = currentPosition;

      // Publish to Firebase
      await _publishBackgroundLocation(
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        speedKmh: currentPosition.speed * 3.6,
        bearing: currentPosition.heading,
        accuracy: currentPosition.accuracy,
        rideStatus: 'active',
        phase: 'forced_update',
      );

      dev.log('Forced immediate location update published to Firebase');
    } catch (e) {
      dev.log('Error in forced immediate update: $e');
    }
  }

  /// Start periodic location updates as fallback mechanism
  void _startPeriodicLocationUpdates() {
    _periodicLocationTimer?.cancel();
    _periodicLocationTimer =
        Timer.periodic(_periodicUpdateInterval, (timer) async {
      if (_isTracking && _currentOrderId != null && _currentDriverId != null) {
        try {
          dev.log('Periodic location update triggered');

          // Get current position
          final Position currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 10),
          );

          // Check if position has changed significantly
          if (_lastKnownPosition == null ||
              _hasSignificantPositionChange(
                  _lastKnownPosition!, currentPosition)) {
            _lastKnownPosition = currentPosition;

            // Publish to Firebase
            await _publishBackgroundLocation(
              latitude: currentPosition.latitude,
              longitude: currentPosition.longitude,
              speedKmh: currentPosition.speed * 3.6,
              bearing: currentPosition.heading,
              accuracy: currentPosition.accuracy,
              rideStatus: 'active',
              phase: 'periodic_update',
            );

            dev.log('Periodic location update published to Firebase');
          } else {
            dev.log('Position unchanged, skipping periodic update');
          }
        } catch (e) {
          dev.log('Error in periodic location update: $e');
        }
      }
    });

    dev.log(
        'Periodic location updates started (${_periodicUpdateInterval.inSeconds}s interval)');
  }

  /// Start fallback timer to ensure location updates are working
  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(_fallbackCheckInterval, (timer) async {
      if (_isTracking && _currentOrderId != null && _currentDriverId != null) {
        try {
          dev.log('Fallback timer check triggered');

          // Check if we have recent location updates
          final Position currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 5),
          );

          // Always publish fallback location to ensure Firebase is updated
          await _publishBackgroundLocation(
            latitude: currentPosition.latitude,
            longitude: currentPosition.longitude,
            speedKmh: currentPosition.speed * 3.6,
            bearing: currentPosition.heading,
            accuracy: currentPosition.accuracy,
            rideStatus: 'active',
            phase: 'fallback_update',
          );

          dev.log('Fallback location update published to Firebase');
        } catch (e) {
          dev.log('Error in fallback location update: $e');
        }
      }
    });

    dev.log(
        'Fallback timer started (${_fallbackCheckInterval.inSeconds}s interval)');
  }

  /// Start heartbeat timer for continuous Firebase updates
  void _startHeartbeatTimer() {
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isTracking && _currentOrderId != null && _currentDriverId != null) {
        try {
          dev.log('Heartbeat timer triggered');

          // Get current position
          final Position currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 2),
          );

          // Always publish heartbeat location to Firebase
          await _publishBackgroundLocation(
            latitude: currentPosition.latitude,
            longitude: currentPosition.longitude,
            speedKmh: currentPosition.speed * 3.6,
            bearing: currentPosition.heading,
            accuracy: currentPosition.accuracy,
            rideStatus: 'active',
            phase: 'heartbeat',
          );

          dev.log('Heartbeat location update published to Firebase');
        } catch (e) {
          dev.log('Error in heartbeat location update: $e');
        }
      } else {
        timer.cancel(); // Stop heartbeat if tracking stops
      }
    });

    dev.log('Heartbeat timer started (2s interval)');
  }

  /// Monitor and restart background tracking if needed
  void _startBackgroundMonitoring() {
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_isTracking && _currentOrderId != null && _currentDriverId != null) {
        try {
          dev.log('Background monitoring check triggered');

          // Check if background stream is still active
          if (_backgroundLocationStream == null ||
              _backgroundLocationStream!.isPaused) {
            dev.log('Background stream inactive, restarting...');
            await _restartBackgroundTracking();
          }

          // Check if periodic timers are still running
          if (_periodicLocationTimer == null) {
            dev.log('Periodic timer stopped, restarting...');
            _startPeriodicLocationUpdates();
          }

          if (_fallbackTimer == null) {
            dev.log('Fallback timer stopped, restarting...');
            _startFallbackTimer();
          }

          // Force a location update to ensure Firebase is current
          await forceImmediateUpdate();
        } catch (e) {
          dev.log('Error in background monitoring: $e');
        }
      } else {
        timer.cancel(); // Stop monitoring if tracking stops
      }
    });

    dev.log('Background monitoring started (10s interval)');
  }

  /// Check if position has changed significantly
  bool _hasSignificantPositionChange(Position oldPos, Position newPos) {
    const double minDistanceChange = 5.0; // 5 meters
    const double minAccuracyThreshold = 50.0; // 50 meters accuracy threshold

    // Calculate distance between positions
    final double distance = Geolocator.distanceBetween(
      oldPos.latitude,
      oldPos.longitude,
      newPos.latitude,
      newPos.longitude,
    );

    // Check if accuracy is good enough and position changed significantly
    return newPos.accuracy < minAccuracyThreshold &&
        distance > minDistanceChange;
  }
}
