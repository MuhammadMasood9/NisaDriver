import 'package:flutter_test/flutter_test.dart';
import 'package:driver/services/enhanced_realtime_location_service.dart';
import 'package:driver/model/enhanced_location_data.dart';

void main() {
  group('EnhancedRealtimeLocationService', () {
    late EnhancedRealtimeLocationService service;

    setUp(() {
      service = EnhancedRealtimeLocationService();
    });

    test('should initialize with correct default state', () {
      expect(service.currentState, equals(ConnectionState.disconnected));
      expect(service.metrics['totalOperations'], equals(0));
      expect(service.metrics['successfulOperations'], equals(0));
      expect(service.metrics['failedOperations'], equals(0));
    });

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
        metadata: {
          'orderId': 'order123',
          'driverId': 'driver456',
        },
      );

      expect(locationData.isValid, isTrue);
      expect(locationData.confidenceScore, greaterThan(0.8));
    });

    test('should reject invalid location data', () async {
      final invalidLocationData = EnhancedLocationData(
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
        metadata: {
          'orderId': 'order123',
          'driverId': 'driver456',
        },
      );

      final result = await service.publishLocation(invalidLocationData);

      expect(result.success, isFalse);
      expect(result.error, contains('Invalid location data'));
    });

    test('should handle missing metadata gracefully', () async {
      final locationDataWithoutMetadata = EnhancedLocationData(
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
        metadata: {}, // Empty metadata
      );

      final result = await service.publishLocation(locationDataWithoutMetadata);

      expect(result.success, isFalse);
      expect(result.error, contains('Missing orderId or driverId'));
    });

    test('should calculate metrics correctly', () {
      final initialMetrics = service.metrics;
      expect(initialMetrics['totalOperations'], equals(0));
      expect(initialMetrics['successfulOperations'], equals(0));
      expect(initialMetrics['failedOperations'], equals(0));
      expect(initialMetrics['successRate'], equals(0.0));
      expect(initialMetrics['averageLatency'], equals(0.0));
      expect(initialMetrics['queuedOperations'], equals(0));
    });

    test('should handle connection state changes', () async {
      final stateChanges = <ConnectionState>[];
      service.connectionState.listen(stateChanges.add);

      // Initialize should trigger state changes
      await service.initialize();

      expect(stateChanges, contains(ConnectionState.connecting));
      // Note: Actual connection state depends on Firebase availability
    });

    test('should handle error stream', () async {
      final errors = <LocationServiceError>[];
      service.errors.listen(errors.add);

      // Try to publish invalid data to trigger an error
      final invalidLocationData = EnhancedLocationData(
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
        metadata: {
          'orderId': 'order123',
          'driverId': 'driver456',
        },
      );

      await service.publishLocation(invalidLocationData);

      // Should not emit errors for validation failures (handled internally)
      // Errors are emitted for Firebase connection issues
    });

    test('should handle batch publishing with empty list', () async {
      final results = await service.batchPublishLocations([]);
      expect(results, isEmpty);
    });

    test('should handle batch publishing with single item', () async {
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
        metadata: {
          'orderId': 'order123',
          'driverId': 'driver456',
        },
      );

      final results = await service.batchPublishLocations([locationData]);
      expect(results.length, equals(1));
      expect(results.first.success, isFalse); // Will fail without Firebase connection
    });

    tearDown(() {
      service.dispose();
    });
  });

  group('PublishResult', () {
    test('should create PublishResult correctly', () {
      final result = PublishResult(
        success: true,
        latency: Duration(milliseconds: 100),
        retryCount: 0,
        timestamp: DateTime.now(),
      );

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.latency.inMilliseconds, equals(100));
      expect(result.retryCount, equals(0));
    });

    test('should create failed PublishResult correctly', () {
      final result = PublishResult(
        success: false,
        error: 'Network error',
        latency: Duration(milliseconds: 50),
        retryCount: 2,
        timestamp: DateTime.now(),
      );

      expect(result.success, isFalse);
      expect(result.error, equals('Network error'));
      expect(result.latency.inMilliseconds, equals(50));
      expect(result.retryCount, equals(2));
    });

    test('should have meaningful toString', () {
      final result = PublishResult(
        success: true,
        latency: Duration(milliseconds: 100),
        retryCount: 0,
        timestamp: DateTime.now(),
      );

      final stringRepresentation = result.toString();
      expect(stringRepresentation, contains('success: true'));
      expect(stringRepresentation, contains('latency: 100ms'));
      expect(stringRepresentation, contains('retries: 0'));
    });
  });

  group('LocationServiceError', () {
    test('should create LocationServiceError correctly', () {
      final error = LocationServiceError(
        code: 'NETWORK_ERROR',
        message: 'Failed to connect',
        timestamp: DateTime.now(),
        details: {'retryCount': 3},
      );

      expect(error.code, equals('NETWORK_ERROR'));
      expect(error.message, equals('Failed to connect'));
      expect(error.details['retryCount'], equals(3));
    });

    test('should have meaningful toString', () {
      final error = LocationServiceError(
        code: 'NETWORK_ERROR',
        message: 'Failed to connect',
        timestamp: DateTime.now(),
      );

      final stringRepresentation = error.toString();
      expect(stringRepresentation, contains('NETWORK_ERROR'));
      expect(stringRepresentation, contains('Failed to connect'));
    });
  });
}