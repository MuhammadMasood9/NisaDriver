import 'package:driver/constant/constant.dart';
import 'package:driver/controller/online_registration_controller.dart';
import 'package:driver/model/document_model.dart';
import 'package:driver/model/driver_document_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/ui/online_registration/details_upload_screen.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class OnlineRegistrationScreen extends StatelessWidget {
  const OnlineRegistrationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetBuilder<OnlineRegistrationController>(
        init: OnlineRegistrationController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: AppColors.primary,
            body: controller.isLoading.value
                ? Constant.loader(context)
                : Column(
                    children: [
                      // Modern Header Section
                      Container(
                        height: Responsive.width(30, context),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  "Document Verification".tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Complete your registration by uploading required documents".tr,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Content Section
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.background,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          child: controller.isLoading.value
                              ? Constant.loader(context)
                              : Column(
                                  children: [
                                    // Progress Indicator
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    
                                    // Document List
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                        child: ListView.builder(
                                          itemCount: controller.documentList.length,
                                          physics: const BouncingScrollPhysics(),
                                          itemBuilder: (context, index) {
                                            DocumentModel documentModel = controller.documentList[index];
                                            Documents documents = Documents();

                                            var contain = controller.driverDocumentList.where((element) => element.documentId == documentModel.id);
                                            if (contain.isNotEmpty) {
                                              documents = controller.driverDocumentList.firstWhere((itemToCheck) => itemToCheck.documentId == documentModel.id);
                                            }

                                            bool isVerified = documents.verified == true;

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 16),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    Get.to(const DetailsUploadScreen(), arguments: {'documentModel': documentModel});
                                                  },
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 200),
                                                    decoration: BoxDecoration(
                                                      color: themeChange.getThem() 
                                                          ? AppColors.darkContainerBackground 
                                                          : Colors.white,
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: isVerified 
                                                            ? Colors.green.withOpacity(0.3)
                                                            : themeChange.getThem() 
                                                                ? AppColors.darkContainerBorder.withOpacity(0.3)
                                                                : Colors.grey.withOpacity(0.2),
                                                        width: 1,
                                                      ),
                                                      boxShadow: themeChange.getThem()
                                                          ? [
                                                              BoxShadow(
                                                                color: Colors.black.withOpacity(0.1),
                                                                blurRadius: 8,
                                                                offset: const Offset(0, 2),
                                                              ),
                                                            ]
                                                          : [
                                                              BoxShadow(
                                                                color: Colors.black.withOpacity(0.08),
                                                                blurRadius: 16,
                                                                offset: const Offset(0, 4),
                                                              ),
                                                              BoxShadow(
                                                                color: Colors.black.withOpacity(0.04),
                                                                blurRadius: 4,
                                                                offset: const Offset(0, 1),
                                                              ),
                                                            ],
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(20),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              // Document Icon
                                                              Container(
                                                                width: 48,
                                                                height: 48,
                                                                decoration: BoxDecoration(
                                                                  color: isVerified 
                                                                      ? Colors.green.withOpacity(0.1)
                                                                      : AppColors.primary.withOpacity(0.1),
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                child: Icon(
                                                                  isVerified 
                                                                      ? Icons.verified_rounded
                                                                      : Icons.description_outlined,
                                                                  color: isVerified ? Colors.green : AppColors.primary,
                                                                  size: 24,
                                                                ),
                                                              ),
                                                              
                                                              const SizedBox(width: 16),
                                                              
                                                              // Document Details
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text(
                                                                      Constant.localizationTitle(documentModel.title),
                                                                      style: TextStyle(
                                                                        fontSize: 16,
                                                                        fontWeight: FontWeight.w600,
                                                                        color: themeChange.getThem() 
                                                                            ? Colors.white 
                                                                            : Colors.black87,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 4),
                                                                    Text(
                                                                      isVerified 
                                                                          ? "Document verified successfully".tr
                                                                          : "Tap to upload document".tr,
                                                                      style: TextStyle(
                                                                        fontSize: 14,
                                                                        color: themeChange.getThem() 
                                                                            ? Colors.white.withOpacity(0.7)
                                                                            : Colors.grey.shade600,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              
                                                              // Action Icon
                                                              Container(
                                                                width: 32,
                                                                height: 32,
                                                                decoration: BoxDecoration(
                                                                  color: themeChange.getThem() 
                                                                      ? Colors.white.withOpacity(0.1)
                                                                      : Colors.grey.withOpacity(0.1),
                                                                  borderRadius: BorderRadius.circular(8),
                                                                ),
                                                                child: Icon(
                                                                  Icons.arrow_forward_ios_rounded,
                                                                  size: 16,
                                                                  color: themeChange.getThem() 
                                                                      ? Colors.white.withOpacity(0.7)
                                                                      : Colors.grey.shade600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          
                                                          const SizedBox(height: 16),
                                                          
                                                          // Status Badge
                                                          Row(
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  color: isVerified 
                                                                      ? Colors.green
                                                                      : Colors.orange,
                                                                  borderRadius: BorderRadius.circular(20),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Icon(
                                                                      isVerified 
                                                                          ? Icons.check_circle_outline
                                                                          : Icons.pending_outlined,
                                                                      size: 14,
                                                                      color: Colors.white,
                                                                    ),
                                                                    const SizedBox(width: 4),
                                                                    Text(
                                                                      isVerified ? "Verified".tr : "Pending".tr,
                                                                      style: const TextStyle(
                                                                        color: Colors.white,
                                                                        fontSize: 12,
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
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
}