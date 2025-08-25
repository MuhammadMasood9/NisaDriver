// Location Data Batcher for Driver App
// This service handles batching of location updates for efficient Firebase operations

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:driver/model/enhanced_location_data.dart';
import 'package:driver/services/enhanced_realtime_location_service.dart';

/// Configuration for batching behavior
class BatchingConfig {
  final int maxBatchSize;
  final Duration maxBatchAge;
  final Duration flushInterval;
  final bool enableCompression;
  final int compressionThreshold; // bytes
  final NetworkQuality networkThreshold;

  const BatchingConfig({
    this.maxBatchSize = 10,
    this.maxBatchAge = const Duration(seconds: 5),
    this.flushInterval = const Duration(seconds: 2),
    this.enableCompression = true,
    this.compressionThreshold = 1024, // 1KB
    this.networkThreshold = NetworkQuality.fair,
  });

  /// Create config optimized for different network conditions
  factory BatchingConfig.forNetworkQuality(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return BatchingConfig(
          maxBatchSize: 5,
          maxBatchAge: Duration(seconds: 2),
          flushInterval: Duration(seconds: 1),
          enableCompression: false,
        );
      case NetworkQuality.good:
        return BatchingConfig(
          maxBatchSize: 8,
          maxBatchAge: Duration(seconds: 3),
          flushInterval: Duration(seconds: 2),
          enableCompression: false,
        );
      case NetworkQuality.fair:
        return BatchingConfig(
          maxBatchSize: 12,
          maxBatchAge: Duration(seconds: 5),
          flushInterval: Duration(seconds: 3),
          enableCompression: true,
        );
      case NetworkQuality.poor:
        return BatchingConfig(
          maxBatchSize: 20,
          maxBatchAge: Duration(seconds: 10),
          flushInterval: Duration(seconds: 5),
          enableCompression: true,
          compressionThreshold: 512,
        );
      case NetworkQuality.offline:
        return BatchingConfig(
          maxBatchSize: 50,
          maxBatchAge: Duration(minutes: 5),
          flushInterval: Duration(seconds: 30),
          enableCompression: true,
          compressionThreshold: 256,
        );
    }
  }
}

/// Batch of location data with metadata
class LocationBatch {
  final List<EnhancedLocationData> locations;
  final DateTime createdAt;
  final String batchId;
  final bool isCompressed;
  final int originalSize;
  final int compressedSize;

  LocationBatch({
    required this.locations,
    required this.createdAt,
    required this.batchId,
    this.isCompressed = false,
    this.originalSize = 0,
    this.compressedSize = 0,
  });

  /// Age of the batch
  Duration get age => DateTime.now().difference(createdAt);

  /// Compression ratio (if compressed)
  double get compressionRatio => 
      isCompressed && originalSize > 0 ? compressedSize / originalSize : 1.0;

  /// Size in bytes (estimated)
  int get estimatedSize => isCompressed ? compressedSize : originalSize;

  @override
  String toString() {
    return 'LocationBatch(id: $batchId, count: ${locations.length}, age: ${age.inSeconds}s, compressed: $isCompressed, ratio: ${compressionRatio.toStringAsFixed(2)})';
  }
}

/// Metrics for batching operations
class BatchingMetrics {
  final int totalBatches;
  final int totalLocations;
  final int compressedBatches;
  final double averageBatchSize;
  final double averageCompressionRatio;
  final Duration averageBatchAge;
  final int bytesOriginal;
  final int bytesCompressed;
  final int bytesSaved;

  const BatchingMetrics({
    required this.totalBatches,
    required this.totalLocations,
    required this.compressedBatches,
    required this.averageBatchSize,
    required this.averageCompressionRatio,
    required this.averageBatchAge,
    required this.bytesOriginal,
    required this.bytesCompressed,
    required this.bytesSaved,
  });

  /// Compression efficiency as percentage
  double get compressionEfficiency => 
      bytesOriginal > 0 ? (bytesSaved / bytesOriginal) * 100 : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'totalBatches': totalBatches,
      'totalLocations': totalLocations,
      'compressedBatches': compressedBatches,
      'averageBatchSize': averageBatchSize,
      'averageCompressionRatio': averageCompressionRatio,
      'averageBatchAge': averageBatchAge.inMilliseconds,
      'bytesOriginal': bytesOriginal,
      'bytesCompressed': bytesCompressed,
      'bytesSaved': bytesSaved,
      'compressionEfficiency': compressionEfficiency,
    };
  }
}

