import 'dart:convert';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart'; // Added for AppTypography
import 'package:driver/ui/auth_screen/login_screen.dart';
import 'package:driver/ui/scheduled_rides/scheduled_rides_screen.dart';
import 'package:driver/utils/Preferences.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
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
            backgroundColor: Colors.white,
          
            body: controller.isLoading.value
                ? Constant.loader(context)
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildSectionTitle("Preferences".tr),
                          const SizedBox(height: 12),
                          _buildSettingsCard(
                            context,
                            children: [
                              _buildSettingItem(
                                context: context,
                                icon: 'assets/icons/ic_language.svg',
                                title: "Language".tr,
                                trailing:
                                    _buildLanguageDropdown(context, controller),
                              ),
                             
                             
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle("Support & Account".tr),
                           IconButton(
      icon: Icon(Icons.schedule),
      tooltip: 'Weekly Schedules',
      onPressed: () {
        Get.to(() => const ScheduledRidesScreen());
      },
    ),
                          const SizedBox(height: 12),
                          _buildSettingsCard(
                            context,
                            children: [
                              _buildSettingItem(
                                context: context,
                                icon: 'assets/icons/ic_support.svg',
                                title: "Support".tr,
                                onTap: () async {
                                  final Uri url =
                                      Uri.parse(Constant.supportURL.toString());
                                  if (!await launchUrl(url)) {
                                    throw Exception(
                                        'Could not launch ${Constant.supportURL.toString()}'
                                            .tr);
                                  }
                                },
                              ),
                              const Divider(height: 1),
                              _buildSettingItem(
                                context: context,
                                icon: 'assets/icons/ic_delete.svg',
                                title: "Delete Account".tr,
                                iconColor: Colors.redAccent,
                                textColor: Colors.redAccent,
                                onTap: () => showDeleteAccountDialog(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "V ${Constant.appVersion}".tr,
                                style: AppTypography.boldLabel(context).copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          );
        });
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: AppTypography.headers(Get.context!).copyWith(
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context,
      {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingItem({
    required BuildContext context,
    required String icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    Color iconColor = Colors.black87,
    Color textColor = Colors.black87,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
             
              child: SvgPicture.asset(
                icon,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTypography.caption(context).copyWith(
                  color: textColor,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown(
      BuildContext context, SettingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton(
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 22,
            color: AppColors.primary,
          ),
          value: controller.selectedLanguage.value.id == null
              ? null
              : controller.selectedLanguage.value,
          onChanged: (value) {
            controller.selectedLanguage.value = value!;
            LocalizationService().changeLocale(value.code.toString());
            Preferences.setString(Preferences.languageCodeKey,
                jsonEncode(controller.selectedLanguage.value));
          },
          hint: Text(
            "select".tr,
            style: AppTypography.bodyMedium(context),
          ),
          items: controller.languageList.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item.name.toString(),
                style: AppTypography.boldLabel(context).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }


  void showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Account delete".tr,
            style: AppTypography.h3(context),
          ),
          content: Text(
            "Are you sure want to delete Account.".tr,
            style: AppTypography.bodyMedium(context),
          ),
          actions: [
            TextButton(
              child: Text(
                "Cancel".tr,
                style: AppTypography.bodyMedium(context).copyWith(color: Colors.grey),
              ),
              onPressed: () {
                Get.back();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                "Delete".tr,
                style: AppTypography.bodyMedium(context).copyWith(
                  color: Colors.white,
                ),
              ),
              onPressed: () async {
                ShowToastDialog.showLoader("Please wait".tr);
                await FireStoreUtils.deleteUser().then((value) {
                  ShowToastDialog.closeLoader();
                  if (value == true) {
                    ShowToastDialog.showToast("Account delete".tr);
                    Get.offAll(const LoginScreen());
                  } else {
                    ShowToastDialog.showToast(
                        "Please contact to administrator".tr);
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }
}