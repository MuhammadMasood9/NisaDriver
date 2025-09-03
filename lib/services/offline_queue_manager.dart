// Offline Queue Manager for Driver App
// This service manages queuing of location updates when offline and processes them when connection is restored

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/model/enhanced_location_data.dart';
import 'package:driver/services/enhanced_realtime_location_service.dart';
import 'package:driver/utils/data_compression_utils.dart';

/// Configuration for offline queue behavior
class OfflineQueueConfig {
  final int maxQueueSize;
  final Duration maxItemAge;
  final bool enablePersistence;
  final bool enableCompression;
  final int compressionThreshold;
  final Duration retryInterval;
  final int maxRetryAttempts;

  const OfflineQueueConfig({
    this.maxQueueSize = 1000,
    this.maxItemAge = const Duration(hours: 24),
    this.enablePersistence = true,
    this.enableCompression = true,
    this.compressionThreshold = 1024,
    this.retryInterval = const Duration(seconds: 30),
    this.maxRetryAttempts = 5,
  });
}

/// Queued location item with metadata
class QueuedLocationItem {
  final EnhancedLocationData location;
  final DateTime queuedAt;
  final int retryCount;
  final String itemId;
  final bool isCompressed;
  final CompressionAlgorithm compressionAlgorithm;

  const QueuedLocationItem({
    required this.location,
    required this.queuedAt,
    required this.itemId,
    this.retryCount = 0,
    this.isCompressed = false,
    this.compressionAlgorithm = CompressionAlgorithm.none,
  });

  /// Age of the queued item
  Duration get age => DateTime.now().difference(queuedAt);

  /// Whether the item has expired
  bool isExpired(Duration maxAge) => age > maxAge;

  /// Whether the item has exceeded max retry attempts
  bool hasExceededRetries(int maxRetries) => retryCount >= maxRetries;

  /// Create a copy with incremented retry count
  QueuedLocationItem withIncrementedRetry() {
    return QueuedLocationItem(
      location: location,
      queuedAt: queuedAt,
      itemId: itemId,
      retryCount: retryCount + 1,
      isCompressed: isCompressed,
      compressionAlgorithm: compressionAlgorithm,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'location': location.toFirebaseJson(),
      'queuedAt': queuedAt.millisecondsSinceEpoch,
      'retryCount': retryCount,
      'itemId': itemId,
      'isCompressed': isCompressed,
      'compressionAlgorithm': compressionAlgorithm.value,
    };
  }

  /// Create from JSON
  static QueuedLocationItem fromJson(Map<String, dynamic> json) {
    return QueuedLocationItem(
      location: EnhancedLocationData.fromFirebaseJson(
        Map<String, dynamic>.from(json['location'] as Map),
      ),
      queuedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['queuedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      itemId: json['itemId'] as String? ?? '',
      isCompressed: json['isCompressed'] as bool? ?? false,
      compressionAlgorithm: CompressionAlgorithm.values.firstWhere(
        (a) => a.value == json['compressionAlgorithm'],
        orElse: () => CompressionAlgorithm.none,
      ),
    );
  }

  @override
  String toString() {
    return 'QueuedLocationItem(id: $itemId, age: ${age.inMinutes}min, retries: $retryCount, compressed: $isCompressed)';
  }
}

/// Metrics for offline queue operations
class OfflineQueueMetrics {
  final int totalQueued;
  final int totalProcessed;
  final int totalFailed;
  final int currentQueueSize;
  final int expiredItems;
  final int compressedItems;
  final double averageProcessingTime;
  final double successRate;
  final int bytesStored;
  final int bytesSaved;

  const OfflineQueueMetrics({
    required this.totalQueued,
    required this.totalProcessed,
    required this.totalFailed,
    required this.currentQueueSize,
    required this.expiredItems,
    required this.compressedItems,
    required this.averageProcessingTime,
    required this.successRate,
    required this.bytesStored,
    required this.bytesSaved,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalQueued': totalQueued,
      'totalProcessed': totalProcessed,
      'totalFailed': totalFailed,
      'currentQueueSize': currentQueueSize,
      'expiredItems': expiredItems,
      'compressedItems': compressedItems,
      'averageProcessingTime': averageProcessingTime,
      'successRate': successRate,
      'bytesStored': bytesStored,
      'bytesSaved': bytesSaved,
    };
  }
}

/// Service for managing offline location data queue
class OfflineQueueManager {
  final EnhancedRealtimeLocationService _realtimeService;
  final OfflineQueueConfig _config;
  
  // Queue state
  final List<QueuedLocationItem> _queue = [];
  Timer? _processingTimer;
  bool _isProcessing = false;
  
