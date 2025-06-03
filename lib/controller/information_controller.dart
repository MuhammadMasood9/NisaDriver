import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/language_name.dart';
import 'package:driver/model/service_model.dart';
import 'package:driver/model/vehicle_type_model.dart';
import 'package:driver/model/zone_model.dart';
import 'package:driver/model/document_model.dart';
import 'package:driver/model/driver_document_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/auth_screen/information_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/ui/subscription_plan_screen/subscription_list_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class InformationController extends GetxController {
  RxInt currentStep = 0.obs;
  RxBool isLoading = true.obs;

  // Personal Info
  Rx<TextEditingController> fullNameController = TextEditingController().obs;
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> passwordController = TextEditingController().obs;
  Rx<TextEditingController> phoneNumberController = TextEditingController().obs;
  RxString countryCode = "+1".obs;
  RxString loginType = Constant.emailLoginType.obs;
  // Driver User Model
  Rx<DriverUserModel> userModel = DriverUserModel().obs;

  // Service Selection
  RxList<ServiceModel> serviceList = <ServiceModel>[].obs;
  Rx<String?> selectedServiceId = Rx<String?>(null);

  // Vehicle Info
  Rx<TextEditingController> vehicleNumberController =
      TextEditingController().obs;
  Rx<TextEditingController> seatsController = TextEditingController().obs;
  Rx<TextEditingController> registrationDateController =
      TextEditingController().obs;
  Rx<TextEditingController> zoneNameController = TextEditingController().obs;
  Rx<DateTime?> selectedDate = DateTime.now().obs;
  Rx<String> selectedColor = "".obs;
  List<String> carColorList = [
    'Red',
    'Black',
    'White',
    'Blue',
    'Green',
    'Orange',
    'Silver',
    'Gray',
    'Yellow',
    'Brown',
    'Gold',
    'Beige',
    'Purple'
  ];
  List<String> sheetList = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
    '13',
    '14',
    '15'
  ];
  RxList<VehicleTypeModel> vehicleList = <VehicleTypeModel>[].obs;
  Rx<VehicleTypeModel> selectedVehicle = VehicleTypeModel().obs;
  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  RxList<String> selectedZone = <String>[].obs;

  // Verification
  RxList<DocumentModel> documentList = <DocumentModel>[].obs;
  RxList<Documents> driverDocumentList = <Documents>[].obs;

  // Document Upload
  final ImagePicker _imagePicker = ImagePicker();
  Rx<DocumentModel> currentDocument = DocumentModel().obs;
  Rx<Documents> currentDocuments = Documents().obs;
  Rx<TextEditingController> documentNumberController =
      TextEditingController().obs;
  Rx<TextEditingController> expireAtController = TextEditingController().obs;
  Rx<DateTime?> selectedDocumentDate = Rx<DateTime?>(null);
  RxString frontImage = "".obs;
  RxString backImage = "".obs;

  // Store document details for registration
  RxMap<String, Documents> registrationDocuments = <String, Documents>{}.obs;

  @override
  void onInit() {
    getInitialData();
    super.onInit();
  }

  Future<void> getInitialData() async {
    isLoading.value = true;
    serviceList.value = await FireStoreUtils.getService();
    zoneList.value = await FireStoreUtils.getZone() ?? [];
    vehicleList.value = await FireStoreUtils.getVehicleType() ?? [];
    documentList.value = await FireStoreUtils.getDocumentList();
    final driverDocs = await FireStoreUtils.getDocumentOfDriver();
    if (driverDocs != null) {
      driverDocumentList.value = driverDocs.documents ?? [];
    }
    // Initialize registrationDocuments for each enabled document
    for (var doc in documentList.value) {
      if (doc.enable == true && doc.id != null) {
        var existing = driverDocumentList.firstWhere(
          (d) => d.documentId == doc.id,
          orElse: () => Documents(documentId: doc.id),
        );
        registrationDocuments[doc.id!] = existing;
      }
    }
    isLoading.value = false;
  }

  void showDocumentUploadScreen(
      BuildContext context, DocumentModel documentModel, Documents documents) {
    if (documentModel.id == null) {
      ShowToastDialog.showToast("Invalid document ID".tr);
      return;
    }

    currentDocument.value = documentModel;
    currentDocuments.value = documents;
    documentNumberController.value.text = documents.documentNumber ?? '';
    // Only set images if they are empty to preserve locally selected images
    if (frontImage.value.isEmpty) frontImage.value = documents.frontImage ?? '';
    if (backImage.value.isEmpty) backImage.value = documents.backImage ?? '';
    if (documents.expireAt != null) {
      selectedDocumentDate.value = documents.expireAt!.toDate();
      expireAtController.value.text =
          DateFormat("dd-MM-yyyy").format(selectedDocumentDate.value!);
    } else {
      selectedDocumentDate.value = null;
      expireAtController.value.text = '';
    }

    // Update registrationDocuments with current data
    registrationDocuments[documentModel.id!] = currentDocuments.value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300]!,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  currentDocument.value.title != null
                      ? Constant.localizationTitle(currentDocument.value.title!)
                      : "Document",
                  style: AppTypography.appBar(context),
                ),
                const SizedBox(height: 24),
                _buildProgressIndicator(context, documentModel, documents),
                const SizedBox(height: 24),
                _buildDocumentNumberSection(context),
                if (currentDocument.value.expireAt == true)
                  _buildExpiryDateSection(context),
                if (currentDocument.value.frontSide == true)
                  _buildImageUploadSection(context, "Front Side",
                      frontImage.value, "front", Icons.credit_card),
                if (currentDocument.value.backSide == true)
                  _buildImageUploadSection(context, "Back Side",
                      backImage.value, "back", Icons.flip_to_back),
                const SizedBox(height: 32),
                if (!(documents.verified ?? false)) _buildActionButton(context),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(
      BuildContext context, DocumentModel documentModel, Documents documents) {
    bool isVerified = documents.verified ?? false;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isVerified ? Colors.green : AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVerified ? Icons.verified : Icons.upload_file,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? "Document Verified".tr : "Upload Required".tr,
                  style: AppTypography.boldLabel(Get.context!).copyWith(
                      color: isVerified ? Colors.green : AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified
                      ? "Your document has been verified successfully".tr
                      : "Please upload all required documents".tr,
                  style: AppTypography.label(Get.context!)
                      .copyWith(color: AppColors.grey500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentNumberSection(BuildContext context) {
    bool isEnabled = !(currentDocuments.value.verified ?? false);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Document Details".tr, style: AppTypography.boldLabel(context)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
              color: isEnabled ? Colors.grey.shade50 : Colors.grey.shade100,
            ),
            child: TextField(
              controller: documentNumberController.value,
              enabled: isEnabled,
              style: AppTypography.caption(context),
              decoration: InputDecoration(
                hintText: currentDocument.value.title != null
                    ? "Enter ${Constant.localizationTitle(currentDocument.value.title!)} Number"
                        .tr
                    : "Enter Document Number".tr,
                hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: Icon(Icons.document_scanner,
                    color: AppColors.darkBackground, size: 20),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              ),
              onChanged: (value) {
                currentDocuments.value.documentNumber = value;
                if (currentDocument.value.id != null) {
                  registrationDocuments[currentDocument.value.id!] =
                      currentDocuments.value;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryDateSection(BuildContext context) {
    return EnhancedDateSelector(
      label: "Expiry Date".tr,
      hintText: "Select Expiry Date".tr,
      selectedDate: selectedDocumentDate.value ?? DateTime.now(),
      onDateSelected: (DateTime date) {
        selectedDocumentDate.value = date;
        expireAtController.value.text = DateFormat("dd-MM-yyyy").format(date);
        currentDocuments.value.expireAt = Timestamp.fromDate(date);
        if (currentDocument.value.id != null) {
          registrationDocuments[currentDocument.value.id!] =
              currentDocuments.value;
        }
      },
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      isRequired: true,
      primaryColor: AppColors.darkBackground,
      showClearButton: true,
      dateFormat: "dd-MM-yyyy",
      errorText: expireAtController.value.text.isEmpty
          ? "Please select an expiry date".tr
          : null,
    );
  }

  Widget _buildImageUploadSection(BuildContext context, String title,
      String imagePath, String type, IconData icon) {
    bool hasImage = imagePath.isNotEmpty;
    bool isVerified = currentDocuments.value.verified ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
                currentDocument.value.title != null
                    ? "$title of ${Constant.localizationTitle(currentDocument.value.title!)}"
                        .tr
                    : "$title of Document".tr,
                style: AppTypography.boldLabel(context)),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: isVerified ? null : () => buildBottomSheet(context, type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: Responsive.height(22, context),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: hasImage
                ? _buildImagePreview(context, imagePath, isVerified)
                : _buildImagePlaceholder(context),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildImagePreview(
      BuildContext context, String imagePath, bool isVerified) {
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
                  end: Alignment.bottomRight),
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
                        offset: Offset(0, 2))
                  ]),
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
                      offset: const Offset(0, 2))
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
              end: Alignment.bottomRight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: Icon(Icons.cloud_upload_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text("Tap to upload photo".tr,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            const SizedBox(height: 4),
            Text("Take a clear photo of your document".tr,
                style:
                    GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.darkBackground,
          AppColors.darkBackground.withOpacity(0.9)
        ], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: AppColors.darkBackground.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          if (documentNumberController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please enter document number".tr);
          } else if (currentDocument.value.frontSide == true &&
              frontImage.value.isEmpty) {
            ShowToastDialog.showToast(
                "Please upload front side of document.".tr);
          } else if (currentDocument.value.backSide == true &&
              backImage.value.isEmpty) {
            ShowToastDialog.showToast(
                "Please upload back side of document.".tr);
          } else if (currentDocument.value.expireAt == true &&
              expireAtController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please select an expiry date".tr);
          } else {
            ShowToastDialog.showLoader("Processing..".tr);
            saveDocumentLocally();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        child: Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading.value)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
              else
                const Icon(Icons.cloud_upload, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(isLoading.value ? "Uploading...".tr : "Save Document".tr,
                  style: AppTypography.appBar(context)
                      .copyWith(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> buildBottomSheet(BuildContext context, String type) {
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
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
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  Text("Choose Photo Source".tr,
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  Text("Select how you want to add your photo".tr,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: _buildSourceOption(
                              context,
                              type,
                              "Camera".tr,
                              Icons.camera_alt,
                              ImageSource.camera,
                              AppColors.primary)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildSourceOption(
                              context,
                              type,
                              "Gallery".tr,
                              Icons.photo_library,
                              ImageSource.gallery,
                              AppColors.darkBackground)),
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

  Widget _buildSourceOption(BuildContext context, String type, String title,
      IconData icon, ImageSource source, Color color) {
    return InkWell(
      onTap: () {
        pickFile(source: source, type: type);
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
                offset: const Offset(0, 2))
          ],
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 28)),
            const SizedBox(height: 8),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> pickFile(
      {required ImageSource source, required String type}) async {
    try {
      XFile? image = await _imagePicker.pickImage(source: source);
      if (image == null) return;
      if (type == "front") {
        frontImage.value = image.path;
        currentDocuments.value.frontImage = image.path;
      } else {
        backImage.value = image.path;
        currentDocuments.value.backImage = image.path;
      }
      if (currentDocument.value.id != null) {
        registrationDocuments[currentDocument.value.id!] =
            currentDocuments.value;
      }
    } catch (e) {
      ShowToastDialog.showToast("Failed to Pick: $e".tr);
    }
  }

  void saveDocumentLocally() {
    currentDocuments.value
      ..frontImage = frontImage.value
      ..documentId = currentDocument.value.id
      ..documentNumber = documentNumberController.value.text
      ..backImage = backImage.value
      ..verified = false;

    if (currentDocument.value.expireAt == true &&
        selectedDocumentDate.value != null) {
      currentDocuments.value.expireAt =
          Timestamp.fromDate(selectedDocumentDate.value!);
    }

    if (currentDocument.value.id != null) {
      registrationDocuments[currentDocument.value.id!] = currentDocuments.value;
      driverDocumentList.add(currentDocuments.value);
    }
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Document saved locally".tr);
    frontImage.value = '';
    backImage.value = '';
    documentNumberController.value.clear();
    expireAtController.value.clear();
    selectedDocumentDate.value = null;
    Get.back();
  }

  Future<bool> uploadDocuments(String driverId) async {
    for (var doc in registrationDocuments.values) {
      if (doc.documentId == null) continue;

      String frontImageFileName = doc.frontImage?.isNotEmpty ?? false
          ? File(doc.frontImage!).path.split('/').last
          : '';
      String backImageFileName = doc.backImage?.isNotEmpty ?? false
          ? File(doc.backImage!).path.split('/').last
          : '';

      if (doc.frontImage?.isNotEmpty ??
          false && !Constant().hasValidUrl(doc.frontImage!)) {
        doc.frontImage = await Constant.uploadUserImageToFireStorage(
            File(doc.frontImage!),
            "driverDocument/$driverId",
            frontImageFileName);
      }

      if (doc.backImage?.isNotEmpty ??
          false && !Constant().hasValidUrl(doc.backImage!)) {
        doc.backImage = await Constant.uploadUserImageToFireStorage(
            File(doc.backImage!),
            "driverDocument/$driverId",
            backImageFileName);
      }

      bool success = await FireStoreUtils.uploadDriverDocument(doc);
      if (!success) return false;
    }
    return true;
  }

  Future<void> handleNext(BuildContext context) async {
    switch (currentStep.value) {
      case 0:
        if (selectedServiceId.value == null ||
            selectedServiceId.value!.isEmpty) {
          ShowToastDialog.showToast("Please select a service type".tr);
          return;
        }
        currentStep.value++;
        break;
      case 1:
        if (fullNameController.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter full name".tr);
          return;
        }
        if (emailController.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter email".tr);
          return;
        }
        if (Constant.validateEmail(emailController.value.text) == false) {
          ShowToastDialog.showToast("Please enter valid email".tr);
          return;
        }
        if (passwordController.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter password".tr);
          return;
        }
        if (passwordController.value.text.length < 6) {
          ShowToastDialog.showToast(
              "Password must be at least 6 characters".tr);
          return;
        }
        if (phoneNumberController.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter phone number".tr);
          return;
        }
        currentStep.value++;
        break;
      case 2:
        if (vehicleNumberController.value.text.isEmpty) {
          ShowToastDialog.showToast("Please select a vehicle number".tr);
          return;
        }
        if (registrationDateController.value.text.isEmpty) {
          ShowToastDialog.showToast("Please select a registration date".tr);
          return;
        }
        if (selectedVehicle.value.id == null) {
          ShowToastDialog.showToast("Please select a vehicle type".tr);
          return;
        }
        if (selectedColor.value.isEmpty) {
          ShowToastDialog.showToast("Please select a vehicle color".tr);
          return;
        }
        if (seatsController.value.text.isEmpty) {
          ShowToastDialog.showToast("Please select seats".tr);
          return;
        }
        if (selectedZone.isEmpty) {
          ShowToastDialog.showToast("Please select a zone".tr);
          return;
        }
        currentStep.value++;
        break;
      case 3:
        // Validate all required documents
        bool allRequiredUploaded = true;
        for (var doc in documentList) {
          if (doc.enable == true && doc.id != null) {
            var uploadedDoc = registrationDocuments[doc.id!];
            if (uploadedDoc == null ||
                (doc.frontSide == true &&
                    (uploadedDoc.frontImage?.isEmpty ?? true)) ||
                (doc.backSide == true &&
                    (uploadedDoc.backImage?.isEmpty ?? true)) ||
                (uploadedDoc.documentNumber?.isEmpty ?? true) ||
                (doc.expireAt == true && uploadedDoc.expireAt == null)) {
              allRequiredUploaded = false;
              break;
            }
          }
        }
        if (!allRequiredUploaded) {
          ShowToastDialog.showToast("Please upload all required documents".tr);
          return;
        }

        ShowToastDialog.showLoader("Processing".tr);
        try {
          final email = emailController.value.text;
          final password = passwordController.value.text;
          UserCredential userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(email: email, password: password);
          final driverId = userCredential.user!.uid;

          userModel.value
            ..id = driverId
            ..fullName = fullNameController.value.text
            ..email = emailController.value.text
            ..password = passwordController.value.text
            ..countryCode = countryCode.value
            ..phoneNumber = phoneNumberController.value.text
            ..documentVerification = false
            ..isOnline = false
            ..createdAt = Timestamp.now()
            ..serviceId = selectedServiceId.value
            ..zoneIds = selectedZone.toList()
            ..loginType = Constant.emailLoginType
            ..vehicleInformation = VehicleInformation(
              vehicleNumber: vehicleNumberController.value.text,
              registrationDate: Timestamp.fromDate(selectedDate.value!),
              vehicleTypeId: selectedVehicle.value.id,
              vehicleType: selectedVehicle.value.name,
              vehicleColor: selectedColor.value,
              seats: seatsController.value.text,
            );

          final token = await NotificationService.getToken();
          userModel.value.fcmToken = token;

          // Upload documents to Firestore
          bool documentsUploaded = await uploadDocuments(driverId);
          if (!documentsUploaded) {
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Failed to upload documents".tr);
            return;
          }

          final success =
              await FireStoreUtils.updateDriverUser(userModel.value);
          if (success) {
            ShowToastDialog.closeLoader();
            if (userModel.value.subscriptionPlanId == null ||
                (userModel.value.subscriptionExpiryDate
                        ?.toDate()
                        .isBefore(DateTime.now()) ??
                    true)) {
              if (!(Constant.adminCommission?.isEnabled ?? false) &&
                  !Constant.isSubscriptionModelApplied) {
                Get.offAll(() => const DashBoardScreen());
              } else {
                Get.offAll(() => const SubscriptionListScreen(),
                    arguments: {"isShow": true});
              }
            } else {
              Get.offAll(() => const DashBoardScreen());
            }
          } else {
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Failed to update profile".tr);
          }
        } catch (e) {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Registration failed: $e".tr);
        }
        break;
    }
  }
}
