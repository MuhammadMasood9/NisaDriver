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
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/auth_screen/information_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
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
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: Responsive.height(10, context),
                        ),
                        Container(
                          decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10)),
                          child: Image.asset(
                            'assets/app_logo.png',
                            height: Responsive.height(10, context),
                            width: Responsive.height(10, context),
                          ),
                        ),
                        SizedBox(height: Responsive.height(3, context)),

                        const SizedBox(height: 10),
                        Text(
                          "Welcome Back! We are happy to have you back".tr,
                          style: AppTypography.caption(context),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: Responsive.height(5, context)),
                        // Tab Bar for Phone/Email Login
                        Container(
                          width: Responsive.width(80, context),
                          decoration: BoxDecoration(
                            color: AppColors.textField,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      controller.loginMethod.value = 'phone',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: controller.loginMethod.value ==
                                              'phone'
                                          ? AppColors.primary
                                          : AppColors.textField,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Phone".tr,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.boldLabel(context)
                                          .copyWith(
                                        color: controller.loginMethod.value ==
                                                'phone'
                                            ? Colors.white
                                            : Colors.black,
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      color: controller.loginMethod.value ==
                                              'email'
                                          ? AppColors.primary
                                          : AppColors.textField,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Email".tr,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.boldLabel(context)
                                          .copyWith(
                                        color: controller.loginMethod.value ==
                                                'email'
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: Responsive.height(5, context)),
// Form with Dissolve Animation
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return FadeTransition(
                                opacity: animation, child: child);
                          },
                          child: Form(
                            key: controller.formKey.value ??
                                GlobalKey<FormState>(),
                            child: Obx(
                              () => controller.loginMethod.value == 'phone'
                                  ? Container(
                                      width: Responsive.width(80, context),
                                      key: const ValueKey('phone'),
                                      child: TextFormField(
                                        validator: (value) =>
                                            value != null && value.isNotEmpty
                                                ? null
                                                : 'Phone number is required'.tr,
                                        keyboardType: TextInputType.number,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        controller: controller
                                            .phoneNumberController.value,
                                        textAlign: TextAlign.start,
                                        style: AppTypography.label(context),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: AppColors.background,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 10, horizontal: 12),
                                          prefixIcon: CountryCodePicker(
                                            onChanged: (value) {
                                              controller.countryCode.value =
                                                  value.dialCode.toString();
                                            },
                                            dialogBackgroundColor:
                                                AppColors.background,
                                            textStyle: AppTypography.boldLabel(
                                                context),
                                            initialSelection:
                                                controller.countryCode.value,
                                            comparator: (a, b) => b.name!
                                                .compareTo(a.name.toString()),
                                            flagDecoration: const BoxDecoration(
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(4)),
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: BorderSide(
                                                color:
                                                    AppColors.textFieldBorder,
                                                width: 1),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: BorderSide(
                                                color:
                                                    AppColors.textFieldBorder,
                                                width: 1),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: BorderSide(
                                                color: AppColors.primary,
                                                width: 1.5),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            borderSide: BorderSide(
                                                color: Colors.redAccent,
                                                width: 1),
                                          ),
                                          hintText: "Phone number".tr,
                                          hintStyle:
                                              AppTypography.label(context)
                                                  .copyWith(
                                                      color: AppColors.grey500),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      key: const ValueKey('email'),
                                      child: Column(
                                        children: [
                                          Container(
                                            width:
                                                Responsive.width(80, context),
                                            child: TextFormField(
                                              validator: (value) =>
                                                  value != null &&
                                                          value.isNotEmpty
                                                      ? (Constant.validateEmail(
                                                              value)
                                                          ? null
                                                          : 'Invalid email'.tr)
                                                      : 'Email is required'.tr,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              controller: controller
                                                  .emailController.value,
                                              style:
                                                  AppTypography.label(context),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                label: Text("Email",
                                                    style: AppTypography.input(
                                                        context)),
                                                filled: true,
                                                fillColor: AppColors.background,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 15,
                                                        horizontal: 12),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: AppColors
                                                          .textFieldBorder,
                                                      width: 1),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: AppColors
                                                          .textFieldBorder,
                                                      width: 1),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: AppColors.primary,
                                                      width: 1.5),
                                                ),
                                                errorBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: Colors.redAccent,
                                                      width: 1),
                                                ),
                                                hintText: "Email".tr,
                                                hintStyle: GoogleFonts.poppins(
                                                    color: Colors.grey[500]),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            width:
                                                Responsive.width(80, context),
                                            child: TextFormField(
                                              validator: (value) => value !=
                                                          null &&
                                                      value.isNotEmpty
                                                  ? value.length >= 6
                                                      ? null
                                                      : 'Password must be at least 6 characters'
                                                          .tr
                                                  : 'Password is required'.tr,
                                              obscureText: controller
                                                  .obscurePassword.value,
                                              controller: controller
                                                  .passwordController.value,
                                              style:
                                                  AppTypography.label(context),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                filled: true,
                                                label: Text("Password",
                                                    style: AppTypography.input(
                                                        context)),
                                                fillColor: AppColors.background,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                        horizontal: 12),
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    controller.obscurePassword
                                                            .value
                                                        ? Icons.visibility_off
                                                        : Icons.visibility,
                                                    color: Colors.black,
                                                  ),
                                                  onPressed: () {
                                                    controller.obscurePassword
                                                            .value =
                                                        !controller
                                                            .obscurePassword
                                                            .value;
                                                  },
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: AppColors
                                                          .textFieldBorder,
                                                      width: 1),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: AppColors
                                                          .textFieldBorder,
                                                      width: 1),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: AppColors.primary,
                                                      width: 1.5),
                                                ),
                                                errorBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: Colors.redAccent,
                                                      width: 1),
                                                ),
                                                hintText: "Password".tr,
                                                hintStyle: GoogleFonts.poppins(
                                                    color: Colors.grey[500]),
                                              ),
                                            ),
                                          ),
                                          // const SizedBox(height: 3),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: () {
                                                if (controller.emailController
                                                    .value.text.isEmpty) {
                                                  ShowToastDialog.showToast(
                                                      "Please enter your email"
                                                          .tr);
                                                } else if (!Constant
                                                    .validateEmail(controller
                                                        .emailController
                                                        .value
                                                        .text)) {
                                                  ShowToastDialog.showToast(
                                                      "Please enter a valid email"
                                                          .tr);
                                                } else {
                                                  FirebaseAuth.instance
                                                      .sendPasswordResetEmail(
                                                          email: controller
                                                              .emailController
                                                              .value
                                                              .text)
                                                      .then((_) {
                                                    ShowToastDialog.showToast(
                                                        "Password reset email sent"
                                                            .tr);
                                                  }).catchError((error) {
                                                    ShowToastDialog.showToast(
                                                        "Failed to send reset email: $error"
                                                            .tr);
                                                  });
                                                }
                                              },
                                              child: Text(
                                                "Forgot Password?".tr,
                                                style: AppTypography.boldLabel(
                                                        context)
                                                    .copyWith(
                                                        color: AppColors
                                                            .darkContainerBackground),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: Responsive.width(80, context),
                          child: ButtonThem.buildButton(
                            context,
                            title: controller.loginMethod.value == 'phone'
                                ? "Next".tr
                                : "Continue with Email".tr,
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
                        ),
                        SizedBox(height: Responsive.height(4, context)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Divider(
                                height: 1,
                                indent: 20,
                                color: Colors.grey[400],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                "Or".tr,
                                style: AppTypography.boldHeaders(context),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                height: 1,
                                endIndent: 20,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Container(
                          width: Responsive.width(80, context),
                          child: ButtonThem.buildBorderButton(
                            context,
                            title: "Continue with Google".tr,
                            iconVisibility: true,
                            iconAssetImage: 'assets/icons/ic_google.png',
                            onPress: () async {
                              ShowToastDialog.showLoader("Please wait".tr);
                              await controller.signInWithGoogle().then((value) {
                                ShowToastDialog.closeLoader();
                                if (value != null) {
                                  if (value.additionalUserInfo!.isNewUser) {
                                    log("----->new user");
                                    DriverUserModel userModel =
                                        DriverUserModel();
                                    userModel.id = value.user!.uid;
                                    userModel.email = value.user!.email;
                                    userModel.fullName =
                                        value.user!.displayName;
                                    userModel.profilePic = value.user!.photoURL;
                                    userModel.loginType =
                                        Constant.googleLoginType;
                                    userModel.profileVerify = true;
                                    Get.to(const InformationScreen(),
                                        arguments: {"userModel": userModel});
                                  } else {
                                    log("----->old user");
                                    FireStoreUtils.userExitOrNot(
                                            value.user!.uid)
                                        .then((userExit) async {
                                      log(" ms $userExit");
                                      if (userExit == true) {
                                        String token = await NotificationService
                                            .getToken();
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
                                                    const DashBoardScreen(),
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
                                        userModel.id = value.user!.uid;
                                        userModel.email = value.user!.email;
                                        userModel.fullName =
                                            value.user!.displayName;
                                        userModel.profilePic =
                                            value.user!.photoURL;
                                        userModel.loginType =
                                            Constant.googleLoginType;
                                        userModel.profileVerify = true;
                                        log("message");
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
                        ),
                        const SizedBox(height: 16),
                        Visibility(
                          visible: Platform.isIOS,
                          child: Container(
                            width: Responsive.width(80, context),
                            child: ButtonThem.buildBorderButton(
                              context,
                              title: "Login with Apple".tr,
                              iconVisibility: true,
                              iconAssetImage: 'assets/icons/ic_apple.png',
                              iconColor: Colors.black,
                              onPress: () async {
                                ShowToastDialog.showLoader("Please wait".tr);
                                await controller
                                    .signInWithApple()
                                    .then((value) {
                                  ShowToastDialog.closeLoader();
                                  if (value != null) {
                                    Map<String, dynamic> map = value;
                                    AuthorizationCredentialAppleID
                                        appleCredential =
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
                                            .additionalUserInfo!
                                            .profile!['email'];
                                        userModel.fullName =
                                            "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}";
                                        userModel.profileVerify = true;
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
                                            await FireStoreUtils
                                                    .getDriverProfile(
                                                        FirebaseAuth.instance
                                                            .currentUser!.uid)
                                                .then((value) {
                                              if (value != null) {
                                                DriverUserModel userModel =
                                                    value;
                                                bool isPlanExpire = false;
                                                if (userModel
                                                        .subscriptionPlan?.id !=
                                                    null) {
                                                  if (userModel
                                                          .subscriptionExpiryDate ==
                                                      null) {
                                                    if (userModel
                                                            .subscriptionPlan
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
                                                    isPlanExpire =
                                                        expiryDate.isBefore(
                                                            DateTime.now());
                                                  }
                                                } else {
                                                  isPlanExpire = true;
                                                }
                                                if (userModel
                                                            .subscriptionPlanId ==
                                                        null ||
                                                    isPlanExpire == true) {
                                                  if (Constant.adminCommission
                                                              ?.isEnabled ==
                                                          false &&
                                                      Constant.isSubscriptionModelApplied ==
                                                          false) {
                                                    ShowToastDialog
                                                        .closeLoader();
                                                    Get.offAll(
                                                        const DashBoardScreen());
                                                  } else {
                                                    ShowToastDialog
                                                        .closeLoader();
                                                    Get.offAll(
                                                        const DashBoardScreen(),
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
                                            userModel.id =
                                                userCredential.user!.uid;
                                            userModel.profilePic =
                                                userCredential.user!.photoURL;
                                            userModel.loginType =
                                                Constant.appleLoginType;
                                            userModel.email = userCredential
                                                .additionalUserInfo!
                                                .profile!['email'];
                                            userModel.fullName =
                                                "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}";
                                            userModel.profileVerify = true;
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
