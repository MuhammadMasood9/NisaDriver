import 'dart:developer';

import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/ui/auth_screen/login_screen.dart';
import 'package:driver/ui/bank_details/bank_details_screen.dart';
import 'package:driver/ui/chat_screen/inbox_screen.dart';
import 'package:driver/ui/home_screens/home_screen.dart';
import 'package:driver/ui/intercity_screen/home_intercity_screen.dart';
import 'package:driver/ui/online_registration/online_registartion_screen.dart';
import 'package:driver/ui/profile_screen/profile_screen.dart';
import 'package:driver/ui/profile_screen/account_screen.dart' as account;
import 'package:driver/ui/safety/safety_screen.dart' as safety;
import 'package:driver/ui/scheduled_rides/scheduled_order_screen.dart';
import 'package:driver/ui/scheduled_rides/scheduled_rides_screen.dart';
import 'package:driver/ui/settings_screen/setting_screen.dart';
import 'package:driver/ui/vehicle_information/vehicle_information_screen.dart';
// import 'package:driver/ui/vehicle_information/vehicle_information_screen.dart';
import 'package:driver/ui/wallet/wallet_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class DashBoardController extends GetxController {
  RxList<DrawerItem> drawerItems = <DrawerItem>[].obs;
  RxInt selectedDrawerIndex = 0.obs;
  final Rx<DriverUserModel?> driverModel = Rx<DriverUserModel?>(null);
  var isOnline = false.obs;

  Widget getDrawerItemWidget(int pos) {
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
        return const BankDetailsScreen();
      case 5:
        return const InboxScreen();
      case 6:
        return const account.MyProfileScreen();
      case 7:
        return const OnlineRegistrationScreen();
      case 8:
        return const VehicleInformationScreen();
      case 9:
        return safety.SafetyScreen();
      case 10:
        return const SettingScreen();

      case 11:
        return const account.MyProfileScreen();

      default:
        return const Text("Error");
    }
  }

  Future<void> onSelectItem(int index) async {
    final logoutIndex = Constant.isSubscriptionModelApplied ? 13 : 12;
    if (index == logoutIndex) {
      await FirebaseAuth.instance.signOut();
      Get.offAll(const LoginScreen());
    } else {
      selectedDrawerIndex.value = index;
    }
    Get.back();
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

  void setDrawerList() {
    drawerItems.value = [
      DrawerItem('Rides'.tr, "assets/icons/ic_city.svg"),
      DrawerItem('Parcels'.tr, "assets/icons/ic_intercity.svg"),
      DrawerItem('Schedule'.tr, "assets/icons/ic_intercity.svg"),
      DrawerItem('My Wallet'.tr, "assets/icons/ic_wallet.svg"),
      DrawerItem('Bank Details'.tr, "assets/icons/ic_profile.svg"),
      DrawerItem('Inbox'.tr, "assets/icons/ic_inbox.svg"),
      DrawerItem('Profile'.tr, "assets/icons/ic_profile.svg"),
      DrawerItem('Online Registration'.tr, "assets/icons/ic_document.svg"),
      DrawerItem('Vehicle Information'.tr, "assets/icons/ic_city.svg"),
      DrawerItem("Safety", "assets/icons/ic_document.svg"),
      DrawerItem('Settings'.tr, "assets/icons/ic_settings.svg"),
      DrawerItem('Log out'.tr, "assets/icons/ic_logout.svg"),
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
    if (value == true) {
      // Only check when turning online
      if (driverModel.value!.documentVerification != true) {
        Get.dialog(AlertDialog(
          title: Text('Information'.tr),
          content: Text(
              'Please complete your document verification to go online.'.tr),
          actions: [
            TextButton(child: Text('OK'.tr), onPressed: () => Get.back()),
          ],
        ));
        return; // Stop execution
      }
      // if (driverModel.value!.profileVerify != true) {
      //   Get.dialog(AlertDialog(
      //     title: Text('Information'.tr),
      //     content: Text(
      //         'Your profile is not yet verified by admin. Please wait for approval.'
      //             .tr),
      //     actions: [
      //       TextButton(child: Text('OK'.tr), onPressed: () => Get.back()),
      //     ],
      //   ));
      //   return; // Stop execution
      // }
    }

    ShowToastDialog.showLoader("Updating Status...");
    isOnline.value = value;
    try {
      // Update the 'isOnline' field in Firestore
      driverModel.value!.isOnline = isOnline.value;
      await FireStoreUtils.updateDriverUser(driverModel.value!);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(
          isOnline.value ? "You are now Online" : "You are now Offline");
    } catch (e) {
      // Revert the switch if the update fails
      isOnline.value = !value;
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to update status: $e");
    }
  }

  Rx<DateTime> currentBackPressTime = DateTime.now().obs;

  Future<bool> onWillPop() {
    DateTime now = DateTime.now();
    if (now.difference(currentBackPressTime.value) >
        const Duration(seconds: 2)) {
      currentBackPressTime.value = now;
      ShowToastDialog.showToast("Double press to exit",
          position: EasyLoadingToastPosition.center);
      return Future.value(false);
    }
    return Future.value(true);
  }
}

class DrawerItem {
  String title;
  String icon;

  DrawerItem(this.title, this.icon);
}
