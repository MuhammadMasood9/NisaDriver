import 'package:driver/constant/constant.dart';
import 'package:driver/controller/online_registration_controller.dart';
import 'package:driver/model/document_model.dart';
import 'package:driver/model/driver_document_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/online_registration/details_upload_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OnlineRegistrationScreen extends StatelessWidget {
  const OnlineRegistrationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OnlineRegistrationController>(
      init: OnlineRegistrationController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: controller.isLoading.value
              ? _buildLoader()
              : _buildBody(context, controller),
        );
      },
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
            'Loading documents...'.tr,
            style: AppTypography.label(Get.context!),
          ),
        ],
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
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressSection(context, completedDocs, totalDocs, progress),
          const SizedBox(height: 24),
          _buildDocumentsSection(context, controller),
          const SizedBox(height: 24),
          _buildInfoCard(context),
          const SizedBox(height: 20),
        ],
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
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      strokeWidth: 7,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isAllComplete ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${(progress * 100).toInt()}%",
                        style: AppTypography.appTitle(context).copyWith(
                          color: isAllComplete
                              ? AppColors.success
                              : AppColors.primary,
                        ),
                      ),
                      Text(
                        "Done".tr,
                        style: AppTypography.caption(context)
                            .copyWith(color: AppColors.grey500),
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
                          ? "Verification Complete!".tr
                          : "Complete Your Profile".tr,
                      style: AppTypography.boldHeaders(context),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAllComplete
                          ? "All documents are verified. You are ready to go!"
                              .tr
                          : "Upload and verify your documents to start driving."
                              .tr,
                      style: AppTypography.caption(context)
                          .copyWith(color: AppColors.grey600, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildProgressStat(
                            Icons.check_circle_outline,
                            completed.toString(),
                            "Verified",
                            AppColors.success),
                        const SizedBox(width: 16),
                        _buildProgressStat(
                            Icons.pending_outlined,
                            (total - completed).toString(),
                            "Pending",
                            AppColors.darkModePrimary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(
      IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          '$value ${label.tr}',
          style: AppTypography.label(Get.context!)
              .copyWith(color: AppColors.grey700),
        ),
      ],
    );
  }

  Widget _buildDocumentsSection(
      BuildContext context, OnlineRegistrationController controller) {
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
                  Icons.folder_copy_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Required Documents'.tr,
                  style: AppTypography.boldHeaders(context),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${controller.documentList.length} items".tr,
                    style: AppTypography.smBoldLabel(context)
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildDocumentsList(context, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(
      BuildContext context, OnlineRegistrationController controller) {
    if (controller.documentList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Text(
            'No documents required at this time.'.tr,
            style: AppTypography.label(context),
          ),
        ),
      );
    }

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

        return _buildDocumentCard(
          context,
          documentModel: documentModel,
          driverDocument: documents,
          isUploaded: contain.isNotEmpty,
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
    required Documents driverDocument,
    required bool isUploaded,
    required VoidCallback onTap,
  }) {
    bool isVerified = driverDocument.verified == true;
    bool isUnderReview = isUploaded && !isVerified;

    Color statusColor;
    Color backgroundColor;
    String statusText;
    IconData statusIcon;

    if (isVerified) {
      statusColor = AppColors.success;
      backgroundColor = statusColor.withOpacity(0.1);
      statusText = "Verified".tr;
      statusIcon = Icons.check_circle;
    } else if (isUnderReview) {
      statusColor = AppColors.ratingColour;
      backgroundColor = statusColor.withOpacity(0.1);
      statusText = "Under Review".tr;
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      statusColor = AppColors.darkModePrimary;
      backgroundColor = statusColor.withOpacity(0.1);
      statusText = "Upload Required".tr;
      statusIcon = Icons.upload_file_rounded;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getDocumentTypeIcon(documentModel.title.toString()),
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Constant.localizationTitle(documentModel.title),
                    style: AppTypography.headers(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: AppTypography.smBoldLabel(context)
                              .copyWith(color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(
              Icons.info_outline,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Your documents will be reviewed by our team. You'll be notified once the verification is complete."
                  .tr,
              style: AppTypography.label(context)
                  .copyWith(color: AppColors.primary.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentTypeIcon(String documentTitle) {
    String title = documentTitle.toLowerCase();
    if (title.contains('license') || title.contains('driving')) {
      return Icons.credit_card_outlined;
    } else if (title.contains('insurance')) {
      return Icons.security_outlined;
    } else if (title.contains('registration') ||
        title.contains('rc') ||
        title.contains('vehicle')) {
      return Icons.directions_car_outlined;
    } else if (title.contains('identity') ||
        title.contains('id') ||
        title.contains('aadhaar')) {
      return Icons.person_outline;
    } else if (title.contains('photo') || title.contains('picture')) {
      return Icons.photo_camera_outlined;
    } else {
      return Icons.description_outlined;
    }
  }
}
