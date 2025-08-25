// lib/model/polyline_models.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents the current phase of a route
enum RoutePhase {
  toPickup,
  toDestination,
  completed,
  cancelled,
  offRoute
}

extension RoutePhaseExtension on RoutePhase {
  String get routeId {
    switch (this) {
      case RoutePhase.toPickup:
        return 'pickup_route';
      case RoutePhase.toDestination:
        return 'destination_route';
      case RoutePhase.completed:
        return 'completed_route';
      case RoutePhase.cancelled:
        return 'cancelled_route';
      case RoutePhase.offRoute:
        return 'off_route';
    }
  }
  
  PolylineStyle get defaultStyle {
    switch (this) {
      case RoutePhase.toPickup:
        return PolylineStyle.pickup();
      case RoutePhase.toDestination:
        return PolylineStyle.destination();
      case RoutePhase.offRoute:
        return PolylineStyle.offRoute();
      case RoutePhase.completed:
        return PolylineStyle.completed();
      default:
        return PolylineStyle();
    }
  }
}

/// Status of a polyline
enum PolylineStatus {
  active,
  updating,
  animating,
  stale,
  error
}

/// Polyline styling configuration
class PolylineStyle {
  final Color color;
  final double width;
  final List<PatternItem> patterns;
  final Cap startCap;
  final Cap endCap;
  final JointType jointType;
  final bool geodesic;
  final double opacity;

  const PolylineStyle({
    this.color = Colors.blue,
    this.width = 4.0,
    this.patterns = const [],
    this.startCap = Cap.roundCap,
    this.endCap = Cap.roundCap,
    this.jointType = JointType.round,
    this.geodesic = true,
    this.opacity = 1.0,
  });

  // Predefined styles for different route types
  factory PolylineStyle.pickup() => const PolylineStyle(
    color: Color(0xFF2196F3), // Primary blue
    width: 4.0,
    geodesic: true,
  );

  factory PolylineStyle.destination() => const PolylineStyle(
    color: Colors.black,
    width: 4.0,
    geodesic: true,
  );

  factory PolylineStyle.offRoute() => PolylineStyle(
    color: Colors.orange,
    width: 4.0,
    patterns: [
      PatternItem.dash(10),
      PatternItem.gap(5),
    ],
    geodesic: true,
  );

  factory PolylineStyle.completed() => const PolylineStyle(
    color: Colors.grey,
    width: 2.0,
    opacity: 0.6,
    geodesic: true,
  );

  factory PolylineStyle.alternative() => PolylineStyle(
    color: Colors.blue.withValues(alpha: 0.6),
    width: 3.0,
    patterns: [
      PatternItem.dot,
      PatternItem.gap(5),
    ],
    geodesic: true,
  );

  /// Create a copy with modified properties
  PolylineStyle copyWith({
    Color? color,
    double? width,
    List<PatternItem>? patterns,
    Cap? startCap,
    Cap? endCap,
    JointType? jointType,
    bool? geodesic,
    double? opacity,
  }) {
    return PolylineStyle(
      color: color ?? this.color,
      width: width ?? this.width,
      patterns: patterns ?? this.patterns,
      startCap: startCap ?? this.startCap,
      endCap: endCap ?? this.endCap,
      jointType: jointType ?? this.jointType,
      geodesic: geodesic ?? this.geodesic,
      opacity: opacity ?? this.opacity,
    );
  }

  /// Convert to Google Maps Polyline
  Polyline toPolyline(String id, List<LatLng> points) {
    return Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color.withValues(alpha: opacity),
      width: width.toInt(),
      patterns: patterns,
      startCap: startCap,
      endCap: endCap,
      jointType: jointType,
      geodesic: geodesic,
    );
  }
}

/// Information about a polyline
class PolylineInfo {
  final String id;
  final List<LatLng> points;
  final PolylineStyle style;
  final PolylineStatus status;
  final DateTime lastUpdated;
  final Map<String, dynamic> metadata;

  const PolylineInfo({
    required this.id,
    required this.points,
    required this.style,
    this.status = PolylineStatus.active,
    required this.lastUpdated,
    this.metadata = const {},
  });

