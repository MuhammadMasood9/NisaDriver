
import 'package:driver/controller/home_intercity_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ActiveInterCityOrderController extends GetxController{

  HomeIntercityController homeController = Get.put(HomeIntercityController());
  Rx<TextEditingController> otpController = TextEditingController().obs;

}