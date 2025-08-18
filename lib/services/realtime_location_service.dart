import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

class RealtimeLocationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  DatabaseReference _locationRefFor(String orderId, String driverId) {
    return _database.ref('live_locations/$orderId/$driverId');
  }

  /// Get Firebase database configuration info for debugging
  Map<String, dynamic> getDatabaseInfo() {
    return {
      'databaseURL': _database.databaseURL,
      'app': _database.app.name,
      'projectId': _database.app.options.projectId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Provide guidance on Firebase database rules
  void printDatabaseRulesGuidance() {
    print('=== FIREBASE DATABASE RULES GUIDANCE ===');
    print(
        'If you are getting permission denied errors, check your Firebase Realtime Database rules.');
    print('The rules should allow writes to the "live_locations" path.');
    print('');
    print('Example rules that should work:');
    print('{');
    print('  "rules": {');
    print('    "live_locations": {');
    print('      "\$orderId": {');
    print('        "\$driverId": {');
    print('          ".read": true,');
    print('          ".write": true');
    print('        }');
    print('      }');
    print('    }');
    print('  }');
    print('}');
    print('');
    print('Or for testing, you can use:');
    print('{');
    print('  "rules": {');
    print('    ".read": true,');
    print('    ".write": true');
    print('  }');
    print('}');
    print('=== END GUIDANCE ===');
  }

  /// Test Firebase database access and permissions
  Future<bool> testDatabaseAccess() async {
    try {
      print('Testing Firebase database access...');

      // Test basic read/write to root
      final testRef = _database.ref('test_access');
      await testRef.set(
          {'test': 'data', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      print('Root write test successful');

      final snapshot = await testRef.get();
      print('Root read test successful: ${snapshot.value}');

      // Test live_locations path
      final liveLocationsRef = _database.ref('live_locations');
      await liveLocationsRef.set(
          {'test': 'data', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      print('live_locations write test successful');

      final liveSnapshot = await liveLocationsRef.get();
      print('live_locations read test successful: ${liveSnapshot.value}');

      // Test specific order path
      final orderRef = _database.ref('live_locations/test_order/test_driver');
      await orderRef.set({
        'lat': 0.0,
        'lng': 0.0,
        'speedKmh': 0.0,
        'bearing': 0.0,
        'accuracy': 10.0,
        'status': 'test',
        'phase': 'test',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      print('Specific order path write test successful');

      final orderSnapshot = await orderRef.get();
      print('Specific order path read test successful: ${orderSnapshot.value}');

      // Clean up test data
      await testRef.remove();
      await liveLocationsRef.remove();
      await orderRef.remove();

      print('All Firebase access tests passed');
      return true;
    } catch (e) {
      print('Firebase access test failed: $e');

      // Provide specific error information
      if (e.toString().contains('permission') ||
          e.toString().contains('denied')) {
        print('ERROR: Firebase permission denied - check database rules');
        print('Current database rules may be too restrictive');
        printDatabaseRulesGuidance();
      } else if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        print('ERROR: Firebase network error - check internet connection');
      } else if (e.toString().contains('not_found')) {
        print('ERROR: Firebase path not found - check database structure');
      } else {
        print('ERROR: Unknown Firebase error: $e');
      }

      return false;
    }
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
    print('RealtimeLocationService: Publishing driver location');
    print('Order ID: $orderId, Driver ID: $driverId');
    print('Coordinates: $latitude, $longitude');

    final DatabaseReference ref = _locationRefFor(orderId, driverId);
    print('Firebase reference path: ${ref.path}');
    print('Firebase database URL: ${_database.databaseURL}');

    // Test database connection by reading a value
    try {
      final snapshot = await ref.get();
      print('Current Firebase data: ${snapshot.value}');
    } catch (e) {
      print('Error reading from Firebase: $e');
    }

    // Test simple write operation first
    try {
      final testRef = _database.ref('test_connection');
      await testRef.set({'timestamp': DateTime.now().millisecondsSinceEpoch});
      print('Test write successful - Firebase connection working');
      await testRef.remove(); // Clean up test data
    } catch (e) {
      print('Test write failed - Firebase connection issue: $e');
      rethrow;
    }

    // Ensure cleanup on disconnect
    try {
      await ref.onDisconnect().remove();
      print('Firebase onDisconnect cleanup set');
    } catch (e) {
      print('Error setting onDisconnect cleanup: $e');
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> locationData = {
      'lat': latitude,
      'lng': longitude,
      'speedKmh': speedKmh,
      'bearing': bearing,
      'accuracy': accuracy,
      'status': rideStatus,
      'phase': phase ?? 'unknown',
      'updatedAt': now,
    };

    print('Publishing location data: $locationData');

    try {
      await ref.update(locationData);
      print('Firebase update successful');

      // Verify the update by reading back
      final verifySnapshot = await ref.get();
      print('Verification - Updated data: ${verifySnapshot.value}');
    } catch (e) {
      print('Firebase update failed: $e');

      // Check if it's a permission error
      if (e.toString().contains('permission') ||
          e.toString().contains('denied')) {
        print('Firebase permission denied - check database rules');
      } else if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        print('Firebase network error - check internet connection');
      } else if (e.toString().contains('not_found')) {
        print('Firebase path not found - check database structure');
      }

      rethrow;
    }
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
