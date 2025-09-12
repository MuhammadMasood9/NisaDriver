import 'dart:async';
import 'dart:convert';

import 'package:driver/ui/auth_screen/login_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

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
    // Check if user is logged in
    User? user = FirebaseAuth.instance.currentUser;
    
    // Send debug info to webhook
    await sendError({
      "message": "Splash screen redirect check",
      "userId": user?.uid ?? "null",
      "userEmail": user?.email ?? "null",
      "timestamp": DateTime.now().toIso8601String(),
    });
    
    if (user != null) {
      // User is logged in, go to dashboard
      Get.offAll(const DashBoardScreen());
    } else {
      // User is not logged in, go to login screen
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