/// Service for batching and compressing location data
class LocationDataBatcher {
  final EnhancedRealtimeLocationService _realtimeService;
  BatchingConfig _config;
  
  // Batching state
  final Map<String, List<EnhancedLocationData>> _pendingBatches = {};
  final Map<String, DateTime> _batchCreationTimes = {};
  Timer? _flushTimer;
  
  // Offline queue
  final List<LocationBatch> _offlineQueue = [];
  static const int _maxOfflineQueueSize = 100;
  
  // Metrics
  int _totalBatches = 0;
  int _totalLocations = 0;
  int _compressedBatches = 0;
  int _bytesOriginal = 0;
  int _bytesCompressed = 0;
  final List<double> _batchSizes = [];
  final List<double> _compressionRatios = [];
  final List<Duration> _batchAges = [];

  LocationDataBatcher(this._realtimeService, [BatchingConfig? config])
      : _config = config ?? BatchingConfig() {
    _startFlushTimer();
  }

  /// Current batching configuration
  BatchingConfig get config => _config;

  /// Update batching configuration
  void updateConfig(BatchingConfig newConfig) {
    _config = newConfig;
    _restartFlushTimer();
    dev.log('LocationDataBatcher: Configuration updated - maxBatchSize: ${_config.maxBatchSize}, compression: ${_config.enableCompression}');
  }

  /// Add location data to batch
  Future<void> addLocation(EnhancedLocationData location) async {
    if (!location.isValid) {
      dev.log('LocationDataBatcher: Skipping invalid location data');
      return;
    }

    final orderId = location.metadata['orderId'] as String?;
    final driverId = location.metadata['driverId'] as String?;
    
    if (orderId == null || driverId == null) {
      dev.log('LocationDataBatcher: Missing orderId or driverId in location metadata');
      return;
    }

    final batchKey = '$orderId/$driverId';
    
    // Initialize batch if needed
    _pendingBatches.putIfAbsent(batchKey, () => []);
    _batchCreationTimes.putIfAbsent(batchKey, () => DateTime.now());
    
    // Add location to batch
    _pendingBatches[batchKey]!.add(location);
    
    dev.log('LocationDataBatcher: Added location to batch $batchKey (${_pendingBatches[batchKey]!.length}/${_config.maxBatchSize})');
    
    // Check if batch should be flushed immediately
    if (_shouldFlushBatch(batchKey)) {
      await _flushBatch(batchKey);
    }
  }

  /// Force flush all pending batches
  Future<void> flushAll() async {
    dev.log('LocationDataBatcher: Flushing all pending batches (${_pendingBatches.length} batches)');
    
    final batchKeys = List<String>.from(_pendingBatches.keys);
    for (final batchKey in batchKeys) {
      await _flushBatch(batchKey);
    }
  }

  /// Process offline queue when connection is restored
  Future<void> processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    
    dev.log('LocationDataBatcher: Processing offline queue (${_offlineQueue.length} batches)');
    
    final batchesToProcess = List<LocationBatch>.from(_offlineQueue);
    _offlineQueue.clear();
    
