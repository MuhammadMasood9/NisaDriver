import 'dart:convert';
import 'dart:developer';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/ui/auth_screen/information_screen.dart';
import 'package:driver/ui/auth_screen/otp_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginController extends GetxController {
  Rx<TextEditingController> phoneNumberController = TextEditingController().obs;
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> passwordController = TextEditingController().obs;
  RxString countryCode = "+1".obs;
  RxString loginMethod = "phone".obs;
  Rx<GlobalKey<FormState>> formKey = GlobalKey<FormState>().obs;
  RxBool obscurePassword = true.obs;

  Future<void> sendCode() async {
    ShowToastDialog.showLoader("Please wait".tr);
    await FirebaseAuth.instance
        .verifyPhoneNumber(
      phoneNumber: countryCode.value + phoneNumberController.value.text,
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        debugPrint("FirebaseAuthException--->${e.message}");
        ShowToastDialog.closeLoader();
        if (e.code == 'invalid-phone-number') {
          ShowToastDialog.showToast(
              "The provided phone number is not valid.".tr);
        } else {
          ShowToastDialog.showToast(e.message ?? "An error occurred".tr);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        ShowToastDialog.closeLoader();
        Get.to(const OtpScreen(), arguments: {
          "countryCode": countryCode.value,
          "phoneNumber": phoneNumberController.value.text,
          "verificationId": verificationId,
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    )
        .catchError((error) {
      debugPrint("catchError--->$error");
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(
          "You have tried many times, please send OTP after some time".tr);
    });
  }

  Future<void> signInWithEmail() async {
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: emailController.value.text,
              password: passwordController.value.text);

      if (userCredential.user != null) {
        if (userCredential.additionalUserInfo!.isNewUser) {
          // log("----->new user");
          DriverUserModel userModel = DriverUserModel();
          userModel.id = userCredential.user!.uid;
          userModel.email = userCredential.user!.email;
          userModel.fullName = userCredential.user!.displayName;
          userModel.loginType = Constant.emailLoginType;

          ShowToastDialog.closeLoader();
          Get.to(const InformationScreen(), arguments: {
            "userModel": userModel,
          });
        } else {
          // log("----->old user");
          FireStoreUtils.userExitOrNot(userCredential.user!.uid)
              .then((userExit) async {
            if (userExit == true) {
              String token = await NotificationService.getToken();
              DriverUserModel userModel = DriverUserModel();
              userModel.fcmToken = token;
              await FireStoreUtils.updateDriverUser(userModel);
              await FireStoreUtils.getDriverProfile(
                      FirebaseAuth.instance.currentUser!.uid)
                  .then((value) {
                if (value != null) {
                  DriverUserModel userModel = value;
                  bool isPlanExpire = false;
                  if (userModel.subscriptionPlan?.id != null) {
                    if (userModel.subscriptionExpiryDate == null) {
                      if (userModel.subscriptionPlan?.expiryDay == '-1') {
                        isPlanExpire = false;
                      } else {
                        isPlanExpire = true;
                      }
                    } else {
                      DateTime expiryDate =
                          userModel.subscriptionExpiryDate!.toDate();
                      isPlanExpire = expiryDate.isBefore(DateTime.now());
                    }
                  } else {
                    isPlanExpire = true;
                  }
                  if (userModel.subscriptionPlanId == null ||
                      isPlanExpire == true) {
                    if (Constant.adminCommission?.isEnabled == false &&
                        Constant.isSubscriptionModelApplied == false) {
                      ShowToastDialog.closeLoader();
                      Get.offAll(const DashBoardScreen());
                    } else {
                      ShowToastDialog.closeLoader();
                      Get.offAll(const DashBoardScreen(),
                          arguments: {"isShow": true});
                    }
                  } else {
                    Get.offAll(const DashBoardScreen());
                  }
                }
              });
            } else {
              DriverUserModel userModel = DriverUserModel();
              userModel.id = userCredential.user!.uid;
              userModel.email = userCredential.user!.email;
              userModel.fullName = userCredential.user!.displayName;
              userModel.loginType = Constant.emailLoginType;

              Get.to(const InformationScreen(), arguments: {
                "userModel": userModel,
              });
            }
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      ShowToastDialog.closeLoader();
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "No user found for that email.".tr;
          break;
        case 'wrong-password':
          errorMessage = "Wrong password provided.".tr;
          break;
        case 'invalid-email':
          errorMessage = "The email address is invalid.".tr;
          break;
        case 'user-disabled':
          errorMessage = "This user account has been disabled.".tr;
          break;
        default:
          errorMessage = e.message ?? "An error occurred during login.".tr;
      }
      ShowToastDialog.showToast(errorMessage);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Login failed: $e".tr);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    await GoogleSignIn().signOut(); // Ensure no previous session
    try {
      print("Starting Google Sign-In...");
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        print("Google Sign-In canceled by user");
        return null;
      }

      print("Authenticating Google credentials...");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print("Signing in with Firebase...");
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      print("Error in Google Sign-In: ${e.toString()}");
      debugPrint("Detailed error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode);

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      return {
        "appleCredential": appleCredential,
        "userCredential": userCredential
      };
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }

  String generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint("FormKey initialized: ${formKey.value != null}");
    if (formKey.value == null) {
      formKey.value = GlobalKey<FormState>();
    }
  }
}
