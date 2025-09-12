import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/services/dynamic_timer_service.dart';
import 'package:driver/widget/geoflutterfire/geoflutterfire.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service to handle nearby driver notifications and real-time updates
class NearbyDriverNotificationService extends GetxService {
  static NearbyDriverNotificationService get instance => Get.find<NearbyDriverNotificationService>();
  
  // Notification state
  final RxList<DriverUserModel> _nearbyDrivers = <DriverUserModel>[].obs;
  final RxMap<String, DateTime> _lastNotificationSent = <String, DateTime>{}.obs;
  final RxMap<String, Timer> _notificationTimers = <String, Timer>{}.obs;
  
  // Configuration
  static const int _notificationCooldownMinutes = 2; // Don't spam drivers
  static const double _searchRadiusKm = 5.0; // Search radius in kilometers
  static const int _maxDriversToNotify = 10; // Maximum drivers to notify at once
  
  @override
  void onInit() {
    super.onInit();
    _initializeService();
  }
  
  @override
  void onClose() {
    _cleanupTimers();
    super.onClose();
  }
  
  void _initializeService() {
    // Initialize any required services
  }
  
  /// Find and notify nearby drivers about a ride request
  Future<void> findAndNotifyNearbyDrivers({
    required OrderModel order,
    required LatLng pickupLocation,
    required Function(List<DriverUserModel>) onDriversFound,
    required Function(String) onStatusUpdate,
  }) async {
    try {
      onStatusUpdate("Searching for nearby drivers...");
      
      // Find nearby drivers
      final nearbyDrivers = await _findNearbyDrivers(pickupLocation);
      
      if (nearbyDrivers.isEmpty) {
        onStatusUpdate("No drivers found in the area");
        return;
      }
      
      onStatusUpdate("Found ${nearbyDrivers.length} nearby drivers");
      _nearbyDrivers.value = nearbyDrivers;
      onDriversFound(nearbyDrivers);
      
      // Notify drivers with smart timing
      await _notifyDriversWithSmartTiming(nearbyDrivers, order, pickupLocation);
      
    } catch (e) {
      debugPrint('Error finding nearby drivers: $e');
      onStatusUpdate("Error searching for drivers");
    }
  }
  
  /// Find nearby drivers using geolocation
  Future<List<DriverUserModel>> _findNearbyDrivers(LatLng pickupLocation) async {
    try {
      final geo = Geoflutterfire();
      final center = geo.point(
        latitude: pickupLocation.latitude, 
        longitude: pickupLocation.longitude
      );
      
      final query = FirebaseFirestore.instance
          .collection(CollectionName.driverUsers)
          .where('isOnline', isEqualTo: true)
          .where('documentVerification', isEqualTo: true);
      
      final snapshots = await geo
          .collection(collectionRef: query)
          .within(
            center: center, 
            radius: _searchRadiusKm, 
            field: 'position', 
            strictMode: true
          )
          .first;
      
      final drivers = snapshots
          .map((doc) => DriverUserModel.fromJson(doc.data() as Map<String, dynamic>))
          .where((driver) => 
              driver.location?.latitude != null && 
              driver.location?.longitude != null &&
              driver.fcmToken != null &&
              driver.fcmToken!.isNotEmpty)
          .toList();
      
      // Sort by distance
      drivers.sort((a, b) {
        final distanceA = _calculateDistance(
          pickupLocation, 
          LatLng(a.location!.latitude!, a.location!.longitude!)
        );
        final distanceB = _calculateDistance(
          pickupLocation, 
          LatLng(b.location!.latitude!, b.location!.longitude!)
        );
        return distanceA.compareTo(distanceB);
      });
      
      return drivers.take(_maxDriversToNotify).toList();
      
    } catch (e) {
      debugPrint('Error finding nearby drivers: $e');
      return [];
    }
  }
  
  /// Notify drivers with smart timing to avoid spam
  Future<void> _notifyDriversWithSmartTiming(
    List<DriverUserModel> drivers, 
    OrderModel order, 
    LatLng pickupLocation
  ) async {
    for (int i = 0; i < drivers.length; i++) {
      final driver = drivers[i];
      final driverId = driver.id!;
      
      // Check if we've sent a notification recently
      if (_shouldSendNotification(driverId)) {
        // Stagger notifications to avoid overwhelming drivers
        final delay = Duration(seconds: i * 2); // 2 seconds between each notification
        
        _notificationTimers[driverId] = Timer(delay, () async {
          await _sendDriverNotification(driver, order, pickupLocation);
          _lastNotificationSent[driverId] = DateTime.now();
        });
      }
    }
  }
  
