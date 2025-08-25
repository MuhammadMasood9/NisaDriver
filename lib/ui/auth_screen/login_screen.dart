// lib/ui/auth_screen/login_screen.dart

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/login_controller.dart';
import 'package:driver/controller/on_boarding_controller.dart';
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
import 'package:driver/services/login_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // Static set to track logged errors across instances
  static final Set<String> _loggedErrors = <String>{};

  // Method to clear logged errors (useful for testing or resetting)
  static void clearLoggedErrors() {
    _loggedErrors.clear();
  }

  // Intro image slider for fallback when network images fail
  Widget _buildIntroImageSlider(BuildContext context, int index) {
    final List<String> introImages = [
      'assets/images/intro_1.png',
      'assets/images/intro_2.png',
      'assets/images/intro_3.png',
    ];

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Image.asset(
        introImages[index % introImages.length],
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Only log asset errors once per session
          final assetPath = introImages[index % introImages.length];
          if (!_loggedErrors.contains('asset:$assetPath')) {
            _loggedErrors.add('asset:$assetPath');
            print('Asset image failed to load: $assetPath - Using placeholder');
          }

          // If even the asset image fails, show a placeholder with gradient
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.grey75,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 80,
                  color: AppColors.grey500,
                ),
                const SizedBox(height: 16),
                Text(
                  'Image Unavailable'.tr,
                  style: AppTypography.label(context).copyWith(
                    color: AppColors.grey500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Shimmer widget for loading state
  Widget _buildOnboardingShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Container(
              height: 24,
              width: Responsive.width(60, context),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Container(
                  height: 12,
                  width: Responsive.width(80, context),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: Responsive.width(70, context),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize controllers
    Get.put(LoginController());
    Get.put(OnBoardingController(), permanent: true);

    final LoginController loginController = Get.find<LoginController>();
    final OnBoardingController onBoardingController =
        Get.find<OnBoardingController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: 20),
                // App Logo and Title
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 45,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          "assets/icons/app_icon_foreground.png",
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Text(
                      "NisaDrive".tr,
                      style: AppTypography.headers(context),
                    ),
                  ],
                ),

                // Onboarding PageView or Shimmer
                SizedBox(
                  height: Responsive.height(42, context),
                  child: Obx(
                    () => onBoardingController.isLoading.value
                        ? _buildOnboardingShimmer(context)
                        : PageView.builder(
                            controller: onBoardingController.pageController,
                            onPageChanged:
                                onBoardingController.selectedPageIndex.call,
                            itemCount:
                                onBoardingController.onBoardingList.length,
                            itemBuilder: (context, index) {
                              final item =
                                  onBoardingController.onBoardingList[index];
                              return Column(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: CachedNetworkImage(
                                        imageUrl: item.image.toString(),
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) =>
                                            Constant.loader(context),
                                        errorWidget: (context, url, error) {
                                          // Only log once per session to reduce noise
                                          if (!_loggedErrors.contains(url)) {
                                            _loggedErrors.add(url);
                                            print(
                                                'Image load failed for: $url - Using fallback intro image');
                                          }
                                          return _buildIntroImageSlider(
                                              context, index);
                                        },
                                        httpHeaders: const {
                                          'Cache-Control': 'max-age=3600',
                                        },
                                        maxWidthDiskCache: 1000,
                                        maxHeightDiskCache: 1000,
                                        memCacheWidth: 1000,
                                        memCacheHeight: 1000,
                                        fadeInDuration:
                                            const Duration(milliseconds: 300),
                                        fadeOutDuration:
                                            const Duration(milliseconds: 300),
                                        fadeInCurve: Curves.easeIn,
                                        fadeOutCurve: Curves.easeOut,
                                        useOldImageOnUrlChange: true,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 20),
                                    child: Text(
                                      Constant.localizationTitle(item.title),
                                      style: AppTypography.h2(context)
                                          .copyWith(letterSpacing: 1.2),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: Text(
                                      Constant.localizationDescription(
                                          item.description),
                                      style: AppTypography.label(context)
                                          .copyWith(letterSpacing: 1.05),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ),
                // PageView Indicators
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Obx(
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        onBoardingController.onBoardingList.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: onBoardingController.selectedPageIndex.value ==
                                  index
                              ? 25
                              : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color:
                                onBoardingController.selectedPageIndex.value ==
                                        index
                                    ? AppColors.primary
                                    : const Color(0xffD4D5E0),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Login Buttons
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          ButtonThem.buildButton(
                            context,
                            title: "Continue with Phone".tr,
                            onPress: () =>
                                _showPhoneLoginSheet(context, loginController),
                          ),
                          const SizedBox(height: 10),
                          ButtonThem.buildBorderButton(
                            context,
                            title: "Continue with Google".tr,
                            iconVisibility: true,
                            iconAssetImage: 'assets/icons/ic_google.png',
                            onPress: () => _handleGoogleLogin(loginController),
                          ),
                          const SizedBox(height: 16),
                          Visibility(
                            visible: Platform.isIOS,
                            child: ButtonThem.buildBorderButton(
                              context,
                              title: "Login with Apple".tr,
                              iconVisibility: true,
                              iconAssetImage: 'assets/icons/ic_apple.png',
                              iconColor: Colors.black,
                              onPress: () => _handleAppleLogin(loginController),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Terms and Conditions Text (at the bottom)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                color: AppColors.background,
                child: Text.rich(
                  textAlign: TextAlign.center,
                  TextSpan(
                    text: 'By tapping "Next" you agree to '.tr,
                    style: AppTypography.caption(context),
                    children: <TextSpan>[
                      TextSpan(
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Get.to(
                              const TermsAndConditionScreen(type: "terms")),
                        text: 'Terms and conditions'.tr,
                        style: AppTypography.boldLabel(context)
                            .copyWith(color: AppColors.primary),
                      ),
                      TextSpan(
                          text: ' and ', style: AppTypography.caption(context)),
                      TextSpan(
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => Get.to(
                              const TermsAndConditionScreen(type: "privacy")),
                        text: 'privacy policy'.tr,
                        style: AppTypography.boldLabel(context)
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Phone Login Modal Bottom Sheet
  void _showPhoneLoginSheet(
      BuildContext context, LoginController loginController) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Enter Phone Number".tr,
                      style: AppTypography.headers(context)),
                  const SizedBox(height: 16),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    controller: loginController.phoneNumberController.value,
                    style: AppTypography.input(context),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      prefixIcon: CountryCodePicker(
                        onChanged: (value) => loginController
                            .countryCode.value = value.dialCode ?? "+1",
                        dialogBackgroundColor: AppColors.background,
                        initialSelection: loginController.countryCode.value,
                        comparator: (a, b) => b.name!.compareTo(a.name!),
                        flagDecoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(2))),
                        padding: EdgeInsets.zero,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(4)),
                        borderSide: BorderSide(color: AppColors.grey300),
                      ),
                      hintText: "Phone number".tr,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel".tr,
                            style: AppTypography.boldLabel(context)
                                .copyWith(color: AppColors.grey400)),
                      ),
                      ButtonThem.buildButton(
                        context,
                        btnWidthRatio: 0.3,
                        btnHeight: 35,
                        title: "Submit".tr,
                        onPress: () {
                          if (loginController
                              .phoneNumberController.value.text.isNotEmpty) {
                            Navigator.pop(context);
                            ShowToastDialog.showLoader("Please wait".tr);
                            loginController.sendCode();
                          } else {
                            ShowToastDialog.showToast(
                                "Please enter a phone number".tr);
                          }
                        },
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Google Login Logic
  Future<void> _handleGoogleLogin(LoginController controller) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final value = await controller.signInWithGoogle();
    ShowToastDialog.closeLoader();

    if (value == null) return;

    if (value.additionalUserInfo!.isNewUser) {
      DriverUserModel userModel = DriverUserModel()
        ..id = value.user!.uid
        ..email = value.user!.email
        ..fullName = value.user!.displayName
        ..profilePic = value.user!.photoURL
        ..loginType = Constant.googleLoginType
        ..profileVerify = true;
      Get.to(() => const InformationScreen(),
          arguments: {"userModel": userModel});
    } else {
      final userExists = await FireStoreUtils.userExitOrNot(value.user!.uid);
      if (userExists) {
        final userModel =
            await FireStoreUtils.getDriverProfile(value.user!.uid);

        String token = await NotificationService.getToken();
        userModel!.fcmToken = token;
        userModel.id = value.user!.uid; // ensure id is present for update
        await FireStoreUtils.updateDriverUser(userModel);

        // Update shared preferences for login persistence
        try {
          await LoginService.updateLoginStatus(value.user);
        } catch (e) {
          print('Error updating login status: $e');
        }

        // Retain your existing driver-specific logic for subscription checks
        Get.offAll(() => const DashBoardScreen()); // Simplified for example
      } else {
        DriverUserModel userModel = DriverUserModel()
          ..id = value.user!.uid
          ..email = value.user!.email
          ..fullName = value.user!.displayName
          ..profilePic = value.user!.photoURL
          ..loginType = Constant.googleLoginType
          ..profileVerify = true;
        Get.to(() => const InformationScreen(),
            arguments: {"userModel": userModel});
      }
    }
  }

  // Apple Login Logic
  Future<void> _handleAppleLogin(LoginController controller) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final value = await controller.signInWithApple();
    ShowToastDialog.closeLoader();

    if (value == null) return;

    AuthorizationCredentialAppleID appleCredential = value['appleCredential'];
    UserCredential userCredential = value['userCredential'];

    if (userCredential.additionalUserInfo!.isNewUser) {
      DriverUserModel userModel = DriverUserModel()
        ..id = userCredential.user!.uid
        ..profilePic = userCredential.user!.photoURL
        ..loginType = Constant.appleLoginType
        ..email = userCredential.additionalUserInfo!.profile!['email']
        ..fullName =
            "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}"
        ..profileVerify = true;
      Get.to(() => const InformationScreen(),
          arguments: {"userModel": userModel});
    } else {
      final userExit =
          await FireStoreUtils.userExitOrNot(userCredential.user!.uid);

      DriverUserModel userModel = DriverUserModel()
        ..id = userCredential.user!.uid
        ..profilePic = userCredential.user!.photoURL
        ..loginType = Constant.appleLoginType
        ..email = userCredential.additionalUserInfo!.profile!['email']
        ..fullName =
            "${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}"
        ..profileVerify = true;
      // If the user exists, go to dashboard, otherwise go to information screen
      if (userExit == true) {
        // Update shared preferences for login persistence
        try {
          await LoginService.updateLoginStatus(userCredential.user);
        } catch (e) {
          print('Error updating login status: $e');
        }
        Get.offAll(() => const DashBoardScreen());
      } else {
        Get.to(() => const InformationScreen(),
            arguments: {"userModel": userModel});
      }
    }
  }
}
