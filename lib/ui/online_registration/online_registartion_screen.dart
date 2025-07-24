import 'package:driver/constant/constant.dart';
import 'package:driver/controller/online_registration_controller.dart';
import 'package:driver/model/document_model.dart';
import 'package:driver/model/driver_document_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/online_registration/details_upload_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          backgroundColor: const Color(0xFFFAFAFC), // Clean light background
          // appBar: _buildAppBar(context),
          body: controller.isLoading.value
              ? Constant.loader(context)
              : _buildBody(context, controller),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF1A1A1A), size: 18),
          onPressed: () => Get.back(),
        ),
      ),
      title: Text(
        "Document Verification".tr,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A),
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.help_outline,
                color: Color(0xFF1A1A1A), size: 18),
            onPressed: () {
              // Show help dialog
            },
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: const Color(0xFFF0F0F0),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, OnlineRegistrationController controller) {
    // Calculate progress
    int completedDocs = controller.driverDocumentList
        .where((doc) => doc.verified == true)
        .length;
    int totalDocs = controller.documentList.length;
    double progress = totalDocs == 0 ? 0.0 : completedDocs / totalDocs;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildProgressSection(context, completedDocs, totalDocs, progress),
            const SizedBox(height: 32),
            _buildDocumentsHeader(controller.documentList.length),
            const SizedBox(height: 16),
            _buildDocumentsList(context, controller),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(
      BuildContext context, int completed, int total, double progress) {
    bool isAllComplete = completed == total && total > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Progress Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: const Color(0xFFF5F5F5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isAllComplete
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFFF6B8A), // Pastel red
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${(progress * 100).toInt()}%",
                        style: AppTypography.appTitle(context),
                      ),
                      Text(
                        "Done".tr,
                        style: AppTypography.caption(context).copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Progress Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAllComplete
                          ? "Verification Complete!"
                          : "Complete Your Profile",
                      style: AppTypography.boldHeaders(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAllComplete
                          ? "All documents have been verified successfully"
                          : "Upload and verify your documents to start driving",
                      style: AppTypography.caption(context).copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildProgressStat(
                            Icons.check_circle_outline,
                            completed.toString(),
                            "Verified",
                            const Color(0xFF22C55E)),
                        const SizedBox(width: 16),
                        _buildProgressStat(
                            Icons.pending_outlined,
                            (total - completed).toString(),
                            "Pending",
                            const Color(0xFFFF6B8A)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isAllComplete) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6B8A).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: const Color(0xFFFF6B8A),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Complete all verifications to activate your driver account",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFFF6B8A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressStat(
      IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.appTitle(Get.context!),
            ),
            Text(
              label.tr,
              style: AppTypography.smBoldLabel(Get.context!).copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentsHeader(int totalDocs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Required Documents".tr,
              style: AppTypography.boldHeaders(Get.context!),
            ),
            const SizedBox(height: 4),
            Text(
              "Upload clear photos of your documents".tr,
              style: AppTypography.caption(Get.context!).copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B8A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "$totalDocs items",
            style: AppTypography.boldLabel(Get.context!)
                .copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsList(
      BuildContext context, OnlineRegistrationController controller) {
    return ListView.separated(
      itemCount: controller.documentList.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        DocumentModel documentModel = controller.documentList[index];
        Documents documents = Documents();

        var contain = controller.driverDocumentList
            .where((element) => element.documentId == documentModel.id);
        if (contain.isNotEmpty) {
          documents = controller.driverDocumentList
              .firstWhere((item) => item.documentId == documentModel.id);
        }

        bool isVerified = documents.verified == true;
        bool isUploaded = contain.isNotEmpty;

        return _buildDocumentCard(
          context,
          documentModel: documentModel,
          isVerified: isVerified,
          isUploaded: isUploaded,
          onTap: () {
            Get.to(() => const DetailsUploadScreen(),
                arguments: {'documentModel': documentModel});
          },
        );
      },
    );
  }

  Widget _buildDocumentCard(
    BuildContext context, {
    required DocumentModel documentModel,
    required bool isVerified,
    required bool isUploaded,
    required VoidCallback onTap,
  }) {
    Color statusColor;
    Color backgroundColor;
    String statusText;
    IconData statusIcon;

    if (isVerified) {
      statusColor = const Color(0xFF22C55E);
      backgroundColor = const Color(0xFF22C55E).withOpacity(0.1);
      statusText = "Verified".tr;
      statusIcon = Icons.check_circle;
    } else if (isUploaded) {
      statusColor = const Color(0xFFF59E0B);
      backgroundColor = const Color(0xFFF59E0B).withOpacity(0.1);
      statusText = "Under Review".tr;
      statusIcon = Icons.schedule;
    } else {
      statusColor = const Color(0xFFFF6B8A);
      backgroundColor = const Color(0xFFFF6B8A).withOpacity(0.1);
      statusText = "Upload Required".tr;
      statusIcon = Icons.cloud_upload;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Document Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getDocumentTypeIcon(documentModel.title.toString()),
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Document Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Constant.localizationTitle(documentModel.title),
                        style: AppTypography.appTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(statusText,
                                    style: AppTypography.smBoldLabel(context)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVerified
                            ? "Document verified successfully".tr
                            : isUploaded
                                ? "Pending admin verification".tr
                                : "Tap to upload your document".tr,
                        style: AppTypography.caption(context).copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow Icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
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
      return Icons.credit_card;
    } else if (title.contains('insurance')) {
      return Icons.security;
    } else if (title.contains('registration') ||
        title.contains('rc') ||
        title.contains('vehicle')) {
      return Icons.directions_car;
    } else if (title.contains('identity') ||
        title.contains('id') ||
        title.contains('aadhaar')) {
      return Icons.person;
    } else if (title.contains('photo') || title.contains('picture')) {
      return Icons.photo_camera;
    } else {
      return Icons.description;
    }
  }
}
