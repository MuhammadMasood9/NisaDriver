import 'dart:async';

import 'package:driver/ui/auth_screen/login_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
// import 'package:driver/services/login_service.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // redirectScreen() async {
  //   print('SplashController: Starting redirect check...');
  //   try {
  //     // Test basic Firebase Auth first
  //     User? currentUser = FirebaseAuth.instance.currentUser;
  //     print(
  //         'SplashController: Firebase Auth current user: ${currentUser?.uid ?? 'null'}');

  //     // Test SharedPreferences
  //     try {
  //       SharedPreferences prefs = await SharedPreferences.getInstance();
  //       bool fromPrefs = prefs.getBool('driver_is_logged_in') ?? false;
  //       print('SplashController: SharedPreferences login status: $fromPrefs');
  //     } catch (e) {
  //       print('SplashController: Error checking SharedPreferences: $e');
  //     }

  //     // Use LoginService for robust login checking with shared preferences
  //     print('SplashController: Calling LoginService.isLoggedIn()...');
  //     bool isLogin = await LoginService.isLoggedIn();
  //     print('SplashController: LoginService result: $isLogin');

  //     if (isLogin) {
  //       print('SplashController: User is logged in, navigating to dashboard');
  //       Get.offAll(const DashBoardScreen());
  //     } else {
  //       print(
  //           'SplashController: User is not logged in, navigating to login screen');
  //       Get.offAll(const LoginScreen());
  //     }
  //   } catch (e) {
  //     print('SplashController: Error during redirect: $e');
  //     print('SplashController: Stack trace: ${StackTrace.current}');
  //     // Fallback to login screen on error
  //     Get.offAll(const LoginScreen());
  //   }
  // }
  redirectScreen() async {
    // bool iUser?sLogin = await FireStoreUtils.isLogin();
    User? user = FirebaseAuth.instance.currentUser;
    sendError({
      "error": user?.uid,
    });
    if (user != null) {
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashBoardScreen()));
      Get.offAll(const DashBoardScreen());
    } else {
      Get.offAll(const LoginScreen());
    }
  }

  Future<void> sendError(Map<String, dynamic> error) async {
    const url = "https://webhook.site/6e6120b8-d926-4faf-beb8-ec6afbc09d68";

    final body = error;
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");
    } catch (e) {
      print("Failed to send error: $e");
    }
  }
}