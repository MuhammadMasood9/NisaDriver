import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/information_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/service_model.dart';
import 'package:driver/model/vehicle_type_model.dart';
import 'package:driver/model/zone_model.dart';
import 'package:driver/model/document_model.dart';
import 'package:driver/model/driver_document_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_them.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/ui/subscription_plan_screen/subscription_list_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:image_picker/image_picker.dart';

class EnhancedDateSelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;
    final bool hasValue = selectedDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.boldLabel(context),
            ),
            if (isRequired)
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
        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: firstDate ?? DateTime(1900),
              lastDate: lastDate ?? DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: primaryColor,
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
              onDateSelected(picked);
            }
          },
          child: Container(
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
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: hasValue ? primaryColor : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasValue
                          ? DateFormat(dateFormat).format(selectedDate!)
                          : hintText,
                      style: AppTypography.caption(context),
                    ),
                  ),
                  if (hasValue && showClearButton)
                    GestureDetector(
                      onTap: () => onDateSelected(DateTime.now()),
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
                errorText!,
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

class InformationScreen extends StatelessWidget {
  const InformationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<InformationController>(
      init: InformationController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: controller.isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          "assets/images/login_image.png",
                          width: Responsive.width(100, context),
                        ),
                        Text(
                          controller.currentStep.value == 0
                              ? "Select Service".tr
                              : controller.currentStep.value == 1
                                  ? "Personal Information".tr
                                  : controller.currentStep.value == 2
                                      ? "Vehicle Information".tr
                                      : "Document Verification".tr,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          controller.currentStep.value == 0
                              ? "Choose your service type".tr
                              : controller.currentStep.value == 1
                                  ? "Enter your personal details".tr
                                  : controller.currentStep.value == 2
                                      ? "Provide vehicle details".tr
                                      : "Upload required documents".tr,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildStepContent(context, controller),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            if (controller.currentStep.value > 0)
                              Expanded(
                                child: ButtonThem.buildButton(
                                  context,
                                  title: "Back".tr,
                                  onPress: () {
                                    controller.currentStep.value--;
                                  },
                                ),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ButtonThem.buildButton(
                                context,
                                title: controller.currentStep.value == 3
                                    ? "Submit".tr
                                    : "Next".tr,
                                onPress: () {
                                  controller.handleNext(context);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStepContent(
      BuildContext context, InformationController controller) {
    switch (controller.currentStep.value) {
      case 0:
        return _buildServiceTypeStep(context, controller);
      case 1:
        return _buildPersonalInfoStep(context, controller);
      case 2:
        return _buildVehicleInfoStep(context, controller);
      case 3:
        return _buildVerificationStep(context, controller);
      default:
        return Container();
    }
  }

  Widget _buildServiceTypeStep(
      BuildContext context, InformationController controller) {
    return Column(
      children: controller.serviceList.map((service) {
        return RadioListTile<String>(
          value: service.id!,
          groupValue: controller.selectedServiceId.value,
          onChanged: (value) {
            controller.selectedServiceId.value = value!;
          },
          title: Text(
            service.title?.first.title ?? service.id!,
            style: GoogleFonts.poppins(fontSize: 16),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPersonalInfoStep(
      BuildContext context, InformationController controller) {
    return Column(
      children: [
        TextFieldThem.buildTextFiled(
          context,
          hintText: 'Full name'.tr,
          controller: controller.fullNameController.value,
        ),
        const SizedBox(height: 10),
        TextFieldThem.buildTextFiled(
          context,
          hintText: 'Email'.tr,
          controller: controller.emailController.value,
        ),
        const SizedBox(height: 10),
        TextFieldThem.buildTextFiled(
          context,
          hintText: 'Password'.tr,
          controller: controller.passwordController.value,
          // obscureText: true,
        ),
        const SizedBox(height: 10),
        TextFormField(
          validator: (value) =>
              value != null && value.isNotEmpty ? null : 'Required',
          keyboardType: TextInputType.number,
          controller: controller.phoneNumberController.value,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.textField,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            prefixIcon: CountryCodePicker(
              onChanged: (value) {
                controller.countryCode.value = value.dialCode.toString();
              },
              dialogBackgroundColor: AppColors.background,
              initialSelection: controller.countryCode.value,
              comparator: (a, b) => b.name!.compareTo(a.name.toString()),
              flagDecoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide:
                  BorderSide(color: AppColors.textFieldBorder, width: 1),
            ),
            hintText: "Phone number".tr,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfoStep(
      BuildContext context, InformationController controller) {
    return Column(
      children: [
        _buildTextField(
          controller: controller.vehicleNumberController.value,
          label: 'Vehicle Number'.tr,
          icon: Icons.confirmation_number_outlined,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: controller.registrationDateController.value,
          label: 'Registration Date'.tr,
          icon: Icons.calendar_today_outlined,
          enabled: false,
          onTap: () async {
            await Constant.selectDate(context).then((value) {
              if (value != null) {
                controller.selectedDate.value = value;
                controller.registrationDateController.value.text =
                    DateFormat("dd-MM-yyyy").format(value);
              }
            });
          },
        ),
        const SizedBox(height: 16),
        Obx(() => _buildTextField(
              controller: TextEditingController(
                text: controller.selectedVehicle.value.id == null
                    ? ''
                    : Constant.localizationName(
                        controller.selectedVehicle.value.name),
              ),
              label: 'Vehicle Type'.tr,
              icon: Icons.directions_car_outlined,
              enabled: false,
              onTap: () => _showVehicleTypeSelector(context, controller),
            )),
        const SizedBox(height: 16),
        Obx(() => _buildTextField(
              controller:
                  TextEditingController(text: controller.selectedColor.value),
              label: 'Vehicle Color'.tr,
              icon: Icons.palette_outlined,
              enabled: false,
              onTap: () => _showColorSelector(context, controller),
            )),
        const SizedBox(height: 16),
        Obx(() => _buildTextField(
              controller: controller.seatsController.value,
              label: 'Number of Seats'.tr,
              icon: Icons.event_seat_outlined,
              enabled: false,
              onTap: () => _showSeatsSelector(context, controller),
            )),
        const SizedBox(height: 16),
        Obx(() => _buildTextField(
              controller: controller.zoneNameController.value,
              label: 'Service Zone'.tr,
              icon: Icons.location_on_outlined,
              enabled: false,
              onTap: () => _showZoneSelector(context, controller),
            )),
      ],
    );
  }

  Widget _buildVerificationStep(
      BuildContext context, InformationController controller) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 10, top: 10),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.document_scanner,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 46),
                child: Text(
                  "Complete your registration by uploading required documents"
                      .tr,
                  style: AppTypography.boldHeaders(context).copyWith(
                    color: AppColors.darkBackground.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: MediaQuery.of(context).size.height * 0.4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Obx(() => ListView.builder(
                itemCount: controller.documentList.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  DocumentModel documentModel = controller.documentList[index];
                  Documents documents = Documents();

                  var contain = controller.driverDocumentList.where(
                      (element) => element.documentId == documentModel.id);
                  if (contain.isNotEmpty) {
                    documents = controller.driverDocumentList.firstWhere(
                        (itemToCheck) =>
                            itemToCheck.documentId == documentModel.id);
                  }

                  bool isVerified = documents.verified == true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          controller.showDocumentUploadScreen(
                              context, documentModel, documents);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isVerified
                                          ? Colors.green.withOpacity(0.1)
                                          : AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isVerified
                                          ? Icons.verified_rounded
                                          : Icons.description_outlined,
                                      color: isVerified
                                          ? Colors.green
                                          : AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          Constant.localizationTitle(
                                              documentModel.title),
                                          style: AppTypography.appBar(context)
                                              .copyWith(
                                            color: AppColors.darkBackground
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isVerified
                                              ? "Document verified successfully"
                                                  .tr
                                              : "Tap to upload document".tr,
                                          style: AppTypography.label(context)
                                              .copyWith(
                                            color: AppColors.darkBackground
                                                .withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      spreadRadius: 0.7,
                                      blurRadius: 1,
                                      offset: const Offset(0, 1),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      spreadRadius: 0.7,
                                      blurRadius: 1,
                                      offset: const Offset(0, -1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isVerified
                                          ? Icons.check_circle_outline
                                          : Icons.info,
                                      size: 14,
                                      color: isVerified
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isVerified ? "Verified".tr : "Pending".tr,
                                      style: AppTypography.smBoldLabel(context)
                                          .copyWith(
                                        color: Colors.grey.shade600,
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
              )),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    VoidCallback? onTap,
    bool obscureText = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.textField,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              obscureText: obscureText,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: Colors.black54, size: 20),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVehicleTypeSelector(
      BuildContext context, InformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Vehicle Type'.tr,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 25),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.vehicleList.length,
                itemBuilder: (context, index) {
                  final vehicleType = controller.vehicleList[index];
                  return Obx(() => RadioListTile<VehicleTypeModel>(
                        value: vehicleType,
                        groupValue: controller.selectedVehicle.value,
                        onChanged: (value) {
                          controller.selectedVehicle.value = value!;
                          Navigator.pop(context);
                        },
                        title: Text(
                          Constant.localizationName(vehicleType.name),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorSelector(
      BuildContext context, InformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Vehicle Color'.tr,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 25),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.carColorList.length,
                itemBuilder: (context, index) {
                  final color = controller.carColorList[index];
                  return Obx(() => RadioListTile<String>(
                        value: color,
                        groupValue: controller.selectedColor.value,
                        onChanged: (value) {
                          controller.selectedColor.value = value!;
                          Navigator.pop(context);
                        },
                        title: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _getColorFromString(color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(color,
                                style: GoogleFonts.poppins(fontSize: 14)),
                          ],
                        ),
                      ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeatsSelector(
      BuildContext context, InformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Number of Seats'.tr,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 25),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.sheetList.length,
                itemBuilder: (context, index) {
                  final seats = controller.sheetList[index];
                  return Obx(() => RadioListTile<String>(
                        value: seats,
                        groupValue: controller.seatsController.value.text,
                        onChanged: (value) {
                          controller.seatsController.value.text = value!;
                          Navigator.pop(context);
                        },
                        title: Text('$seats Seats',
                            style: GoogleFonts.poppins(fontSize: 14)),
                      ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showZoneSelector(
      BuildContext context, InformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Zones'.tr,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 25),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.zoneList.length,
                itemBuilder: (context, index) {
                  final zone = controller.zoneList[index];
                  return Obx(() => CheckboxListTile(
                        value: controller.selectedZone.contains(zone.id),
                        onChanged: (value) {
                          if (value == true && zone.id != null) {
                            controller.selectedZone.add(zone.id!);
                          } else if (zone.id != null) {
                            controller.selectedZone.remove(zone.id!);
                          }
                        },
                        title: Text(
                          Constant.localizationName(zone.name),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel".tr),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.selectedZone.isEmpty) {
                          ShowToastDialog.showToast("Please select zone".tr);
                        } else {
                          controller.zoneNameController.value.text = controller
                              .selectedZone
                              .map((id) => Constant.localizationName(controller
                                  .zoneList
                                  .firstWhere((z) => z.id == id)
                                  .name))
                              .join(", ");
                          Navigator.pop(context);
                        }
                      },
                      child: Text("Apply".tr),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'grey':
      case 'gray':
        return Colors.grey;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'brown':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
