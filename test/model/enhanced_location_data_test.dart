import 'package:flutter_test/flutter_test.dart';
import 'package:driver/model/enhanced_location_data.dart';

void main() {
  group('EnhancedLocationData', () {
    test('should create valid location data', () {
      final locationData = EnhancedLocationData(
        latitude: 40.7128,
        longitude: -74.0060,
        speedKmh: 45.5,
        bearing: 180.0,
        accuracy: 5.0,
        status: 'rideInProgress',
        phase: RidePhase.rideInProgress,
        timestamp: DateTime.now(),
        sequenceNumber: 1234,
        batteryLevel: 85.0,
        networkQuality: NetworkQuality.good,
      );

      expect(locationData.isValid, isTrue);
      expect(locationData.confidenceScore, greaterThan(0.8));
      expect(locationData.latitude, equals(40.7128));
      expect(locationData.longitude, equals(-74.0060));
    });

    test('should validate coordinate bounds', () {
      final invalidLat = EnhancedLocationData(
        latitude: 91.0, // Invalid latitude
        longitude: -74.0060,
        speedKmh: 45.5,
        bearing: 180.0,
        accuracy: 5.0,
        status: 'rideInProgress',
        phase: RidePhase.rideInProgress,
        timestamp: DateTime.now(),
        sequenceNumber: 1234,
        batteryLevel: 85.0,
        networkQuality: NetworkQuality.good,
      );

      expect(invalidLat.isValid, isFalse);

      final invalidLng = EnhancedLocationData(
        latitude: 40.7128,
        longitude: 181.0, // Invalid longitude
        speedKmh: 45.5,
        bearing: 180.0,
        accuracy: 5.0,
        status: 'rideInProgress',
        phase: RidePhase.rideInProgress,
        timestamp: DateTime.now(),
        sequenceNumber: 1234,
        batteryLevel: 85.0,
        networkQuality: NetworkQuality.good,
      );

      expect(invalidLng.isValid, isFalse);
    });

    test('should validate speed bounds', () {
      final invalidSpeed = EnhancedLocationData(
        latitude: 40.7128,
        longitude: -74.0060,
        speedKmh: -10.0, // Invalid negative speed
        bearing: 180.0,
        accuracy: 5.0,
        status: 'rideInProgress',
        phase: RidePhase.rideInProgress,
        timestamp: DateTime.now(),
        sequenceNumber: 1234,
        batteryLevel: 85.0,
        networkQuality: NetworkQuality.good,
      );

      expect(invalidSpeed.isValid, isFalse);

      final excessiveSpeed = EnhancedLocationData(
        latitude: 40.7128,
        longitude: -74.0060,
        speedKmh: 350.0, // Unreasonably high speed
        bearing: 180.0,
        accuracy: 5.0,
        status: 'rideInProgress',
        phase: RidePhase.rideInProgress,
        timestamp: DateTime.now(),
        sequenceNumber: 1234,
        batteryLevel: 85.0,
        networkQuality: NetworkQuality.good,
      );

      expect(excessiveSpeed.isValid, isFalse);
    });

    test('should calculate confidence score correctly', () {
      // High accuracy, good network = high confidence
      final highConfidence = EnhancedLocationData(
        latitude: 40.7128,
        longitude: -74.0060,
        speedKmh: 45.5,
        bearing: 180.0,
        accuracy: 3.0, // Excellent accuracy
        status: 'rideInProgress',
        phase: RidePhase.rideInProgress,
        timestamp: DateTime.now(),
        sequenceNumber: 1234,
        batteryLevel: 85.0,
        networkQuality: NetworkQuality.excellent,
      );

      expect(highConfidence.confidenceScore, greaterThan(0.9));

      // Poor accuracy, poor network = low confidence
      final lowConfidence = EnhancedLocationData(
        latitude: 40.7128,
        longitude: -74.0060,
        speedKmh: 45.5,
        bearing: 180.0,
        accuracy: 60.0, // Poor accuracy
        status: 'rideInProgress',
        phase: RidePhase.rideInProgress,
        timestamp: DateTime.now().subtract(Duration(seconds: 35)), // Old data
        sequenceNumber: 1234,
        batteryLevel: 85.0,
        networkQuality: NetworkQuality.poor,
      );

      expect(lowConfidence.confidenceScore, lessThan(0.5));
    });

    test('should serialize to and from Firebase JSON', () {
      final originalData = EnhancedLocationData(
        latitude: 40.7128,
        longitude: -74.0060,
        speedKmh: 45.5,
        bearing: 180.0,
        accuracy: 5.0,
        status: 'rideInProgress',
        phase: RidePhase.rideInProgress,
        timestamp: DateTime.now(),
        sequenceNumber: 1234,
        batteryLevel: 85.0,
        networkQuality: NetworkQuality.good,
        metadata: {'test': 'value'},
      );

      final json = originalData.toFirebaseJson();
      final deserializedData = EnhancedLocationData.fromFirebaseJson(json);

      expect(deserializedData.latitude, equals(originalData.latitude));
      expect(deserializedData.longitude, equals(originalData.longitude));
      expect(deserializedData.speedKmh, equals(originalData.speedKmh));
      expect(deserializedData.bearing, equals(originalData.bearing));
      expect(deserializedData.accuracy, equals(originalData.accuracy));
      expect(deserializedData.status, equals(originalData.status));
      expect(deserializedData.phase, equals(originalData.phase));
      expect(deserializedData.sequenceNumber, equals(originalData.sequenceNumber));
      expect(deserializedData.batteryLevel, equals(originalData.batteryLevel));
      expect(deserializedData.networkQuality, equals(originalData.networkQuality));
      expect(deserializedData.metadata['test'], equals('value'));
    });

    test('should handle malformed Firebase JSON gracefully', () {
      final malformedJson = <String, dynamic>{
        'lat': 'invalid', // String instead of number
        'lng': null,
        'speedKmh': -1,
        'bearing': 400, // Invalid bearing
        'accuracy': null,
        'status': null,
        'phase': 'invalidPhase',
        'updatedAt': 'invalid',
        'sequenceNumber': null,
        'batteryLevel': 150, // Invalid battery level
        'networkQuality': 'invalidQuality',
        'metadata': null,
      };

      final locationData = EnhancedLocationData.fromFirebaseJson(malformedJson);

      // Should have default/clamped values and be valid due to clamping
      expect(locationData.latitude, equals(0.0));
      expect(locationData.longitude, equals(0.0));
      expect(locationData.speedKmh, equals(0.0)); // Clamped from -1
      expect(locationData.bearing, equals(359.9)); // Clamped from 400
      expect(locationData.accuracy, equals(10.0));
      expect(locationData.status, equals(''));
      expect(locationData.phase, equals(RidePhase.enRouteToPickup));
      expect(locationData.sequenceNumber, equals(0));
      expect(locationData.batteryLevel, equals(100.0)); // Clamped from 150
      expect(locationData.networkQuality, equals(NetworkQuality.good));
      expect(locationData.metadata, isEmpty);
      // Data is now valid because values are clamped to valid ranges
      expect(locationData.isValid, isTrue);
    });

    test('should create copy with updated values', () {
      final originalData = EnhancedLocationData(
        latitude: 40.7128,
        longitude: -74.0060,
        speedKmh: 45.5,
        bearing: 180.0,
        accuracy: 5.0,
        status: 'rideInProgress',
        phase: RidePhase.rideInProgress,
        timestamp: DateTime.now(),
        sequenceNumber: 1234,
        batteryLevel: 85.0,
        networkQuality: NetworkQuality.good,
      );

      final updatedData = originalData.copyWith(
        speedKmh: 55.0,
        bearing: 190.0,
        phase: RidePhase.atDropoffLocation,
      );

      expect(updatedData.latitude, equals(originalData.latitude)); // Unchanged
      expect(updatedData.longitude, equals(originalData.longitude)); // Unchanged
      expect(updatedData.speedKmh, equals(55.0)); // Changed
      expect(updatedData.bearing, equals(190.0)); // Changed
      expect(updatedData.phase, equals(RidePhase.atDropoffLocation)); // Changed
      expect(updatedData.accuracy, equals(originalData.accuracy)); // Unchanged
    });
  });

  group('RidePhase', () {
    test('should convert to and from string correctly', () {
      for (final phase in RidePhase.values) {
        final stringValue = phase.value;
        final convertedBack = RidePhase.fromString(stringValue);
        expect(convertedBack, equals(phase));
      }
    });

    test('should handle invalid string gracefully', () {
      final invalidPhase = RidePhase.fromString('invalidPhase');
      expect(invalidPhase, equals(RidePhase.enRouteToPickup));
    });
  });

  group('NetworkQuality', () {
    test('should convert to and from string correctly', () {
      for (final quality in NetworkQuality.values) {
        final stringValue = quality.value;
        final convertedBack = NetworkQuality.fromString(stringValue);
        expect(convertedBack, equals(quality));
      }
    });

    test('should handle invalid string gracefully', () {
      final invalidQuality = NetworkQuality.fromString('invalidQuality');
      expect(invalidQuality, equals(NetworkQuality.good));
    });
  });

  group('LocationTrackingStatus', () {
    test('should create and serialize correctly', () {
      final status = LocationTrackingStatus(
        isActive: true,
        lastUpdate: DateTime.now(),
        accuracy: 5.0,
        status: 'tracking',
        issues: ['network_slow'],
      );

      final json = status.toJson();
      final deserializedStatus = LocationTrackingStatus.fromJson(json);

      expect(deserializedStatus.isActive, equals(status.isActive));
      expect(deserializedStatus.accuracy, equals(status.accuracy));
      expect(deserializedStatus.status, equals(status.status));
      expect(deserializedStatus.issues, equals(status.issues));
    });

    test('should create copy with updated values', () {
      final originalStatus = LocationTrackingStatus(
        isActive: true,
        lastUpdate: DateTime.now(),
        accuracy: 5.0,
        status: 'tracking',
        issues: ['network_slow'],
      );

      final updatedStatus = originalStatus.copyWith(
        isActive: false,
        status: 'stopped',
        issues: [],
      );

      expect(updatedStatus.isActive, isFalse);
      expect(updatedStatus.status, equals('stopped'));
      expect(updatedStatus.issues, isEmpty);
      expect(updatedStatus.accuracy, equals(originalStatus.accuracy)); // Unchanged
    });
  });

  group('LocationTrackingMetrics', () {
    test('should calculate success rate correctly', () {
      final metrics = LocationTrackingMetrics(
        totalUpdates: 100,
        averageAccuracy: 5.0,
        averageInterval: Duration(seconds: 3),
        failedUpdates: 10,
        batteryUsagePercent: 2.5,
        networkUsageMB: 1.2,
        trackingStartTime: DateTime.now().subtract(Duration(hours: 1)),
        totalTrackingTime: Duration(hours: 1),
      );

      expect(metrics.successRate, equals(90.0));
      expect(metrics.updatesPerMinute, equals(100.0 / 60.0));
    });

    test('should handle zero updates gracefully', () {
      final metrics = LocationTrackingMetrics(
        totalUpdates: 0,
        averageAccuracy: 0.0,
        averageInterval: Duration.zero,
        failedUpdates: 0,
        batteryUsagePercent: 0.0,
        networkUsageMB: 0.0,
        trackingStartTime: DateTime.now(),
        totalTrackingTime: Duration.zero,
      );

      expect(metrics.successRate, equals(0.0));
      expect(metrics.updatesPerMinute, equals(0.0));
    });

    test('should serialize to and from JSON correctly', () {
      final originalMetrics = LocationTrackingMetrics(
        totalUpdates: 100,
        averageAccuracy: 5.0,
        averageInterval: Duration(seconds: 3),
        failedUpdates: 10,
        batteryUsagePercent: 2.5,
        networkUsageMB: 1.2,
        trackingStartTime: DateTime.now().subtract(Duration(hours: 1)),
        totalTrackingTime: Duration(hours: 1),
      );

      final json = originalMetrics.toJson();
      final deserializedMetrics = LocationTrackingMetrics.fromJson(json);

      expect(deserializedMetrics.totalUpdates, equals(originalMetrics.totalUpdates));
      expect(deserializedMetrics.averageAccuracy, equals(originalMetrics.averageAccuracy));
      expect(deserializedMetrics.averageInterval, equals(originalMetrics.averageInterval));
      expect(deserializedMetrics.failedUpdates, equals(originalMetrics.failedUpdates));
      expect(deserializedMetrics.batteryUsagePercent, equals(originalMetrics.batteryUsagePercent));
      expect(deserializedMetrics.networkUsageMB, equals(originalMetrics.networkUsageMB));
      expect(deserializedMetrics.totalTrackingTime, equals(originalMetrics.totalTrackingTime));
    });
  });
}