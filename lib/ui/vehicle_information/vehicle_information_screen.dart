import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/vehicle_information_controller.dart';
import 'package:driver/model/VehicleUpdateRequestModel.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/vehicle_type_model.dart';
import 'package:driver/model/zone_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class VehicleInformationScreen extends StatelessWidget {
  const VehicleInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return GetX<VehicleInformationController>(
      init: VehicleInformationController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: controller.isLoading.value
              ? _buildLoader(context)
              : _buildBody(context, controller),
        );
      },
    );
  }

  Widget _buildLoader(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildBody(BuildContext context,
      VehicleInformationController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVehicleDetailsSection(context, controller),
          const SizedBox(height: 32),
          _buildInfoCard(context),
          const SizedBox(height: 32),
          _buildSaveButton(context, controller),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailsSection(BuildContext context,
      VehicleInformationController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTextField(
                controller: controller.vehicleNumberController.value,
                label: 'Vehicle Number'.tr,
                icon: Icons.confirmation_number_outlined,
              
              ),
              const SizedBox(height: 16),
              _buildDateField(context, controller),
              const SizedBox(height: 16),
              _buildVehicleTypeField(context, controller),
              const SizedBox(height: 16),
              _buildColorField(context, controller),
              const SizedBox(height: 16),
              _buildSeatsField(context, controller),
              const SizedBox(height: 16),
              _buildZoneField(context, controller),
            ],
          ),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.boldLabel(Get.context!)
                .copyWith(color: AppColors.grey600),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color:  const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:  Colors.grey.withOpacity(0.1),
              ),
            ),
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              style: AppTypography.caption(Get.context!),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color: Colors.black54,
                  size: 20,
                ),
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

  Widget _buildDateField(BuildContext context,
      VehicleInformationController controller) {
    return _buildTextField(
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
    );
  }

  Widget _buildVehicleTypeField(BuildContext context,
      VehicleInformationController controller) {
    return _buildTextField(
      controller: TextEditingController(
          text: controller.selectedVehicle.value.id == null
              ? ''
              : Constant.localizationName(
                  controller.selectedVehicle.value.name)),
      label: 'Vehicle Type'.tr,
      icon: Icons.directions_car_outlined,
      enabled: false,
      onTap: () => _showVehicleTypeSelector(context, controller),
    );
  }

  Widget _buildColorField(BuildContext context,
      VehicleInformationController controller) {
    return _buildTextField(
      controller: TextEditingController(text: controller.selectedColor.value),
      label: 'Vehicle Color'.tr,
      icon: Icons.palette_outlined,
      enabled: false,
      onTap: () => _showColorSelector(context, controller),
    );
  }

  Widget _buildSeatsField(BuildContext context,
      VehicleInformationController controller ) {
    return _buildTextField(
      controller: controller.seatsController.value,
      label: 'Number of Seats'.tr,
      icon: Icons.event_seat_outlined,
      enabled: false,
      onTap: () => _showSeatsSelector(context, controller),
    );
  }

  Widget _buildZoneField(BuildContext context,
      VehicleInformationController controller ) {
    return _buildTextField(
      controller: controller.zoneNameController.value,
      label: 'Service Zone'.tr,
      icon: Icons.location_on_outlined,
      enabled: false,
      onTap: () => _showZoneSelector(context, controller),
    );
  }

  Widget _buildInfoCard(BuildContext context ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.amber.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Vehicle information is submitted for admin approval. You cannot submit another request until the pending one is processed."
                  .tr,
              style: AppTypography.label(context).copyWith(
                color: Colors.amber.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(
      BuildContext context, VehicleInformationController controller) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleSave(context, controller),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkBackground,
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Text(
          "Save Information".tr,
          style: AppTypography.appTitle(context).copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _handleSave(
      BuildContext context, VehicleInformationController controller) async {
    ShowToastDialog.showLoader("Please wait".tr);

    String driverId = FireStoreUtils.getCurrentUid();
    QuerySnapshot pendingRequests = await FirebaseFirestore.instance
        .collection('vehicle_requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (pendingRequests.docs.isNotEmpty) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(
          "You have a pending vehicle request. Please wait for admin approval."
              .tr);
      return;
    }

    if (controller.vehicleNumberController.value.text.isEmpty) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Please enter Vehicle number".tr);
    } else if (controller.registrationDateController.value.text.isEmpty) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Please select registration date".tr);
    } else if (controller.selectedVehicle.value.id == null ||
        controller.selectedVehicle.value.id!.isEmpty) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Please select Vehicle type".tr);
    } else if (controller.selectedColor.value.isEmpty) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Please select Vehicle color".tr);
    } else if (controller.seatsController.value.text.isEmpty) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Please select seats".tr);
    } else if (controller.selectedZone.isEmpty) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Please select Zone".tr);
    } else {
      VehicleInformationRequest vehicleRequest = VehicleInformationRequest(
        registrationDate: Timestamp.fromDate(controller.selectedDate.value!),
        vehicleColor: controller.selectedColor.value,
        vehicleNumber: controller.vehicleNumberController.value.text,
        vehicleType: controller.selectedVehicle.value.name,
        vehicleTypeId: controller.selectedVehicle.value.id,
        seats: controller.seatsController.value.text,
        driverId: driverId,
        driverName: controller.driverModel.value.fullName,
        status: "pending",
      );

      await FirebaseFirestore.instance
          .collection('vehicle_requests')
          .doc()
          .set(vehicleRequest.toJson())
          .then((value) async {
        // Update DriverUserModel with selected zones
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .update({
          'zoneIds': controller.selectedZone.toList().cast<String>(),
        }).then((value) {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast(
              "Vehicle information and zones submitted for admin approval".tr);
        }).catchError((error) {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Error updating zones: $error".tr);
        });
      }).catchError((error) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Error submitting request: $error".tr);
      });
    }
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

  void _showVehicleTypeSelector(BuildContext context,
      VehicleInformationController controller ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color:  Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
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
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: controller.vehicleList.length,
                itemBuilder: (context, index) {
                  VehicleTypeModel vehicleType = controller.vehicleList[index];
                  return Obx(() {
                    bool isSelected =
                        controller.selectedVehicle.value.id == vehicleType.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.1),
                        ),
                      ),
                      child: RadioListTile<VehicleTypeModel>(
                        value: vehicleType,
                        groupValue: controller.selectedVehicle.value,
                        onChanged: (value) {
                          controller.selectedVehicle.value = value!;
                          Navigator.pop(context);
                        },
                        activeColor: AppColors.primary,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(
                          Constant.localizationName(vehicleType.name),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color:  Colors.black87,
                          ),
                        ),
                      ),
                    );
                  });
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
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Text(
                        "Cancel".tr,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.selectedVehicle.value.id == null) {
                          ShowToastDialog.showToast(
                              "Please select a vehicle type".tr);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Apply".tr,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
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

  void _showColorSelector(BuildContext context,
      VehicleInformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color:  Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
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
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: controller.carColorList.length,
                    itemBuilder: (context, index) {
                      String color = controller.carColorList[index];
                      bool isSelected = controller.selectedColor.value == color;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: color,
                          groupValue: controller.selectedColor.value,
                          onChanged: (value) {
                            controller.selectedColor.value = value!;
                            Navigator.pop(context);
                          },
                          activeColor: AppColors.primary,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          title: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _getColorFromString(color),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.grey.withOpacity(0.3)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                color,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Text(
                        "Cancel".tr,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.selectedColor.value.isEmpty) {
                          ShowToastDialog.showToast(
                              "Please select a vehicle color".tr);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Apply".tr,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
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

  void _showSeatsSelector(BuildContext context,
      VehicleInformationController controller ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color:  Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
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
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: controller.sheetList.length,
                    itemBuilder: (context, index) {
                      String seats = controller.sheetList[index];
                      bool isSelected =
                          controller.seatsController.value.text == seats;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: seats,
                          groupValue: controller.seatsController.value.text,
                          onChanged: (value) {
                            controller.seatsController.value.text = value!;
                            Navigator.pop(context);
                          },
                          activeColor: AppColors.primary,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          title: Text(
                            '$seats Seats',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color:  Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  )),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Text(
                        "Cancel".tr,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.seatsController.value.text.isEmpty) {
                          ShowToastDialog.showToast("Please select seats".tr);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Apply".tr,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
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

  void _showZoneSelector(BuildContext context,
      VehicleInformationController controller ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color:  Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
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
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Debugging: Display selected zones for confirmation

            Expanded(
              child: controller.zoneList.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Obx(() => ListView.builder(
                        key: ValueKey(controller
                            .selectedZone.length), // Force rebuild on change
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: controller.zoneList.length,
                        itemBuilder: (context, index) {
                          final zone = controller.zoneList[index];
                          final isSelected =
                              controller.selectedZone.contains(zone.id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.1),
                              ),
                            ),
                            child: CheckboxListTile(
                              key:
                                  ValueKey(zone.id), // Unique key for each item
                              value: isSelected,
                              onChanged: (value) {
                                if (value == true) {
                                  if (!controller.selectedZone
                                      .contains(zone.id)) {
                                    controller.selectedZone.add(zone.id);
                                  }
                                } else {
                                  controller.selectedZone.remove(zone.id);
                                }
                                print(
                                    "Tapped zone: ${zone.id}, Selected: $value");
                                print(
                                    "Current selectedZone: ${controller.selectedZone}");
                              },
                              activeColor: AppColors.primary,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              title: Text(
                                Constant.localizationName(zone.name),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      )),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Text(
                        "Cancel".tr,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.selectedZone.isEmpty) {
                          ShowToastDialog.showToast("Please select zone".tr);
                        } else {
                          String nameValue = "";
                          for (var element in controller.selectedZone) {
                            List<ZoneModel> list = controller.zoneList
                                .where((p0) => p0.id == element)
                                .toList();
                            if (list.isNotEmpty) {
                              nameValue =
                                  "$nameValue${nameValue.isEmpty ? "" : ", "} ${Constant.localizationName(list.first.name)}";
                            }
                          }
                          controller.zoneNameController.value.text = nameValue;
                          _updateDriverZones(
                              controller.selectedZone.toList().cast<String>());
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBackground,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Apply".tr,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
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

  Future<void> _updateDriverZones(List<String> zoneIds) async {
    try {
      String driverId = FireStoreUtils.getCurrentUid();
      DocumentReference driverRef =
          FirebaseFirestore.instance.collection('drivers').doc(driverId);

      // Check if the document exists
      DocumentSnapshot driverSnapshot = await driverRef.get();
      if (driverSnapshot.exists) {
        // Document exists, perform update
        await driverRef.update({
          'zoneIds': zoneIds,
        });
        ShowToastDialog.showToast("Zones updated successfully".tr);
      } else {
        // Document doesn't exist, create it with zoneIds
        await driverRef.set({
          'id': driverId,
          'zoneIds': zoneIds,
          // Add other required fields for the driver document
        }, SetOptions(merge: true));
        ShowToastDialog.showToast("Driver profile created with zones".tr);
      }
    } catch (e) {
      ShowToastDialog.showToast("Error updating zones: $e".tr);
    }
  }
}