  // Persistence
  static const String _queueKey = 'offline_location_queue';
  SharedPreferences? _prefs;
  
  // Metrics
  int _totalQueued = 0;
  int _totalProcessed = 0;
  int _totalFailed = 0;
  int _expiredItems = 0;
  int _compressedItems = 0;
  int _bytesStored = 0;
  int _bytesSaved = 0;
  final List<Duration> _processingTimes = [];

  OfflineQueueManager(this._realtimeService, [OfflineQueueConfig? config])
      : _config = config ?? OfflineQueueConfig() {
    _initialize();
  }

  /// Current queue configuration
  OfflineQueueConfig get config => _config;

  /// Current queue size
  int get queueSize => _queue.length;

  /// Whether the queue is empty
  bool get isEmpty => _queue.isEmpty;

  /// Whether the queue is full
  bool get isFull => _queue.length >= _config.maxQueueSize;

  /// Initialize the offline queue manager
  Future<void> _initialize() async {
    dev.log('OfflineQueueManager: Initializing offline queue manager');
    
    if (_config.enablePersistence) {
      await _loadPersistedQueue();
    }
    
    _startProcessingTimer();
    
    dev.log('OfflineQueueManager: Initialized with ${_queue.length} persisted items');
  }

  /// Add location to offline queue
  Future<bool> enqueue(EnhancedLocationData location) async {
    if (!location.isValid) {
      dev.log('OfflineQueueManager: Skipping invalid location data');
      return false;
    }

    // Check if queue is full
    if (isFull) {
      // Remove oldest item to make room
      final removed = _queue.removeAt(0);
      dev.log('OfflineQueueManager: Queue full, removed oldest item: ${removed.itemId}');
    }

    // Create queued item
    final itemId = '${location.sequenceNumber}_${DateTime.now().millisecondsSinceEpoch}';
    bool isCompressed = false;
    CompressionAlgorithm compressionAlgorithm = CompressionAlgorithm.none;

    // Compress if enabled and beneficial
    if (_config.enableCompression) {
      final jsonString = jsonEncode(location.toFirebaseJson());
      final data = utf8.encode(jsonString);
      
      if (data.length >= _config.compressionThreshold) {
        final compressionResult = DataCompressionUtils.compress(data);
        if (compressionResult.success && compressionResult.compressionRatio < 0.8) {
          isCompressed = true;
          compressionAlgorithm = compressionResult.algorithm;
          _compressedItems++;
          _bytesSaved += compressionResult.bytesSaved;
        }
      }
      
      _bytesStored += data.length;
    }

    final queuedItem = QueuedLocationItem(
      location: location,
      queuedAt: DateTime.now(),
      itemId: itemId,
      isCompressed: isCompressed,
      compressionAlgorithm: compressionAlgorithm,
    );

    _queue.add(queuedItem);
    _totalQueued++;

    dev.log('OfflineQueueManager: Queued location $itemId (${_queue.length}/${_config.maxQueueSize})');

    // Persist if enabled
    if (_config.enablePersistence) {
      await _persistQueue();
    }

    return true;
  }

  /// Process the offline queue
  Future<void> processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    dev.log('OfflineQueueManager: Processing offline queue (${_queue.length} items)');

    final stopwatch = Stopwatch()..start();
    final itemsToProcess = List<QueuedLocationItem>.from(_queue);
    final processedItems = <QueuedLocationItem>[];
    final failedItems = <QueuedLocationItem>[];

    for (final item in itemsToProcess) {
      try {
        // Check if item has expired
        if (item.isExpired(_config.maxItemAge)) {
          dev.log('OfflineQueueManager: Item ${item.itemId} expired, removing');
          _expiredItems++;
          processedItems.add(item);
          continue;
        }

        // Check if item has exceeded retry attempts
        if (item.hasExceededRetries(_config.maxRetryAttempts)) {
          dev.log('OfflineQueueManager: Item ${item.itemId} exceeded max retries, removing');
          _totalFailed++;
          processedItems.add(item);
          continue;
        }

        // Attempt to publish location
        final result = await _realtimeService.publishLocation(item.location);
        
        if (result.success) {
          dev.log('OfflineQueueManager: Successfully published item ${item.itemId}');
          _totalProcessed++;
          processedItems.add(item);
        } else {
          dev.log('OfflineQueueManager: Failed to publish item ${item.itemId}: ${result.error}');
          failedItems.add(item.withIncrementedRetry());
        }

        // Small delay between items to avoid overwhelming the service
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        dev.log('OfflineQueueManager: Error processing item ${item.itemId}: $e');
        failedItems.add(item.withIncrementedRetry());
      }
    }

    // Update queue - remove processed items and update failed items
    for (final item in processedItems) {
      _queue.remove(item);
    }

