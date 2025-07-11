// lib/ui/auth_screen/otp_screen.dart

import 'dart:developer';

import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/otp_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/auth_screen/information_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({Key? key}) : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  // Manage the TextEditingController locally within the State object for best practice.
  late final TextEditingController _pinController;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize the local controller
    _pinController = TextEditingController();

    // Still put the GetX controller for business logic
    Get.put(OtpController());

    // Animation initializations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500), // Added a smooth duration
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500), // Added a smooth duration
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

    // Start the animations
    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    // Dispose the local controller and animation controllers
    _pinController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetX<OtpController>(builder: (controller) {
      return Scaffold(
        appBar: AppBar(
          surfaceTintColor: AppColors.background,
          backgroundColor: AppColors.background,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        backgroundColor: AppColors.background,
        body: SafeArea(
          top: true,
          child: Column(
            children: [
              // Content Section (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: Responsive.width(10, context)),
                            Container(
                              decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(50)),
                              padding: const EdgeInsets.all(20),
                              child: Icon(
                                Icons.verified_user,
                                size: 40,
                                color: AppColors.background,
                              ),
                            ),
                            SizedBox(height: Responsive.width(5, context)),
                            Text("Verify Phone Number".tr,
                                style: AppTypography.h1(context),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      height: 1.5),
                                  children: [
                                    TextSpan(
                                        text:
                                            "We've sent a verification code to"
                                                .tr,
                                        style: AppTypography.caption(context)),
                                    TextSpan(
                                      text:
                                          "\n${controller.countryCode.value}${controller.phoneNumber.value}",
                                      style: AppTypography.headers(context)
                                          .copyWith(color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
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
                                  fieldHeight: 45,
                                  fieldWidth: 45,
                                  borderWidth: 0.5,
                                  activeColor: AppColors.primary,
                                  selectedColor:
                                      AppColors.primary.withOpacity(0.7),
                                  inactiveColor: Colors.grey[200]!,
                                  activeFillColor: Colors.white,
                                  inactiveFillColor: AppColors.background,
                                  selectedFillColor: Colors.white,
                                  shape: PinCodeFieldShape.box,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: AppTypography.headers(context),
                                enableActiveFill: true,
                                cursorColor: AppColors.primary,
                                controller:
                                    _pinController, // Using local controller
                                onCompleted: (v) =>
                                    HapticFeedback.lightImpact(),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    HapticFeedback.selectionClick();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 22),
                            TextButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                // You can call your resend OTP logic here if needed
                                // controller.resendOtp();
                              },
                              icon: Icon(Icons.refresh_rounded,
                                  size: 18, color: AppColors.primary),
                              label: Text("Didn't receive code? Resend".tr,
                                  style: AppTypography.boldLabel(context)
                                      .copyWith(color: AppColors.primary)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Verify Button (Stays at the bottom)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.darkBackground,
                      AppColors.darkBackground.withOpacity(0.9)
                    ]),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.darkBackground.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        HapticFeedback.mediumImpact();

                        // Read from the local controller and check length
                        if (_pinController.text.length == 6) {
                          ShowToastDialog.showLoader("Verify OTP".tr);
                          PhoneAuthCredential credential =
                              PhoneAuthProvider.credential(
                            verificationId: controller.verificationId.value,
                            smsCode: _pinController.text,
                          );

                          try {
                            final value = await FirebaseAuth.instance
                                .signInWithCredential(credential);

                            // --- ALL YOUR ORIGINAL DRIVER LOGIC IS PRESERVED HERE ---
                            if (value.additionalUserInfo!.isNewUser) {
                              log("----->new user");
                              DriverUserModel userModel = DriverUserModel(
                                id: value.user!.uid,
                                countryCode: controller.countryCode.value,
                                phoneNumber: controller.phoneNumber.value,
                                loginType: Constant.phoneLoginType,
                                profileVerify: true,
                              );

                              ShowToastDialog.closeLoader();
                              Get.off(() => const InformationScreen(),
                                  arguments: {"userModel": userModel});
                            } else {
                              log("----->old user");
                              final userExit =
                                  await FireStoreUtils.userExitOrNot(
                                      value.user!.uid);
                              ShowToastDialog.closeLoader();
                              if (userExit) {
                                DriverUserModel? userModel =
                                    await FireStoreUtils.getDriverProfile(
                                        value.user!.uid);

                                if (userModel != null) {
                                  // Your existing subscription check logic
                                  bool isPlanExpire = true;
                                  if (userModel.subscriptionPlan?.id != null) {
                                    if (userModel.subscriptionExpiryDate ==
                                        null) {
                                      isPlanExpire = userModel
                                              .subscriptionPlan?.expiryDay !=
                                          '-1';
                                    } else {
                                      isPlanExpire = userModel
                                          .subscriptionExpiryDate!
                                          .toDate()
                                          .isBefore(DateTime.now());
                                    }
                                  }

                                  if (userModel.subscriptionPlanId == null ||
                                      isPlanExpire) {
                                    if (Constant.adminCommission?.isEnabled ==
                                            false &&
                                        Constant.isSubscriptionModelApplied ==
                                            false) {
                                      Get.offAll(() => const DashBoardScreen());
                                    } else {
                                      Get.offAll(() => const DashBoardScreen(),
                                          arguments: {"isShow": true});
                                    }
                                  } else {
                                    Get.offAll(() => const DashBoardScreen());
                                  }
                                }
                              } else {
                                DriverUserModel userModel = DriverUserModel(
                                  id: value.user!.uid,
                                  countryCode: controller.countryCode.value,
                                  phoneNumber: controller.phoneNumber.value,
                                  loginType: Constant.phoneLoginType,
                                  profileVerify: true,
                                );
                                Get.off(() => const InformationScreen(),
                                    arguments: {"userModel": userModel});
                              }
                            }
                          } catch (error) {
                            ShowToastDialog.closeLoader();
                            ShowToastDialog.showToast(
                                "The entered code is invalid.".tr);
                          }
                        } else {
                          ShowToastDialog.showToast(
                              "Please enter a valid OTP.".tr);
                        }
                      },
                      child: Center(
                          child: Text("Verify".tr,
                              style: AppTypography.buttonlight(context))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
