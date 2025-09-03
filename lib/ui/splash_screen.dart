import 'package:driver/controller/splash_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import 'package:driver/ui/auth_screen/login_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/services/login_service.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () async {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const DashBoardScreen()));
        // Get.offAll(const DashBoardScreen());
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const LoginScreen()));
        // Get.offAll(const LoginScreen());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Image.asset(
          "assets/app_logo.png",
          width: 200,
        ),
      ),
    );

    //   GetBuilder<SplashController>(
    //       init: SplashController(),
    //       builder: (controller) {
    //         return Scaffold(
    //           backgroundColor: AppColors.primary,
    //           body: Center(
    //               child: Image.asset(
    //             "assets/app_logo.png",
    //             width: 200,
    //           )),
    //         );
    //       });
  }
}