    for (final batch in batchesToProcess) {
      try {
        final results = await _realtimeService.batchPublishLocations(batch.locations);
        final successCount = results.where((r) => r.success).length;
        
        if (successCount < batch.locations.length) {
          // Some locations failed, re-queue the failed ones
          final failedLocations = <EnhancedLocationData>[];
          for (int i = 0; i < results.length; i++) {
            if (!results[i].success) {
              failedLocations.add(batch.locations[i]);
            }
          }
          
          if (failedLocations.isNotEmpty) {
            _addToOfflineQueue(failedLocations);
          }
        }
        
        dev.log('LocationDataBatcher: Processed offline batch ${batch.batchId} - ${successCount}/${batch.locations.length} successful');
      } catch (e) {
        dev.log('LocationDataBatcher: Failed to process offline batch ${batch.batchId}: $e');
        // Re-queue the entire batch
        _offlineQueue.insert(0, batch);
        break; // Stop processing if we hit an error
      }
    }
  }

  /// Get current batching metrics
  BatchingMetrics getMetrics() {
    return BatchingMetrics(
      totalBatches: _totalBatches,
      totalLocations: _totalLocations,
      compressedBatches: _compressedBatches,
      averageBatchSize: _batchSizes.isNotEmpty 
          ? _batchSizes.reduce((a, b) => a + b) / _batchSizes.length 
          : 0.0,
      averageCompressionRatio: _compressionRatios.isNotEmpty
          ? _compressionRatios.reduce((a, b) => a + b) / _compressionRatios.length
          : 1.0,
      averageBatchAge: _batchAges.isNotEmpty
          ? Duration(microseconds: (_batchAges.map((d) => d.inMicroseconds).reduce((a, b) => a + b) / _batchAges.length).round())
          : Duration.zero,
      bytesOriginal: _bytesOriginal,
      bytesCompressed: _bytesCompressed,
      bytesSaved: _bytesOriginal - _bytesCompressed,
    );
  }

  /// Check if batch should be flushed
  bool _shouldFlushBatch(String batchKey) {
    final batch = _pendingBatches[batchKey];
    final creationTime = _batchCreationTimes[batchKey];
    
    if (batch == null || creationTime == null) return false;
    
    // Flush if batch is full
    if (batch.length >= _config.maxBatchSize) {
      return true;
    }
    
    // Flush if batch is too old
    final age = DateTime.now().difference(creationTime);
    if (age >= _config.maxBatchAge) {
      return true;
    }
    
    return false;
  }

  /// Flush a specific batch
  Future<void> _flushBatch(String batchKey) async {
    final batch = _pendingBatches[batchKey];
    final creationTime = _batchCreationTimes[batchKey];
    
    if (batch == null || batch.isEmpty || creationTime == null) {
      return;
    }
    
    dev.log('LocationDataBatcher: Flushing batch $batchKey with ${batch.length} locations');
    
    // Remove from pending
    _pendingBatches.remove(batchKey);
    _batchCreationTimes.remove(batchKey);
    
    // Create batch object
    final batchAge = DateTime.now().difference(creationTime);
    final batchId = '${batchKey}_${DateTime.now().millisecondsSinceEpoch}';
    
    // Compress if needed
    final shouldCompress = _shouldCompressBatch(batch);
    int originalSize = 0;
    int compressedSize = 0;
    
    if (shouldCompress) {
      final sizeInfo = _estimateBatchSize(batch);
      originalSize = sizeInfo['original']!;
      compressedSize = sizeInfo['compressed']!;
    }
    
    final locationBatch = LocationBatch(
      locations: List.from(batch),
      createdAt: creationTime,
      batchId: batchId,
      isCompressed: shouldCompress,
      originalSize: originalSize,
      compressedSize: compressedSize,
    );
    
    // Update metrics
    _updateMetrics(locationBatch, batchAge);
    
    try {
      // Attempt to publish
      final results = await _realtimeService.batchPublishLocations(batch);
      final successCount = results.where((r) => r.success).length;
      
      if (successCount < batch.length) {
        // Some locations failed, add to offline queue
        final failedLocations = <EnhancedLocationData>[];
        for (int i = 0; i < results.length; i++) {
          if (!results[i].success) {
            failedLocations.add(batch[i]);
          }
        }
        
        if (failedLocations.isNotEmpty) {
          _addToOfflineQueue(failedLocations);
        }
      }
      
      dev.log('LocationDataBatcher: Batch $batchId published - ${successCount}/${batch.length} successful');
    } catch (e) {
      dev.log('LocationDataBatcher: Failed to publish batch $batchId: $e');
      // Add entire batch to offline queue
      _addToOfflineQueue(batch);
    }
  }

  /// Add locations to offline queue
  void _addToOfflineQueue(List<EnhancedLocationData> locations) {
    if (_offlineQueue.length >= _maxOfflineQueueSize) {
      // Remove oldest batch to make room
      _offlineQueue.removeAt(0);
      dev.log('LocationDataBatcher: Offline queue full, removed oldest batch');
    }
    
    final batchId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    final batch = LocationBatch(
      locations: List.from(locations),
      createdAt: DateTime.now(),
      batchId: batchId,
    );
    
    _offlineQueue.add(batch);
    dev.log('LocationDataBatcher: Added ${locations.length} locations to offline queue (${_offlineQueue.length} batches queued)');
  }

  /// Check if batch should be compressed
  bool _shouldCompressBatch(List<EnhancedLocationData> batch) {
    if (!_config.enableCompression) return false;
    
    // Estimate size
    final estimatedSize = _estimateBatchSize(batch)['original']!;
    return estimatedSize >= _config.compressionThreshold;
  }

  /// Estimate batch size (original and compressed)
  Map<String, int> _estimateBatchSize(List<EnhancedLocationData> batch) {
    try {
      // Convert to JSON
      final jsonData = batch.map((location) => location.toFirebaseJson()).toList();
      final jsonString = jsonEncode(jsonData);
      final originalBytes = utf8.encode(jsonString);
      final originalSize = originalBytes.length;
      
      // Compress
      final compressedBytes = gzip.encode(originalBytes);
      final compressedSize = compressedBytes.length;
      
      return {
        'original': originalSize,
        'compressed': compressedSize,
      };
    } catch (e) {
      dev.log('LocationDataBatcher: Error estimating batch size: $e');
      return {
        'original': batch.length * 200, // Rough estimate
        'compressed': batch.length * 150, // Rough estimate
      };
    }
  }

  /// Update metrics with batch information
  void _updateMetrics(LocationBatch batch, Duration batchAge) {
    _totalBatches++;
    _totalLocations += batch.locations.length;
    
    if (batch.isCompressed) {
      _compressedBatches++;
      _compressionRatios.add(batch.compressionRatio);
      _bytesOriginal += batch.originalSize;
      _bytesCompressed += batch.compressedSize;
    }
    
    _batchSizes.add(batch.locations.length.toDouble());
    _batchAges.add(batchAge);
    
    // Keep metrics history limited
    if (_batchSizes.length > 100) {
      _batchSizes.removeAt(0);
    }
    if (_compressionRatios.length > 100) {
      _compressionRatios.removeAt(0);
    }
    if (_batchAges.length > 100) {
      _batchAges.removeAt(0);
    }
  }

  /// Start flush timer
  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_config.flushInterval, (timer) {
      _flushExpiredBatches();
    });
  }

  /// Restart flush timer with new interval
  void _restartFlushTimer() {
    _startFlushTimer();
  }

  /// Flush expired batches
  void _flushExpiredBatches() async {
    final now = DateTime.now();
    final expiredBatches = <String>[];
    
    for (final entry in _batchCreationTimes.entries) {
      final age = now.difference(entry.value);
      if (age >= _config.maxBatchAge) {
        expiredBatches.add(entry.key);
      }
    }
    
    for (final batchKey in expiredBatches) {
      await _flushBatch(batchKey);
    }
  }

  /// Get current queue status
  Map<String, dynamic> getQueueStatus() {
    return {
      'pendingBatches': _pendingBatches.length,
      'pendingLocations': _pendingBatches.values.fold<int>(0, (sum, batch) => sum + batch.length),
      'offlineQueueSize': _offlineQueue.length,
      'offlineLocations': _offlineQueue.fold<int>(0, (sum, batch) => sum + batch.locations.length),
      'oldestBatchAge': _batchCreationTimes.values.isNotEmpty
          ? DateTime.now().difference(_batchCreationTimes.values.reduce((a, b) => a.isBefore(b) ? a : b)).inSeconds
          : 0,
    };
  }

  /// Dispose of the batcher
  void dispose() {
    dev.log('LocationDataBatcher: Disposing batcher');
    
    _flushTimer?.cancel();
    
    // Flush all pending batches
    flushAll();
    
    _pendingBatches.clear();
    _batchCreationTimes.clear();
    _offlineQueue.clear();
    _batchSizes.clear();
    _compressionRatios.clear();
    _batchAges.clear();
  }
}