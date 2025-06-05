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
  RxInt otpStep = 1.obs;

  Rx<TextEditingController> fullNameController = TextEditingController().obs;
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> phoneNumberController = TextEditingController().obs;
  Rx<TextEditingController> otpController = TextEditingController().obs;
  RxString countryCode = "+1".obs;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? verificationId;
  int? _resendToken;

  @override
  void onInit() {
    // Remove appVerificationDisabledForTesting for production
    getData();
    super.onInit();
  }

  Future<void> getData() async {
    try {
      String? driverId = FireStoreUtils.getCurrentUid();
      if (driverId == null) {
        ShowToastDialog.showToast("User not authenticated".tr);
        isLoading.value = false;
        return;
      }
      final value = await FireStoreUtils.getDriverProfile(driverId);
      if (value != null) {
        driverModel.value = value;
        phoneNumberController.value.text = value.phoneNumber ?? '';
        countryCode.value = value.countryCode ?? '+92';
        emailController.value.text = value.email ?? '';
        fullNameController.value.text = value.fullName ?? '';
        profileImage.value = value.profilePic ?? '';
        await syncProfileVerification();
      } else {
        ShowToastDialog.showToast("Driver profile not found".tr);
      }
    } catch (e) {
      ShowToastDialog.showToast("Error fetching profile: $e".tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> syncProfileVerification() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.phoneNumber != null) {
      String fullPhoneNumber =
          '${countryCode.value}${phoneNumberController.value.text}';
      if (currentUser.phoneNumber == fullPhoneNumber &&
          !driverModel.value.profileVerify!) {
        await updateFirestore(fullPhoneNumber);
        ShowToastDialog.showToast(
            "Profile verification synced with Firebase".tr);
      }
    }
  }

  final ImagePicker _imagePicker = ImagePicker();
  RxString profileImage = "".obs;

  Future<void> pickFile({required ImageSource source}) async {
    try {
      XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        profileImage.value = image.path;
      }
    } on PlatformException catch (e) {
      ShowToastDialog.showToast("Failed to pick image: $e".tr);
    }
  }

  Future<void> sendOtp() async {
    String phoneNumber =
        '${countryCode.value}${phoneNumberController.value.text}';
    if (phoneNumber.isEmpty || phoneNumber.length < 10) {
      ShowToastDialog.showToast("Invalid phone number".tr);
      return;
    }

    User? currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.phoneNumber == phoneNumber) {
      await updateFirestore(phoneNumber);
      ShowToastDialog.showToast("Phone number already verified".tr);
      return;
    }

    ShowToastDialog.showLoader("Sending OTP...".tr);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await handleCredential(credential, phoneNumber);
        },
        verificationFailed: (FirebaseAuthException e) {
          ShowToastDialog.closeLoader();
          String message = e.message ?? "Verification failed";
          if (e.code == 'invalid-phone-number') {
            message = "Invalid phone number format".tr;
          } else if (e.code == 'too-many-requests') {
            message = "Too many attempts. Try again later.".tr;
          } else if (e.code.contains('recaptcha')) {
            message = "reCAPTCHA verification failed. Please try again.".tr;
          }
          ShowToastDialog.showToast(message);
        },
        codeSent: (String verId, int? resendToken) {
          ShowToastDialog.closeLoader();
          verificationId = verId;
          _resendToken = resendToken;
          isOtpSent.value = true;
          otpStep.value = 2;
          ShowToastDialog.showToast("OTP sent to $phoneNumber".tr);
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error sending OTP: $e".tr);
    }
  }

  Future<void> handleCredential(
      PhoneAuthCredential credential, String phoneNumber) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("No authenticated user found".tr);
        return;
      }

      try {
        await updateFirestore(phoneNumber);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          UserCredential userCredential =
              await _auth.signInWithCredential(credential);
          if (userCredential.user?.uid == currentUser.uid) {
            await updateFirestore(phoneNumber);
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast(
                "Phone number already verified for this account".tr);
          } else {
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast(
                "This phone number is linked to another account. Please use a different number."
                    .tr);
          }
          resetOtpProcess();
          return;
        } else if (e.code == 'requires-recent-login') {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast(
              "Please re-authenticate to verify your phone number".tr);
          resetOtpProcess();
          return;
        }
        rethrow;
      }

      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Phone number verified successfully".tr);
      resetOtpProcess();
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error verifying phone number: $e".tr);
    }
  }

  Future<void> updateFirestore(String phoneNumber) async {
    driverModel.value.profileVerify = true;
    driverModel.value.phoneNumber = phoneNumberController.value.text;
    driverModel.value.countryCode = countryCode.value;
    await FireStoreUtils.updateDriverUser(driverModel.value);
  }

  Future<void> verifyOtp() async {
    if (verificationId == null) {
      ShowToastDialog.showToast("Verification ID is missing".tr);
      return;
    }
    if (otpController.value.text.isEmpty ||
        otpController.value.text.length < 6) {
      ShowToastDialog.showToast("Invalid OTP".tr);
      return;
    }

    ShowToastDialog.showLoader("Verifying OTP...".tr);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpController.value.text,
      );
      await handleCredential(credential,
          '${countryCode.value}${phoneNumberController.value.text}');
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Invalid OTP: $e".tr);
    }
  }

  void resetOtpProcess() {
    isOtpSent.value = false;
    otpStep.value = 1;
    otpController.value.clear();
    verificationId = null;
    _resendToken = null;
  }
}
