import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/bank_details_controller.dart';
import 'package:driver/model/bank_details_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class BankDetailsScreen extends StatelessWidget {
  const BankDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<BankDetailsController>(
      init: BankDetailsController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: _buildAppBar(context),
          body: controller.isLoading.value
              ? _buildLoader(context)
              : _buildBody(context, controller),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.3,
      surfaceTintColor: AppColors.background,
      leading: IconButton(
        onPressed: () => Get.back(),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.primary,
            size: 18,
          ),
        ),
      ),
      title: Text(
        'Bank Details'.tr,
        style: AppTypography.appTitle(context),
      ),
      centerTitle: true,
    );
  }

  Widget _buildLoader(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading bank details...'.tr,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, BankDetailsController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 24),
          _buildBankDetailsSection(context, controller),
          const SizedBox(height: 32),
          _buildSaveButton(context, controller),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkModePrimary,
            AppColors.primary,
            // AppColors.darkBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grey300),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.background,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bank Information'.tr,
                  style: AppTypography.boldHeaders(Get.context!)
                      .copyWith(color: AppColors.background),
                ),
                const SizedBox(height: 4),
                Text(
                  'Secure your details for smooth transactions'.tr,
                  style: AppTypography.caption(Get.context!)
                      .copyWith(color: AppColors.grey300),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsSection(
      BuildContext context, BankDetailsController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Banking Details'.tr,
                  style: AppTypography.boldHeaders(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildModernTextField(
                  controller: controller.bankNameController.value,
                  label: 'Bank Name'.tr,
                  icon: Icons.account_balance_outlined,
                  hint: 'Enter your bank name'.tr,
                ),
                const SizedBox(height: 20),
                _buildModernTextField(
                  controller: controller.branchNameController.value,
                  label: 'Branch Name'.tr,
                  icon: Icons.business_outlined,
                  hint: 'Enter branch name'.tr,
                ),
                const SizedBox(height: 20),
                _buildModernTextField(
                  controller: controller.holderNameController.value,
                  label: 'Account Holder Name'.tr,
                  icon: Icons.person_outline,
                  hint: 'Enter account holder name'.tr,
                ),
                const SizedBox(height: 20),
                _buildModernTextField(
                  controller: controller.accountNumberController.value,
                  label: 'Account Number'.tr,
                  icon: Icons.numbers_outlined,
                  hint: 'Enter account number'.tr,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                _buildModernTextField(
                  controller: controller.otherInformationController.value,
                  label: 'Additional Information (Optional)'.tr,
                  icon: Icons.notes_outlined,
                  hint: 'Enter any additional details'.tr,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.boldLabel(Get.context!),
        ),
        const SizedBox(height: 8),
        Container(
          // height: maxLines > 1 ? null : 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: AppTypography.label(Get.context!),
            decoration: InputDecoration(
              prefixIcon: Container(
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        AppColors.primary,
                        Color.lerp(
                            AppColors.primary, AppColors.darkBackground, 0.4)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds);
                  },
                  child: Icon(
                    icon,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              hintText: hint,
              hintStyle: AppTypography.label(Get.context!),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: maxLines > 1 ? 16 : 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(
      BuildContext context, BankDetailsController controller) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            AppColors.darkBackground,
            AppColors.darkBackground.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ElevatedButton(
        onPressed: () => _handleSave(controller),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.save_outlined,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 12),
            Text(
              "Save Bank Details".tr,
              style: AppTypography.buttonlight(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave(BankDetailsController controller) async {
    // Validation
    if (controller.bankNameController.value.text.trim().isEmpty) {
      ShowToastDialog.showToast("Please enter bank name".tr);
      return;
    }
    if (controller.branchNameController.value.text.trim().isEmpty) {
      ShowToastDialog.showToast("Please enter branch name".tr);
      return;
    }
    if (controller.holderNameController.value.text.trim().isEmpty) {
      ShowToastDialog.showToast("Please enter account holder name".tr);
      return;
    }
    if (controller.accountNumberController.value.text.trim().isEmpty) {
      ShowToastDialog.showToast("Please enter account number".tr);
      return;
    }

    try {
      ShowToastDialog.showLoader("Saving details...".tr);

      BankDetailsModel bankDetailsModel = controller.bankDetailsModel.value;
      bankDetailsModel.userId = FireStoreUtils.getCurrentUid();
      bankDetailsModel.bankName =
          controller.bankNameController.value.text.trim();
      bankDetailsModel.branchName =
          controller.branchNameController.value.text.trim();
      bankDetailsModel.holderName =
          controller.holderNameController.value.text.trim();
      bankDetailsModel.accountNumber =
          controller.accountNumberController.value.text.trim();
      bankDetailsModel.otherInformation =
          controller.otherInformationController.value.text.trim();

      await FireStoreUtils.updateBankDetails(bankDetailsModel);

      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Bank details saved successfully".tr);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to save details. Please try again.".tr);
    }
  }
}
