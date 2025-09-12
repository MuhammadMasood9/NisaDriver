import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/language_controller.dart';
import '../../themes/app_colors.dart';
import '../../themes/typography.dart';
import '../../widgets/localization/language_selector_widget.dart';
import '../../widgets/localization/rtl_layout_helper.dart';
import '../../utils/language_utils.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LanguageController>(
      builder: (languageController) {
        return Scaffold(
          backgroundColor: AppColors.grey75,
          appBar: AppBar(
            elevation: 0.5,
            shadowColor: AppColors.grey50,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: Text(
              'settings_title'.tr,
              style: AppTypography.appBar(context),
            ),
            centerTitle: true,
            leading: InkWell(
              onTap: () => Get.back(),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Icon(
                  languageController.isCurrentLanguageRTL 
                      ? Icons.arrow_forward_ios 
                      : Icons.arrow_back_ios,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
          body: RTLLayoutHelper(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: languageController.isCurrentLanguageRTL 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                _buildSettingsSection(
                  context: context,
                  title: 'Language & Region'.tr,
                  children: [
                    _buildLanguageSelector(context, languageController),
                  ],
                ),
            const SizedBox(height: 24),
            _buildSettingsSection(
              context: context,
              title: 'App Preferences'.tr,
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.notifications_outlined,
                  title: 'Notifications'.tr,
                  subtitle: 'Manage notification preferences'.tr,
                  onTap: () {
                    // TODO: Navigate to notifications settings
                  },
                ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode'.tr,
                  subtitle: 'Switch between light and dark theme'.tr,
                  onTap: () {
                    // TODO: Implement theme switching
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSettingsSection(
              context: context,
              title: 'Support & Legal'.tr,
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.help_outline,
                  title: 'Help & Support'.tr,
                  subtitle: 'Get help and contact support'.tr,
                  onTap: () {
                    // TODO: Navigate to help screen
                  },
                ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy'.tr,
                  subtitle: 'Read our privacy policy'.tr,
                  onTap: () {
                    // TODO: Navigate to privacy policy
                  },
                ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions'.tr,
                  subtitle: 'Read terms and conditions'.tr,
                  onTap: () {
                    // TODO: Navigate to terms and conditions
                  },
                ),
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

  Widget _buildSettingsSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: AppTypography.boldLabel(context).copyWith(
              color: AppColors.grey600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(BuildContext context, LanguageController languageController) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: languageController.isChangingLanguage ? null : () {
          LanguageSelectorWidget.showLanguageSelector(context, showOnlyPrimaryLanguages: true);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RTLRow(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.language,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: languageController.isCurrentLanguageRTL 
                      ? CrossAxisAlignment.end 
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      'language_setting'.tr,
                      style: AppTypography.boldLabel(context),
                      textAlign: languageController.getTextAlign(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      languageController.currentLanguage.nativeName,
                      style: AppTypography.caption(context).copyWith(
                        color: AppColors.grey500,
                      ),
                      textAlign: languageController.getTextAlign(),
                    ),
                  ],
                ),
              ),
              if (languageController.isChangingLanguage)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else
                Icon(
                  languageController.isCurrentLanguageRTL 
                      ? Icons.arrow_back_ios 
                      : Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.grey400,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RTLRow(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.grey600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: LanguageUtils.isCurrentLanguageRTL() 
                      ? CrossAxisAlignment.end 
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.boldLabel(context),
                      textAlign: LanguageUtils.getTextAlign(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption(context).copyWith(
                        color: AppColors.grey500,
                      ),
                      textAlign: LanguageUtils.getTextAlign(),
                    ),
                  ],
                ),
              ),
              Icon(
                LanguageUtils.isCurrentLanguageRTL() 
                    ? Icons.arrow_back_ios 
                    : Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.grey400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}