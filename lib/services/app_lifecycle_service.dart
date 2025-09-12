import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppLifecycleService extends GetxService with WidgetsBindingObserver {
  static AppLifecycleService get to => Get.find();
  
  final RxBool _isAppInForeground = true.obs;
  final RxBool _wasOnlineBeforeBackground = false.obs;
  Timer? _heartbeatTimer;
  Timer? _offlineCheckTimer;
  
  bool get isAppInForeground => _isAppInForeground.value;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
    dev.log('AppLifecycleService: Initialized and observer added');
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _offlineCheckTimer?.cancel();
    super.onClose();
  }

  /// Start heartbeat to detect app termination
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateHeartbeat();
    });
    _updateHeartbeat(); // Initial heartbeat
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Update heartbeat timestamp in Firestore
  Future<void> _updateHeartbeat() async {
    try {
      final uid = FireStoreUtils.getCurrentUid();
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(uid)
            .update({
          'lastHeartbeat': FieldValue.serverTimestamp(),
          'appInForeground': _isAppInForeground.value,
        });
      }
    } catch (e) {
      dev.log('AppLifecycleService: Error updating heartbeat: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    dev.log('AppLifecycleService: App state changed to $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }

  /// Called when app comes to foreground
  void _onAppResumed() {
    dev.log('AppLifecycleService: App resumed (foreground)');
    _isAppInForeground.value = true;
    
    // Restore online status if driver was online before going to background
    if (_wasOnlineBeforeBackground.value) {
      _setDriverOnlineStatus(true);
      _wasOnlineBeforeBackground.value = false;
    }
  }

  /// Called when app goes to background
  void _onAppPaused() {
    dev.log('AppLifecycleService: App paused (background)');
    _isAppInForeground.value = false;
    
    // Remember current online status but keep driver online in background
    // This allows the driver to receive ride requests even when app is backgrounded
    _handleBackgroundState();
  }

  /// Called when app becomes inactive (like during phone calls)
  void _onAppInactive() {
    dev.log('AppLifecycleService: App inactive');
    // Don't change online status for inactive state (temporary interruptions)
  }

  /// Called when app is hidden (iOS specific)
  void _onAppHidden() {
    dev.log('AppLifecycleService: App hidden');
    _isAppInForeground.value = false;
  }

  /// Handle background state - keep driver online
  void _handleBackgroundState() {
    try {
      final dashboardController = Get.find<DashBoardController>();
      
      // Remember if driver was online before going to background
      if (dashboardController.isOnline.value) {
        _wasOnlineBeforeBackground.value = true;
        dev.log('AppLifecycleService: Driver was online, keeping online in background');
        // Driver stays online in background to receive ride requests
      }
    } catch (e) {
      dev.log('AppLifecycleService: Error handling background state: $e');
    }
  }

  /// Set driver online/offline status
  Future<void> _setDriverOnlineStatus(bool isOnline) async {
    try {
      if (Get.isRegistered<DashBoardController>()) {
        final dashboardController = Get.find<DashBoardController>();
        
        // Only update if status is different
        if (dashboardController.isOnline.value != isOnline) {
          dev.log('AppLifecycleService: Setting driver status to ${isOnline ? "online" : "offline"}');
          
          // Update local state
          dashboardController.isOnline.value = isOnline;
          
          // Update in Firestore
          if (dashboardController.driverModel.value != null) {
            dashboardController.driverModel.value!.isOnline = isOnline;
            await FireStoreUtils.updateDriverUser(dashboardController.driverModel.value!);
          }
        }
      }
    } catch (e) {
      dev.log('AppLifecycleService: Error setting driver status: $e');
    }
  }

  /// Force driver offline (called when app is terminated)
  Future<void> forceDriverOffline() async {
    try {
      dev.log('AppLifecycleService: Forcing driver offline');
      await _setDriverOnlineStatus(false);
    } catch (e) {
      dev.log('AppLifecycleService: Error forcing driver offline: $e');
    }
  }

  /// Check if driver should be automatically set online
  bool shouldAutoSetOnline() {
    try {
      if (Get.isRegistered<DashBoardController>()) {
        final dashboardController = Get.find<DashBoardController>();
        
        // Auto set online if:
        // 1. Driver model is loaded
        // 2. Documents are verified
        // 3. Driver was online before
        return dashboardController.driverModel.value != null &&
               dashboardController.driverModel.value!.documentVerification == true &&
               _wasOnlineBeforeBackground.value;
      }
    } catch (e) {
      dev.log('AppLifecycleService: Error checking auto online status: $e');
    }
    return false;
  }

  /// Manual method to handle app termination
  /// This should be called from main app's dispose or when user manually closes app
  static Future<void> handleAppTermination() async {
    try {
      dev.log('AppLifecycleService: Handling app termination');
      
      // Set driver offline when app is completely closed
      final uid = FireStoreUtils.getCurrentUid();
      if (uid != null) {
        final driverModel = await FireStoreUtils.getDriverProfile(uid);
        if (driverModel != null) {
          driverModel.isOnline = false;
          await FireStoreUtils.updateDriverUser(driverModel);
          
          // Also update heartbeat fields
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(uid)
              .update({
            'lastHeartbeat': FieldValue.serverTimestamp(),
            'appInForeground': false,
            'isOnline': false,
          });
          
          dev.log('AppLifecycleService: Driver set offline on app termination');
        }
      }
    } catch (e) {
      dev.log('AppLifecycleService: Error handling app termination: $e');
    }
  }

  /// Start monitoring for app termination (server-side check)
  /// This can be called from a cloud function or admin panel
  static void startOfflineDetection() {
    // This would typically be implemented as a cloud function
    // that runs every minute and checks for drivers whose heartbeat
    // is older than 2 minutes and sets them offline
    dev.log('AppLifecycleService: Offline detection should be implemented server-side');
  }

  /// Check if driver should be marked offline based on heartbeat
  /// This is a client-side helper method
  static Future<bool> shouldMarkDriverOffline(String driverId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final lastHeartbeat = data['lastHeartbeat'] as Timestamp?;
        
        if (lastHeartbeat != null) {
          final now = DateTime.now();
          final heartbeatTime = lastHeartbeat.toDate();
          final difference = now.difference(heartbeatTime);
          
          // If no heartbeat for more than 2 minutes, consider app terminated
          return difference.inMinutes > 2;
        }
      }
      return false;
    } catch (e) {
      dev.log('AppLifecycleService: Error checking offline status: $e');
      return false;
    }
  }
}