  /// Check if we should send notification to this driver
  bool _shouldSendNotification(String driverId) {
    final lastSent = _lastNotificationSent[driverId];
    if (lastSent == null) return true;
    
    final timeSinceLastSent = DateTime.now().difference(lastSent);
    return timeSinceLastSent.inMinutes >= _notificationCooldownMinutes;
  }
  
  /// Send notification to a specific driver
  Future<void> _sendDriverNotification(
    DriverUserModel driver, 
    OrderModel order, 
    LatLng pickupLocation
  ) async {
    try {
      final distance = _calculateDistance(
        pickupLocation, 
        LatLng(driver.location!.latitude!, driver.location!.longitude!)
      );
      
      final distanceText = distance < 1000 
          ? '${distance.toStringAsFixed(0)}m away'
          : '${(distance / 1000.0).toStringAsFixed(1)}km away';
      
      await SendNotification.sendOneNotification(
        token: driver.fcmToken!,
        title: '🚗 New Ride Request Nearby!',
        body: 'A customer needs a ride $distanceText. Tap to accept!',
        payload: {
          'orderId': order.id,
          'type': 'ride_request',
          'pickup': order.sourceLocationName ?? '',
          'destination': order.destinationLocationName ?? '',
          'distance': distanceText,
          'amount': order.offerRate?.toString() ?? '0.0',
          'customerId': order.userId,
          'pickupLat': pickupLocation.latitude.toString(),
          'pickupLng': pickupLocation.longitude.toString(),
        },
      );
      
      debugPrint('Notification sent to driver: ${driver.fullName}');
      
    } catch (e) {
      debugPrint('Error sending notification to driver ${driver.fullName}: $e');
    }
  }
  
  /// Send follow-up notification to drivers who haven't responded
  Future<void> sendFollowUpNotification(
    List<DriverUserModel> drivers, 
    OrderModel order, 
    LatLng pickupLocation
  ) async {
    for (final driver in drivers) {
      final driverId = driver.id!;
      
      // Only send follow-up if we haven't sent one recently
      if (_shouldSendNotification(driverId)) {
        await SendNotification.sendOneNotification(
          token: driver.fcmToken!,
          title: '⏰ Ride Request Still Available',
          body: 'This ride request is still waiting for a driver. Quick response needed!',
          payload: {
            'orderId': order.id,
            'type': 'ride_request_followup',
            'pickup': order.sourceLocationName ?? '',
            'destination': order.destinationLocationName ?? '',
            'amount': order.offerRate?.toString() ?? '0.0',
          },
        );
        
        _lastNotificationSent[driverId] = DateTime.now();
      }
    }
  }
  
  /// Send cancellation notification to all contacted drivers
  Future<void> notifyRideCancelled(
    List<DriverUserModel> drivers, 
    OrderModel order
  ) async {
    for (final driver in drivers) {
      if (driver.fcmToken != null && driver.fcmToken!.isNotEmpty) {
        await SendNotification.sendOneNotification(
          token: driver.fcmToken!,
          title: '❌ Ride Request Cancelled',
          body: 'The customer has cancelled their ride request.',
          payload: {
            'orderId': order.id,
            'type': 'ride_cancelled',
          },
        );
      }
    }
  }
  
  /// Send driver accepted notification to customer
  Future<void> notifyDriverAccepted(
    String customerFcmToken, 
    DriverUserModel driver, 
    OrderModel order
  ) async {
    await SendNotification.sendOneNotification(
      token: customerFcmToken,
      title: '✅ Driver Found!',
      body: '${driver.fullName} has accepted your ride request. They\'re on their way!',
      payload: {
        'orderId': order.id,
        'type': 'driver_accepted',
        'driverId': driver.id,
        'driverName': driver.fullName ?? '',
        'driverPhone': driver.phoneNumber ?? '',
        'vehicleInfo': driver.vehicleInformation?.vehicleNumber ?? '',
      },
    );
  }
  
  /// Send driver rejected notification to customer
  Future<void> notifyDriverRejected(
    String customerFcmToken, 
    DriverUserModel driver, 
    OrderModel order
  ) async {
    await SendNotification.sendOneNotification(
      token: customerFcmToken,
      title: 'Driver Unavailable',
      body: '${driver.fullName} is not available. Searching for another driver...',
      payload: {
        'orderId': order.id,
        'type': 'driver_rejected',
        'driverId': driver.id,
      },
    );
  }
  
  /// Calculate distance between two points
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  /// Clean up notification timers
  void _cleanupTimers() {
    for (final timer in _notificationTimers.values) {
      timer.cancel();
    }
    _notificationTimers.clear();
  }
  
  /// Get nearby drivers list
  List<DriverUserModel> get nearbyDrivers => _nearbyDrivers;
  
  /// Clear nearby drivers list
  void clearNearbyDrivers() {
    _nearbyDrivers.clear();
  }
}
