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

class DetailsUploadScreen extends StatelessWidget {
  const DetailsUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<DetailsUploadController>(
        init: DetailsUploadController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: AppColors.primary,
            body: CustomScrollView(
              slivers: [
                // Modern App Bar
                SliverAppBar(
                  expandedHeight: 120,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: Text(
                      Constant.localizationTitle(controller.documentModel.value.title),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Content
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.background,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Constant.loader(context),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Progress Indicator
                                _buildProgressIndicator(controller),
                                
                                const SizedBox(height: 32),
                                
                                // Document Number Section
                                _buildDocumentNumberSection(context, controller),
                                
                                // Expiry Date Section
                                if (controller.documentModel.value.expireAt == true)
                                  _buildExpiryDateSection(context, controller),
                                
                                // Front Side Section
                                if (controller.documentModel.value.frontSide == true)
                                  _buildImageUploadSection(
                                    context,
                                    controller,
                                    "Front Side",
                                    controller.frontImage.value,
                                    "front",
                                    Icons.credit_card,
                                  ),
                                
                                // Back Side Section
                                if (controller.documentModel.value.backSide == true)
                                  _buildImageUploadSection(
                                    context,
                                    controller,
                                    "Back Side",
                                    controller.backImage.value,
                                    "back",
                                    Icons.flip_to_back,
                                  ),
                                
                                const SizedBox(height: 40),
                                
                                // Action Button
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
        });
  }

  Widget _buildProgressIndicator(DetailsUploadController controller) {
    bool isVerified = controller.documents.value.verified == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified ? Colors.green.withOpacity(0.3) : AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isVerified ? Colors.green : AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isVerified ? Icons.verified : Icons.upload_file,
              color: Colors.white,
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
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isVerified ? Colors.green : AppColors.primary,
                  ),
                ),
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

  Widget _buildDocumentNumberSection(BuildContext context, DetailsUploadController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Document Details".tr,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: TextFieldThem.buildTextFiled(
              context,
              hintText: "Enter ${Constant.localizationTitle(controller.documentModel.value.title)} Number".tr,
              controller: controller.documentNumberController.value,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildExpiryDateSection(BuildContext context, DetailsUploadController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Expiry Date".tr,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            await Constant.selectFetureDate(context).then((value) {
              if (value != null) {
                controller.selectedDate.value = value;
                controller.expireAtController.value.text = DateFormat("dd-MM-yyyy").format(value);
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TextFieldThem.buildTextFiledWithSuffixIcon(
                context,
                hintText: "Select Expiry Date".tr,
                controller: controller.expireAtController.value,
                enable: false,
                suffixIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.calendar_month, color: AppColors.primary),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
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
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text(
              "$title of ${Constant.localizationTitle(controller.documentModel.value.title)}".tr,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        InkWell(
          onTap: () {
            if (!isVerified) {
              buildBottomSheet(context, controller, type);
            }
          },
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
              border: hasImage && isVerified 
                  ? Border.all(color: Colors.green.withOpacity(0.3), width: 2)
                  : null,
            ),
            child: hasImage
                ? _buildImagePreview(context, controller, imagePath, isVerified)
                : _buildImagePlaceholder(context),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildImagePreview(BuildContext context, DetailsUploadController controller, String imagePath, bool isVerified) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: Responsive.height(25, context),
            width: double.infinity,
            child: Constant().hasValidUrl(imagePath) == false
                ? Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: imagePath,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[100],
                      child: Center(child: Constant.loader(context)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[100],
                      child: Icon(Icons.error, color: Colors.red[300]),
                    ),
                  ),
          ),
        ),
        if (isVerified)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
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
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 18),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(20),
      dashPattern: const [8, 4],
      color: AppColors.primary.withOpacity(0.4),
      strokeWidth: 2,
      child: Container(
        height: Responsive.height(25, context),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.primary.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
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

  Widget _buildActionButton(BuildContext context, DetailsUploadController controller) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (controller.documentNumberController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please enter document number".tr);
          } else {
            if (controller.documentModel.value.frontSide == true && controller.frontImage.value.isEmpty) {
              ShowToastDialog.showToast("Please upload front side of document.".tr);
            } else if (controller.documentModel.value.backSide == true && controller.backImage.value.isEmpty) {
              ShowToastDialog.showToast("Please upload back side of document.".tr);
            } else {
              ShowToastDialog.showLoader("Please wait..".tr);
              controller.uploadDocument();
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              "Upload Document".tr,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  buildBottomSheet(BuildContext context, DetailsUploadController controller, String type) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  "Choose Photo Source".tr,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Select how you want to add your photo".tr,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                
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
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
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
      onTap: () => controller.pickFile(source: source, type: type),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}