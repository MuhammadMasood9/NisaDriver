import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/information_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/service_model.dart';
import 'package:driver/model/vehicle_type_model.dart';
import 'package:driver/model/zone_model.dart';
import 'package:driver/model/document_model.dart';
import 'package:driver/model/driver_document_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_them.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';

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
    this.primaryColor = Colors.blue,
    this.showClearButton = true,
    this.dateFormat = "dd-MM-yyyy",
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
              style: AppTypography.boldLabel(Get.context!),
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
        const SizedBox(height: 5),
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
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasError
                    ? Colors.red
                    : hasValue
                        ? Colors.grey[200]!
                        : Colors.grey[200]!,
                width: hasError || hasValue ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                          ? DateFormat(dateFormat).format(selectedDate!)
                          : hintText,
                      style: AppTypography.caption(context),
                    ),
                  ),
                  if (hasValue && showClearButton)
                    GestureDetector(
                      onTap: () => onDateSelected(DateTime.now()),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: Colors.red[700],
              ),
              const SizedBox(width: 4),
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
        ],
        const SizedBox(height: 20),
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
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Column(
                    children: [
                      _buildTabBar(context, controller),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(28),
                                  topRight: Radius.circular(28),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(28),
                                  topRight: Radius.circular(28),
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: Responsive.height(1, context),
                                      ),
                                      Text(
                                        controller.currentStep.value == 0
                                            ? "Select Service".tr
                                            : controller.currentStep.value == 1
                                                ? "Personal Information".tr
                                                : controller.currentStep
                                                            .value ==
                                                        2
                                                    ? "Vehicle Information".tr
                                                    : "Document Verification"
                                                        .tr,
                                        style:
                                            AppTypography.boldHeaders(context),
                                      ),
                                      SizedBox(
                                        height: Responsive.height(1, context),
                                      ),
                                      Text(
                                        controller.currentStep.value == 0
                                            ? "Choose your service type".tr
                                            : controller.currentStep.value == 1
                                                ? "Enter your personal details"
                                                    .tr
                                                : controller.currentStep
                                                            .value ==
                                                        2
                                                    ? "Provide vehicle details"
                                                        .tr
                                                    : "Upload required documents"
                                                        .tr,
                                        style: AppTypography.caption(context),
                                      ),
                                      const SizedBox(height: 20),
                                      _buildStepContent(context, controller),
                                      const SizedBox(
                                          height: 80), // Space for buttons
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    if (controller.currentStep.value > 0)
                                      Expanded(
                                        child: ButtonThem.buildButton(
                                          context,
                                          title: "Back".tr,
                                          onPress: () {
                                            controller.currentStep.value--;
                                          },
                                        ),
                                      ),
                                    if (controller.currentStep.value > 0)
                                      const SizedBox(width: 10),
                                    Expanded(
                                      child: ButtonThem.buildButton(
                                        context,
                                        title: controller.currentStep.value == 3
                                            ? "Submit".tr
                                            : "Next".tr,
                                        onPress: () {
                                          controller.handleNext(context);
                                        },
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

  Widget _buildTabBar(BuildContext context, InformationController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress Bar (background layer)
          Positioned(
            left: 20,
            right: 20,
            top: 30,
            child: Container(
              width: double.infinity,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (controller.currentStep.value + 1) / 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          // Tabs (foreground layer)
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTabItem(
                    context,
                    controller,
                    controller.currentStep.value >= 0,
                    Icons.list_alt_rounded,
                    'Service',
                    0,
                  ),
                  _buildTabItem(
                    context,
                    controller,
                    controller.currentStep.value >= 1,
                    Icons.person_outline_rounded,
                    'Personal',
                    1,
                  ),
                  _buildTabItem(
                    context,
                    controller,
                    controller.currentStep.value >= 2,
                    Icons.directions_car_outlined,
                    'Vehicle',
                    2,
                  ),
                  _buildTabItem(
                    context,
                    controller,
                    controller.currentStep.value >= 3,
                    Icons.document_scanner_outlined,
                    'Documents',
                    3,
                  ),
                ],
              ),
              const SizedBox(height: 20), // Space to avoid overlap
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context,
    InformationController controller,
    bool isActive,
    IconData icon,
    String label,
    int index,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.currentStep.value = index,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                color: isActive ? AppColors.primary : Colors.grey[50],
              ),
              child: Icon(
                icon,
                color: isActive ? AppColors.background : Colors.grey[600],
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.smBoldLabel(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(
      BuildContext context, InformationController controller) {
    switch (controller.currentStep.value) {
      case 0:
        return _buildServiceTypeStep(context, controller);
      case 1:
        return _buildPersonalInfoStep(context, controller);
      case 2:
        return _buildVehicleInfoStep(context, controller);
      case 3:
        return _buildVerificationStep(context, controller);
      default:
        return Container();
    }
  }

  Widget _buildServiceTypeStep(
      BuildContext context, InformationController controller) {
    // Select the first service by default when the list is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.serviceList.isNotEmpty &&
          (controller.selectedServiceId.value == null ||
              controller.selectedServiceId.value!.isEmpty)) {
        final firstService = controller.serviceList.firstWhere(
          (service) => service.enable ?? false,
          orElse: () => controller.serviceList.first,
        );
        if (firstService.id != null) {
          controller.selectedServiceId.value = firstService.id!;
        }
      }
    });

    return Obx(() => Column(
          children: controller.serviceList.map((service) {
            final bool isEnabled = service.enable ?? false;
            return GestureDetector(
              onTap: isEnabled
                  ? () {
                      controller.selectedServiceId.value = service.id!;
                    }
                  : () {
                      ShowToastDialog.showToast(
                          "This service is coming soon".tr);
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: controller.selectedServiceId.value == service.id
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (service.image != null && service.image!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: service.image!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.error,
                            color: Colors.red,
                            size: 30,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.grey,
                          size: 30,
                        ),
                      ),
                    const SizedBox(width: 12),
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
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Coming Soon".tr,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      )
                    else if (controller.selectedServiceId.value == service.id)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 24,
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
        // Profile Image Upload Section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'Profile Image'.tr,
              style: AppTypography.caption(Get.context!)
                  .copyWith(color: AppColors.grey500),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showImageSourceSelector(context, controller),
              child: Obx(() => Container(
                    height: Responsive.height(15, context),
                    width: Responsive.width(30, context),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.grey.shade200, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: controller.userImage.value.isEmpty
                        ? _buildImagePlaceholder(
                            context, "Tap to upload photo".tr)
                        : _buildImagePreview(
                            context, controller.userImage.value),
                  )),
            ),
            if (controller.userImage.value.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Profile image is required".tr,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
            controller: controller.fullNameController.value,
            label: 'Full Name'.tr,
            icon: Icons.person_outline,
            caption: "Enter Your Name"),
        const SizedBox(height: 16),
        _buildTextField(
            controller: controller.emailController.value,
            label: 'Email'.tr,
            icon: Icons.email_outlined,
            caption: "Enter Your Email"),
        const SizedBox(height: 16),
        _buildTextField(
            controller: controller.passwordController.value,
            label: 'Password'.tr,
            icon: Icons.lock_outline,
            obscureText: true,
            caption: "Enter Your Password"),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phone Number'.tr,
              style: AppTypography.caption(Get.context!)
                  .copyWith(color: AppColors.grey500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.textField,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: TextFormField(
                validator: (value) =>
                    value != null && value.isNotEmpty ? null : 'Required',
                keyboardType: TextInputType.number,
                controller: controller.phoneNumberController.value,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: CountryCodePicker(
                    onChanged: (value) {
                      controller.countryCode.value = value.dialCode.toString();
                    },
                    dialogBackgroundColor: AppColors.background,
                    initialSelection: controller.countryCode.value,
                    comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                    flagDecoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context, String imagePath) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: Responsive.height(15, context),
            width: Responsive.width(30, context),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey[200]!, Colors.grey[300]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Constant().hasValidUrl(imagePath)
                ? CachedNetworkImage(
                    imageUrl: imagePath,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Center(child: Constant.loader(context)),
                    errorWidget: (context, url, error) =>
                        Icon(Icons.error, color: Colors.red[300]),
                  )
                : Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.error, color: Colors.red[300]),
                  ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder(BuildContext context, String text) {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(8),
      dashPattern: const [6, 4],
      color: AppColors.primary.withOpacity(0.08),
      strokeWidth: 1.5,
      child: Container(
        height: Responsive.height(15, context),
        width: Responsive.width(30, context),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [Colors.grey[50]!, Colors.grey[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBackground.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_upload_outlined,
                  size: 25, color: AppColors.darkBackground),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: AppTypography.boldLabel(context).copyWith(
                color: AppColors.primary.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceSelector(
      BuildContext context, InformationController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                "Choose Photo Source".tr,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Select how you want to add your profile photo".tr,
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        controller.pickUserImage(source: ImageSource.camera);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Camera".tr,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        controller.pickUserImage(source: ImageSource.gallery);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                              color: AppColors.darkBackground.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.darkBackground,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.photo_library,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Gallery".tr,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkBackground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
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
            icon: Icons.confirmation_number_outlined,
            caption: "Enter Your Vehicle Number"),
        const SizedBox(height: 16),
        _buildTextField(
          controller: controller.registrationDateController.value,
          label: 'Registration Date'.tr,
          icon: Icons.calendar_today_outlined,
          enabled: false,
          onTap: () async {
            await Constant.selectDate(context).then((value) {
              if (value != null) {
                controller.selectedDate.value = value;
                controller.registrationDateController.value.text =
                    DateFormat("dd-MM-yyyy").format(value);
              }
            });
          },
        ),
        const SizedBox(height: 16),
        Obx(() => _buildTextField(
            controller: TextEditingController(
              text: controller.selectedVehicle.value.id == null
                  ? ''
                  : Constant.localizationName(
                      controller.selectedVehicle.value.name),
            ),
            label: 'Vehicle Type'.tr,
            icon: Icons.directions_car_outlined,
            enabled: false,
            onTap: () => _showVehicleTypeSelector(context, controller),
            caption: "Enter Your Vehicle Type")),
        const SizedBox(height: 16),
        Obx(() => _buildTextField(
            controller:
                TextEditingController(text: controller.selectedColor.value),
            label: 'Vehicle Color'.tr,
            icon: Icons.palette_outlined,
            enabled: false,
            onTap: () => _showColorSelector(context, controller),
            caption: "Enter Your Vehicle Color")),
        const SizedBox(height: 16),
        Obx(() => _buildTextField(
            controller: controller.seatsController.value,
            label: 'Number of Seats'.tr,
            icon: Icons.event_seat_outlined,
            enabled: false,
            onTap: () => _showSeatsSelector(context, controller),
            caption: "Enter No Of Seats")),
        const SizedBox(height: 16),
        Obx(() => _buildTextField(
            controller: controller.zoneNameController.value,
            label: 'Service Zone'.tr,
            icon: Icons.location_on_outlined,
            enabled: false,
            onTap: () => _showZoneSelector(context, controller),
            caption: "Select Your Zone")),
      ],
    );
  }

  Widget _buildVerificationStep(
      BuildContext context, InformationController controller) {
    return Column(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          child: Obx(() => ListView.builder(
                itemCount: controller.documentList.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  DocumentModel documentModel = controller.documentList[index];
                  Documents documents = Documents();

                  var contain = controller.driverDocumentList.where(
                      (element) => element.documentId == documentModel.id);
                  if (contain.isNotEmpty) {
                    documents = controller.driverDocumentList.firstWhere(
                        (itemToCheck) =>
                            itemToCheck.documentId == documentModel.id);
                  }

                  bool isVerified = documents.verified == true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          controller.showDocumentUploadScreen(
                              context, documentModel, documents);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isVerified
                                          ? Colors.green.withOpacity(0.1)
                                          : AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isVerified
                                          ? Icons.verified_rounded
                                          : Icons.description_outlined,
                                      color: isVerified
                                          ? Colors.green
                                          : AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          Constant.localizationTitle(
                                              documentModel.title),
                                          style: AppTypography.appBar(context)
                                              .copyWith(
                                            color: AppColors.darkBackground
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isVerified
                                              ? "Document verified successfully"
                                                  .tr
                                              : "Tap to upload document".tr,
                                          style: AppTypography.label(context)
                                              .copyWith(
                                            color: AppColors.darkBackground
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      spreadRadius: 0.7,
                                      blurRadius: 1,
                                      offset: const Offset(0, 1),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      spreadRadius: 0.7,
                                      blurRadius: 1,
                                      offset: const Offset(0, -1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isVerified
                                          ? Icons.check_circle_outline
                                          : Icons.info,
                                      size: 14,
                                      color: isVerified
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isVerified ? "Verified".tr : "Pending".tr,
                                      style: AppTypography.smBoldLabel(context)
                                          .copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    VoidCallback? onTap,
    bool obscureText = false,
    String? caption,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption(Get.context!)
                .copyWith(color: AppColors.grey500),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.textField,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              obscureText: obscureText,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: caption,
                hintStyle: AppTypography.input(Get.context!)
                    .copyWith(color: AppColors.grey500),
                prefixIcon: Icon(icon, color: Colors.black54, size: 20),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVehicleTypeSelector(
      BuildContext context, InformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Vehicle Type'.tr,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 25),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.vehicleList.length,
                itemBuilder: (context, index) {
                  final vehicleType = controller.vehicleList[index];
                  return Obx(() => RadioListTile<VehicleTypeModel>(
                        value: vehicleType,
                        groupValue: controller.selectedVehicle.value,
                        onChanged: (value) {
                          controller.selectedVehicle.value = value!;
                          Navigator.pop(context);
                        },
                        title: Text(
                          Constant.localizationName(vehicleType.name),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorSelector(
      BuildContext context, InformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Vehicle Color'.tr,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 25),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.carColorList.length,
                itemBuilder: (context, index) {
                  final color = controller.carColorList[index];
                  return Obx(() => RadioListTile<String>(
                        value: color,
                        groupValue: controller.selectedColor.value,
                        onChanged: (value) {
                          controller.selectedColor.value = value!;
                          Navigator.pop(context);
                        },
                        title: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _getColorFromString(color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(color,
                                style: GoogleFonts.poppins(fontSize: 14)),
                          ],
                        ),
                      ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeatsSelector(
      BuildContext context, InformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Number of Seats'.tr,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 25),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.sheetList.length,
                itemBuilder: (context, index) {
                  final seats = controller.sheetList[index];
                  return Obx(() => RadioListTile<String>(
                        value: seats,
                        groupValue: controller.seatsController.value.text,
                        onChanged: (value) {
                          controller.seatsController.value.text = value!;
                          Navigator.pop(context);
                        },
                        title: Text('$seats Seats',
                            style: GoogleFonts.poppins(fontSize: 14)),
                      ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showZoneSelector(
      BuildContext context, InformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Zones'.tr,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 25),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.zoneList.length,
                itemBuilder: (context, index) {
                  final zone = controller.zoneList[index];
                  return Obx(() => CheckboxListTile(
                        value: controller.selectedZone.contains(zone.id),
                        onChanged: (value) {
                          if (value == true && zone.id != null) {
                            controller.selectedZone.add(zone.id!);
                          } else if (zone.id != null) {
                            controller.selectedZone.remove(zone.id!);
                          }
                        },
                        title: Text(
                          Constant.localizationName(zone.name),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel".tr),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.selectedZone.isEmpty) {
                          ShowToastDialog.showToast("Please select zone".tr);
                        } else {
                          controller.zoneNameController.value.text = controller
                              .selectedZone
                              .map((id) => Constant.localizationName(controller
                                  .zoneList
                                  .firstWhere((z) => z.id == id)
                                  .name))
                              .join(", ");
                          Navigator.pop(context);
                        }
                      },
                      child: Text("Apply".tr),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'grey':
      case 'gray':
        return Colors.grey;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'brown':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
