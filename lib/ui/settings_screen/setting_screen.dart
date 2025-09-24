import 'dart:convert';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/auth_screen/login_screen.dart';
import 'package:driver/utils/Preferences.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controller/setting_controller.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SettingController>(
      init: SettingController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.grey100,
          body: controller.isLoading.value
              ? Constant.loader(context)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 15),

                              // Language Section
                              _buildModernCard(
                                context,
                                child: _buildLanguageItem(context, controller),
                              ),

                              const SizedBox(height: 16),

                              // App Features & Support Section
                              _buildModernCard(
                                context,
                                child: Column(
                                  children: [
                                    _buildSupportItem(context),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Danger Zone
                              _buildModernCard(
                                context,
                                child: _buildDeleteAccountItem(context),
                                isDanger: true,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // App Version - Fixed at the bottom
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Version ${Constant.appVersion}",
                                  style:
                                      AppTypography.boldLabel(context).copyWith(
                                    color: const Color(0xFF6B7280),
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
        );
      },
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildModernCard(BuildContext context,
      {required Widget child, bool isDanger = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: isDanger
            ? Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.2), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLanguageItem(
      BuildContext context, SettingController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkBackground.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SvgPicture.asset(
              'assets/icons/ic_language.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                  AppColors.darkBackground, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Language".tr,
                  style: AppTypography.boldLabel(context),
                ),
                const SizedBox(height: 2),
                Text(
                  "Choose your preferred language".tr,
                  style: AppTypography.smBoldLabel(context)
                      .copyWith(color: AppColors.grey500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildModernLanguageDropdown(context, controller),
        ],
      ),
    );
  }

  Widget _buildSupportItem(BuildContext context) {
    return InkWell(
      onTap: () async {
        final Uri url = Uri.parse(Constant.supportURL.toString());
        if (!await launchUrl(url)) {
          ShowToastDialog.showToast(
              'Could not launch ${Constant.supportURL.toString()}'.tr);
        }
      },
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(8),
        bottomRight: Radius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset(
                'assets/icons/ic_support.svg',
                width: 20,
                height: 20,
                colorFilter:
                    const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Support".tr,
                    style: AppTypography.boldLabel(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Get help and contact support".tr,
                    style: AppTypography.smBoldLabel(context)
                        .copyWith(color: AppColors.grey500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountItem(BuildContext context) {
    return InkWell(
      onTap: () => showDeleteAccountDialog(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset(
                'assets/icons/ic_delete.svg',
                width: 20,
                height: 20,
                colorFilter:
                    const ColorFilter.mode(Color(0xFFEF4444), BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Delete Account".tr,
                    style: AppTypography.boldLabel(context)
                        .copyWith(color: const Color(0xFFEF4444)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Permanently delete your account".tr,
                    style: AppTypography.smBoldLabel(context).copyWith(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPERS & DIALOGS ---

  Widget _buildModernLanguageDropdown(
      BuildContext context, SettingController controller) {
    return GestureDetector(
      onTap: () => _showLanguageBottomSheet(context, controller),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.selectedLanguage.value.name?.toString() ?? "Select".tr,
              style: AppTypography.smBoldLabel(context),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.expand_more,
              size: 18,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageBottomSheet(
      BuildContext context, SettingController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Select Language".tr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1D29),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...controller.languageList.map(
              (language) => InkWell(
                onTap: () {
                  controller.selectedLanguage.value = language;
                  LocalizationService().changeLocale(language.code.toString());
                  Preferences.setString(Preferences.languageCodeKey,
                      jsonEncode(controller.selectedLanguage.value));
                  Get.back();
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          language.name.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1D29),
                          ),
                        ),
                      ),
                      if (controller.selectedLanguage.value.id == language.id)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  void showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Color(0xFFEF4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Delete Account".tr,
                style: AppTypography.boldLabel(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Are you sure you want to delete your account? This action cannot be undone."
                    .tr,
                style: AppTypography.caption(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onPressed: () => Get.back(),
                      child: Text("Cancel".tr,
                          style: AppTypography.boldLabel(context)
                              .copyWith(color: AppColors.grey600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Get.back();
                        ShowToastDialog.showLoader("Deleting account...".tr);
                        try {
                          bool? result = await FireStoreUtils.deleteUser();
                          ShowToastDialog.closeLoader();
                          
                          if (result == true) {
                            ShowToastDialog.showToast(
                                "Account deleted successfully".tr);
                            Get.offAll(const LoginScreen());
                          } else {
                            ShowToastDialog.showToast(
                                "Failed to delete account. This may require recent authentication. Please log out and log back in, then try again."
                                    .tr);
                          }
                        } catch (e) {
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast(
                              "Error deleting account: ${e.toString()}".tr);
                        }
                      },
                      child: Text("Delete".tr,
                          style: AppTypography.boldLabel(context)
                              .copyWith(color: AppColors.background)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
