// Enhanced Realtime Location Service for Driver App
// This service provides robust Firebase Realtime Database operations with improved reliability

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:driver/model/enhanced_location_data.dart';

/// Connection state for the realtime service
enum ConnectionState {
  connected,
  connecting,
  disconnected,
  error;

  String get value {
    switch (this) {
      case ConnectionState.connected:
        return 'connected';
      case ConnectionState.connecting:
        return 'connecting';
      case ConnectionState.disconnected:
        return 'disconnected';
      case ConnectionState.error:
        return 'error';
    }
  }
}

/// Result of a publish operation
class PublishResult {
  final bool success;
  final String? error;
  final Duration latency;
  final int retryCount;
  final DateTime timestamp;

  const PublishResult({
    required this.success,
    this.error,
    required this.latency,
    required this.retryCount,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'PublishResult(success: $success, latency: ${latency.inMilliseconds}ms, retries: $retryCount, error: $error)';
  }
}

/// Error information for location services
class LocationServiceError {
  final String code;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  const LocationServiceError({
    required this.code,
    required this.message,
    required this.timestamp,
    this.details = const {},
  });

  @override
  String toString() {
    return 'LocationServiceError(code: $code, message: $message, timestamp: $timestamp)';
  }
}

/// Enhanced Realtime Location Service with robust error handling and retry mechanisms
class EnhancedRealtimeLocationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // Connection state management
  final StreamController<ConnectionState> _connectionStateController = 
      StreamController<ConnectionState>.broadcast();
  final StreamController<LocationServiceError> _errorController = 
      StreamController<LocationServiceError>.broadcast();
  
  ConnectionState _currentState = ConnectionState.disconnected;
  Timer? _connectionTestTimer;
  Timer? _retryTimer;
  
