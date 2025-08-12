import 'dart:async';

import 'package:driver/constant/constant.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/ui/auth_screen/login_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/ui/on_boarding_screen.dart';
import 'package:driver/utils/Preferences.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    // TODO: implement onInit
    Timer(const Duration(seconds: 3), () => redirectScreen());
    super.onInit();
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
