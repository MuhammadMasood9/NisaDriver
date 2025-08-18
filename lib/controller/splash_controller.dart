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

  redirectScreen() async {
    // Use FireStoreUtils.isLogin() for robust login check
    bool isLogin = await FireStoreUtils.isLogin();
    if (isLogin) {
      Get.offAll(const DashBoardScreen());
    } else {
      Get.offAll(const LoginScreen());
    }
  }
}
