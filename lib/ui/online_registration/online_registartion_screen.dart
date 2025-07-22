import 'package:driver/constant/constant.dart';
import 'package:driver/controller/online_registration_controller.dart';
import 'package:driver/model/document_model.dart';
import 'package:driver/model/driver_document_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/online_registration/details_upload_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class OnlineRegistrationScreen extends StatelessWidget {
  const OnlineRegistrationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OnlineRegistrationController>(
      init: OnlineRegistrationController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC), // Lighter, cleaner background
         
          body: controller.isLoading.value
              ? Constant.loader(context)
              : _buildBody(context, controller),
        );
      },
    );
  }


  Widget _buildBody(BuildContext context, OnlineRegistrationController controller) {
    // Calculate progress
    int completedDocs = controller.driverDocumentList.where((doc) => doc.verified == true).length;
    int totalDocs = controller.documentList.length;
    double progress = totalDocs == 0 ? 0.0 : completedDocs / totalDocs;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressCard(context, completedDocs, totalDocs, progress),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "Required Documents".tr,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          ListView.builder(
            itemCount: controller.documentList.length,
            shrinkWrap: true, // Important for nested lists
            physics: const NeverScrollableScrollPhysics(), // Important for nested lists
            itemBuilder: (context, index) {
              DocumentModel documentModel = controller.documentList[index];
              Documents documents = Documents();

              var contain = controller.driverDocumentList.where((element) => element.documentId == documentModel.id);
              if (contain.isNotEmpty) {
                documents = controller.driverDocumentList.firstWhere((item) => item.documentId == documentModel.id);
              }

              bool isVerified = documents.verified == true;
              bool isUploaded = contain.isNotEmpty;

              return _buildDocumentItem(
                context,
                documentModel: documentModel,
                isVerified: isVerified,
                isUploaded: isUploaded,
                onTap: () {
                  Get.to(() => const DetailsUploadScreen(), arguments: {'documentModel': documentModel});
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, int completed, int total, double progress) {
    bool isAllComplete = completed == total && total > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_turned_in, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Verification Progress".tr, style: AppTypography.boldHeaders(context)),
                    const SizedBox(height: 4),
                    Text("Complete all steps to get started".tr, style: AppTypography.caption(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Task Completed".tr, style: AppTypography.label(context)),
              Text(
                "$completed/$total",
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isAllComplete ? Colors.green.shade500 : AppColors.primary,
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${(progress * 100).toInt()}%",
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDocumentItem(
    BuildContext context, {
    required DocumentModel documentModel,
    required bool isVerified,
    required bool isUploaded,
    required VoidCallback onTap,
  }) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isVerified) {
      statusColor = Colors.green;
      statusText = "Verified".tr;
      statusIcon = Icons.check_circle_rounded;
    } else if (isUploaded) {
      statusColor = Colors.orange;
      statusText = "Under Review".tr;
      statusIcon = Icons.access_time_filled_rounded;
    } else {
      statusColor = Colors.blue;
      statusText = "Upload Required".tr;
      statusIcon = Icons.upload_file_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Document Icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_getDocumentTypeIcon(documentModel.title.toString()), color: statusColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    // Document Title and Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Constant.localizationTitle(documentModel.title),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isVerified
                                ? "Document verified successfully".tr
                                : isUploaded
                                    ? "Pending admin verification".tr
                                    : "Tap to upload your document".tr,
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Action Arrow
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(thickness: 0.5),
                const SizedBox(height: 4),
                // Status Badge
                Row(
                  children: [
                    Icon(statusIcon, size: 18, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper method to get an icon based on the document name for better visuals.
  IconData _getDocumentTypeIcon(String documentTitle) {
    String title = documentTitle.toLowerCase();
    if (title.contains('license') || title.contains('driving')) {
      return Icons.credit_card_rounded;
    } else if (title.contains('insurance')) {
      return Icons.shield_rounded;
    } else if (title.contains('registration') || title.contains('rc') || title.contains('vehicle')) {
      return Icons.directions_car_rounded;
    } else if (title.contains('identity') || title.contains('id') || title.contains('aadhaar')) {
      return Icons.badge_rounded;
    } else if (title.contains('photo') || title.contains('picture')) {
      return Icons.photo_camera_rounded;
    } else {
      return Icons.description_rounded;
    }
  }
}