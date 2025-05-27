import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/details_upload_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_them.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: hasError ? Colors.red[700] : Colors.grey[800],
              ),
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
        const SizedBox(height: 12),
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
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: hasValue
                                ? widget.primaryColor.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            color: hasValue
                                ? widget.primaryColor
                                : Colors.grey[600],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasValue
                                ? DateFormat(widget.dateFormat)
                                    .format(widget.selectedDate!)
                                : widget.hintText,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight:
                                  hasValue ? FontWeight.w500 : FontWeight.w400,
                              color: hasValue
                                  ? Colors.grey[800]
                                  : Colors.grey[500],
                            ),
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
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color.fromARGB(255, 255, 255, 255),
                    const Color.fromARGB(255, 255, 255, 255).withOpacity(0.85)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(12),
                  child: InkWell(
                    onTap: () => Get.back(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.darkTextFieldBorder,
                        size: 25,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  Constant.localizationTitle(
                      controller.documentModel.value.title),
                  style: GoogleFonts.poppins(
                    color: AppColors.tabBarSelected,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: true,
              ),
            ),
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: controller.isLoading.value
                      ? SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Constant.loader(context),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProgressIndicator(controller),
                              const SizedBox(height: 24),
                              _buildDocumentNumberSection(context, controller),
                              if (controller.documentModel.value.expireAt ==
                                  true)
                                _buildExpiryDateSection(context, controller),
                              if (controller.documentModel.value.frontSide ==
                                  true)
                                _buildImageUploadSection(
                                  context,
                                  controller,
                                  "Front Side",
                                  controller.frontImage.value,
                                  "front",
                                  Icons.credit_card,
                                ),
                              if (controller.documentModel.value.backSide ==
                                  true)
                                _buildImageUploadSection(
                                  context,
                                  controller,
                                  "Back Side",
                                  controller.backImage.value,
                                  "back",
                                  Icons.flip_to_back,
                                ),
                              const SizedBox(height: 32),
                              if (controller.documents.value.verified != true)
                                _buildActionButton(context, controller),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(DetailsUploadController controller) {
    bool isVerified = controller.documents.value.verified == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isVerified ? Colors.green : AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVerified ? Icons.verified : Icons.upload_file,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? "Document Verified".tr : "Upload Required".tr,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isVerified ? Colors.green : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified
                      ? "Your document has been verified successfully".tr
                      : "Please upload all required documents".tr,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentNumberSection(
      BuildContext context, DetailsUploadController controller) {
    return _buildModernTextField(
      context,
      label: "Document Details".tr,
      hint:
          "Enter ${Constant.localizationTitle(controller.documentModel.value.title)} Number"
              .tr,
      controller: controller.documentNumberController.value,
      icon: Icons.document_scanner,
      enabled: false,
    );
  }

  Widget _buildExpiryDateSection(
      BuildContext context, DetailsUploadController controller) {
    return EnhancedDateSelector(
      label: "Expiry Date".tr,
      hintText: "Select Expiry Date".tr,
      selectedDate: controller.selectedDate.value,
      onDateSelected: (DateTime date) {
        controller.selectedDate.value = date;
        controller.expireAtController.value.text =
            DateFormat("dd-MM-yyyy").format(date);
      },
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      isRequired: true,
      primaryColor: AppColors.darkBackground,
      showClearButton: true,
      dateFormat: "dd-MM-yyyy",
      errorText: controller.expireAtController.value.text.isEmpty
          ? "Please select an expiry date".tr
          : null,
    );
  }

  Widget _buildImageUploadSection(
    BuildContext context,
    DetailsUploadController controller,
    String title,
    String imagePath,
    String type,
    IconData icon,
  ) {
    bool hasImage = imagePath.isNotEmpty;
    bool isVerified = controller.documents.value.verified == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "$title of ${Constant.localizationTitle(controller.documentModel.value.title)}"
                  .tr,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: isVerified
              ? null
              : () => buildBottomSheet(context, controller, type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: Responsive.height(25, context),
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
            ),
            child: hasImage
                ? _buildImagePreview(context, controller, imagePath, isVerified)
                : _buildImagePlaceholder(context),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context,
      DetailsUploadController controller, String imagePath, bool isVerified) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: Responsive.height(25, context),
            width: double.infinity,
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
        if (isVerified)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
          ),
        if (!isVerified)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
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
              child: const Icon(Icons.edit, color: Colors.white, size: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(16),
      dashPattern: const [6, 4],
      color: AppColors.primary.withOpacity(0.5),
      strokeWidth: 1.5,
      child: Container(
        height: Responsive.height(25, context),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.grey[100]!, Colors.grey[200]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Tap to upload photo".tr,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Take a clear photo of your document".tr,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, DetailsUploadController controller) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.9)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (controller.documentNumberController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please enter document number".tr);
          } else if (controller.documentModel.value.frontSide == true &&
              controller.frontImage.value.isEmpty) {
            ShowToastDialog.showToast(
                "Please upload front side of document.".tr);
          } else if (controller.documentModel.value.backSide == true &&
              controller.backImage.value.isEmpty) {
            ShowToastDialog.showToast(
                "Please upload back side of document.".tr);
          } else {
            ShowToastDialog.showLoader("Please wait..".tr);
            controller.uploadDocument();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (controller.isLoading.value)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              else
                const Icon(Icons.cloud_upload, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                controller.isLoading.value
                    ? "Uploading...".tr
                    : "Upload Document".tr,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
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
      isScrollControlled: true,
      builder: (context) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
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
                    "Select how you want to add your photo".tr,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSourceOption(
                          context,
                          controller,
                          type,
                          "Camera".tr,
                          Icons.camera_alt,
                          ImageSource.camera,
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSourceOption(
                          context,
                          controller,
                          type,
                          "Gallery".tr,
                          Icons.photo_library,
                          ImageSource.gallery,
                          Colors.blue,
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
      },
    );
  }

  Widget _buildSourceOption(
    BuildContext context,
    DetailsUploadController controller,
    String type,
    String title,
    IconData icon,
    ImageSource source,
    Color color,
  ) {
    return InkWell(
      onTap: () {
        controller.pickFile(source: source, type: type);
        Get.back();
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
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.darkBackground.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
              color: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
            ),
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.darkBackground,
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
                    color: AppColors.darkBackground.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.darkBackground,
                    size: 20,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