    // Update failed items with incremented retry count
    for (final failedItem in failedItems) {
      final index = _queue.indexWhere((item) => item.itemId == failedItem.itemId);
      if (index >= 0) {
        _queue[index] = failedItem;
      }
    }

    stopwatch.stop();
    _processingTimes.add(stopwatch.elapsed);

    // Keep processing times history limited
    if (_processingTimes.length > 50) {
      _processingTimes.removeAt(0);
    }

    dev.log('OfflineQueueManager: Processing completed - ${processedItems.length} processed, ${failedItems.length} failed, ${_queue.length} remaining');

    // Persist updated queue
    if (_config.enablePersistence) {
      await _persistQueue();
    }

    _isProcessing = false;
  }

  /// Clear expired items from queue
  Future<void> clearExpiredItems() async {
    final initialSize = _queue.length;
    _queue.removeWhere((item) {
      if (item.isExpired(_config.maxItemAge)) {
        _expiredItems++;
        return true;
      }
      return false;
    });

    final removedCount = initialSize - _queue.length;
    if (removedCount > 0) {
      dev.log('OfflineQueueManager: Removed $removedCount expired items');
      
      if (_config.enablePersistence) {
        await _persistQueue();
      }
    }
  }

  /// Clear all items from queue
  Future<void> clearQueue() async {
    final clearedCount = _queue.length;
    _queue.clear();
    
    if (_config.enablePersistence) {
      await _persistQueue();
    }
    
    dev.log('OfflineQueueManager: Cleared $clearedCount items from queue');
  }

  /// Get current queue metrics
  OfflineQueueMetrics getMetrics() {
    final averageProcessingTime = _processingTimes.isNotEmpty
        ? _processingTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / _processingTimes.length
        : 0.0;

    final successRate = _totalQueued > 0 ? (_totalProcessed / _totalQueued) * 100 : 0.0;

    return OfflineQueueMetrics(
      totalQueued: _totalQueued,
      totalProcessed: _totalProcessed,
      totalFailed: _totalFailed,
      currentQueueSize: _queue.length,
      expiredItems: _expiredItems,
      compressedItems: _compressedItems,
      averageProcessingTime: averageProcessingTime,
      successRate: successRate,
      bytesStored: _bytesStored,
      bytesSaved: _bytesSaved,
    );
  }

  /// Get queue status information
  Map<String, dynamic> getQueueStatus() {
    final oldestItem = _queue.isNotEmpty 
        ? _queue.reduce((a, b) => a.queuedAt.isBefore(b.queuedAt) ? a : b)
        : null;

    return {
      'queueSize': _queue.length,
      'maxQueueSize': _config.maxQueueSize,
      'isProcessing': _isProcessing,
      'oldestItemAge': oldestItem?.age.inMinutes ?? 0,
      'retryItems': _queue.where((item) => item.retryCount > 0).length,
      'compressedItems': _queue.where((item) => item.isCompressed).length,
    };
  }

  /// Load persisted queue from SharedPreferences
  Future<void> _loadPersistedQueue() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final queueJson = _prefs!.getString(_queueKey);
      
      if (queueJson != null) {
        final queueData = jsonDecode(queueJson) as List<dynamic>;
        
        for (final itemData in queueData) {
          try {
            final item = QueuedLocationItem.fromJson(
              Map<String, dynamic>.from(itemData as Map),
            );
            _queue.add(item);
          } catch (e) {
            dev.log('OfflineQueueManager: Failed to deserialize queue item: $e');
          }
        }
        
        dev.log('OfflineQueueManager: Loaded ${_queue.length} items from persistence');
      }
    } catch (e) {
      dev.log('OfflineQueueManager: Failed to load persisted queue: $e');
    }
  }

  /// Persist queue to SharedPreferences
  Future<void> _persistQueue() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      
      final queueData = _queue.map((item) => item.toJson()).toList();
      final queueJson = jsonEncode(queueData);
      
      await _prefs!.setString(_queueKey, queueJson);
    } catch (e) {
      dev.log('OfflineQueueManager: Failed to persist queue: $e');
    }
  }

  /// Start processing timer
  void _startProcessingTimer() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(_config.retryInterval, (timer) {
      processQueue();
      clearExpiredItems();
    });
  }

  /// Dispose of the offline queue manager
  Future<void> dispose() async {
    dev.log('OfflineQueueManager: Disposing offline queue manager');
    
    _processingTimer?.cancel();
    
    // Process remaining items one last time
    if (_queue.isNotEmpty) {
      await processQueue();
    }
    
    // Persist final state
    if (_config.enablePersistence) {
      await _persistQueue();
    }
    
    _queue.clear();
    _processingTimes.clear();
  }
}