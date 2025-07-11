import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/document_model.dart';
import 'package:driver/model/driver_document_model.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/language_name.dart';
import 'package:driver/model/service_model.dart';
import 'package:driver/model/vehicle_type_model.dart';
import 'package:driver/model/zone_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/auth_screen/information_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class InformationController extends GetxController {
  RxInt currentStep = 0.obs;
  RxBool isLoading = true.obs;
  RxBool isSubmitting = false.obs;

  // Personal Info
  Rx<TextEditingController> fullNameController = TextEditingController().obs;
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> passwordController = TextEditingController().obs;
  Rx<TextEditingController> phoneNumberController = TextEditingController().obs;
  RxString countryCode = "+1".obs;
  RxString loginType = Constant.emailLoginType.obs;
  Rx<DriverUserModel> userModel = DriverUserModel().obs;
  RxString userImage = "".obs;

  // Service Selection
  RxList<ServiceModel> serviceList = <ServiceModel>[].obs;
  Rx<String?> selectedServiceId = Rx<String?>(null);

  // Vehicle Info
  Rx<TextEditingController> vehicleNumberController =
      TextEditingController().obs;
  Rx<TextEditingController> seatsController = TextEditingController().obs;
  Rx<DateTime?> selectedDate = Rx<DateTime?>(null);
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
  Rx<TextEditingController> zoneNameController = TextEditingController().obs;

  // Verification
  RxList<DocumentModel> documentList = <DocumentModel>[].obs;

  // Document Upload
  final ImagePicker _imagePicker = ImagePicker();
  Rx<DocumentModel> currentDocument = DocumentModel().obs;
  Rx<TextEditingController> documentNumberController =
      TextEditingController().obs;
  Rx<DateTime?> selectedDocumentDate = Rx<DateTime?>(null);
  RxString frontImage = "".obs;
  RxString backImage = "".obs;

  // Store document details for registration
  RxMap<String, Documents> registrationDocuments = <String, Documents>{}.obs;

  @override
  void onInit() {
    getInitialData();
    if (Get.arguments != null && Get.arguments['userModel'] != null) {
      DriverUserModel passedUserModel = Get.arguments['userModel'];
      userModel.value = passedUserModel;
      loginType.value = passedUserModel.loginType ?? Constant.emailLoginType;
      fullNameController.value.text = passedUserModel.fullName ?? '';
      emailController.value.text = passedUserModel.email ?? '';
      userImage.value = passedUserModel.profilePic ?? '';
      phoneNumberController.value.text = passedUserModel.phoneNumber ?? '';
      countryCode.value = passedUserModel.countryCode ?? '+1';
    }
    super.onInit();
  }

  Future<void> pickUserImage({required ImageSource source}) async {
    try {
      XFile? image =
          await _imagePicker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        userImage.value = image.path;
      }
    } catch (e) {
      ShowToastDialog.showToast("Failed to pick image: $e".tr);
    }
  }

  Future<void> getInitialData() async {
    isLoading.value = true;
    await Future.wait([
      FireStoreUtils.getService().then((value) => serviceList.value = value),
      FireStoreUtils.getZone().then((value) => zoneList.value = value ?? []),
      FireStoreUtils.getVehicleType()
          .then((value) => vehicleList.value = value ?? []),
      FireStoreUtils.getDocumentList().then((value) {
        documentList.value = value.where((doc) => doc.enable ?? false).toList();
        for (var doc in documentList.value) {
          if (doc.id != null) {
            registrationDocuments[doc.id!] = Documents(documentId: doc.id);
          }
        }
      }),
    ]);
    isLoading.value = false;
  }

  void showDocumentUploadScreen(
      BuildContext context, DocumentModel documentModel) {
    if (documentModel.id == null) return;
    currentDocument.value = documentModel;

    // Load existing/temp data for this document
    Documents savedDoc =
        registrationDocuments[documentModel.id!] ?? Documents();
    documentNumberController.value.text = savedDoc.documentNumber ?? '';
    frontImage.value = savedDoc.frontImage ?? '';
    backImage.value = savedDoc.backImage ?? '';
    selectedDocumentDate.value = savedDoc.expireAt?.toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(6.0),
                child: Column(
                  children: [
                    Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    Text(Constant.localizationTitle(documentModel.title),
                        style: AppTypography.h2(context)),
                    const SizedBox(height: 4),
                    Text("Please provide clear and valid images.".tr,
                        style: AppTypography.caption(context))
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDocumentNumberSection(context),
                      if (documentModel.expireAt == true)
                        _buildExpiryDateSection(context),
                      if (documentModel.frontSide == true)
                        Obx(() => _buildImageUploadSection(
                            context,
                            "Front Side Image".tr,
                            frontImage.value,
                            "front",
                            Icons.credit_card)),
                      if (documentModel.backSide == true)
                        Obx(() => _buildImageUploadSection(
                            context,
                            "Back Side Image".tr,
                            backImage.value,
                            "back",
                            Icons.flip_to_back)),
                    ],
                  ),
                ),
              ),
              _buildDocumentSaveButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentNumberSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Document Number".tr, style: AppTypography.boldLabel(context)),
        const SizedBox(height: 8),
        TextField(
          controller: documentNumberController.value,
          style: AppTypography.input(context),
          decoration: InputDecoration(
            hintText: "Enter number".tr,
            hintStyle:
                AppTypography.input(context).copyWith(color: AppColors.grey500),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.primary, width: 1)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildExpiryDateSection(BuildContext context) {
    return Obx(() => EnhancedDateSelector(
          label: "Expiry Date".tr,
          hintText: "Select expiry date".tr,
          selectedDate: selectedDocumentDate.value,
          onDateSelected: (date) {
            selectedDocumentDate.value = date;
          },
          onClear: () => selectedDocumentDate.value = null,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
          isRequired: true,
          errorText: selectedDocumentDate.value == null
              ? "Please select an expiry date".tr
              : null,
        ));
  }

  Widget _buildImageUploadSection(BuildContext context, String title,
      String imagePath, String type, IconData icon) {
    bool hasImage = imagePath.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.boldLabel(context)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => buildBottomSheet(context, type),
          borderRadius: BorderRadius.circular(16),
          child: DottedBorder(
            borderType: BorderType.RRect,
            radius: const Radius.circular(16),
            dashPattern: const [8, 4],
            color: AppColors.primary.withOpacity(0.5),
            strokeWidth: 1.5,
            child: Container(
              width: double.infinity,
              height: Responsive.height(22, context),
              decoration: BoxDecoration(
                  color: hasImage
                      ? Colors.transparent
                      : AppColors.primary.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16)),
              child: hasImage
                  ? _buildDocImagePreview(context, imagePath)
                  : _buildDocImagePlaceholder(context, icon),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDocImagePreview(BuildContext context, String imagePath) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Constant().hasValidUrl(imagePath)
              ? CachedNetworkImage(
                  imageUrl: imagePath,
                  width: double.infinity,
                  fit: BoxFit.cover)
              : Image.file(File(imagePath),
                  width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDocImagePlaceholder(BuildContext context, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text("Tap to upload".tr,
              style:
                  AppTypography.h3(context).copyWith(color: AppColors.primary)),
          const SizedBox(height: 4),
          Text("PNG, JPG supported".tr,
              style:
                  GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildDocumentSaveButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2))
      ]),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: saveDocumentLocally,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text("Save Document".tr,
              style: AppTypography.button(context)
                  .copyWith(color: AppColors.background)),
        ),
      ),
    );
  }

  Future<void> buildBottomSheet(BuildContext context, String type) {
    return showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Text("Choose Photo Source".tr,
                      style: AppTypography.h2(context)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSourceOption(
                          context,
                          type,
                          "Camera".tr,
                          Icons.camera_alt_outlined,
                          ImageSource.camera,
                          AppColors.primary),
                      _buildSourceOption(
                          context,
                          type,
                          "Gallery".tr,
                          Icons.photo_library_outlined,
                          ImageSource.gallery,
                          Colors.deepOrange),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ));
  }

  Widget _buildSourceOption(BuildContext context, String type, String title,
      IconData icon, ImageSource source, Color color) {
    return InkWell(
      onTap: () {
        pickFile(source: source, type: type);
        Get.back();
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTypography.boldLabel(context)),
        ],
      ),
    );
  }

  Future<void> pickFile(
      {required ImageSource source, required String type}) async {
    try {
      XFile? image =
          await _imagePicker.pickImage(source: source, imageQuality: 70);
      if (image == null) return;
      if (type == "front") {
        frontImage.value = image.path;
      } else {
        backImage.value = image.path;
      }
    } catch (e) {
      ShowToastDialog.showToast("Failed to Pick: $e".tr);
    }
  }

  void saveDocumentLocally() {
    if (documentNumberController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter document number".tr);
      return;
    }
    if (currentDocument.value.frontSide == true && frontImage.value.isEmpty) {
      ShowToastDialog.showToast("Please upload front side image.".tr);
      return;
    }
    if (currentDocument.value.backSide == true && backImage.value.isEmpty) {
      ShowToastDialog.showToast("Please upload back side image.".tr);
      return;
    }
    if (currentDocument.value.expireAt == true &&
        selectedDocumentDate.value == null) {
      ShowToastDialog.showToast("Please select an expiry date".tr);
      return;
    }

    String docId = currentDocument.value.id!;
    registrationDocuments[docId] = Documents(
        documentId: docId,
        documentNumber: documentNumberController.value.text,
        frontImage: frontImage.value,
        backImage: backImage.value,
        expireAt: selectedDocumentDate.value != null
            ? Timestamp.fromDate(selectedDocumentDate.value!)
            : null,
        verified: false);
    // Force a refresh for the UI in _buildVerificationStep
    registrationDocuments.refresh();

    ShowToastDialog.showToast("Document saved locally.".tr);
    Get.back();
  }

  Future<String?> uploadImage(
      String filePath, String driverId, String docId) async {
    if (filePath.isEmpty || Constant().hasValidUrl(filePath)) return filePath;
    String fileName = filePath.split('/').last;
    return await Constant.uploadUserImageToFireStorage(
        File(filePath), "driverDocument/$driverId/$docId", fileName);
  }

  Future<bool> uploadAllDocuments(String driverId) async {
    for (var entry in registrationDocuments.entries) {
      final docId = entry.key;
      final doc = entry.value;

      doc.frontImage = await uploadImage(doc.frontImage ?? '', driverId, docId);
      doc.backImage = await uploadImage(doc.backImage ?? '', driverId, docId);

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
          ShowToastDialog.showToast("Please enter your full name".tr);
          return;
        }
        if (emailController.value.text.isEmpty ||
            !Constant.validateEmail(emailController.value.text)) {
          ShowToastDialog.showToast("Please enter a valid email".tr);
          return;
        }
        if (loginType.value == Constant.emailLoginType &&
            passwordController.value.text.length < 6) {
          ShowToastDialog.showToast(
              "Password must be at least 6 characters".tr);
          return;
        }
        if (phoneNumberController.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter your phone number".tr);
          return;
        }
        if (userImage.value.isEmpty) {
          ShowToastDialog.showToast("Please upload your profile image".tr);
          return;
        }
        currentStep.value++;
        break;
      case 2:
        if (vehicleNumberController.value.text.isEmpty) {
          ShowToastDialog.showToast("Please enter a vehicle number".tr);
          return;
        }
        if (selectedDate.value == null) {
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
          ShowToastDialog.showToast("Please enter number of seats".tr);
          return;
        }
        if (selectedZone.isEmpty) {
          ShowToastDialog.showToast("Please select a service zone".tr);
          return;
        }
        currentStep.value++;
        break;
      case 3:
        for (var doc in documentList) {
          final uploadedDoc = registrationDocuments[doc.id];
          if (uploadedDoc == null ||
              uploadedDoc.documentNumber?.isEmpty == true) {
            ShowToastDialog.showToast(
                "Please upload details for ${Constant.localizationTitle(doc.title)}"
                    .tr);
            return;
          }
        }
        submitRegistration();
        break;
    }
  }

  Future<void> submitRegistration() async {
    isSubmitting.value = true;
    ShowToastDialog.showLoader("Finalizing your profile...".tr);
    try {
      final driverId = FirebaseAuth.instance.currentUser!.uid;

      if (userImage.value.isNotEmpty &&
          !Constant().hasValidUrl(userImage.value)) {
        userImage.value =
            await uploadImage(userImage.value, driverId, "profile_pic") ?? "";
      }

      userModel.value
        ..id = driverId
        ..fullName = fullNameController.value.text
        ..email = emailController.value.text
        ..countryCode = countryCode.value
        ..profilePic = userImage.value
        ..phoneNumber = phoneNumberController.value.text
        ..documentVerification = false
        ..isOnline = true
        ..createdAt = Timestamp.now()
        ..serviceId = selectedServiceId.value
        ..zoneIds = selectedZone.toList()
        ..loginType = loginType.value
        ..fcmToken = await NotificationService.getToken()
        ..vehicleInformation = VehicleInformation(
          vehicleNumber: vehicleNumberController.value.text,
          registrationDate: Timestamp.fromDate(selectedDate.value!),
          vehicleTypeId: selectedVehicle.value.id,
          vehicleType: selectedVehicle.value.name,
          vehicleColor: selectedColor.value,
          seats: seatsController.value.text,
        );

      bool documentsUploaded = await uploadAllDocuments(driverId);
      if (!documentsUploaded) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast(
            "Failed to upload one or more documents. Please try again.".tr);
        isSubmitting.value = false;
        return;
      }

      final success = await FireStoreUtils.updateDriverUser(userModel.value);
      ShowToastDialog.closeLoader();

      if (success) {
        Get.offAll(() => const DashBoardScreen());
      } else {
        ShowToastDialog.showToast(
            "An error occurred while saving your profile. Please try again."
                .tr);
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Registration failed: ${e.toString()}".tr);
    } finally {
      isSubmitting.value = false;
    }
  }
}
