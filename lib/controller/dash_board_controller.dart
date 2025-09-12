import 'dart:developer';

import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/ui/chat_screen/inbox_screen.dart';
import 'package:driver/ui/home_screens/home_screen.dart';
import 'package:driver/ui/intercity_screen/home_intercity_screen.dart';
import 'package:driver/ui/online_registration/online_registartion_screen.dart';
import 'package:driver/ui/profile_screen/account_screen.dart' as account;
import 'package:driver/ui/safety/safety_screen.dart' as safety;
import 'package:driver/ui/scheduled_rides/scheduled_rides_screen.dart';
import 'package:driver/ui/settings_screen/setting_screen.dart';
// import 'package:driver/ui/vehicle_information/vehicle_information_screen.dart';
import 'package:driver/ui/wallet/wallet_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:driver/controller/live_tracking_controller.dart';

class DashBoardController extends GetxController {
  RxList<DrawerItem> drawerItems = <DrawerItem>[].obs;
  RxInt selectedDrawerIndex = 0.obs;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final Rx<DriverUserModel?> driverModel = Rx<DriverUserModel?>(null);
  var isOnline = false.obs;

  Widget getDrawerItemWidget(int pos) {
    try {
      switch (pos) {
        case 0:
          return const HomeScreen();
        case 1:
          return const HomeIntercityScreen();
        case 2:
          return const ScheduledRidesScreen();
        case 3:
          return const WalletScreen();
        case 4:
          return const InboxScreen();
        case 5:
          return const OnlineRegistrationScreen();
        case 6:
          return safety.SafetyScreen();
        case 7:
          return const SettingScreen();
        // Added case 8 to handle the MyProfileScreen
        case 8:
          return const account.MyProfileScreen();
        default:
          return const Center(child: Text("Screen not found"));
      }
    } catch (e) {
      log('Error in getDrawerItemWidget for position $pos: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading screen: $e'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => selectedDrawerIndex.value = 0,
              child: const Text('Go to Home'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> onSelectItem(int index) async {
    // Since logout is not in the drawer anymore, just handle normal navigation
    // If you add logout back to the drawer later, it would be at the end of the list

    try {
      // Close the drawer first, then navigate
      Get.back();

      // Add a small delay to ensure drawer is closed before navigation
      await Future.delayed(const Duration(milliseconds: 100));

      // Update the selected index
      selectedDrawerIndex.value = index;
    } catch (e) {
      log('Error in onSelectItem: $e');
      // Fallback: just update the index
      selectedDrawerIndex.value = index;
    }
  }

  @override
  void onInit() {
    setDrawerList();
    getLocation();
    fetchDriverData();
    super.onInit();
  }

  // Method to fetch driver data and update observables
  Future<void> fetchDriverData() async {
    final uid = FireStoreUtils.getCurrentUid();
    if (uid != null) {
      driverModel.value = await FireStoreUtils.getDriverProfile(uid);
      log('Driver:$driverModel');
      if (driverModel.value != null) {
        // Initialize the isOnline status from the fetched data
        isOnline.value = driverModel.value!.isOnline ?? false;
      }
    }
  }

  // Drawer list with only visible items (My Profile is accessible via case 8 but not shown in drawer)
  void setDrawerList() {
    drawerItems.value = [
      DrawerItem('Rides'.tr, "assets/icons/ic_city.svg"), // 0
      DrawerItem('Parcels'.tr, "assets/icons/ic_intercity.svg"), // 1
      DrawerItem('Schedule'.tr, "assets/icons/ic_intercity.svg"), // 2
      DrawerItem('My Wallet'.tr, "assets/icons/ic_wallet.svg"), // 3
      DrawerItem('Inbox'.tr, "assets/icons/ic_inbox.svg"), // 4
      DrawerItem('Online Registration'.tr, "assets/icons/ic_document.svg"), // 5
      DrawerItem("Safety".tr, "assets/icons/ic_document.svg"), // 6
      DrawerItem('Settings'.tr, "assets/icons/ic_settings.svg"), // 7
      // Note: My Profile (case 8) is handled in getDrawerItemWidget() but not shown in drawer
      // Uncomment the line below if you want to add logout back to the drawer
      // DrawerItem('Log out'.tr, "assets/icons/ic_logout.svg"),    // 8
    ];
  }

  Future<void> getLocation() async {
    await Utils.determinePosition();
  }

  Future<void> toggleOnlineStatus(bool value) async {
    // Prevent action if data isn't loaded yet
    log('Driver:$driverModel');
    if (driverModel.value == null) {
      ShowToastDialog.showToast("Please wait, user data is loading.");
      return;
    }

    // Add checks before allowing the driver to go online
    // if (value == true) {
    //   // Only check when turning online
    //   if (driverModel.value!.documentVerification != true) {
    //     Get.dialog(AlertDialog(
    //       title: Text('Information'.tr),
    //       content: Text(
    //           'Please complete your document verification to go online.'.tr),
    //       actions: [
    //         TextButton(child: Text('OK'.tr), onPressed: () => Get.back()),
    //       ],
    //     ));
    //     return; // Stop execution
    //   }
    // }

    ShowToastDialog.showLoader("Updating Status...");
    isOnline.value = value;
    try {
      // Update the 'isOnline' field in Firestore
      driverModel.value!.isOnline = isOnline.value;
      await FireStoreUtils.updateDriverUser(driverModel.value!);

      // Notify other controllers about the status change
      _notifyOnlineStatusChange(value);

      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(
          isOnline.value ? "You are now Online".tr : "You are now Offline".tr);
    } catch (e) {
      // Revert the switch if the update fails
      isOnline.value = !value;
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to update status: $e");
    }
  }

  /// Method to update online status without showing UI feedback (used by lifecycle service)
  Future<void> updateOnlineStatusSilently(bool value) async {
    if (driverModel.value == null) return;

    try {
      isOnline.value = value;
      driverModel.value!.isOnline = isOnline.value;
      await FireStoreUtils.updateDriverUser(driverModel.value!);
      _notifyOnlineStatusChange(value);
      log('Driver status updated silently to: ${value ? "online" : "offline"}');
    } catch (e) {
      log('Failed to update driver status silently: $e');
      // Revert on failure
      isOnline.value = !value;
    }
  }

  /// Notify other controllers about online status changes
  void _notifyOnlineStatusChange(bool isOnline) {
    try {
      // Try to find and notify the live tracking controller
      if (Get.isRegistered<LiveTrackingController>()) {
        final liveTrackingController = Get.find<LiveTrackingController>();
        liveTrackingController.onDriverStatusChanged(isOnline);
      }
    } catch (e) {
      log('Could not notify live tracking controller: $e');
    }
  }

  /// Test background location tracking (for debugging)
  void testBackgroundTracking() {
    try {
      if (Get.isRegistered<LiveTrackingController>()) {
        final liveTrackingController = Get.find<LiveTrackingController>();
        final status = liveTrackingController.getBackgroundTrackingStatus();
        log('Background tracking status: $status');

        // Force start background tracking if not active
        if (!status['isBackgroundTrackingActive']) {
          liveTrackingController.forceStartBackgroundTracking();
        }
      }
    } catch (e) {
      log('Error testing background tracking: $e');
    }
  }

  /// Test manual location update (for debugging)
  void testManualLocationUpdate() {
    try {
      if (Get.isRegistered<LiveTrackingController>()) {
        final liveTrackingController = Get.find<LiveTrackingController>();
        liveTrackingController.triggerManualLocationUpdate();
        log('Manual location update triggered');
      }
    } catch (e) {
      log('Error triggering manual location update: $e');
    }
  }

  /// Test forced immediate location update (for debugging)
  void testForcedImmediateUpdate() {
    try {
      if (Get.isRegistered<LiveTrackingController>()) {
        final liveTrackingController = Get.find<LiveTrackingController>();
        liveTrackingController.forceImmediateLocationUpdate();
        log('Forced immediate location update triggered');
      }
    } catch (e) {
      log('Error triggering forced immediate update: $e');
    }
  }

  /// Get detailed background tracking status
  Map<String, dynamic> getDetailedBackgroundTrackingStatus() {
    try {
      if (Get.isRegistered<LiveTrackingController>()) {
        final liveTrackingController = Get.find<LiveTrackingController>();
        return liveTrackingController.getDetailedBackgroundTrackingStatus();
      }
      return {'error': 'LiveTrackingController not registered'};
    } catch (e) {
      return {'error': 'Error getting status: $e'};
    }
  }

  Rx<DateTime> currentBackPressTime = DateTime.now().obs;

  Future<bool> onWillPop() async {
    // If not on MainScreen, go to MainScreen instead of exiting
    if (selectedDrawerIndex.value != 0) {
      selectedDrawerIndex.value = 0;
      return false;
    }

    // If already on MainScreen, use double-tap-to-exit logic
    DateTime now = DateTime.now();
    if (now.difference(currentBackPressTime.value) >
        const Duration(seconds: 2)) {
      currentBackPressTime.value = now;
      ShowToastDialog.showToast("Double press to exit",
          position: EasyLoadingToastPosition.center);
      return false;
    }
    return true;
  }
}

class DrawerItem {
  String title;
  String icon;

  DrawerItem(this.title, this.icon);
}
