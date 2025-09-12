import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/language_controller.dart';
import '../../models/language_model.dart';
import '../../utils/language_utils.dart';
import '../../themes/app_colors.dart';
import '../../themes/typography.dart';

class LanguageSelectorWidget extends StatelessWidget {
  final bool showTitle;
  final bool isBottomSheet;
  final bool showOnlyPrimaryLanguages;

  const LanguageSelectorWidget({
    super.key,
    this.showTitle = true,
    this.isBottomSheet = false,
    this.showOnlyPrimaryLanguages = true,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LanguageController>(
      builder: (languageController) {
        // Get languages to display
        final languages = showOnlyPrimaryLanguages
            ? languageController.getPrimaryLanguages()
            : languageController.getAllSupportedLanguages();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: isBottomSheet
                ? const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  )
                : BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitle) ...[
                Row(
                  children: [
                    Text(
                      "language_setting".tr,
                      style: AppTypography.headers(context),
                    ),
                    const Spacer(),
                    if (languageController.isChangingLanguage)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              ...languages.map(
                (language) =>
                    _buildLanguageOption(context, language, languageController),
              ),
              if (isBottomSheet) const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context,
      SupportedLanguageModel language, LanguageController controller) {
    final isSelected = controller.currentLanguageCode == language.code;
    final isChanging = controller.isChangingLanguage;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isChanging
              ? null
              : () async {
                  if (!isSelected) {
                    // Show immediate feedback
                    final success =
                        await controller.changeLanguage(language.code);

                    if (success && Get.isBottomSheetOpen == true) {
                      // Small delay to show the selection before closing
                      await Future.delayed(const Duration(milliseconds: 300));
                      Get.back();
                    } else if (!success) {
                      // Show error message if language change failed
                      Get.snackbar(
                        'error_title'.tr,
                        'failed_change_language'.tr,
                        backgroundColor: AppColors.error,
                        colorText: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                    }
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.grey300,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  language.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.name,
                        style: AppTypography.boldLabel(context).copyWith(
                          color:
                              isSelected ? AppColors.primary : Colors.black87,
                        ),
                      ),
                      Text(
                        language.nativeName,
                        style: AppTypography.caption(context).copyWith(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.8)
                              : AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isChanging && isSelected)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                else if (isSelected)
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
    );
  }

  /// Show language selector as bottom sheet with performance optimization
  static void showLanguageSelector(BuildContext context,
      {bool showOnlyPrimaryLanguages = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => LanguageSelectorWidget(
        showTitle: true,
        isBottomSheet: true,
        showOnlyPrimaryLanguages: showOnlyPrimaryLanguages,
      ),
    );
  }

  /// Show language selector as dialog
  static void showLanguageSelectorDialog(BuildContext context,
      {bool showOnlyPrimaryLanguages = true}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: LanguageSelectorWidget(
          showTitle: true,
          isBottomSheet: false,
          showOnlyPrimaryLanguages: showOnlyPrimaryLanguages,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'.tr),
          ),
        ],
      ),
    );
  }
}