  // Retry configuration
  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 1);
  static const Duration _maxRetryDelay = Duration(seconds: 30);
  static const Duration _connectionTestInterval = Duration(seconds: 30);
  
  // Failed operations queue
  final List<_QueuedOperation> _failedOperations = [];
  bool _isRetrying = false;
  
  // Metrics
  int _totalOperations = 0;
  int _successfulOperations = 0;
  int _failedOperationsCount = 0;
  final List<Duration> _latencyHistory = [];
  
  /// Stream of connection state changes
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  
  /// Stream of service errors
  Stream<LocationServiceError> get errors => _errorController.stream;
  
  /// Current connection state
  ConnectionState get currentState => _currentState;
  
  /// Service metrics
  Map<String, dynamic> get metrics => {
    'totalOperations': _totalOperations,
    'successfulOperations': _successfulOperations,
    'failedOperations': _failedOperationsCount,
    'successRate': _totalOperations > 0 ? (_successfulOperations / _totalOperations) * 100 : 0.0,
    'averageLatency': _latencyHistory.isNotEmpty 
        ? _latencyHistory.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / _latencyHistory.length
        : 0.0,
    'queuedOperations': _failedOperations.length,
  };

  /// Initialize the service and start connection monitoring
  Future<void> initialize() async {
    dev.log('EnhancedRealtimeLocationService: Initializing service');
    
    _updateConnectionState(ConnectionState.connecting);
    
    // Test initial connection
    final isConnected = await testConnection();
    _updateConnectionState(isConnected ? ConnectionState.connected : ConnectionState.error);
    
    // Start periodic connection testing
    _startConnectionMonitoring();
    
    dev.log('EnhancedRealtimeLocationService: Service initialized with state: ${_currentState.value}');
  }

  /// Test Firebase database connection
  Future<bool> testConnection() async {
    try {
      dev.log('EnhancedRealtimeLocationService: Testing database connection');
      
      final testRef = _database.ref('connection_test');
      final testData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'test': 'connection_check',
      };
      
      final stopwatch = Stopwatch()..start();
      
      // Test write operation
      await testRef.set(testData).timeout(Duration(seconds: 10));
      
      // Test read operation
      final snapshot = await testRef.get().timeout(Duration(seconds: 10));
      
      stopwatch.stop();
      
      // Clean up test data
      await testRef.remove().catchError((e) {
        dev.log('EnhancedRealtimeLocationService: Failed to clean up test data: $e');
      });
      
      final isValid = snapshot.exists && snapshot.value != null;
      
      if (isValid) {
        dev.log('EnhancedRealtimeLocationService: Connection test successful (${stopwatch.elapsedMilliseconds}ms)');
        _recordLatency(stopwatch.elapsed);
      } else {
        dev.log('EnhancedRealtimeLocationService: Connection test failed - invalid response');
      }
      
      return isValid;
    } catch (e) {
      dev.log('EnhancedRealtimeLocationService: Connection test failed: $e');
      _emitError('CONNECTION_TEST_FAILED', 'Failed to test database connection: $e');
      return false;
    }
  }

  /// Publish location data to Firebase
  Future<PublishResult> publishLocation(EnhancedLocationData data) async {
    final stopwatch = Stopwatch()..start();
    _totalOperations++;
    
    try {
      dev.log('EnhancedRealtimeLocationService: Publishing location data');
      
      if (!data.isValid) {
        throw Exception('Invalid location data provided');
      }
      
      final orderId = data.metadata['orderId'] as String?;
      final driverId = data.metadata['driverId'] as String?;
      
      if (orderId == null || driverId == null) {
        throw Exception('Missing orderId or driverId in metadata');
      }
      
      final ref = _database.ref('live_locations/$orderId/$driverId');
      final jsonData = data.toFirebaseJson();
      
      await ref.set(jsonData).timeout(Duration(seconds: 15));
      
      stopwatch.stop();
      _recordLatency(stopwatch.elapsed);
      _successfulOperations++;
      
      final result = PublishResult(
        success: true,
        latency: stopwatch.elapsed,
        retryCount: 0,
        timestamp: DateTime.now(),
      );
      
      dev.log('EnhancedRealtimeLocationService: Location published successfully (${stopwatch.elapsedMilliseconds}ms)');
      
      // Update connection state to connected if it wasn't already
      if (_currentState != ConnectionState.connected) {
        _updateConnectionState(ConnectionState.connected);
      }
      
      return result;
    } catch (e) {
      stopwatch.stop();
      _failedOperationsCount++;
      
      dev.log('EnhancedRealtimeLocationService: Failed to publish location: $e');
      
      final error = 'Failed to publish location: $e';
      _emitError('PUBLISH_FAILED', error, {'data': data.toString()});
      
      // Queue for retry
      _queueFailedOperation(_QueuedOperation(
        type: _OperationType.publish,
        data: data,
        timestamp: DateTime.now(),
      ));
      
      // Update connection state
      _updateConnectionState(ConnectionState.error);
      
      return PublishResult(
        success: false,
        error: error,
        latency: stopwatch.elapsed,
        retryCount: 0,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Batch publish multiple location updates
  Future<List<PublishResult>> batchPublishLocations(List<EnhancedLocationData> locations) async {
    dev.log('EnhancedRealtimeLocationService: Batch publishing ${locations.length} locations');
    
    final results = <PublishResult>[];
    
    // Group locations by order/driver for efficient batching
    final Map<String, List<EnhancedLocationData>> groupedLocations = {};
    
    for (final location in locations) {
      final orderId = location.metadata['orderId'] as String?;
      final driverId = location.metadata['driverId'] as String?;
      
      if (orderId != null && driverId != null) {
        final key = '$orderId/$driverId';
        groupedLocations.putIfAbsent(key, () => []).add(location);
      }
    }
    
    // Process each group
    for (final entry in groupedLocations.entries) {
      final locations = entry.value;
      
      if (locations.length == 1) {
        // Single location - use regular publish
        results.add(await publishLocation(locations.first));
      } else {
        // Multiple locations - use batch update
        try {
          final stopwatch = Stopwatch()..start();
          _totalOperations++;
          
          final updates = <String, dynamic>{};
          
          for (final location in locations) {
            final orderId = location.metadata['orderId'] as String;
            final driverId = location.metadata['driverId'] as String;
            final path = 'live_locations/$orderId/$driverId';
            updates[path] = location.toFirebaseJson();
          }
          
          await _database.ref().update(updates).timeout(Duration(seconds: 20));
          
          stopwatch.stop();
          _recordLatency(stopwatch.elapsed);
          _successfulOperations++;
          
          // Add success result for each location
          for (int i = 0; i < locations.length; i++) {
            results.add(PublishResult(
              success: true,
              latency: Duration(milliseconds: stopwatch.elapsedMilliseconds ~/ locations.length),
              retryCount: 0,
              timestamp: DateTime.now(),
            ));
          }
          
          dev.log('EnhancedRealtimeLocationService: Batch published ${locations.length} locations successfully');
          
        } catch (e) {
          _failedOperationsCount++;
          dev.log('EnhancedRealtimeLocationService: Batch publish failed: $e');
          
          // Add failure result for each location and queue for retry
          for (final location in locations) {
            results.add(PublishResult(
              success: false,
              error: 'Batch publish failed: $e',
              latency: Duration.zero,
              retryCount: 0,
              timestamp: DateTime.now(),
            ));
            
            _queueFailedOperation(_QueuedOperation(
              type: _OperationType.publish,
              data: location,
              timestamp: DateTime.now(),
            ));
          }
          
          _emitError('BATCH_PUBLISH_FAILED', 'Failed to batch publish locations: $e');
          _updateConnectionState(ConnectionState.error);
        }
      }
    }
    
    return results;
  }

  /// Retry failed operations
  Future<void> retryFailedOperations() async {
    if (_isRetrying || _failedOperations.isEmpty) return;
    
    _isRetrying = true;
    dev.log('EnhancedRealtimeLocationService: Retrying ${_failedOperations.length} failed operations');
    
    final operationsToRetry = List<_QueuedOperation>.from(_failedOperations);
    _failedOperations.clear();
    
    for (final operation in operationsToRetry) {
      try {
        switch (operation.type) {
          case _OperationType.publish:
            final result = await publishLocation(operation.data);
            if (!result.success) {
              // Re-queue if still failing
              _queueFailedOperation(operation.copyWith(
                retryCount: operation.retryCount + 1,
              ));
            }
            break;
        }
        
        // Small delay between retries to avoid overwhelming the service
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        dev.log('EnhancedRealtimeLocationService: Retry failed for operation: $e');
        _queueFailedOperation(operation.copyWith(
          retryCount: operation.retryCount + 1,
        ));
      }
    }
    
    _isRetrying = false;
    dev.log('EnhancedRealtimeLocationService: Retry completed. ${_failedOperations.length} operations still queued');
  }

  /// Clean up location data for a specific order
  Future<void> cleanupLocationData(String orderId) async {
    try {
      dev.log('EnhancedRealtimeLocationService: Cleaning up location data for order: $orderId');
      
      final ref = _database.ref('live_locations/$orderId');
      await ref.remove().timeout(Duration(seconds: 10));
      
      dev.log('EnhancedRealtimeLocationService: Location data cleaned up successfully');
    } catch (e) {
      dev.log('EnhancedRealtimeLocationService: Failed to cleanup location data: $e');
      _emitError('CLEANUP_FAILED', 'Failed to cleanup location data: $e', {'orderId': orderId});
    }
  }

  /// Start periodic connection monitoring
  void _startConnectionMonitoring() {
    _connectionTestTimer?.cancel();
    _connectionTestTimer = Timer.periodic(_connectionTestInterval, (timer) async {
      if (_currentState == ConnectionState.connected) {
        final isConnected = await testConnection();
        if (!isConnected) {
          _updateConnectionState(ConnectionState.error);
          _scheduleRetry();
        }
      } else if (_currentState == ConnectionState.error) {
        final isConnected = await testConnection();
        if (isConnected) {
          _updateConnectionState(ConnectionState.connected);
          // Retry failed operations when connection is restored
          retryFailedOperations();
        }
      }
    });
  }

  /// Schedule retry with exponential backoff
  void _scheduleRetry() {
    if (_retryTimer?.isActive == true) return;
    
    final retryDelay = _calculateRetryDelay(_failedOperations.length);
    dev.log('EnhancedRealtimeLocationService: Scheduling retry in ${retryDelay.inSeconds} seconds');
    
    _retryTimer = Timer(retryDelay, () {
      retryFailedOperations();
    });
  }

  /// Calculate retry delay with exponential backoff
  Duration _calculateRetryDelay(int attemptCount) {
    final delay = Duration(
      milliseconds: (_baseRetryDelay.inMilliseconds * pow(2, attemptCount)).round(),
    );
    return delay > _maxRetryDelay ? _maxRetryDelay : delay;
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(ConnectionState newState) {
    if (_currentState != newState) {
      dev.log('EnhancedRealtimeLocationService: Connection state changed: ${_currentState.value} -> ${newState.value}');
      _currentState = newState;
      _connectionStateController.add(newState);
    }
  }

  /// Emit error to listeners
  void _emitError(String code, String message, [Map<String, dynamic>? details]) {
    final error = LocationServiceError(
      code: code,
      message: message,
      timestamp: DateTime.now(),
      details: details ?? {},
    );
    _errorController.add(error);
  }

  /// Queue failed operation for retry
  void _queueFailedOperation(_QueuedOperation operation) {
    if (operation.retryCount >= _maxRetries) {
      dev.log('EnhancedRealtimeLocationService: Max retries exceeded for operation, discarding');
      return;
    }
    
    _failedOperations.add(operation);
    
    // Schedule retry if not already scheduled
    if (_retryTimer?.isActive != true) {
      _scheduleRetry();
    }
  }

  /// Record latency for metrics
  void _recordLatency(Duration latency) {
    _latencyHistory.add(latency);
    
    // Keep only recent latency measurements
    if (_latencyHistory.length > 100) {
      _latencyHistory.removeAt(0);
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    dev.log('EnhancedRealtimeLocationService: Disposing service');
    
    _connectionTestTimer?.cancel();
    _retryTimer?.cancel();
    _connectionStateController.close();
    _errorController.close();
    _failedOperations.clear();
    _latencyHistory.clear();
  }
}

/// Internal class for queued operations
enum _OperationType { publish }

class _QueuedOperation {
  final _OperationType type;
  final EnhancedLocationData data;
  final DateTime timestamp;
  final int retryCount;

  const _QueuedOperation({
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });

  _QueuedOperation copyWith({
    _OperationType? type,
    EnhancedLocationData? data,
    DateTime? timestamp,
    int? retryCount,
  }) {
    return _QueuedOperation(
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}