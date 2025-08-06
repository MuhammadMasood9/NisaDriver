import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/details_upload_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// NOTE: This widget is preserved in the file as requested, but is no longer
// used by the refactored DetailsUploadScreen below.
class EnhancedDateSelector extends StatefulWidget {
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
  State<EnhancedDateSelector> createState() => _EnhancedDateSelectorState();
}

class _EnhancedDateSelectorState extends State<EnhancedDateSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate ?? DateTime.now(),
      firstDate: widget.firstDate ?? DateTime(1900),
      lastDate: widget.lastDate ?? DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
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
      widget.onDateSelected(picked);
    }
  }

  void _clearDate() {
    // A null date would be more appropriate for clearing.
    // However, adhering to the original logic.
    widget.onDateSelected(DateTime.now());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;
    final bool hasValue = widget.selectedDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: AppTypography.boldLabel(context),
            ),
            if (widget.isRequired)
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
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTapDown: (_) {
                  setState(() => _isPressed = true);
                  _animationController.forward();
                },
                onTapUp: (_) {
                  setState(() => _isPressed = false);
                  _animationController.reverse();
                  _selectDate();
                },
                onTapCancel: () {
                  setState(() => _isPressed = false);
                  _animationController.reverse();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
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
                        color: _isPressed
                            ? widget.primaryColor.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                        spreadRadius: _isPressed ? 2 : 1,
                        blurRadius: _isPressed ? 12 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color:
                              hasValue ? widget.primaryColor : Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasValue
                                ? DateFormat(widget.dateFormat)
                                    .format(widget.selectedDate!)
                                : widget.hintText,
                            style: AppTypography.caption(context),
                          ),
                        ),
                        if (hasValue && widget.showClearButton)
                          GestureDetector(
                            onTap: _clearDate,
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
            );
          },
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
                widget.errorText!,
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

