// lib/services/polyline_manager.dart

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rxdart/rxdart.dart';
import '../model/polyline_models.dart';

/// Smart polyline manager that handles intelligent updates and cleanup
class PolylineManager {
  // Private state
  PolylineState _currentState = PolylineState(
    metrics: PolylineMetrics(lastUpdate: DateTime.now()),
  );
  
  // Reactive streams
  final BehaviorSubject<PolylineState> _stateController = BehaviorSubject<PolylineState>();
  final BehaviorSubject<Set<Polyline>> _polylinesController = BehaviorSubject<Set<Polyline>>();
  
  // Cache for route points
  final Map<String, List<LatLng>> _routeCache = {};
  
  // Memory monitoring
  static const int _maxActivePolylines = 20;
  
  // Cleanup timer
  Timer? _cleanupTimer;
  
  // Batch operations and debouncing
  Timer? _batchUpdateTimer;
  final List<PolylineOperation> _pendingOperations = [];
  static const Duration _batchDelay = Duration(milliseconds: 100);
  
  /// Stream of polyline state changes
  Stream<PolylineState> get stateStream => _stateController.stream;
  
  /// Stream of Google Maps polylines for rendering
  Stream<Set<Polyline>> get polylinesStream => _polylinesController.stream;
  
  /// Current polyline state
  PolylineState get currentState => _currentState;
  
  /// Current Google Maps polylines
  Set<Polyline> get currentPolylines => _currentState.toGoogleMapsPolylines();

  PolylineManager() {
    _initializeCleanupTimer();
    _publishInitialState();
  }

