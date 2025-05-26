import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/bank_details_controller.dart';
import 'package:driver/model/bank_details_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_them.dart';
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
            backgroundColor: AppColors.primary,
            body: Column(
              children: [
                // Header section with icon
                Container(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Manage your banking information".tr,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Main content area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.background,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? Constant.loader(context)
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Progress indicator
                                  Container(
                                    width: 40,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 32),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    alignment: Alignment.center,
                                  ),
                                  
                                  // Form fields
                                  _buildModernTextField(
                                    context,
                                    label: "Bank Name".tr,
                                    hint: "Enter your bank name".tr,
                                    controller: controller.bankNameController.value,
                                    icon: Icons.account_balance,
                                  ),
                                  
                                  _buildModernTextField(
                                    context,
                                    label: "Branch Name".tr,
                                    hint: "Enter branch name".tr,
                                    controller: controller.branchNameController.value,
                                    icon: Icons.business,
                                  ),
                                  
                                  _buildModernTextField(
                                    context,
                                    label: "Account Holder Name".tr,
                                    hint: "Enter account holder name".tr,
                                    controller: controller.holderNameController.value,
                                    icon: Icons.person,
                                  ),
                                  
                                  _buildModernTextField(
                                    context,
                                    label: "Account Number".tr,
                                    hint: "Enter account number".tr,
                                    controller: controller.accountNumberController.value,
                                    icon: Icons.numbers,
                                    keyboardType: TextInputType.number,
                                  ),
                                  
                                  _buildModernTextField(
                                    context,
                                    label: "Additional Information".tr,
                                    hint: "Enter any additional details (optional)".tr,
                                    controller: controller.otherInformationController.value,
                                    icon: Icons.info_outline,
                                    maxLines: 3,
                                    isOptional: true,
                                  ),
                                  
                                  const SizedBox(height: 40),
                                  
                                  // Modern save button
                                  _buildModernSaveButton(context, controller),
                                  
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
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
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              if (isOptional)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
              color: Colors.grey.shade50,
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSaveButton(BuildContext context, BankDetailsController controller) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleSave(controller),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.save_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  "Save Details".tr,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
      bankDetailsModel.bankName = controller.bankNameController.value.text.trim();
      bankDetailsModel.branchName = controller.branchNameController.value.text.trim();
      bankDetailsModel.holderName = controller.holderNameController.value.text.trim();
      bankDetailsModel.accountNumber = controller.accountNumberController.value.text.trim();
      bankDetailsModel.otherInformation = controller.otherInformationController.value.text.trim();

      await FireStoreUtils.updateBankDetails(bankDetailsModel);
      
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Bank details saved successfully".tr);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to save details. Please try again.".tr);
    }
  }
}