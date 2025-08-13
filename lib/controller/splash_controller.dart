import 'dart:async';

import 'package:driver/ui/auth_screen/login_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _start();
  }

  Future<void> _start() async {
    // Keep splash visible briefly
    await Future.delayed(const Duration(seconds: 2));
    await redirectScreen();
  }

  Future<void> redirectScreen() async {
    try {
      // Prefer currentUser, but also wait briefly for auth state in case it isn't ready yet
      User? user = FirebaseAuth.instance.currentUser;
      user ??= await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 2), onTimeout: () => null);

      if (user != null) {
        // Do not block navigation on Firestore checks; user is authenticated
        try {
          // Optional: warm up Firestore/user doc
          await FireStoreUtils.userExitOrNot(user.uid);
        } catch (_) {}
        Get.offAll(const DashBoardScreen());
      } else {
        Get.offAll(const LoginScreen());
      }
    } catch (_) {
      // Fallback: if FirebaseAuth already has a user, go to dashboard
      final User? fallback = FirebaseAuth.instance.currentUser;
      if (fallback != null) {
        Get.offAll(const DashBoardScreen());
      } else {
        Get.offAll(const LoginScreen());
      }
    }
  }
}
