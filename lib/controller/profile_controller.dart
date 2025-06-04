import 'package:firebase_auth/firebase_auth.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class ProfileController extends GetxController {
  RxBool isLoading = true.obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;
  RxBool isOtpSent = false.obs;

  Rx<TextEditingController> fullNameController = TextEditingController().obs;
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> phoneNumberController = TextEditingController().obs;
  Rx<TextEditingController> otpController = TextEditingController().obs;
  RxString countryCode = "+1".obs;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? verificationId;

  @override
  void onInit() {
    getData();
    super.onInit();
  }

  getData() async {
    String? driverId = FireStoreUtils.getCurrentUid();
    if (driverId == null) {
      isLoading.value = false;
      return;
    }
    await FireStoreUtils.getDriverProfile(driverId).then((value) {
      if (value != null) {
        driverModel.value = value;
        phoneNumberController.value.text =
            driverModel.value.phoneNumber.toString();
        countryCode.value = driverModel.value.countryCode.toString();
        emailController.value.text = driverModel.value.email.toString();
        fullNameController.value.text = driverModel.value.fullName.toString();
        profileImage.value = driverModel.value.profilePic ?? '';
        isLoading.value = false;
      }
    });
  }

  final ImagePicker _imagePicker = ImagePicker();
  RxString profileImage = "".obs;

  Future pickFile({required ImageSource source}) async {
    try {
      XFile? image = await _imagePicker.pickImage(source: source);
      if (image == null) return;
      Get.back();
      profileImage.value = image.path;
    } on PlatformException catch (e) {
      ShowToastDialog.showToast("Failed to Pick : \n $e");
    }
  }

  Future<void> sendOtp() async {
    String phoneNumber = '$countryCode${phoneNumberController.value.text}';
    ShowToastDialog.showLoader("Sending OTP...".tr);
    print("Num:$phoneNumber");

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Auto-verified successfully".tr);
          driverModel.value.profileVerify = true;
          await FireStoreUtils.updateDriverUser(driverModel.value);
        },
        verificationFailed: (FirebaseAuthException e) {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Verification failed: ${e.message}".tr);
        },
        codeSent: (String verId, int? resendToken) {
          ShowToastDialog.closeLoader();
          verificationId = verId;
          isOtpSent.value = true;
          ShowToastDialog.showToast("OTP sent to $phoneNumber".tr);
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
      );
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error: $e".tr);
    }
  }

  Future<void> verifyOtp() async {
    ShowToastDialog.showLoader("Verifying OTP...".tr);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpController.value.text,
      );
      await _auth.signInWithCredential(credential);
      driverModel.value.profileVerify = true;
      await FireStoreUtils.updateDriverUser(driverModel.value);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Profile verified successfully".tr);
      isOtpSent.value = false;
      otpController.value.clear();
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Invalid OTP: $e".tr);
    }
  }
}
