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
import 'package:google_fonts/google_fonts.dart';
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
            backgroundColor: AppColors.background,
            body: controller.isLoading.value
                ? Constant.loader(context)
                : Column(
                    children: [
                      // Modern Header Section
                      Container(
                        padding: const EdgeInsets.only(bottom: 30, top: 20),
                        child: Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.darkBackground.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.document_scanner,
                                color: AppColors.darkBackground,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 36),
                              child: Text(
                                "Complete your registration by uploading required documents"
                                    .tr,
                                style: GoogleFonts.poppins(
                                  color:
                                      AppColors.darkBackground.withOpacity(0.8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content Section
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.background,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: controller.isLoading.value
                              ? Constant.loader(context)
                              : Column(
                                  children: [
                                    // Progress Indicator

                                    // Document List
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 20),
                                        child: ListView.builder(
                                          itemCount:
                                              controller.documentList.length,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          itemBuilder: (context, index) {
                                            DocumentModel documentModel =
                                                controller.documentList[index];
                                            Documents documents = Documents();

                                            var contain = controller
                                                .driverDocumentList
                                                .where((element) =>
                                                    element.documentId ==
                                                    documentModel.id);
                                            if (contain.isNotEmpty) {
                                              documents = controller
                                                  .driverDocumentList
                                                  .firstWhere((itemToCheck) =>
                                                      itemToCheck.documentId ==
                                                      documentModel.id);
                                            }

                                            bool isVerified =
                                                documents.verified == true;

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 20),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: () {
                                                    Get.to(
                                                        const DetailsUploadScreen(),
                                                        arguments: {
                                                          'documentModel':
                                                              documentModel
                                                        });
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            20),
                                                    decoration: BoxDecoration(
                                                      color: themeChange
                                                              .getThem()
                                                          ? AppColors
                                                              .darkContainerBackground
                                                          : Colors.grey.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey.shade200,
                                                        width: 1.5,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppColors
                                                              .darkBackground
                                                              .withOpacity(
                                                                  0.08),
                                                          blurRadius: 8,
                                                          offset: const Offset(
                                                              0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            // Document Icon
                                                            Container(
                                                              width: 48,
                                                              height: 48,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isVerified
                                                                    ? Colors
                                                                        .green
                                                                        .withOpacity(
                                                                            0.1)
                                                                    : AppColors
                                                                        .primary
                                                                        .withOpacity(
                                                                            0.1),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              child: Icon(
                                                                isVerified
                                                                    ? Icons
                                                                        .verified_rounded
                                                                    : Icons
                                                                        .description_outlined,
                                                                color: isVerified
                                                                    ? Colors
                                                                        .green
                                                                    : AppColors
                                                                        .primary,
                                                                size: 24,
                                                              ),
                                                            ),

                                                            const SizedBox(
                                                                width: 16),

                                                            // Document Details
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    Constant.localizationTitle(
                                                                        documentModel
                                                                            .title),
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      color: themeChange.getThem()
                                                                          ? Colors
                                                                              .white
                                                                          : AppColors
                                                                              .darkBackground,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    isVerified
                                                                        ? "Document verified successfully"
                                                                            .tr
                                                                        : "Tap to upload document"
                                                                            .tr,
                                                                    style: GoogleFonts
                                                                        .poppins(
                                                                      fontSize:
                                                                          14,
                                                                      color: themeChange
                                                                              .getThem()
                                                                          ? Colors.white.withOpacity(
                                                                              0.7)
                                                                          : Colors
                                                                              .grey
                                                                              .shade500,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),

                                                            // Action Icon
                                                            Container(
                                                              width: 32,
                                                              height: 32,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: themeChange
                                                                        .getThem()
                                                                    ? Colors
                                                                        .white
                                                                        .withOpacity(
                                                                            0.1)
                                                                    : Colors
                                                                        .grey
                                                                        .shade100,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                              child: Icon(
                                                                Icons
                                                                    .arrow_forward_ios_rounded,
                                                                size: 16,
                                                                color: themeChange
                                                                        .getThem()
                                                                    ? Colors
                                                                        .white
                                                                        .withOpacity(
                                                                            0.7)
                                                                    : Colors
                                                                        .grey
                                                                        .shade600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),

                                                        const SizedBox(
                                                            height: 16),

                                                        // Status Badge
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 6),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isVerified
                                                                ? Colors.green
                                                                : Colors.orange,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                isVerified
                                                                    ? Icons
                                                                        .check_circle_outline
                                                                    : Icons
                                                                        .pending_outlined,
                                                                size: 14,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                isVerified
                                                                    ? "Verified"
                                                                        .tr
                                                                    : "Pending"
                                                                        .tr,
                                                                style:
                                                                    GoogleFonts
                                                                        .poppins(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
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
