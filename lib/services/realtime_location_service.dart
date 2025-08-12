import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

class RealtimeLocationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  DatabaseReference _locationRefFor(String orderId, String driverId) {
    return _database.ref('live_locations/$orderId/$driverId');
  }

  Future<void> publishDriverLocation({
    required String orderId,
    required String driverId,
    required double latitude,
    required double longitude,
    required double speedKmh,
    required double bearing,
    required double accuracy,
    required String rideStatus,
    String? phase,
  }) async {
    final DatabaseReference ref = _locationRefFor(orderId, driverId);
    // Ensure cleanup on disconnect
    try {
      await ref.onDisconnect().remove();
    } catch (_) {}

    final int now = DateTime.now().millisecondsSinceEpoch;
    await ref.update({
      'lat': latitude,
      'lng': longitude,
      'speedKmh': speedKmh,
      'bearing': bearing,
      'accuracy': accuracy,
      'status': rideStatus,
      'phase': phase ?? 'unknown',
      'updatedAt': now,
    });
  }

  Future<void> removeDriverLocation(
      {required String orderId, required String driverId}) async {
    await _locationRefFor(orderId, driverId).remove();
  }

  Stream<Map<String, dynamic>?> subscribeToDriver({
    required String orderId,
    required String driverId,
  }) {
    final DatabaseReference ref = _locationRefFor(orderId, driverId);
    return ref.onValue.map((event) {
      final Object? value = event.snapshot.value;
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    });
  }
}
