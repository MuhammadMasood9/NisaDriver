import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/bank_details_controller.dart';
import 'package:driver/model/bank_details_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_them.dart';
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
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                // Header section with icon
                Container(
                  padding: const EdgeInsets.only(bottom: 10, top: 20),
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: AppColors.primary,
                          size: 25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: Text(
                          "Manage your banking information".tr,
                          style: AppTypography.boldHeaders(context).copyWith(
                            color: AppColors.darkBackground.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                // Main content area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                    ),
                    child: controller.isLoading.value
                        ? Constant.loader(context)
                        : Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Form fields
                                        _buildModernTextField(
                                          context,
                                          label: "Bank Name".tr,
                                          hint: "Enter your bank name".tr,
                                          controller: controller
                                              .bankNameController.value,
                                          icon: Icons.account_balance,
                                        ),
                                        _buildModernTextField(
                                          context,
                                          label: "Branch Name".tr,
                                          hint: "Enter branch name".tr,
                                          controller: controller
                                              .branchNameController.value,
                                          icon: Icons.business,
                                        ),
                                        _buildModernTextField(
                                          context,
                                          label: "Account Holder Name".tr,
                                          hint: "Enter account holder name".tr,
                                          controller: controller
                                              .holderNameController.value,
                                          icon: Icons.person,
                                        ),
                                        _buildModernTextField(
                                          context,
                                          label: "Account Number".tr,
                                          hint: "Enter account number".tr,
                                          controller: controller
                                              .accountNumberController.value,
                                          icon: Icons.numbers,
                                          keyboardType: TextInputType.number,
                                        ),
                                        _buildModernTextField(
                                          context,
                                          label: "Additional Information".tr,
                                          hint:
                                              "Enter any additional details".tr,
                                          controller: controller
                                              .otherInformationController.value,
                                          icon: Icons.info_outline,
                                          isOptional: true,
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20.0, vertical: 10.0),
                                child:
                                    _buildModernSaveButton(context, controller),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  Widget _buildModernTextField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isOptional = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTypography.boldLabel(context)
                    .copyWith(color: AppColors.darkBackground.withOpacity(0.7)),
              ),
              if (isOptional)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Optional".tr,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
              color: AppColors.background,
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: AppTypography.label(context)
                  .copyWith(color: AppColors.darkBackground.withOpacity(0.7)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.label(context)
                    .copyWith(color: AppColors.darkBackground.withOpacity(0.7)),
                prefixIcon: Container(
                  child: Icon(
                    icon,
                    color: AppColors.darkBackground.withOpacity(0.7),
                    size: 20,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSaveButton(
      BuildContext context, BankDetailsController controller) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkBackground,
            AppColors.darkBackground.withOpacity(0.8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBackground.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _handleSave(controller),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.save_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Text(
                  "Save Details".tr,
                  style: AppTypography.button(context)
                      .copyWith(color: AppColors.background),
                ),
              ],
            ),
          ),
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