  PolylineInfo copyWith({
    String? id,
    List<LatLng>? points,
    PolylineStyle? style,
    PolylineStatus? status,
    DateTime? lastUpdated,
    Map<String, dynamic>? metadata,
  }) {
    return PolylineInfo(
      id: id ?? this.id,
      points: points ?? this.points,
      style: style ?? this.style,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to Google Maps Polyline
  Polyline toPolyline() {
    return style.toPolyline(id, points);
  }
}

/// Metrics for polyline performance monitoring
class PolylineMetrics {
  final int totalPolylines;
  final int activePolylines;
  final int memoryUsageBytes;
  final double averageRenderTime;
  final int totalUpdates;
  final DateTime lastUpdate;

  const PolylineMetrics({
    this.totalPolylines = 0,
    this.activePolylines = 0,
    this.memoryUsageBytes = 0,
    this.averageRenderTime = 0.0,
    this.totalUpdates = 0,
    required this.lastUpdate,
  });

  PolylineMetrics copyWith({
    int? totalPolylines,
    int? activePolylines,
    int? memoryUsageBytes,
    double? averageRenderTime,
    int? totalUpdates,
    DateTime? lastUpdate,
  }) {
    return PolylineMetrics(
      totalPolylines: totalPolylines ?? this.totalPolylines,
      activePolylines: activePolylines ?? this.activePolylines,
      memoryUsageBytes: memoryUsageBytes ?? this.memoryUsageBytes,
      averageRenderTime: averageRenderTime ?? this.averageRenderTime,
      totalUpdates: totalUpdates ?? this.totalUpdates,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// Overall state of the polyline system
class PolylineState {
  final Map<String, PolylineInfo> activePolylines;
  final String? primaryRouteId;
  final RoutePhase currentPhase;
  final PolylineMetrics metrics;
  final List<String> errors;

  const PolylineState({
    this.activePolylines = const {},
    this.primaryRouteId,
    this.currentPhase = RoutePhase.toPickup,
    required this.metrics,
    this.errors = const [],
  });

  PolylineState copyWith({
    Map<String, PolylineInfo>? activePolylines,
    String? primaryRouteId,
    RoutePhase? currentPhase,
    PolylineMetrics? metrics,
    List<String>? errors,
  }) {
    return PolylineState(
      activePolylines: activePolylines ?? this.activePolylines,
      primaryRouteId: primaryRouteId ?? this.primaryRouteId,
      currentPhase: currentPhase ?? this.currentPhase,
      metrics: metrics ?? this.metrics,
      errors: errors ?? this.errors,
    );
  }

  /// Get polyline by ID
  PolylineInfo? getPolyline(String id) {
    return activePolylines[id];
  }

  /// Check if polyline exists
  bool hasPolyline(String id) {
    return activePolylines.containsKey(id);
  }

  /// Get all polylines as Google Maps polylines
  Set<Polyline> toGoogleMapsPolylines() {
    return activePolylines.values
        .where((info) => info.status == PolylineStatus.active)
        .map((info) => info.toPolyline())
        .toSet();
  }

  /// Get polylines by status
  List<PolylineInfo> getPolylinesByStatus(PolylineStatus status) {
    return activePolylines.values
        .where((info) => info.status == status)
        .toList();
  }
}

/// Operation types for batch polyline updates
enum PolylineOperationType {
  create,
  update,
  remove,
  clear
}

/// Represents a polyline operation for batch processing
class PolylineOperation {
  final PolylineOperationType type;
  final String? routeId;
  final List<LatLng>? points;
  final PolylineStyle? style;
  final Map<String, dynamic>? metadata;

  const PolylineOperation({
    required this.type,
    this.routeId,
    this.points,
    this.style,
    this.metadata,
  });

  factory PolylineOperation.create(
    String routeId,
    List<LatLng> points,
    PolylineStyle style, {
    Map<String, dynamic>? metadata,
  }) {
    return PolylineOperation(
      type: PolylineOperationType.create,
      routeId: routeId,
      points: points,
      style: style,
      metadata: metadata,
    );
  }

  factory PolylineOperation.update(
    String routeId,
    List<LatLng> points, {
    PolylineStyle? style,
    Map<String, dynamic>? metadata,
  }) {
    return PolylineOperation(
      type: PolylineOperationType.update,
      routeId: routeId,
      points: points,
      style: style,
      metadata: metadata,
    );
  }

  factory PolylineOperation.remove(String routeId) {
    return PolylineOperation(
      type: PolylineOperationType.remove,
      routeId: routeId,
    );
  }

  factory PolylineOperation.clear() {
    return const PolylineOperation(
      type: PolylineOperationType.clear,
    );
  }
}