  /// Initialize automatic cleanup timer
  void _initializeCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _performAutomaticCleanup();
    });
  }

  /// Publish initial state
  void _publishInitialState() {
    _stateController.add(_currentState);
    _polylinesController.add(currentPolylines);
  }

  /// Update or create a route with intelligent diffing and optional batching
  Future<void> updateRoute({
    required String routeId,
    required List<LatLng> points,
    PolylineStyle? style,
    Map<String, dynamic>? metadata,
    bool batch = false,
  }) async {
    if (batch) {
      // Add to batch queue
      _addToBatch(PolylineOperation.update(routeId, points, style: style, metadata: metadata));
      return;
    }
    
    await _updateRouteImmediate(routeId, points, style, metadata);
  }

  /// Immediate route update (non-batched)
  Future<void> _updateRouteImmediate(
    String routeId,
    List<LatLng> points,
    PolylineStyle? style,
    Map<String, dynamic>? metadata,
  ) async {
    if (points.isEmpty) {
      dev.log('PolylineManager: Skipping empty route update for $routeId');
      return;
    }

    try {
      // Check if route actually changed using intelligent diffing
      if (_hasRouteChanged(routeId, points)) {
        final polylineStyle = style ?? RoutePhase.toPickup.defaultStyle;
        
        // Apply point simplification for performance
        final simplifiedPoints = simplifyPoints(points, tolerance: 0.00005);
        
        // Create new polyline info
        final polylineInfo = PolylineInfo(
          id: routeId,
          points: simplifiedPoints, // Use simplified points
          style: polylineStyle,
          status: PolylineStatus.active,
          lastUpdated: DateTime.now(),
          metadata: {
            ...metadata ?? {},
            'originalPointCount': points.length,
            'simplifiedPointCount': simplifiedPoints.length,
            'compressionRatio': points.length > 0 ? (simplifiedPoints.length / points.length) : 1.0,
          },
        );

        // Update state
        final updatedPolylines = Map<String, PolylineInfo>.from(_currentState.activePolylines);
        updatedPolylines[routeId] = polylineInfo;
        
        // Cache the route points
        _routeCache[routeId] = List.from(points);
        
        // Update metrics
        final updatedMetrics = _currentState.metrics.copyWith(
          totalPolylines: updatedPolylines.length,
          activePolylines: updatedPolylines.values.where((p) => p.status == PolylineStatus.active).length,
          totalUpdates: _currentState.metrics.totalUpdates + 1,
          lastUpdate: DateTime.now(),
        );

        // Create new state
        _currentState = _currentState.copyWith(
          activePolylines: updatedPolylines,
          primaryRouteId: routeId,
          metrics: updatedMetrics,
        );

        // Publish updates
        _stateController.add(_currentState);
        _polylinesController.add(currentPolylines);
        
        dev.log('PolylineManager: Updated route $routeId with ${points.length} points');
      } else {
        dev.log('PolylineManager: Route $routeId unchanged, skipping update');
      }
    } catch (e) {
      dev.log('PolylineManager: Error updating route $routeId: $e');
      _addError('Failed to update route $routeId: $e');
    }
  }

  /// Check if route has actually changed using intelligent diffing
  bool _hasRouteChanged(String routeId, List<LatLng> newPoints) {
    final cachedPoints = _routeCache[routeId];
    if (cachedPoints == null) return true;
    
    if (cachedPoints.length != newPoints.length) return true;
    
    // Check if points are significantly different (tolerance for GPS noise)
    const double tolerance = 0.00001; // ~1 meter
    for (int i = 0; i < cachedPoints.length; i++) {
      final cached = cachedPoints[i];
      final newPoint = newPoints[i];
      
      if ((cached.latitude - newPoint.latitude).abs() > tolerance ||
          (cached.longitude - newPoint.longitude).abs() > tolerance) {
        return true;
      }
    }
    
    return false;
  }

  /// Add operation to batch queue
  void _addToBatch(PolylineOperation operation) {
    _pendingOperations.add(operation);
    
    // Reset the batch timer
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(_batchDelay, () {
      _processBatchedOperations();
    });
  }

  /// Process all batched operations
  Future<void> _processBatchedOperations() async {
    if (_pendingOperations.isEmpty) return;
    
    final operations = List<PolylineOperation>.from(_pendingOperations);
    _pendingOperations.clear();
    
    dev.log('PolylineManager: Processing ${operations.length} batched operations');
    
    for (final operation in operations) {
      switch (operation.type) {
        case PolylineOperationType.create:
        case PolylineOperationType.update:
          if (operation.routeId != null && operation.points != null) {
            await _updateRouteImmediate(
              operation.routeId!,
              operation.points!,
              operation.style,
              operation.metadata,
            );
          }
          break;
        case PolylineOperationType.remove:
          if (operation.routeId != null) {
            await removeRoute(operation.routeId!);
          }
          break;
        case PolylineOperationType.clear:
          await clearAllRoutes();
          break;
      }
    }
  }

  /// Remove a specific route
  Future<void> removeRoute(String routeId, {bool batch = false}) async {
    if (batch) {
      _addToBatch(PolylineOperation.remove(routeId));
      return;
    }
    try {
      if (_currentState.hasPolyline(routeId)) {
        final updatedPolylines = Map<String, PolylineInfo>.from(_currentState.activePolylines);
        updatedPolylines.remove(routeId);
        _routeCache.remove(routeId);
        
        // Update metrics
        final updatedMetrics = _currentState.metrics.copyWith(
          totalPolylines: updatedPolylines.length,
          activePolylines: updatedPolylines.values.where((p) => p.status == PolylineStatus.active).length,
          lastUpdate: DateTime.now(),
        );

        // Create new state
        _currentState = _currentState.copyWith(
          activePolylines: updatedPolylines,
          primaryRouteId: _currentState.primaryRouteId == routeId ? null : _currentState.primaryRouteId,
          metrics: updatedMetrics,
        );

        // Publish updates
        _stateController.add(_currentState);
        _polylinesController.add(currentPolylines);
        
        dev.log('PolylineManager: Removed route $routeId');
      }
    } catch (e) {
      dev.log('PolylineManager: Error removing route $routeId: $e');
      _addError('Failed to remove route $routeId: $e');
    }
  }

  /// Clear all routes (smart cleanup, not brute force)
  Future<void> clearAllRoutes() async {
    try {
      if (_currentState.activePolylines.isNotEmpty) {
        _routeCache.clear();
        
        // Update metrics
        final updatedMetrics = _currentState.metrics.copyWith(
          totalPolylines: 0,
          activePolylines: 0,
          lastUpdate: DateTime.now(),
        );

        // Create new state
        _currentState = _currentState.copyWith(
          activePolylines: {},
          primaryRouteId: null,
          metrics: updatedMetrics,
        );

        // Publish updates
        _stateController.add(_currentState);
        _polylinesController.add(currentPolylines);
        
        dev.log('PolylineManager: Cleared all routes');
      }
    } catch (e) {
      dev.log('PolylineManager: Error clearing routes: $e');
      _addError('Failed to clear routes: $e');
    }
  }

  /// Switch route phase with proper cleanup
  Future<void> switchRoutePhase(RoutePhase newPhase) async {
    try {
      if (_currentState.currentPhase != newPhase) {
        // Clear old phase-specific routes
        await _clearPhaseSpecificRoutes(_currentState.currentPhase);
        
        // Update state with new phase
        _currentState = _currentState.copyWith(
          currentPhase: newPhase,
        );

        // Publish updates
        _stateController.add(_currentState);
        _polylinesController.add(currentPolylines);
        
        dev.log('PolylineManager: Switched to phase $newPhase');
      }
    } catch (e) {
      dev.log('PolylineManager: Error switching phase: $e');
      _addError('Failed to switch phase: $e');
    }
  }

  /// Clear routes specific to a phase
  Future<void> _clearPhaseSpecificRoutes(RoutePhase phase) async {
    final routesToRemove = <String>[];
    
    for (final entry in _currentState.activePolylines.entries) {
      if (entry.key.contains(phase.routeId)) {
        routesToRemove.add(entry.key);
      }
    }
    
    for (final routeId in routesToRemove) {
      await removeRoute(routeId);
    }
  }

  /// Batch update multiple polylines efficiently
  Future<void> batchUpdate(List<PolylineOperation> operations) async {
    try {
      for (final operation in operations) {
        switch (operation.type) {
          case PolylineOperationType.create:
          case PolylineOperationType.update:
            if (operation.routeId != null && operation.points != null) {
              await updateRoute(
                routeId: operation.routeId!,
                points: operation.points!,
                style: operation.style,
                metadata: operation.metadata,
              );
            }
            break;
          case PolylineOperationType.remove:
            if (operation.routeId != null) {
              await removeRoute(operation.routeId!);
            }
            break;
          case PolylineOperationType.clear:
            await clearAllRoutes();
            break;
        }
      }
      
      dev.log('PolylineManager: Completed batch update with ${operations.length} operations');
    } catch (e) {
      dev.log('PolylineManager: Error in batch update: $e');
      _addError('Batch update failed: $e');
    }
  }

  /// Perform automatic cleanup based on memory pressure and age
  void _performAutomaticCleanup() {
    try {
      final now = DateTime.now();
      final staleRoutes = <String>[];
      
      // Find stale routes (older than 10 minutes)
      for (final entry in _currentState.activePolylines.entries) {
        final age = now.difference(entry.value.lastUpdated);
        if (age.inMinutes > 10 && entry.value.status != PolylineStatus.active) {
          staleRoutes.add(entry.key);
        }
      }
      
      // Remove stale routes
      for (final routeId in staleRoutes) {
        removeRoute(routeId);
      }
      
      // Check memory pressure
      if (_currentState.activePolylines.length > _maxActivePolylines) {
        _performMemoryPressureCleanup();
      }
      
      if (staleRoutes.isNotEmpty) {
        dev.log('PolylineManager: Cleaned up ${staleRoutes.length} stale routes');
      }
    } catch (e) {
      dev.log('PolylineManager: Error in automatic cleanup: $e');
    }
  }

  /// Perform cleanup under memory pressure
  void _performMemoryPressureCleanup() {
    try {
      // Sort by last updated (oldest first)
      final sortedRoutes = _currentState.activePolylines.entries.toList()
        ..sort((a, b) => a.value.lastUpdated.compareTo(b.value.lastUpdated));
      
      // Remove oldest routes until we're under the limit
      final routesToRemove = sortedRoutes.length - _maxActivePolylines;
      for (int i = 0; i < routesToRemove && i < sortedRoutes.length; i++) {
        removeRoute(sortedRoutes[i].key);
      }
      
      dev.log('PolylineManager: Memory pressure cleanup removed $routesToRemove routes');
    } catch (e) {
      dev.log('PolylineManager: Error in memory pressure cleanup: $e');
    }
  }

  /// Add error to state
  void _addError(String error) {
    final updatedErrors = List<String>.from(_currentState.errors)..add(error);
    _currentState = _currentState.copyWith(errors: updatedErrors);
    _stateController.add(_currentState);
  }

  /// Get performance metrics
  PolylineMetrics getMetrics() {
    return _currentState.metrics;
  }

  /// Check if manager is healthy
  bool get isHealthy {
    return _currentState.errors.isEmpty && 
           _currentState.activePolylines.length <= _maxActivePolylines;
  }

  /// Simplify polyline points using Douglas-Peucker algorithm
  List<LatLng> simplifyPoints(List<LatLng> points, {double tolerance = 0.0001}) {
    if (points.length <= 2) return points;
    
    return _douglasPeucker(points, tolerance);
  }

  /// Douglas-Peucker line simplification algorithm
  List<LatLng> _douglasPeucker(List<LatLng> points, double tolerance) {
    if (points.length <= 2) return points;
    
    // Find the point with maximum distance from the line between first and last
    double maxDistance = 0.0;
    int maxIndex = 0;
    
    final LatLng start = points.first;
    final LatLng end = points.last;
    
    for (int i = 1; i < points.length - 1; i++) {
      final double distance = _perpendicularDistance(points[i], start, end);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }
    
    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > tolerance) {
      // Recursive call on both segments
      final List<LatLng> leftSegment = _douglasPeucker(
        points.sublist(0, maxIndex + 1), 
        tolerance
      );
      final List<LatLng> rightSegment = _douglasPeucker(
        points.sublist(maxIndex), 
        tolerance
      );
      
      // Combine results (remove duplicate point at junction)
      return [...leftSegment.sublist(0, leftSegment.length - 1), ...rightSegment];
    } else {
      // All points between start and end can be removed
      return [start, end];
    }
  }

  /// Calculate perpendicular distance from point to line segment
  double _perpendicularDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final double A = point.latitude - lineStart.latitude;
    final double B = point.longitude - lineStart.longitude;
    final double C = lineEnd.latitude - lineStart.latitude;
    final double D = lineEnd.longitude - lineStart.longitude;
    
    final double dot = A * C + B * D;
    final double lenSq = C * C + D * D;
    
    if (lenSq == 0) {
      // Line start and end are the same point
      return sqrt(A * A + B * B);
    }
    
    final double param = dot / lenSq;
    
    double xx, yy;
    if (param < 0) {
      xx = lineStart.latitude;
      yy = lineStart.longitude;
    } else if (param > 1) {
      xx = lineEnd.latitude;
      yy = lineEnd.longitude;
    } else {
      xx = lineStart.latitude + param * C;
      yy = lineStart.longitude + param * D;
    }
    
    final double dx = point.latitude - xx;
    final double dy = point.longitude - yy;
    
    return sqrt(dx * dx + dy * dy);
  }

  /// Get simplified points based on zoom level
  List<LatLng> getSimplifiedPoints(List<LatLng> points, double zoomLevel) {
    // Adjust tolerance based on zoom level
    // Higher zoom = more detail needed = lower tolerance
    // Lower zoom = less detail needed = higher tolerance
    double tolerance;
    
    if (zoomLevel >= 16) {
      tolerance = 0.00001; // High detail for close zoom
    } else if (zoomLevel >= 14) {
      tolerance = 0.00005; // Medium detail
    } else if (zoomLevel >= 12) {
      tolerance = 0.0001; // Lower detail
    } else {
      tolerance = 0.0005; // Very low detail for far zoom
    }
    
    return simplifyPoints(points, tolerance: tolerance);
  }

  /// Force process any pending batched operations
  Future<void> flushBatchedOperations() async {
    _batchUpdateTimer?.cancel();
    await _processBatchedOperations();
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'activePolylines': _currentState.activePolylines.length,
      'cacheSize': _routeCache.length,
      'pendingBatchOperations': _pendingOperations.length,
      'memoryUsage': _currentState.metrics.memoryUsageBytes,
      'totalUpdates': _currentState.metrics.totalUpdates,
      'isHealthy': isHealthy,
    };
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _batchUpdateTimer?.cancel();
    _stateController.close();
    _polylinesController.close();
    _routeCache.clear();
    _pendingOperations.clear();
    dev.log('PolylineManager: Disposed');
  }
}