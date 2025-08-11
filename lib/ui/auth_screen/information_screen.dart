import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/information_controller.dart';
import 'package:driver/model/document_model.dart';
import 'package:driver/model/driver_document_model.dart';
import 'package:driver/model/vehicle_type_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EnhancedDateSelector extends StatelessWidget {
  final String label;
  final String hintText;
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool isRequired;
  final String? errorText;
  final Color primaryColor;
  final bool showClearButton;
  final String dateFormat;
  final Function()? onClear;

  const EnhancedDateSelector({
    Key? key,
    required this.label,
    required this.hintText,
    required this.onDateSelected,
    this.selectedDate,
    this.firstDate,
    this.lastDate,
    this.isRequired = false,
    this.errorText,
    this.primaryColor = AppColors.primary,
    this.showClearButton = true,
    this.dateFormat = "MMMM dd, yyyy",
    this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;
    final bool hasValue = selectedDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.boldLabel(Get.context!)
                  .copyWith(color: AppColors.darkBackground.withOpacity(0.8)),
            ),
            if (isRequired)
              Text(
                ' *',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: firstDate ?? DateTime(1900),
              lastDate: lastDate ?? DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: primaryColor,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Colors.black,
                    ),
                    dialogBackgroundColor: Colors.white,
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasError ? AppColors.primary : AppColors.grey200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: hasValue ? primaryColor : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue
                        ? Constant.timestampToDateTime(
                            Timestamp.fromDate(selectedDate!),
                            format: dateFormat)
                        : hintText,
                    style: AppTypography.caption(context).copyWith(
                      color: hasValue
                          ? AppColors.darkBackground
                          : Colors.grey[600],
                    ),
                  ),
                ),
                if (hasValue && showClearButton)
                  GestureDetector(
                    onTap: onClear ?? () => onDateSelected(DateTime.now()),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: Colors.red[700],
                ),
                const SizedBox(width: 6),
                Text(
                  errorText!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class InformationScreen extends StatelessWidget {
  const InformationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<InformationController>(
      init: InformationController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: controller.isLoading.value
              ? Center(child: Constant.loader(context))
              : SafeArea(
                  child: Column(
                    children: [
                      _buildTabBar(context, controller),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(32),
                                  topRight: Radius.circular(32),
                                ),
                              ),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20.0, vertical: 24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.currentStep.value == 0
                                          ? "Select Service".tr
                                          : controller.currentStep.value == 1
                                              ? "Personal Information".tr
                                              : controller.currentStep.value ==
                                                      2
                                                  ? "Vehicle Information".tr
                                                  : "Document Verification".tr,
                                      style: AppTypography.h1(context),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      controller.currentStep.value == 0
                                          ? "Choose your service to get started."
                                              .tr
                                          : controller.currentStep.value == 1
                                              ? "Tell us a bit about yourself."
                                                  .tr
                                              : controller.currentStep.value ==
                                                      2
                                                  ? "Provide your vehicle details."
                                                      .tr
                                                  : "Upload your documents for verification."
                                                      .tr,
                                      style: AppTypography.caption(context)
                                          .copyWith(color: AppColors.grey500),
                                    ),
                                    const SizedBox(height: 30),
                                    _buildStepContent(context, controller),
                                    const SizedBox(
                                        height:
                                            120), // Space for floating buttons
                                  ],
                                ),
                              ),
                            ),
                            // Floating Action Buttons
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 15),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, -5),
                                    ),
                                  ],
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(32),
                                    topRight: Radius.circular(32),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (controller.currentStep.value > 0)
                                      Expanded(
                                        child: _buildNavButton(
                                          context: context,
                                          title: "Back".tr,
                                          onPress: () =>
                                              controller.currentStep.value--,
                                          isPrimary: false,
                                        ),
                                      ),
                                    if (controller.currentStep.value > 0)
                                      const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildNavButton(
                                        context: context,
                                        title: controller.currentStep.value == 3
                                            ? "Submit".tr
                                            : "Next".tr,
                                        onPress: () =>
                                            controller.handleNext(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildNavButton(
      {required BuildContext context,
      required String title,
      required VoidCallback onPress,
      bool isPrimary = true}) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPress,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.primary : Colors.white,
          foregroundColor: isPrimary ? Colors.white : AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(color: AppColors.primary, width: 1),
          ),
          elevation: isPrimary ? 2 : 0,
          shadowColor: isPrimary
              ? AppColors.primary.withOpacity(0.4)
              : Colors.transparent,
        ),
        child: Text(
          title,
          style: AppTypography.appTitle(context).copyWith(
              color: isPrimary ? AppColors.background : AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, InformationController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabItem(
                  context, controller, 0, Icons.list_alt_rounded, 'Service'.tr),
              _buildTabItem(context, controller, 1,
                  Icons.person_outline_rounded, 'Personal'.tr),
              _buildTabItem(context, controller, 2,
                  Icons.directions_car_outlined, 'Vehicle'.tr),
              _buildTabItem(context, controller, 3,
                  Icons.document_scanner_outlined, 'Docs'.tr),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (controller.currentStep.value + 1) / 4,
                  backgroundColor: Colors.grey[200],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, InformationController controller,
      int index, IconData icon, String label) {
    bool isActive = controller.currentStep.value >= index;
    bool isCurrent = controller.currentStep.value == index;

    return Expanded(
      child: InkWell(
        // Allow tapping only on completed steps to go back
        onTap: isActive && !isCurrent
            ? () => controller.currentStep.value = index
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent
                    ? AppColors.primary.withOpacity(0.15)
                    : isActive
                        ? AppColors.primary.withOpacity(0.05)
                        : Colors.grey.shade100,
                border: Border.all(
                  color: isCurrent ? AppColors.primary : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? AppColors.primary : Colors.grey[500],
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.boldLabel(context).copyWith(
                color: isActive ? AppColors.primary : AppColors.grey400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(
      BuildContext context, InformationController controller) {
    // A small animated transition between steps
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Container(
        key: ValueKey<int>(controller.currentStep.value),
        child: Column(
          children: [
            if (controller.currentStep.value == 0)
              _buildServiceTypeStep(context, controller),
            if (controller.currentStep.value == 1)
              _buildPersonalInfoStep(context, controller),
            if (controller.currentStep.value == 2)
              _buildVehicleInfoStep(context, controller),
            if (controller.currentStep.value == 3)
              _buildVerificationStep(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTypeStep(
      BuildContext context, InformationController controller) {
    // Auto-select first enabled service on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.serviceList.isNotEmpty &&
          controller.selectedServiceId.value == null) {
        final firstEnabledService = controller.serviceList.firstWhere(
            (s) => s.enable == true,
            orElse: () => controller.serviceList.first);
        controller.selectedServiceId.value = firstEnabledService.id;
      }
    });

    return Obx(() => Column(
          children: controller.serviceList.map((service) {
            final bool isEnabled = service.enable ?? false;
            final bool isSelected =
                controller.selectedServiceId.value == service.id;
            return InkWell(
              onTap: isEnabled
                  ? () => controller.selectedServiceId.value = service.id!
                  : () => ShowToastDialog.showToast(
                      "This service is coming soon".tr),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.primary : Colors.grey.shade200,
                    width: isSelected ? 2.0 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: service.image ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey.shade100),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.directions_car,
                              color: Colors.grey.shade400, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.title?.first.title ?? service.id!,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isEnabled
                                  ? AppColors.darkBackground
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text("Coming Soon".tr,
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade800)),
                      )
                    else if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 18),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ));
  }

  Widget _buildPersonalInfoStep(
      BuildContext context, InformationController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              InkWell(
                onTap: () => _showImageSourceSelector(context, controller),
                borderRadius: BorderRadius.circular(60),
                child: Obx(
                  () => Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 2),
                    ),
                    child: controller.userImage.value.isEmpty
                        ? _buildImagePlaceholder(context)
                        : _buildImagePreview(
                            context, controller.userImage.value),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (controller.userImage.value.isEmpty)
                Text("Tap to upload profile picture".tr,
                    style: AppTypography.smBoldLabel(context)
                        .copyWith(color: AppColors.grey500))
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
            controller: controller.fullNameController.value,
            label: 'Full Name'.tr,
            hint: "Enter your full name".tr,
            icon: Icons.person_outline),
        _buildTextField(
            controller: controller.emailController.value,
            label: 'Email'.tr,
            hint: "Enter your email".tr,
            icon: Icons.email_outlined),
        if (controller.loginType.value == Constant.emailLoginType)
          _buildTextField(
              controller: controller.passwordController.value,
              label: 'Password'.tr,
              hint: "Enter your password".tr,
              icon: Icons.lock_outline,
              obscureText: true),
        _buildPhoneField(context, controller),
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context, String imagePath) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(60),
          child: Constant().hasValidUrl(imagePath)
              ? CachedNetworkImage(
                  imageUrl: imagePath,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover)
              : Image.file(File(imagePath),
                  width: 120, height: 120, fit: BoxFit.cover),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)),
            child: const Icon(Icons.edit, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(Icons.camera_alt_outlined,
            size: 40, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildVehicleInfoStep(
      BuildContext context, InformationController controller) {
    return Column(
      children: [
        _buildTextField(
            controller: controller.vehicleNumberController.value,
            label: 'Vehicle Number'.tr,
            hint: "Enter vehicle number".tr,
            icon: Icons.confirmation_number_outlined),
        Obx(
          () => EnhancedDateSelector(
            label: 'Registration Date'.tr,
            hintText: 'Select vehicle registration date'.tr,
            selectedDate: controller.selectedDate.value,
            onDateSelected: (date) {
              controller.selectedDate.value = date;
            },
            isRequired: true,
          ),
        ),
        _buildSelectorField(context, controller,
            label: 'Vehicle Type'.tr,
            value: controller.selectedVehicle.value.id == null
                ? ''
                : Constant.localizationName(
                    controller.selectedVehicle.value.name),
            onTap: () => _showVehicleTypeSelector(context, controller)),
        const SizedBox(height: 24),
        _buildSelectorField(context, controller,
            label: 'Vehicle Color'.tr,
            value: controller.selectedColor.value,
            onTap: () => _showColorSelector(context, controller)),
        const SizedBox(height: 24),
        _buildSelectorField(context, controller,
            label: 'Number of Seats'.tr,
            value: controller.seatsController.value.text,
            onTap: () => _showSeatsSelector(context, controller)),
        const SizedBox(height: 24),
        _buildSelectorField(context, controller,
            label: 'Service Zone'.tr,
            value: controller.zoneNameController.value.text,
            onTap: () => _showZoneSelector(context, controller)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSelectorField(
      BuildContext context, InformationController controller,
      {required String label,
      required String value,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.boldLabel(context)
                .copyWith(color: AppColors.darkBackground.withOpacity(0.8)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.grey200, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? "Select $label" : value,
                    style: AppTypography.caption(context).copyWith(
                      color: value.isEmpty
                          ? Colors.grey.shade600
                          : AppColors.darkBackground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStep(
      BuildContext context, InformationController controller) {
    return Obx(
      () => ListView.builder(
        itemCount: controller.documentList.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          DocumentModel documentModel = controller.documentList[index];
          Documents documents = Documents();

          // Check if document details are already available
          if (controller.registrationDocuments.containsKey(documentModel.id)) {
            documents = controller.registrationDocuments[documentModel.id]!;
          }

          bool isVerified = documents.verified == true;
          bool isUploaded = (documents.documentNumber?.isNotEmpty ?? false) &&
              (documentModel.frontSide != true ||
                  (documents.frontImage?.isNotEmpty ?? false)) &&
              (documentModel.backSide != true ||
                  (documents.backImage?.isNotEmpty ?? false));

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () =>
                  controller.showDocumentUploadScreen(context, documentModel),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.grey200, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isVerified
                            ? Colors.green.withOpacity(0.1)
                            : isUploaded
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isVerified
                            ? Icons.check_circle_outline_rounded
                            : Icons.description_outlined,
                        color: isVerified
                            ? Colors.green
                            : (isUploaded
                                ? AppColors.primary
                                : Colors.grey.shade600),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Constant.localizationTitle(documentModel.title),
                            style: AppTypography.boldLabel(context),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isVerified
                                ? "Document verified successfully".tr
                                : "Tap to upload document".tr,
                            style: AppTypography.label(context),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isVerified ? "Verified".tr : "Pending".tr,
                        style: AppTypography.smBoldLabel(context).copyWith(
                          color: isVerified
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageSourceSelector(
      BuildContext context, InformationController controller) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 20),
                    Text("Choose Source".tr, style: AppTypography.h2(context)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSourceOption(context, controller, "Camera",
                            Icons.camera_alt_outlined, ImageSource.camera),
                        _buildSourceOption(context, controller, "Gallery",
                            Icons.photo_library_outlined, ImageSource.gallery),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ));
  }

  Widget _buildSourceOption(
      BuildContext context,
      InformationController controller,
      String title,
      IconData icon,
      ImageSource source) {
    return InkWell(
      onTap: () {
        controller.pickUserImage(source: source);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 12),
          Text(title.tr, style: AppTypography.boldLabel(context)),
        ],
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required String hint,
      required IconData icon,
      bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.boldLabel(Get.context!)
                .copyWith(color: AppColors.darkBackground.withOpacity(0.8)),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: AppTypography.input(Get.context!),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.input(Get.context!)
                  .copyWith(color: AppColors.grey500),
              prefixIcon: Icon(icon, color: AppColors.grey500, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300, width: 1)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      BorderSide(color: Colors.grey.shade300, width: 1)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.primary, width: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField(
      BuildContext context, InformationController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Phone Number'.tr,
              style: AppTypography.boldLabel(context)
                  .copyWith(color: AppColors.darkBackground.withOpacity(0.8))),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.grey200, width: 1),
            ),
            child: Row(
              children: [
                CountryCodePicker(
                  onChanged: (value) =>
                      controller.countryCode.value = value.dialCode.toString(),
                  initialSelection: controller.countryCode.value,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                  textStyle: AppTypography.input(context),
                  flagDecoration: const BoxDecoration(shape: BoxShape.circle),
                ),
                Container(width: 1.5, height: 30, color: Colors.grey.shade200),
                Expanded(
                  child: TextFormField(
                    controller: controller.phoneNumberController.value,
                    keyboardType: TextInputType.phone,
                    style: AppTypography.input(context),
                    decoration: InputDecoration(
                      hintText: "Enter your phone number".tr,
                      hintStyle: AppTypography.input(context)
                          .copyWith(color: AppColors.grey500),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVehicleTypeSelector(
      BuildContext context, InformationController controller) {
    _showAppBottomSheet(
      context,
      title: 'Select Vehicle Type'.tr,
      child: ListView.builder(
        itemCount: controller.vehicleList.length,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final vehicleType = controller.vehicleList[index];
          return Obx(() => RadioListTile<VehicleTypeModel>(
                value: vehicleType,
                groupValue: controller.selectedVehicle.value,
                activeColor: AppColors.primary,
                onChanged: (value) {
                  controller.selectedVehicle.value = value!;
                  Navigator.pop(context);
                },
                title: Text(Constant.localizationName(vehicleType.name),
                    style: GoogleFonts.poppins()),
              ));
        },
      ),
    );
  }

  void _showColorSelector(
      BuildContext context, InformationController controller) {
    _showAppBottomSheet(
      context,
      title: 'Select Vehicle Color'.tr,
      child: ListView.builder(
        itemCount: controller.carColorList.length,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final color = controller.carColorList[index];
          return Obx(() => RadioListTile<String>(
                value: color,
                groupValue: controller.selectedColor.value,
                activeColor: AppColors.primary,
                onChanged: (value) {
                  controller.selectedColor.value = value!;
                  Navigator.pop(context);
                },
                title: Text(color, style: GoogleFonts.poppins()),
              ));
        },
      ),
    );
  }

  void _showSeatsSelector(
      BuildContext context, InformationController controller) {
    _showAppBottomSheet(
      context,
      title: 'Select Number of Seats'.tr,
      child: ListView.builder(
        itemCount: controller.sheetList.length,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final seats = controller.sheetList[index];
          return Obx(() => RadioListTile<String>(
                value: seats,
                groupValue: controller.seatsController.value.text,
                activeColor: AppColors.primary,
                onChanged: (value) {
                  controller.seatsController.value.text = value!;
                  Navigator.pop(context);
                },
                title: Text('$seats Seats', style: GoogleFonts.poppins()),
              ));
        },
      ),
    );
  }

  void _showZoneSelector(
      BuildContext context, InformationController controller) {
    _showAppBottomSheet(
      context,
      title: 'Select Service Zones'.tr,
      child: SizedBox(
        height:
            400, // or use MediaQuery.of(context).size.height * 0.5 for 50% of screen
        child: StatefulBuilder(builder: (context, setModalState) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.only(left: 10),
                  child: ListView.builder(
                    itemCount: controller.zoneList.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final zone = controller.zoneList[index];
                      return Obx(() => CheckboxListTile(
                            value: controller.selectedZone.contains(zone.id),
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              if (value == true && zone.id != null) {
                                controller.selectedZone.add(zone.id!);
                              } else {
                                controller.selectedZone.remove(zone.id);
                              }
                            },
                            title: Text(Constant.localizationName(zone.name),
                                style: AppTypography.appTitle(context)),
                          ));
                    },
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.only(bottom: 40),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildNavButton(
                              context: context,
                              title: "Cancel".tr,
                              onPress: () => Navigator.pop(context),
                              isPrimary: false)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildNavButton(
                          context: context,
                          title: "Apply".tr,
                          onPress: () {
                            if (controller.selectedZone.isEmpty) {
                              ShowToastDialog.showToast(
                                  "Please select at least one zone".tr);
                            } else {
                              controller.zoneNameController.value.text =
                                  controller.selectedZone
                                      .map((id) => Constant.localizationName(
                                          controller.zoneList
                                              .firstWhere((z) => z.id == id)
                                              .name))
                                      .join(", ");
                              Navigator.pop(context);
                            }
                          },
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          );
        }),
      ),
    );
  }

  // A generic bottom sheet for our selectors
  void _showAppBottomSheet(BuildContext context,
      {required String title, required Widget child}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 16),
                        Text(title, style: AppTypography.h2(context)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      controller: scrollController,
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
