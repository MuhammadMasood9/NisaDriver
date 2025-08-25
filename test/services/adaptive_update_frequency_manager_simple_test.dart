// Simple test file for Adaptive Update Frequency Manager
// Basic functionality tests

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:driver/model/enhanced_location_data.dart';
import 'package:driver/services/adaptive_update_frequency_manager.dart';

void main() {
  group('AdaptiveUpdateFrequencyManager - Basic Tests', () {
    late AdaptiveUpdateFrequencyManager manager;

    setUp(() {
      manager = AdaptiveUpdateFrequencyManager();
    });

    test('should initialize with default values', () {
      expect(manager.calculateUpdateInterval(), equals(Duration(seconds: 3)));
      expect(manager.calculateRequiredAccuracy(), isA<LocationAccuracy>());
    });

    test('should adjust for ride phases', () {
      // Test pickup phase
      manager.setRidePhase(RidePhase.atPickupLocation);
      final pickupInterval = manager.calculateUpdateInterval();
      expect(pickupInterval.inSeconds, lessThanOrEqualTo(4)); // Should be shorter or similar
      
      // Test completed phase
      manager.setRidePhase(RidePhase.rideCompleted);
      final completedInterval = manager.calculateUpdateInterval();
      expect(completedInterval.inSeconds, greaterThan(5)); // Should be longer
    });

    test('should adjust for network quality', () {
      // Test excellent network
      manager.setNetworkQuality(NetworkQuality.excellent);
      final excellentInterval = manager.calculateUpdateInterval();
      
      // Test poor network
      manager.setNetworkQuality(NetworkQuality.poor);
      final poorInterval = manager.calculateUpdateInterval();
      
      expect(poorInterval.inSeconds, greaterThanOrEqualTo(excellentInterval.inSeconds));
    });

    test('should adjust for battery level', () {
      // Test high battery
      manager.setBatteryLevel(90.0);
      final highBatteryInterval = manager.calculateUpdateInterval();
      
      // Test low battery
      manager.setBatteryLevel(15.0);
      final lowBatteryInterval = manager.calculateUpdateInterval();
      
      expect(lowBatteryInterval.inSeconds, greaterThanOrEqualTo(highBatteryInterval.inSeconds));
    });

    test('should provide metrics', () {
      final metrics = manager.metrics;
      
      expect(metrics.currentInterval, isA<Duration>());
      expect(metrics.updatesPerMinute, isA<int>());
      expect(metrics.batteryImpact, isA<double>());
      expect(metrics.networkUsage, isA<double>());
    });

    test('should reset correctly', () {
      // Make some changes
      manager.setRidePhase(RidePhase.rideInProgress);
      manager.setNetworkQuality(NetworkQuality.poor);
      
      // Reset
      manager.reset();
      
      // Should be back to defaults
      expect(manager.calculateUpdateInterval(), equals(Duration(seconds: 3)));
    });
  });
}