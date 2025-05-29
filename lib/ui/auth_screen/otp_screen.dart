import 'dart:developer';

import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/otp_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/auth_screen/information_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/ui/subscription_plan_screen/subscription_list_screen.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import '../../themes/responsive.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({Key? key}) : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final isDark = themeChange.getThem();

    return GetX<OtpController>(
        init: OtpController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFAFBFC),
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Header Section with improved design
                    Container(
                      width: double.infinity,
                      height: 250,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        image: const DecorationImage(
                          image: AssetImage("assets/images/login_image.png"),
                          fit: BoxFit.fill,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            // Back button removed as per original code
                            // Icon
                            Container(
                              margin: EdgeInsets.only(top: 40),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.security_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Content Section
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),

                              // Title
                              Text(
                                "Verify Phone Number".tr,
                                style: AppTypography.boldHeaders(context),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 12),

                              // Subtitle
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      height: 1.5,
                                    ),
                                    children: [
                                      TextSpan(
                                          text:
                                              "We've sent a verification code to"
                                                  .tr,
                                          style:
                                              AppTypography.caption(context)),
                                      TextSpan(
                                        text:
                                            "\n${controller.countryCode.value + controller.phoneNumber.value}",
                                        style: AppTypography.headers(context)
                                            .copyWith(color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 30),

                              // OTP Input
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: PinCodeTextField(
                                  length: 6,
                                  appContext: context,
                                  keyboardType: TextInputType.number,
                                  animationType: AnimationType.slide,
                                  animationDuration:
                                      const Duration(milliseconds: 300),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  pinTheme: PinTheme(
                                    fieldHeight: 56,
                                    fieldWidth: 48,
                                    borderWidth: 2,
                                    activeColor: AppColors.primary,
                                    selectedColor:
                                        AppColors.primary.withOpacity(0.7),
                                    inactiveColor: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                    activeFillColor: isDark
                                        ? const Color(0xFF1F1F1F)
                                        : Colors.white,
                                    inactiveFillColor: isDark
                                        ? const Color(0xFF1A1A1A)
                                        : const Color(0xFFF8F9FA),
                                    selectedFillColor: isDark
                                        ? const Color(0xFF1F1F1F)
                                        : Colors.white,
                                    shape: PinCodeFieldShape.box,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                  enableActiveFill: true,
                                  cursorColor: AppColors.primary,
                                  controller: controller.otpController.value,
                                  onCompleted: (v) async {
                                    HapticFeedback.lightImpact();
                                  },
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      HapticFeedback.selectionClick();
                                    }
                                  },
                                ),
                              ),

                              const SizedBox(height: 22),

                              // Resend Code
                              TextButton.icon(
                                onPressed: () {
                                  // Add resend functionality
                                  HapticFeedback.lightImpact();
                                  // controller.resendOtp();
                                },
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  "Didn't receive code? Resend".tr,
                                  style: AppTypography.headers(context)
                                      .copyWith(color: AppColors.primary),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Verify Button
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.darkBackground,
                                      AppColors.darkBackground.withOpacity(0.9),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.darkBackground
                                          .withOpacity(0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      HapticFeedback.mediumImpact();

                                      if (controller.otpController.value.text
                                              .length ==
                                          6) {
                                        ShowToastDialog.showLoader(
                                            "Verify OTP".tr);

                                        PhoneAuthCredential credential =
                                            PhoneAuthProvider.credential(
                                                verificationId: controller
                                                    .verificationId.value,
                                                smsCode: controller
                                                    .otpController.value.text);

                                        await FirebaseAuth.instance
                                            .signInWithCredential(credential)
                                            .then((value) async {
                                          if (value
                                              .additionalUserInfo!.isNewUser) {
                                            log("----->new user");
                                            DriverUserModel userModel =
                                                DriverUserModel();
                                            userModel.id = value.user!.uid;
                                            userModel.countryCode =
                                                controller.countryCode.value;
                                            userModel.phoneNumber =
                                                controller.phoneNumber.value;
                                            userModel.loginType =
                                                Constant.phoneLoginType;

                                            ShowToastDialog.closeLoader();
                                            Get.off(const InformationScreen(),
                                                arguments: {
                                                  "userModel": userModel,
                                                });
                                          } else {
                                            log("----->old user");
                                            FireStoreUtils.userExitOrNot(
                                                    value.user!.uid)
                                                .then((userExit) async {
                                              ShowToastDialog.closeLoader();
                                              if (userExit == true) {
                                                await FireStoreUtils
                                                        .getDriverProfile(
                                                            value.user!.uid)
                                                    .then(
                                                  (value) {
                                                    if (value != null) {
                                                      DriverUserModel
                                                          userModel = value;
                                                      bool isPlanExpire = false;
                                                      if (userModel
                                                              .subscriptionPlan
                                                              ?.id !=
                                                          null) {
                                                        if (userModel
                                                                .subscriptionExpiryDate ==
                                                            null) {
                                                          if (userModel
                                                                  .subscriptionPlan
                                                                  ?.expiryDay ==
                                                              '-1') {
                                                            isPlanExpire =
                                                                false;
                                                          } else {
                                                            isPlanExpire = true;
                                                          }
                                                        } else {
                                                          DateTime expiryDate =
                                                              userModel
                                                                  .subscriptionExpiryDate!
                                                                  .toDate();
                                                          isPlanExpire =
                                                              expiryDate.isBefore(
                                                                  DateTime
                                                                      .now());
                                                        }
                                                      } else {
                                                        isPlanExpire = true;
                                                      }
                                                      if (userModel
                                                                  .subscriptionPlanId ==
                                                              null ||
                                                          isPlanExpire ==
                                                              true) {
                                                        if (Constant.adminCommission
                                                                    ?.isEnabled ==
                                                                false &&
                                                            Constant.isSubscriptionModelApplied ==
                                                                false) {
                                                          Get.offAll(
                                                              const DashBoardScreen());
                                                        } else {
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
                                                  },
                                                );
                                              } else {
                                                DriverUserModel userModel =
                                                    DriverUserModel();
                                                userModel.id = value.user!.uid;
                                                userModel.countryCode =
                                                    controller
                                                        .countryCode.value;
                                                userModel.phoneNumber =
                                                    controller
                                                        .phoneNumber.value;
                                                userModel.loginType =
                                                    Constant.phoneLoginType;

                                                Get.off(
                                                    const InformationScreen(),
                                                    arguments: {
                                                      "userModel": userModel,
                                                    });
                                              }
                                            });
                                          }
                                        }).catchError((error) {
                                          ShowToastDialog.closeLoader();
                                          ShowToastDialog.showToast(
                                              "Code is Invalid".tr);
                                        });
                                      } else {
                                        ShowToastDialog.showToast(
                                            "Please Enter Valid OTP".tr);
                                      }
                                    },
                                    child: Center(
                                      child: Text(
                                        "Verify".tr,
                                        style:
                                            AppTypography.buttonlight(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Security Notice
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.amber.withOpacity(0.1)
                                      : Colors.amber.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.amber[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Keep your code secure and don't share it with anyone"
                                            .tr,
                                        style: AppTypography.boldLabel(context)
                                            .copyWith(
                                          color: isDark
                                              ? Colors.amber[200]
                                              : Colors.amber[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
