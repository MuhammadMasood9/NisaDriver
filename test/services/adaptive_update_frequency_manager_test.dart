// Test file for Adaptive Update Frequency Manager
// Tests frequency calculations, context awareness, and optimization logic

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:driver/model/enhanced_location_data.dart';
import 'package:driver/services/adaptive_update_frequency_manager.dart';

void main() {
  group('AdaptiveUpdateFrequencyManager', () {
    late AdaptiveUpdateFrequencyManager manager;

    setUp(() {
      manager = AdaptiveUpdateFrequencyManager();
    });

    group('Initialization', () {
      test('should initialize with default values', () {
        expect(manager.calculateUpdateInterval(), equals(Duration(seconds: 3)));
        expect(manager.calculateRequiredAccuracy(), isA<LocationAccuracy>());
        expect(manager.metrics.currentInterval, equals(Duration(seconds: 3)));
        expect(manager.adjustmentHistory, isEmpty);
      });

      test('should provide valid initial metrics', () {
        final metrics = manager.metrics;
        
        expect(metrics.currentInterval, isA<Duration>());
        expect(metrics.updatesPerMinute, isA<int>());
        expect(metrics.batteryImpact, isA<double>());
        expect(metrics.networkUsage, isA<double>());
        expect(metrics.lastAdjustment, isA<DateTime>());
        expect(metrics.totalAdjustments, equals(0));
      });
    });

    group('Ride Phase Adjustments', () {
      test('should adjust frequency for enRouteToPickup phase', () {
        manager.setRidePhase(RidePhase.enRouteToPickup);
        final interval = manager.calculateUpdateInterval();
        
        // Should be slightly longer than default for en route
        expect(interval.inSeconds, greaterThanOrEqualTo(3));
      });

      test('should adjust frequency for atPickupLocation phase', () {
        manager.setRidePhase(RidePhase.atPickupLocation);
        final interval = manager.calculateUpdateInterval();
        
        // Should be shorter for critical pickup phase
        expect(interval.inSeconds, lessThanOrEqualTo(3));
        expect(interval.inSeconds, greaterThanOrEqualTo(2));
      });

      test('should adjust frequency for rideInProgress phase', () {
        manager.setRidePhase(RidePhase.rideInProgress);
        final interval = manager.calculateUpdateInterval();
        
        // Should be around default for active ride
        expect(interval.inSeconds, equals(3));
      });

      test('should adjust frequency for atDropoffLocation phase', () {
        manager.setRidePhase(RidePhase.atDropoffLocation);
        final interval = manager.calculateUpdateInterval();
        
        // Should be shorter for critical dropoff phase
        expect(interval.inSeconds, lessThanOrEqualTo(3));
        expect(interval.inSeconds, greaterThanOrEqualTo(2));
      });

      test('should adjust frequency for rideCompleted phase', () {
        manager.setRidePhase(RidePhase.rideCompleted);
        final interval = manager.calculateUpdateInterval();
        
        // Should be much longer when ride is completed
        expect(interval.inSeconds, greaterThan(5));
      });

      test('should track phase change adjustments', () {
        manager.setRidePhase(RidePhase.enRouteToPickup);
        manager.setRidePhase(RidePhase.atPickupLocation);
        
        expect(manager.adjustmentHistory, isNotEmpty);
        expect(manager.adjustmentHistory.last.reason, equals('ride_phase_change'));
      });
    });

    group('Network Quality Adjustments', () {
      test('should adjust frequency for excellent network', () {
        manager.setNetworkQuality(NetworkQuality.excellent);
        final interval = manager.calculateUpdateInterval();
        
        // Should maintain default frequency for excellent network
        expect(interval.inSeconds, equals(3));
      });

      test('should adjust frequency for good network', () {
        manager.setNetworkQuality(NetworkQuality.good);
        final interval = manager.calculateUpdateInterval();
        
        // Should be slightly longer for good network
        expect(interval.inSeconds, greaterThanOrEqualTo(3));
      });

      test('should adjust frequency for fair network', () {
        manager.setNetworkQuality(NetworkQuality.fair);
        final interval = manager.calculateUpdateInterval();
        
        // Should be moderately longer for fair network
        expect(interval.inSeconds, greaterThan(3));
      });

      test('should adjust frequency for poor network', () {
        manager.setNetworkQuality(NetworkQuality.poor);
        final interval = manager.calculateUpdateInterval();
        
        // Should be significantly longer for poor network
        expect(interval.inSeconds, greaterThan(4));
      });

      test('should adjust frequency for offline network', () {
        manager.setNetworkQuality(NetworkQuality.offline);
        final interval = manager.calculateUpdateInterval();
        
        // Should be much longer when offline
        expect(interval.inSeconds, greaterThan(6));
      });

      test('should track network quality adjustments', () {
        manager.setNetworkQuality(NetworkQuality.excellent);
        manager.setNetworkQuality(NetworkQuality.poor);
        
        expect(manager.adjustmentHistory, isNotEmpty);
        expect(manager.adjustmentHistory.last.reason, equals('network_quality_change'));
      });
    });

    group('Battery Level Adjustments', () {
      test('should not adjust frequency for high battery', () {
        manager.setBatteryLevel(90.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should maintain default frequency for high battery
        expect(interval.inSeconds, equals(3));
      });

      test('should adjust frequency for medium battery', () {
        manager.setBatteryLevel(60.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be slightly longer for medium battery
        expect(interval.inSeconds, greaterThanOrEqualTo(3));
      });

      test('should adjust frequency for low battery', () {
        manager.setBatteryLevel(30.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be moderately longer for low battery
        expect(interval.inSeconds, greaterThan(3));
      });

      test('should adjust frequency for very low battery', () {
        manager.setBatteryLevel(15.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be significantly longer for very low battery
        expect(interval.inSeconds, greaterThan(4));
      });

      test('should adjust frequency for critical battery', () {
        manager.setBatteryLevel(5.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be much longer for critical battery
        expect(interval.inSeconds, greaterThan(5));
      });

      test('should only adjust on significant battery changes', () {
        manager.setBatteryLevel(80.0);
        final initialAdjustments = manager.metrics.totalAdjustments;
        
        manager.setBatteryLevel(79.0); // Small change, should not adjust
        expect(manager.metrics.totalAdjustments, equals(initialAdjustments));
        
        manager.setBatteryLevel(74.0); // Significant change, should adjust
        expect(manager.metrics.totalAdjustments, greaterThan(initialAdjustments));
      });

      test('should handle invalid battery levels', () {
        manager.setBatteryLevel(-10.0); // Should be clamped
        manager.setBatteryLevel(150.0); // Should be clamped
        
        // Should not throw exceptions
        expect(manager.calculateUpdateInterval(), isA<Duration>());
      });
    });

    group('Speed-Based Adjustments', () {
      test('should adjust frequency for stationary driver', () {
        manager.setDriverSpeed(0.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be longer when stationary
        expect(interval.inSeconds, greaterThanOrEqualTo(10));
      });

      test('should adjust frequency for slow movement', () {
        manager.setDriverSpeed(5.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be slightly longer for slow movement
        expect(interval.inSeconds, greaterThanOrEqualTo(3));
      });

      test('should adjust frequency for normal speed', () {
        manager.setDriverSpeed(30.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be around default for normal speed
        expect(interval.inSeconds, equals(3));
      });

      test('should adjust frequency for high speed', () {
        manager.setDriverSpeed(80.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be shorter for high speed
        expect(interval.inSeconds, lessThanOrEqualTo(3));
        expect(interval.inSeconds, greaterThanOrEqualTo(2));
      });

      test('should adjust frequency for very high speed', () {
        manager.setDriverSpeed(120.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be shortest for very high speed
        expect(interval.inSeconds, lessThanOrEqualTo(3));
        expect(interval.inSeconds, greaterThanOrEqualTo(2));
      });

      test('should only adjust on significant speed changes', () {
        manager.setDriverSpeed(30.0);
        final initialAdjustments = manager.metrics.totalAdjustments;
        
        manager.setDriverSpeed(32.0); // Small change, should not adjust
        expect(manager.metrics.totalAdjustments, equals(initialAdjustments));
        
        manager.setDriverSpeed(40.0); // Significant change, should adjust
        expect(manager.metrics.totalAdjustments, greaterThan(initialAdjustments));
      });
    });

    group('Accuracy-Based Adjustments', () {
      test('should adjust frequency for excellent accuracy', () {
        manager.setLocationAccuracy(3.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be slightly longer for excellent accuracy
        expect(interval.inSeconds, greaterThanOrEqualTo(3));
      });

      test('should adjust frequency for good accuracy', () {
        manager.setLocationAccuracy(8.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should maintain default for good accuracy
        expect(interval.inSeconds, equals(3));
      });

      test('should adjust frequency for fair accuracy', () {
        manager.setLocationAccuracy(25.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be shorter for fair accuracy to get better readings
        expect(interval.inSeconds, lessThanOrEqualTo(3));
        expect(interval.inSeconds, greaterThanOrEqualTo(2));
      });

      test('should adjust frequency for poor accuracy', () {
        manager.setLocationAccuracy(60.0);
        final interval = manager.calculateUpdateInterval();
        
        // Should be shorter for poor accuracy to get better readings
        expect(interval.inSeconds, lessThanOrEqualTo(3));
        expect(interval.inSeconds, greaterThanOrEqualTo(2));
      });

      test('should only adjust on significant accuracy changes', () {
        manager.setLocationAccuracy(10.0);
        final initialAdjustments = manager.metrics.totalAdjustments;
        
        manager.setLocationAccuracy(12.0); // Small change, should not adjust
        expect(manager.metrics.totalAdjustments, equals(initialAdjustments));
        
        manager.setLocationAccuracy(20.0); // Significant change, should adjust
        expect(manager.metrics.totalAdjustments, greaterThan(initialAdjustments));
      });
    });

    group('Combined Adjustments', () {
      test('should handle multiple factors correctly', () {
        // Set up a complex scenario
        manager.setRidePhase(RidePhase.atPickupLocation); // Shorter interval
        manager.setNetworkQuality(NetworkQuality.poor);   // Longer interval
        manager.setBatteryLevel(15.0);                    // Longer interval
        manager.setDriverSpeed(0.0);                      // Longer interval
        manager.setLocationAccuracy(50.0);                // Shorter interval
        
        final interval = manager.calculateUpdateInterval();
        
        // Should balance all factors
        expect(interval.inSeconds, greaterThanOrEqualTo(2));
        expect(interval.inSeconds, lessThanOrEqualTo(30));
      });

      test('should prioritize critical phases over other factors', () {
        // Critical pickup phase should override other factors
        manager.setRidePhase(RidePhase.atPickupLocation);
        manager.setNetworkQuality(NetworkQuality.poor);
        manager.setBatteryLevel(10.0);
        
        final interval = manager.calculateUpdateInterval();
        
        // Should still be relatively frequent for critical phase
        expect(interval.inSeconds, lessThanOrEqualTo(10));
      });

      test('should handle extreme low battery scenarios', () {
        manager.setRidePhase(RidePhase.rideInProgress);
        manager.setBatteryLevel(2.0);
        manager.setNetworkQuality(NetworkQuality.poor);
        
        final interval = manager.calculateUpdateInterval();
        
        // Should significantly reduce frequency to save battery
        expect(interval.inSeconds, greaterThan(5));
      });
    });

    group('Bounds and Limits', () {
      test('should respect minimum interval bounds', () {
        // Try to force very short interval
        manager.setRidePhase(RidePhase.atPickupLocation);
        manager.setNetworkQuality(NetworkQuality.excellent);
        manager.setBatteryLevel(100.0);
        manager.setDriverSpeed(100.0);
        manager.setLocationAccuracy(100.0);
        
        final interval = manager.calculateUpdateInterval();
        
        // Should not go below minimum
        expect(interval.inSeconds, greaterThanOrEqualTo(2));
      });

      test('should respect maximum interval bounds', () {
        // Try to force very long interval
        manager.setRidePhase(RidePhase.rideCompleted);
        manager.setNetworkQuality(NetworkQuality.offline);
        manager.setBatteryLevel(1.0);
        manager.setDriverSpeed(0.0);
        
        final interval = manager.calculateUpdateInterval();
        
        // Should not exceed maximum
        expect(interval.inSeconds, lessThanOrEqualTo(30));
      });
    });

    group('Location Accuracy Requirements', () {
      test('should require best accuracy for critical phases', () {
        manager.setRidePhase(RidePhase.atPickupLocation);
        expect(manager.calculateRequiredAccuracy(), equals(LocationAccuracy.best));
        
        manager.setRidePhase(RidePhase.atDropoffLocation);
        expect(manager.calculateRequiredAccuracy(), equals(LocationAccuracy.best));
      });

      test('should require high accuracy for active ride', () {
        manager.setRidePhase(RidePhase.rideInProgress);
        expect(manager.calculateRequiredAccuracy(), equals(LocationAccuracy.bestForNavigation));
      });

      test('should require good accuracy for en route', () {
        manager.setRidePhase(RidePhase.enRouteToPickup);
        expect(manager.calculateRequiredAccuracy(), equals(LocationAccuracy.high));
      });

      test('should require medium accuracy for completed ride', () {
        manager.setRidePhase(RidePhase.rideCompleted);
        expect(manager.calculateRequiredAccuracy(), equals(LocationAccuracy.medium));
      });
    });

    group('Metrics and History', () {
      test('should track adjustment history', () {
        manager.setRidePhase(RidePhase.enRouteToPickup);
        manager.setNetworkQuality(NetworkQuality.poor);
        manager.setBatteryLevel(50.0);
        
        final history = manager.adjustmentHistory;
        expect(history, isNotEmpty);
        expect(history.length, greaterThanOrEqualTo(2));
      });

      test('should limit history size', () {
        // Make many adjustments
        for (int i = 0; i < 60; i++) {
          manager.setBatteryLevel(100.0 - i);
        }
        
        // Should not exceed maximum history size
        expect(manager.adjustmentHistory.length, lessThanOrEqualTo(50));
      });

      test('should provide accurate metrics', () {
        manager.setRidePhase(RidePhase.rideInProgress);
        manager.setNetworkQuality(NetworkQuality.good);
        
        final metrics = manager.metrics;
        
        expect(metrics.updatesPerMinute, greaterThan(0));
        expect(metrics.batteryImpact, greaterThanOrEqualTo(0.0));
        expect(metrics.networkUsage, greaterThanOrEqualTo(0.0));
        expect(metrics.totalAdjustments, greaterThanOrEqualTo(0));
      });

      test('should calculate updates per minute correctly', () {
        manager.setRidePhase(RidePhase.rideInProgress); // 3 second interval
        
        final metrics = manager.metrics;
        final expectedUpdatesPerMinute = 60 ~/ 3; // 20 updates per minute
        
        expect(metrics.updatesPerMinute, equals(expectedUpdatesPerMinute));
      });
    });

    group('Configuration and Reset', () {
      test('should provide configuration summary', () {
        manager.setRidePhase(RidePhase.rideInProgress);
        manager.setNetworkQuality(NetworkQuality.good);
        manager.setBatteryLevel(75.0);
        
        final config = manager.getConfigurationSummary();
        
        expect(config['currentPhase'], equals('rideInProgress'));
        expect(config['networkQuality'], equals('good'));
        expect(config['batteryLevel'], equals(75.0));
        expect(config['currentInterval'], isA<int>());
        expect(config['totalAdjustments'], isA<int>());
      });

      test('should reset to default state', () {
        // Make some changes
        manager.setRidePhase(RidePhase.rideInProgress);
        manager.setNetworkQuality(NetworkQuality.poor);
        manager.setBatteryLevel(30.0);
        
        // Reset
        manager.reset();
        
        // Should be back to defaults
        expect(manager.calculateUpdateInterval(), equals(Duration(seconds: 3)));
        expect(manager.adjustmentHistory, isEmpty);
        expect(manager.metrics.totalAdjustments, equals(0));
      });

      test('should force recalculation', () {
        final initialAdjustments = manager.metrics.totalAdjustments;
        
        manager.forceRecalculation('test_reason');
        
        expect(manager.metrics.totalAdjustments, greaterThan(initialAdjustments));
        expect(manager.adjustmentHistory.last.reason, equals('test_reason'));
      });
    });
  });
}