class DetailsUploadScreen extends StatelessWidget {
  const DetailsUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<DetailsUploadController>(
      init: DetailsUploadController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: _buildAppBar(context, controller),
          body: controller.isLoading.value &&
                  controller.documents.value.documentId == null
              ? _buildLoader()
              : _buildBody(context, controller),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, DetailsUploadController controller) {
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
        Constant.localizationTitle(controller.documentModel.value.title),
        style: AppTypography.appTitle(context),
      ),
      centerTitle: true,
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading details...'.tr,
            style: AppTypography.label(Get.context!),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, DetailsUploadController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(controller),
          const SizedBox(height: 24),
          _buildDetailsSection(context, controller),
          const SizedBox(height: 32),
          if (controller.documents.value.verified != true)
            _buildSaveButton(context, controller),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(DetailsUploadController controller) {
    bool isVerified = controller.documents.value.verified == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVerified
              ? [const Color(0xFF10B981), const Color(0xFF059669)] // Green
              : [AppColors.primary, AppColors.darkModePrimary], // Blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
            ),
            child: Icon(
              isVerified
                  ? Icons.verified_user_outlined
                  : Icons.upload_file_outlined,
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
                  isVerified ? "Document Verified".tr : "Upload Required".tr,
                  style: AppTypography.boldHeaders(Get.context!)
                      .copyWith(color: AppColors.background),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified
                      ? "This document has been successfully verified.".tr
                      : "Please fill in the details and upload photos.".tr,
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

  Widget _buildDetailsSection(
      BuildContext context, DetailsUploadController controller) {
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
                const Icon(
                  Icons.edit_document,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Document Information'.tr,
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
                  label: "Document Number".tr,
                  hint:
                      "Enter ${Constant.localizationTitle(controller.documentModel.value.title)} Number"
                          .tr,
                  controller: controller.documentNumberController.value,
                  icon: Icons.confirmation_number_outlined,
                  enabled: controller.documents.value.verified != true,
                ),
                if (controller.documentModel.value.expireAt == true)
                  _buildModernDateField(context, controller),
                if (controller.documentModel.value.frontSide == true)
                  _buildImageUploadSection(
                    context,
                    controller,
                    "Front Side Image",
                    controller.frontImage.value,
                    "front",
                  ),
                if (controller.documentModel.value.backSide == true)
                  _buildImageUploadSection(
                    context,
                    controller,
                    "Back Side Image",
                    controller.backImage.value,
                    "back",
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.boldLabel(Get.context!),
          ),
          const SizedBox(height: 8),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              style: AppTypography.label(Get.context!),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
                hintText: hint,
                hintStyle: AppTypography.label(Get.context!)
                    .copyWith(color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDateField(
      BuildContext context, DetailsUploadController controller) {
    bool isEnabled = controller.documents.value.verified != true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Expiry Date".tr,
            style: AppTypography.boldLabel(Get.context!),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: !isEnabled
                ? null
                : () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate:
                          controller.selectedDate.value ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 20)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      controller.selectedDate.value = picked;
                      controller.expireAtController.value.text =
                          DateFormat("dd-MM-yyyy").format(picked);
                    }
                  },
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isEnabled ? Colors.white : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      controller.expireAtController.value.text.isEmpty
                          ? "Select Expiry Date".tr
                          : controller.expireAtController.value.text,
                      style: AppTypography.label(Get.context!).copyWith(
                        color: controller.expireAtController.value.text.isEmpty
                            ? Colors.grey.shade400
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (isEnabled)
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection(
    BuildContext context,
    DetailsUploadController controller,
    String title,
    String imagePath,
    String type,
  ) {
    bool isVerified = controller.documents.value.verified == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.tr,
            style: AppTypography.boldLabel(context),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: isVerified
                ? null
                : () => buildBottomSheet(context, controller, type),
            child: imagePath.isNotEmpty
                ? _buildImagePreview(context, imagePath, isVerified)
                : _buildImagePlaceholder(context),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(
      BuildContext context, String imagePath, bool isVerified) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: Responsive.height(22, context),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
            ),
            child: Constant().hasValidUrl(imagePath)
                ? CachedNetworkImage(
                    imageUrl: imagePath,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Center(child: Constant.loader(context)),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, color: Colors.red),
                  )
                : Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                  ),
          ),
          if (!isVerified)
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 18),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(8),
      dashPattern: const [6, 4],
      color: AppColors.primary.withOpacity(0.5),
      strokeWidth: 1.5,
      child: Container(
        height: Responsive.height(22, context),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_upload_outlined,
              size: 40,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              "Tap to upload photo".tr,
              style: AppTypography.headers(context)
                  .copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              "Use a clear, well-lit photo".tr,
              style: AppTypography.caption(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(
      BuildContext context, DetailsUploadController controller) {
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
        onPressed: () {
          // Prevent multiple clicks while loading
          if (controller.isLoading.value) return;

          if (controller.documentNumberController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please enter document number".tr);
          } else if (controller.documentModel.value.expireAt == true &&
              controller.expireAtController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please select an expiry date.".tr);
          } else if (controller.documentModel.value.frontSide == true &&
              controller.frontImage.value.isEmpty) {
            ShowToastDialog.showToast(
                "Please upload front side of document.".tr);
          } else if (controller.documentModel.value.backSide == true &&
              controller.backImage.value.isEmpty) {
            ShowToastDialog.showToast(
                "Please upload back side of document.".tr);
          } else {
            controller.uploadDocument();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Obx(
          () => controller.isLoading.value
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save_outlined,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      "Save & Upload Document".tr,
                      style: AppTypography.buttonlight(context),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> buildBottomSheet(
      BuildContext context, DetailsUploadController controller, String type) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      "Choose Photo Source".tr,
                      style: AppTypography.appTitle(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSourceOptionItem(
                        context: context,
                        title: "Camera".tr,
                        icon: Icons.camera_alt_outlined,
                        onTap: () {
                          Get.back();
                          controller.pickFile(
                              source: ImageSource.camera, type: type);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSourceOptionItem(
                        context: context,
                        title: "Gallery".tr,
                        icon: Icons.photo_library_outlined,
                        onTap: () {
                          Get.back();
                          controller.pickFile(
                              source: ImageSource.gallery, type: type);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceOptionItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTypography.headers(context),
            ),
          ],
        ),
      ),
    );
  }
}
