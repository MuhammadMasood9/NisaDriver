import 'package:driver/controller/home_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ActiveOrderController extends GetxController {
  HomeController homeController = Get.put(HomeController());
  Rx<TextEditingController> otpController = TextEditingController().obs;
  RxBool isRefreshing = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize with current data
    refreshData();
  }

  // Method to refresh data when ride state changes
  void refreshData() {
    if (isRefreshing.value) return; // Prevent multiple simultaneous refreshes
    
    try {
      isRefreshing.value = true;
      
      // Trigger UI update immediately
      update();
      
      // Reset refreshing flag after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        isRefreshing.value = false;
      });
    } catch (e) {
      isRefreshing.value = false;
      if (kDebugMode) {
        print("Error refreshing active order data: $e");
      }
    }
  }

  // Force refresh data immediately
  void forceRefresh() {
    isRefreshing.value = false;
    refreshData();
  }
}
