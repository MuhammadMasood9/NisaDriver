// Location Data Conversion Utilities for Driver App
// This file contains utilities for converting between different location data formats

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driver/model/enhanced_location_data.dart';

/// Utility class for converting location data between different formats
class LocationDataConverter {
  /// Converts Geolocator Position to EnhancedLocationData
  static EnhancedLocationData fromPosition({
    required Position position,
    required String status,
    required RidePhase phase,
    required int sequenceNumber,
    required double batteryLevel,
    required NetworkQuality networkQuality,
    Map<String, dynamic> metadata = const {},
  }) {
    return EnhancedLocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      speedKmh: (position.speed * 3.6).clamp(0.0, 300.0), // Convert m/s to km/h
      bearing: position.heading.clamp(0.0, 359.9),
      accuracy: position.accuracy,
      status: status,
      phase: phase,
      timestamp: position.timestamp ?? DateTime.now(),
      sequenceNumber: sequenceNumber,
      batteryLevel: batteryLevel,
      networkQuality: networkQuality,
      metadata: metadata,
    );
  }

  /// Converts legacy location data to EnhancedLocationData
  static EnhancedLocationData fromLegacyLocationData({
    required double latitude,
    required double longitude,
    double speedKmh = 0.0,
    double bearing = 0.0,
    double accuracy = 10.0,
    required String status,
    RidePhase phase = RidePhase.enRouteToPickup,
    DateTime? timestamp,
    int sequenceNumber = 0,
    double batteryLevel = 100.0,
    NetworkQuality networkQuality = NetworkQuality.good,
    Map<String, dynamic> metadata = const {},
  }) {
    return EnhancedLocationData(
      latitude: latitude,
      longitude: longitude,
      speedKmh: speedKmh.clamp(0.0, 300.0),
      bearing: bearing.clamp(0.0, 359.9),
      accuracy: accuracy.clamp(0.0, 1000.0),
      status: status,
      phase: phase,
      timestamp: timestamp ?? DateTime.now(),
      sequenceNumber: sequenceNumber,
      batteryLevel: batteryLevel.clamp(0.0, 100.0),
      networkQuality: networkQuality,
      metadata: metadata,
    );
  }

  /// Converts ride status string to RidePhase enum
  static RidePhase rideStatusToPhase(String status) {
    switch (status.toLowerCase()) {
      case 'rideplaced':
      case 'rideaccepted':
        return RidePhase.enRouteToPickup;
      case 'ridearrived':
        return RidePhase.atPickupLocation;
      case 'rideinprogress':
      case 'rideactive':
        return RidePhase.rideInProgress;
      case 'ridecomplete':
        return RidePhase.rideCompleted;
      default:
        return RidePhase.enRouteToPickup;
    }
  }

  /// Determines network quality based on connection type and strength
  static NetworkQuality determineNetworkQuality({
    bool isConnected = true,
    String connectionType = 'wifi',
    int signalStrength = 100,
  }) {
    if (!isConnected) return NetworkQuality.offline;

    if (connectionType.toLowerCase() == 'wifi') {
      if (signalStrength >= 80) return NetworkQuality.excellent;
      if (signalStrength >= 60) return NetworkQuality.good;
      if (signalStrength >= 40) return NetworkQuality.fair;
      return NetworkQuality.poor;
    } else {
      // Cellular connection
      if (signalStrength >= 75) return NetworkQuality.excellent;
      if (signalStrength >= 50) return NetworkQuality.good;
      if (signalStrength >= 25) return NetworkQuality.fair;
      return NetworkQuality.poor;
    }
  }

  /// Creates metadata map with common tracking information
  static Map<String, dynamic> createMetadata({
    String? deviceId,
    String? appVersion,
    String? osVersion,
    bool isBackgroundMode = false,
    double? altitude,
    double? altitudeAccuracy,
    String? provider,
  }) {
    final metadata = <String, dynamic>{};
    
    if (deviceId != null) metadata['deviceId'] = deviceId;
    if (appVersion != null) metadata['appVersion'] = appVersion;
    if (osVersion != null) metadata['osVersion'] = osVersion;
    metadata['isBackgroundMode'] = isBackgroundMode;
    if (altitude != null) metadata['altitude'] = altitude;
    if (altitudeAccuracy != null) metadata['altitudeAccuracy'] = altitudeAccuracy;
    if (provider != null) metadata['provider'] = provider;
    
    return metadata;
  }

  /// Validates and cleans location data
  static EnhancedLocationData? validateAndClean(EnhancedLocationData data) {
    // Check if coordinates are valid
    if (data.latitude == 0.0 && data.longitude == 0.0) {
      return null; // Invalid coordinates
    }

    // Check if data is too old
    final age = DateTime.now().difference(data.timestamp);
    if (age.inMinutes > 15) {
      return null; // Data too old
    }

    // Check accuracy threshold
    if (data.accuracy > 100.0) {
      return null; // Accuracy too poor
    }

    return data.copyWith(
      // Ensure values are within valid ranges
      speedKmh: data.speedKmh.clamp(0.0, 300.0),
      bearing: data.bearing.clamp(0.0, 359.9),
      accuracy: data.accuracy.clamp(0.0, 1000.0),
      batteryLevel: data.batteryLevel.clamp(0.0, 100.0),
    );
  }

  /// Calculates distance between two location points in meters
  static double calculateDistance(
    EnhancedLocationData point1,
    EnhancedLocationData point2,
  ) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Calculates bearing between two location points in degrees
  static double calculateBearing(
    EnhancedLocationData from,
    EnhancedLocationData to,
  ) {
    return Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    ).clamp(0.0, 359.9);
  }

  /// Interpolates between two location points
  static EnhancedLocationData interpolate(
    EnhancedLocationData from,
    EnhancedLocationData to,
    double factor, // 0.0 to 1.0
  ) {
    factor = factor.clamp(0.0, 1.0);
    
    return EnhancedLocationData(
      latitude: from.latitude + (to.latitude - from.latitude) * factor,
      longitude: from.longitude + (to.longitude - from.longitude) * factor,
      speedKmh: from.speedKmh + (to.speedKmh - from.speedKmh) * factor,
      bearing: _interpolateBearing(from.bearing, to.bearing, factor),
      accuracy: from.accuracy + (to.accuracy - from.accuracy) * factor,
      status: factor < 0.5 ? from.status : to.status,
      phase: factor < 0.5 ? from.phase : to.phase,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        from.timestamp.millisecondsSinceEpoch +
            ((to.timestamp.millisecondsSinceEpoch - from.timestamp.millisecondsSinceEpoch) * factor).round(),
      ),
      sequenceNumber: factor < 0.5 ? from.sequenceNumber : to.sequenceNumber,
      batteryLevel: from.batteryLevel + (to.batteryLevel - from.batteryLevel) * factor,
      networkQuality: factor < 0.5 ? from.networkQuality : to.networkQuality,
      metadata: factor < 0.5 ? from.metadata : to.metadata,
    );
  }

  /// Interpolates bearing values considering circular nature (0-360 degrees)
  static double _interpolateBearing(double from, double to, double factor) {
    double diff = to - from;
    
    // Handle wrap-around (e.g., from 350° to 10°)
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }
    
    double result = from + diff * factor;
    
    // Ensure result is in 0-360 range
    if (result < 0) {
      result += 360;
    } else if (result >= 360) {
      result -= 360;
    }
    
    return result.clamp(0.0, 359.9);
  }

  /// Creates a sequence of interpolated points for smooth animation
  static List<EnhancedLocationData> createAnimationSequence(
    EnhancedLocationData from,
    EnhancedLocationData to,
    int steps,
  ) {
    if (steps <= 1) return [to];
    
    final sequence = <EnhancedLocationData>[];
    for (int i = 1; i <= steps; i++) {
      final factor = i / steps;
      sequence.add(interpolate(from, to, factor));
    }
    
    return sequence;
  }

  /// Filters out location data that appears to be GPS noise
  static bool isLikelyGpsNoise(
    EnhancedLocationData current,
    EnhancedLocationData? previous,
  ) {
    if (previous == null) return false;
    
    // Check for sudden large jumps in position
    final distance = calculateDistance(previous, current);
    final timeDiff = current.timestamp.difference(previous.timestamp).inSeconds;
    
    if (timeDiff <= 0) return true; // Invalid time sequence
    
    // Calculate implied speed
    final impliedSpeed = (distance / timeDiff) * 3.6; // km/h
    
    // If implied speed is unreasonably high, it's likely noise
    if (impliedSpeed > 200) return true;
    
    // Check for poor accuracy
    if (current.accuracy > 50) return true;
    
    // Check for sudden bearing changes at low speeds
    if (current.speedKmh < 5 && previous.speedKmh < 5) {
      final bearingDiff = (current.bearing - previous.bearing).abs();
      if (bearingDiff > 90 && bearingDiff < 270) return true;
    }
    
    return false;
  }

  /// Calculate distance between two LatLng points in meters
  static double calculateDistanceLatLng(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Snap a location to the nearest point on a polyline
  static LatLng snapToPolyline(LatLng location, List<LatLng> polyline) {
    if (polyline.isEmpty) return location;
    
    double minDistance = double.infinity;
    LatLng closestPoint = location;
    
    for (int i = 0; i < polyline.length - 1; i++) {
      final segmentStart = polyline[i];
      final segmentEnd = polyline[i + 1];
      final snapped = _snapToLineSegment(location, segmentStart, segmentEnd);
      final distance = calculateDistanceLatLng(location, snapped);
      
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = snapped;
      }
    }
    
    return closestPoint;
  }

  /// Snap a point to a line segment
  static LatLng _snapToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final A = point.latitude - lineStart.latitude;
    final B = point.longitude - lineStart.longitude;
    final C = lineEnd.latitude - lineStart.latitude;
    final D = lineEnd.longitude - lineStart.longitude;
    
    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    
    if (lenSq == 0) return lineStart; // Line start and end are the same
    
    final param = dot / lenSq;
    
    if (param < 0) {
      return lineStart;
    } else if (param > 1) {
      return lineEnd;
    } else {
      return LatLng(
        lineStart.latitude + param * C,
        lineStart.longitude + param * D,
      );
    }
  }
}