import 'package:flutter_test/flutter_test.dart';
import 'package:driver/services/location_data_batcher.dart';
import 'package:driver/services/enhanced_realtime_location_service.dart';
import 'package:driver/model/enhanced_location_data.dart';

// Mock service for testing
class MockRealtimeLocationService extends EnhancedRealtimeLocationService {
  final List<List<EnhancedLocationData>> publishedBatches = [];
  bool shouldFail = false;
  
  @override
  Future<List<PublishResult>> batchPublishLocations(List<EnhancedLocationData> locations) async {
    publishedBatches.add(List.from(locations));
    
    if (shouldFail) {
      return locations.map((location) => PublishResult(
        success: false,
        error: 'Mock failure',
        latency: Duration(milliseconds: 100),
        retryCount: 0,
        timestamp: DateTime.now(),
      )).toList();
    }
    
    return locations.map((location) => PublishResult(
      success: true,
      latency: Duration(milliseconds: 50),
      retryCount: 0,
      timestamp: DateTime.now(),
    )).toList();
  }
}

void main() {
  group('BatchingConfig', () {
    test('should create default config correctly', () {
      final config = BatchingConfig();
      
      expect(config.maxBatchSize, equals(10));
      expect(config.maxBatchAge, equals(Duration(seconds: 5)));
      expect(config.flushInterval, equals(Duration(seconds: 2)));
      expect(config.enableCompression, isTrue);
      expect(config.compressionThreshold, equals(1024));
      expect(config.networkThreshold, equals(NetworkQuality.fair));
    });

    test('should create network-optimized configs', () {
      final excellentConfig = BatchingConfig.forNetworkQuality(NetworkQuality.excellent);
      expect(excellentConfig.maxBatchSize, equals(5));
      expect(excellentConfig.enableCompression, isFalse);
      
      final poorConfig = BatchingConfig.forNetworkQuality(NetworkQuality.poor);
      expect(poorConfig.maxBatchSize, equals(20));
      expect(poorConfig.enableCompression, isTrue);
      expect(poorConfig.compressionThreshold, equals(512));
    });
  });

  group('LocationBatch', () {
    test('should create location batch correctly', () {
      final locations = [
        _createTestLocation(1),
        _createTestLocation(2),
      ];
      
      final batch = LocationBatch(
        locations: locations,
        createdAt: DateTime.now().subtract(Duration(seconds: 5)),
        batchId: 'test_batch_1',
        isCompressed: true,
        originalSize: 1000,
        compressedSize: 600,
      );
      
      expect(batch.locations.length, equals(2));
      expect(batch.isCompressed, isTrue);
      expect(batch.compressionRatio, equals(0.6));
      expect(batch.age.inSeconds, greaterThanOrEqualTo(4));
      expect(batch.estimatedSize, equals(600));
    });

    test('should calculate compression ratio correctly', () {
      final batch = LocationBatch(
        locations: [_createTestLocation(1)],
        createdAt: DateTime.now(),
        batchId: 'test_batch',
        isCompressed: true,
        originalSize: 2000,
        compressedSize: 800,
      );
      
      expect(batch.compressionRatio, equals(0.4));
    });

    test('should handle uncompressed batch', () {
      final batch = LocationBatch(
        locations: [_createTestLocation(1)],
        createdAt: DateTime.now(),
        batchId: 'test_batch',
        originalSize: 1000,
      );
      
      expect(batch.isCompressed, isFalse);
      expect(batch.compressionRatio, equals(1.0));
      expect(batch.estimatedSize, equals(1000));
    });
  });

  group('LocationDataBatcher', () {
    late MockRealtimeLocationService mockService;
    late LocationDataBatcher batcher;

    setUp(() {
      mockService = MockRealtimeLocationService();
      batcher = LocationDataBatcher(
        mockService,
        BatchingConfig(
          maxBatchSize: 3,
          maxBatchAge: Duration(seconds: 1),
          flushInterval: Duration(milliseconds: 500),
        ),
      );
    });

    tearDown(() {
      batcher.dispose();
    });

    test('should initialize with correct config', () {
      expect(batcher.config.maxBatchSize, equals(3));
      expect(batcher.config.maxBatchAge, equals(Duration(seconds: 1)));
    });

    test('should add location to batch', () async {
      final location = _createTestLocation(1);
      
      await batcher.addLocation(location);
      
      final status = batcher.getQueueStatus();
      expect(status['pendingBatches'], equals(1));
      expect(status['pendingLocations'], equals(1));
    });

    test('should flush batch when max size reached', () async {
      final config = BatchingConfig(maxBatchSize: 2);
      final testBatcher = LocationDataBatcher(mockService, config);
      
      // Add locations to reach max batch size
      await testBatcher.addLocation(_createTestLocation(1));
      await testBatcher.addLocation(_createTestLocation(2));
      
      // Give some time for async processing
      await Future.delayed(Duration(milliseconds: 100));
      
      expect(mockService.publishedBatches.length, equals(1));
      expect(mockService.publishedBatches.first.length, equals(2));
      
      testBatcher.dispose();
    });

    test('should reject invalid location data', () async {
      final invalidLocation = EnhancedLocationData(
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
      
      await batcher.addLocation(invalidLocation);
      
      final status = batcher.getQueueStatus();
      expect(status['pendingLocations'], equals(0));
    });

    test('should handle missing metadata gracefully', () async {
      final locationWithoutMetadata = EnhancedLocationData(
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
      
      await batcher.addLocation(locationWithoutMetadata);
      
      final status = batcher.getQueueStatus();
      expect(status['pendingLocations'], equals(0));
    });

    test('should flush all batches', () async {
      // Add some locations
      await batcher.addLocation(_createTestLocation(1));
      await batcher.addLocation(_createTestLocation(2));
      
      // Flush all
      await batcher.flushAll();
      
      final status = batcher.getQueueStatus();
      expect(status['pendingLocations'], equals(0));
      expect(mockService.publishedBatches.length, equals(1));
    });

    test('should update configuration', () {
      final newConfig = BatchingConfig(
        maxBatchSize: 20,
        enableCompression: false,
      );
      
      batcher.updateConfig(newConfig);
      
      expect(batcher.config.maxBatchSize, equals(20));
      expect(batcher.config.enableCompression, isFalse);
    });

    test('should calculate metrics correctly', () async {
      // Add and flush some locations
      await batcher.addLocation(_createTestLocation(1));
      await batcher.addLocation(_createTestLocation(2));
      await batcher.flushAll();
      
      final metrics = batcher.getMetrics();
      expect(metrics.totalBatches, greaterThan(0));
      expect(metrics.totalLocations, greaterThan(0));
    });

    test('should handle offline queue when publish fails', () async {
      mockService.shouldFail = true;
      
      await batcher.addLocation(_createTestLocation(1));
      await batcher.flushAll();
      
      final status = batcher.getQueueStatus();
      expect(status['offlineQueueSize'], greaterThan(0));
    });

    test('should process offline queue when connection restored', () async {
      // First, make service fail to create offline queue
      mockService.shouldFail = true;
      await batcher.addLocation(_createTestLocation(1));
      await batcher.flushAll();
      
      // Then restore service and process queue
      mockService.shouldFail = false;
      await batcher.processOfflineQueue();
      
      // Should have attempted to publish the queued location
      expect(mockService.publishedBatches.length, greaterThan(0));
    });
  });

  group('BatchingMetrics', () {
    test('should calculate compression efficiency correctly', () {
      final metrics = BatchingMetrics(
        totalBatches: 10,
        totalLocations: 50,
        compressedBatches: 5,
        averageBatchSize: 5.0,
        averageCompressionRatio: 0.6,
        averageBatchAge: Duration(seconds: 3),
        bytesOriginal: 10000,
        bytesCompressed: 6000,
        bytesSaved: 4000,
      );
      
      expect(metrics.compressionEfficiency, equals(40.0));
    });

    test('should handle zero bytes gracefully', () {
      final metrics = BatchingMetrics(
        totalBatches: 0,
        totalLocations: 0,
        compressedBatches: 0,
        averageBatchSize: 0.0,
        averageCompressionRatio: 1.0,
        averageBatchAge: Duration.zero,
        bytesOriginal: 0,
        bytesCompressed: 0,
        bytesSaved: 0,
      );
      
      expect(metrics.compressionEfficiency, equals(0.0));
    });

    test('should serialize to JSON correctly', () {
      final metrics = BatchingMetrics(
        totalBatches: 5,
        totalLocations: 25,
        compressedBatches: 2,
        averageBatchSize: 5.0,
        averageCompressionRatio: 0.7,
        averageBatchAge: Duration(seconds: 2),
        bytesOriginal: 5000,
        bytesCompressed: 3500,
        bytesSaved: 1500,
      );
      
      final json = metrics.toJson();
      expect(json['totalBatches'], equals(5));
      expect(json['totalLocations'], equals(25));
      expect(json['compressionEfficiency'], equals(30.0));
    });
  });
}

// Helper function to create test location data
EnhancedLocationData _createTestLocation(int sequenceNumber) {
  return EnhancedLocationData(
    latitude: 40.7128 + (sequenceNumber * 0.001),
    longitude: -74.0060 + (sequenceNumber * 0.001),
    speedKmh: 45.5,
    bearing: 180.0,
    accuracy: 5.0,
    status: 'rideInProgress',
    phase: RidePhase.rideInProgress,
    timestamp: DateTime.now(),
    sequenceNumber: sequenceNumber,
    batteryLevel: 85.0,
    networkQuality: NetworkQuality.good,
    metadata: {
      'orderId': 'order123',
      'driverId': 'driver456',
    },
  );
}