import 'dart:developer';
import 'dart:io';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/login_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/ui/auth_screen/information_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/ui/subscription_plan_screen/subscription_list_screen.dart';
import 'package:driver/ui/terms_and_condition/terms_and_condition_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<LoginController>(
      init: LoginController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  "assets/images/login_image.png",
                  fit: BoxFit.fill,
                  width: Responsive.width(100, context),
                  height: Responsive.width(50, context),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          "Login".tr,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          "Welcome Back! We are happy to have \n you back".tr,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Tab Bar for Phone/Email Login
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.textField,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    controller.loginMethod.value = 'phone',
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color:
                                        controller.loginMethod.value == 'phone'
                                            ? AppColors.primary
                                            : AppColors.textField,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Phone".tr,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: controller.loginMethod.value ==
                                              'phone'
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    controller.loginMethod.value = 'email',
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color:
                                        controller.loginMethod.value == 'email'
                                            ? AppColors.primary
                                            : AppColors.textField,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Email".tr,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: controller.loginMethod.value ==
                                              'email'
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Form based on selected login method
                      Form(
                        key: controller.formKey.value ?? GlobalKey<FormState>(),
                        child: Obx(() => controller.loginMethod.value == 'phone'
                            ? TextFormField(
                                validator: (value) =>
                                    value != null && value.isNotEmpty
                                        ? null
                                        : 'Phone number is required'.tr,
                                keyboardType: TextInputType.number,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                controller:
                                    controller.phoneNumberController.value,
                                textAlign: TextAlign.start,
                                style: GoogleFonts.poppins(color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: AppColors.textField,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  prefixIcon: CountryCodePicker(
                                    onChanged: (value) {
                                      controller.countryCode.value =
                                          value.dialCode.toString();
                                    },
                                    dialogBackgroundColor: AppColors.background,
                                    initialSelection:
                                        controller.countryCode.value,
                                    comparator: (a, b) =>
                                        b.name!.compareTo(a.name.toString()),
                                    flagDecoration: const BoxDecoration(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(2)),
                                    ),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(4)),
                                    borderSide: BorderSide(
                                        color: AppColors.textFieldBorder,
                                        width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(4)),
                                    borderSide: BorderSide(
                                        color: AppColors.textFieldBorder,
                                        width: 1),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(4)),
                                    borderSide: BorderSide(
                                        color: AppColors.textFieldBorder,
                                        width: 1),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(4)),
                                    borderSide: BorderSide(
                                        color: AppColors.textFieldBorder,
                                        width: 1),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(4)),
                                    borderSide: BorderSide(
                                        color: AppColors.textFieldBorder,
                                        width: 1),
                                  ),
                                  hintText: "Phone number".tr,
                                ),
                              )
                            : Column(
                                children: [
                                  TextFormField(
                                    validator: (value) =>
                                        value != null && value.isNotEmpty
                                            ? (Constant.validateEmail(value)
                                                ? null
                                                : 'Invalid email'.tr)
                                            : 'Email is required'.tr,
                                    keyboardType: TextInputType.emailAddress,
                                    controller:
                                        controller.emailController.value,
                                    style: GoogleFonts.poppins(
                                        color: Colors.black),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: AppColors.textField,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12),
                                      prefixIcon: const Icon(Icons.email,
                                          color: Colors.black),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                        borderSide: BorderSide(
                                            color: AppColors.textFieldBorder,
                                            width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                        borderSide: BorderSide(
                                            color: AppColors.textFieldBorder,
                                            width: 1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                        borderSide: BorderSide(
                                            color: AppColors.textFieldBorder,
                                            width: 1),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                        borderSide: BorderSide(
                                            color: AppColors.textFieldBorder,
                                            width: 1),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                        borderSide: BorderSide(
                                            color: AppColors.textFieldBorder,
                                            width: 1),
                                      ),
                                      hintText: "Email".tr,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    validator: (value) => value != null &&
                                            value.isNotEmpty
                                        ? value.length >= 6
                                            ? null
                                            : 'Password must be at least 6 characters'
                                                .tr
                                        : 'Password is required'.tr,
                                    obscureText:
                                        controller.obscurePassword.value,
                                    controller:
                                        controller.passwordController.value,
                                    style: GoogleFonts.poppins(
                                        color: Colors.black),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: AppColors.textField,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12),
                                      prefixIcon: const Icon(Icons.lock,
                                          color: Colors.black),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          controller.obscurePassword.value
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.black,
                                        ),
                                        onPressed: () {
                                          controller.obscurePassword.value =
                                              !controller.obscurePassword.value;
                                        },
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                        borderSide: BorderSide(
                                            color: AppColors.textFieldBorder,
                                            width: 1),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                        borderSide: BorderSide(
                                            color: AppColors.textFieldBorder,
                                            width: 1),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                        borderSide: BorderSide(
                                            color: AppColors.textFieldBorder,
                                            width: 1),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                        borderSide: BorderSide(
                                            color: AppColors.textFieldBorder,
                                            width: 1),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(4)),
                                        borderSide: BorderSide(
                                            color: AppColors.textFieldBorder,
                                            width: 1),
                                      ),
                                      hintText: "Password".tr,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        if (controller.emailController.value
                                            .text.isEmpty) {
                                          ShowToastDialog.showToast(
                                              "Please enter your email".tr);
                                        } else if (!Constant.validateEmail(
                                            controller
                                                .emailController.value.text)) {
                                          ShowToastDialog.showToast(
                                              "Please enter a valid email".tr);
                                        } else {
                                          FirebaseAuth.instance
                                              .sendPasswordResetEmail(
                                                  email: controller
                                                      .emailController
                                                      .value
                                                      .text)
                                              .then((_) {
                                            ShowToastDialog.showToast(
                                                "Password reset email sent".tr);
                                          }).catchError((error) {
                                            ShowToastDialog.showToast(
                                                "Failed to send reset email: $error"
                                                    .tr);
                                          });
                                        }
                                      },
                                      child: Text(
                                        "Forgot Password?".tr,
                                        style: GoogleFonts.poppins(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                      ),
                      const SizedBox(height: 20),
                      ButtonThem.buildButton(
                        context,
                        title: controller.loginMethod.value == 'phone'
                            ? "Next".tr
                            : "Login with Email".tr,
                        onPress: () {
                          if (controller.formKey.value != null &&
                              controller.formKey.value.currentState!
                                  .validate()) {
                            try {
                              if (controller.loginMethod.value == 'phone') {
                                controller.sendCode();
                              } else {
                                controller.signInWithEmail();
                              }
                            } catch (e) {
                              ShowToastDialog.showToast("Error: $e".tr);
                            }
                          } else {
                            ShowToastDialog.showToast(
                                "Please fill all required fields".tr);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 40),
                        child: Row(
                          children: [
                            const Expanded(child: Divider(height: 1)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                "Or".tr,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(height: 1)),
                          ],
                        ),
                      ),
                      ButtonThem.buildBorderButton(
                        context,
                        title: "Login with Google".tr,
                        iconVisibility: true,
                        iconAssetImage: 'assets/icons/ic_google.png',
                        onPress: () async {
                          ShowToastDialog.showLoader("Please wait".tr);
                          await controller.signInWithGoogle().then((value) {
                            ShowToastDialog.closeLoader();
                            if (value != null) {
                              if (value.additionalUserInfo!.isNewUser) {
                                log("----->new user");
                                DriverUserModel userModel = DriverUserModel();
                                userModel.id = value.user!.uid;
                                userModel.email = value.user!.email;
                                userModel.fullName = value.user!.displayName;
                                userModel.profilePic = value.user!.photoURL;
                                userModel.loginType = Constant.googleLoginType;

                                Get.to(const InformationScreen(), arguments: {
                                  "userModel": userModel,
                                });
                              } else {
                                log("----->old user");
                                FireStoreUtils.userExitOrNot(value.user!.uid)
                                    .then((userExit) async {
                                  if (userExit == true) {
                                    String token =
                                        await NotificationService.getToken();
                                    DriverUserModel userModel =
                                        DriverUserModel();
                                    userModel.fcmToken = token;
                                    await FireStoreUtils.updateDriverUser(
                                        userModel);
                                    await FireStoreUtils.getDriverProfile(
                                            FirebaseAuth
                                                .instance.currentUser!.uid)
                                        .then((value) {
                                      if (value != null) {
                                        DriverUserModel userModel = value;
                                        bool isPlanExpire = false;
                                        if (userModel.subscriptionPlan?.id !=
                                            null) {
                                          if (userModel
                                                  .subscriptionExpiryDate ==
                                              null) {
                                            if (userModel.subscriptionPlan
                                                    ?.expiryDay ==
                                                '-1') {
                                              isPlanExpire = false;
                                            } else {
                                              isPlanExpire = true;
                                            }
                                          } else {
                                            DateTime expiryDate = userModel
                                                .subscriptionExpiryDate!
                                                .toDate();
                                            isPlanExpire = expiryDate
                                                .isBefore(DateTime.now());
                                          }
                                        } else {
                                          isPlanExpire = true;
                                        }
                                        if (userModel.subscriptionPlanId ==
                                                null ||
                                            isPlanExpire == true) {
                                          if (Constant.adminCommission
                                                      ?.isEnabled ==
                                                  false &&
                                              Constant.isSubscriptionModelApplied ==
                                                  false) {
                                            ShowToastDialog.closeLoader();
                                            Get.offAll(const DashBoardScreen());
                                          } else {
                                            ShowToastDialog.closeLoader();
                                            Get.offAll(
                                                const SubscriptionListScreen(),
                                                arguments: {"isShow": true});
                                          }
                                        } else {
                                          Get.offAll(const DashBoardScreen());
                                        }
                                      }
                                    });
                                  } else {
                                    DriverUserModel userModel =
                                        DriverUserModel();
                                    userModel.id = value.user!.uid;
                                    userModel.email = value.user!.email;
                                    userModel.fullName =
                                        value.user!.displayName;
                                    userModel.profilePic = value.user!.photoURL;
                                    userModel.loginType =
                                        Constant.googleLoginType;

                                    Get.to(const InformationScreen(),
                                        arguments: {
                                          "userModel": userModel,
                                        });
                                  }
                                });
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Visibility(
                        visible: Platform.isIOS,
                        child: ButtonThem.buildBorderButton(
                          context,
                          title: "Login with Apple".tr,
                          iconVisibility: true,
                          iconAssetImage: 'assets/icons/ic_apple.png',
                          iconColor: Colors.black,
                          onPress: () async {
                            ShowToastDialog.showLoader("Please wait".tr);
                            await controller.signInWithApple().then((value) {
                              ShowToastDialog.closeLoader();
                              if (value != null) {
                                Map<String, dynamic> map = value;
                                AuthorizationCredentialAppleID appleCredential =
                                    map['appleCredential'];
                                UserCredential userCredential =
                                    map['userCredential'];

                                if (value != null) {
                                  if (userCredential
                                      .additionalUserInfo!.isNewUser) {
                                    log("----->new user");
                                    DriverUserModel userModel =
                                        DriverUserModel();
                                    userModel.id = userCredential.user!.uid;
                                    userModel.profilePic =
                                        userCredential.user!.photoURL;
                                    userModel.loginType =
                                        Constant.appleLoginType;
                                    userModel.email = userCredential
                                        .additionalUserInfo!.profile!['email'];
                                    userModel.fullName =
                                        "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}";

                                    Get.to(const InformationScreen(),
                                        arguments: {
                                          "userModel": userModel,
                                        });
                                  } else {
                                    log("----->old user");
                                    FireStoreUtils.userExitOrNot(
                                            userCredential.user!.uid)
                                        .then((userExit) async {
                                      if (userExit == true) {
                                        await FireStoreUtils.getDriverProfile(
                                                FirebaseAuth
                                                    .instance.currentUser!.uid)
                                            .then((value) {
                                          if (value != null) {
                                            DriverUserModel userModel = value;
                                            bool isPlanExpire = false;
                                            if (userModel
                                                    .subscriptionPlan?.id !=
                                                null) {
                                              if (userModel
                                                      .subscriptionExpiryDate ==
                                                  null) {
                                                if (userModel.subscriptionPlan
                                                        ?.expiryDay ==
                                                    '-1') {
                                                  isPlanExpire = false;
                                                } else {
                                                  isPlanExpire = true;
                                                }
                                              } else {
                                                DateTime expiryDate = userModel
                                                    .subscriptionExpiryDate!
                                                    .toDate();
                                                isPlanExpire = expiryDate
                                                    .isBefore(DateTime.now());
                                              }
                                            } else {
                                              isPlanExpire = true;
                                            }
                                            if (userModel.subscriptionPlanId ==
                                                    null ||
                                                isPlanExpire == true) {
                                              if (Constant.adminCommission
                                                          ?.isEnabled ==
                                                      false &&
                                                  Constant.isSubscriptionModelApplied ==
                                                      false) {
                                                ShowToastDialog.closeLoader();
                                                Get.offAll(
                                                    const DashBoardScreen());
                                              } else {
                                                ShowToastDialog.closeLoader();
                                                Get.offAll(
                                                    const SubscriptionListScreen(),
                                                    arguments: {
                                                      "isShow": true
                                                    });
                                              }
                                            } else {
                                              Get.offAll(
                                                  const DashBoardScreen());
                                            }
                                          }
                                        });
                                      } else {
                                        DriverUserModel userModel =
                                            DriverUserModel();
                                        userModel.id = userCredential.user!.uid;
                                        userModel.profilePic =
                                            userCredential.user!.photoURL;
                                        userModel.loginType =
                                            Constant.appleLoginType;
                                        userModel.email = userCredential
                                            .additionalUserInfo!
                                            .profile!['email'];
                                        userModel.fullName =
                                            "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}";

                                        Get.to(const InformationScreen(),
                                            arguments: {
                                              "userModel": userModel,
                                            });
                                      }
                                    });
                                  }
                                }
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            text: "Don't have an account? ".tr,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Get.to(const InformationScreen());
                                  },
                                text: 'Sign Up'.tr,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text.rich(
              textAlign: TextAlign.center,
              TextSpan(
                text: 'By tapping "Next" you agree to '.tr,
                style: GoogleFonts.poppins(),
                children: <TextSpan>[
                  TextSpan(
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Get.to(const TermsAndConditionScreen(type: "terms"));
                      },
                    text: 'Terms and conditions'.tr,
                    style: GoogleFonts.poppins(
                        decoration: TextDecoration.underline),
                  ),
                  TextSpan(text: ' and ', style: GoogleFonts.poppins()),
                  TextSpan(
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Get.to(const TermsAndConditionScreen(type: "privacy"));
                      },
                    text: 'Privacy policy'.tr,
                    style: GoogleFonts.poppins(
                        decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
