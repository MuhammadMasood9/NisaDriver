import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/vehicle_information_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/service_model.dart';
import 'package:driver/model/vehicle_type_model.dart';
import 'package:driver/model/zone_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_them.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
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
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX<VehicleInformationController>(
      init: VehicleInformationController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: themeChange.getThem()
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFF8F9FA),
          body: controller.isLoading.value
              ? _buildLoader(context)
              : _buildBody(context, controller, themeChange),
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
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Selection
          _buildServiceSection(context, controller, themeChange),
          const SizedBox(height: 32),

          // Vehicle Details
          _buildVehicleDetailsSection(context, controller, themeChange),
          const SizedBox(height: 32),

          // Driver Rules
          _buildDriverRulesSection(context, controller, themeChange),
          const SizedBox(height: 32),

          // Info Message
          _buildInfoCard(context, themeChange),
          const SizedBox(height: 32),

          // Save Button
          _buildSaveButton(context, controller),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildServiceSection(BuildContext context,
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Service'.tr,
          style: AppTypography.headers(context),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.serviceList.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              ServiceModel serviceModel = controller.serviceList[index];
              return Obx(() {
                bool isSelected =
                    controller.selectedServiceId.value == serviceModel.id;
                return _buildServiceCard(
                    serviceModel, isSelected, controller, themeChange);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(ServiceModel serviceModel, bool isSelected,
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    return GestureDetector(
      onTap: () {
        if (controller.driverModel.value.serviceId == null) {
          controller.selectedServiceId.value = serviceModel.id;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (themeChange.getThem()
                  ? const Color(0xFF2A2A2A)
                  : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (themeChange.getThem()
                    ? Colors.grey.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1)),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(50)),
              child: CachedNetworkImage(
                imageUrl: serviceModel.image.toString(),
                height: 32,
                width: 32,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(
                  height: 32,
                  width: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.error_outline,
                  color: Colors.grey,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Constant.localizationTitle(serviceModel.title),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (themeChange.getThem() ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleDetailsSection(BuildContext context,
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Details'.tr,
          style: AppTypography.headers(context),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                themeChange.getThem() ? const Color(0xFF2A2A2A) : Colors.white,
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
                themeChange: themeChange,
              ),
              const SizedBox(height: 16),
              _buildDateField(context, controller, themeChange),
              const SizedBox(height: 16),
              _buildVehicleTypeField(context, controller, themeChange),
              const SizedBox(height: 16),
              _buildColorField(context, controller, themeChange),
              const SizedBox(height: 16),
              _buildSeatsField(context, controller, themeChange),
              const SizedBox(height: 16),
              _buildZoneField(context, controller, themeChange),
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
    required DarkThemeProvider themeChange,
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
              color: themeChange.getThem()
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: themeChange.getThem()
                    ? Colors.grey.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
              ),
            ),
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              style: AppTypography.caption(Get.context!),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  icon,
                  color:
                      themeChange.getThem() ? Colors.white54 : Colors.black54,
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
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    return _buildTextField(
      controller: controller.registrationDateController.value,
      label: 'Registration Date'.tr,
      icon: Icons.calendar_today_outlined,
      themeChange: themeChange,
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
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    return _buildTextField(
      controller: TextEditingController(
          text: controller.selectedVehicle.value.id == null
              ? ''
              : Constant.localizationName(
                  controller.selectedVehicle.value.name)),
      label: 'Vehicle Type'.tr,
      icon: Icons.directions_car_outlined,
      themeChange: themeChange,
      enabled: false,
      onTap: () => _showVehicleTypeSelector(context, controller, themeChange),
    );
  }

  Widget _buildColorField(BuildContext context,
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    return _buildTextField(
      controller: TextEditingController(text: controller.selectedColor.value),
      label: 'Vehicle Color'.tr,
      icon: Icons.palette_outlined,
      themeChange: themeChange,
      enabled: false,
      onTap: () => _showColorSelector(context, controller, themeChange),
    );
  }

  Widget _buildSeatsField(BuildContext context,
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    return _buildTextField(
      controller: controller.seatsController.value,
      label: 'Number of Seats'.tr,
      icon: Icons.event_seat_outlined,
      themeChange: themeChange,
      enabled: false,
      onTap: () => _showSeatsSelector(context, controller, themeChange),
    );
  }

  Widget _buildZoneField(BuildContext context,
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    return _buildTextField(
      controller: controller.zoneNameController.value,
      label: 'Service Zone'.tr,
      icon: Icons.location_on_outlined,
      themeChange: themeChange,
      enabled: false,
      onTap: () => _showZoneSelector(context, controller, themeChange),
    );
  }

  Widget _buildDriverRulesSection(BuildContext context,
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Driver Rules'.tr,
          style: AppTypography.headers(context),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color:
                themeChange.getThem() ? const Color(0xFF2A2A2A) : Colors.white,
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
            children: controller.driverRulesList.map((item) {
              bool isSelected = controller.selectedDriverRulesList
                      .indexWhere((element) => element.id == item.id) !=
                  -1;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    if (value == true) {
                      controller.selectedDriverRulesList.add(item);
                    } else {
                      controller.selectedDriverRulesList
                          .removeWhere((element) => element.id == item.id);
                    }
                  },
                  activeColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(
                    Constant.localizationName(item.name),
                    style: AppTypography.label(context),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, DarkThemeProvider themeChange) {
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
              "You cannot change service type once selected. Contact administrator to change."
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
        onPressed: () => _handleSave(controller),
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

  Future<void> _handleSave(VehicleInformationController controller) async {
    ShowToastDialog.showLoader("Please wait".tr);

    if (controller.selectedServiceId.value!.isEmpty) {
      ShowToastDialog.showToast("Please select service".tr);
    } else if (controller.vehicleNumberController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter Vehicle number".tr);
    } else if (controller.registrationDateController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please select registration date".tr);
    } else if (controller.selectedVehicle.value.id == null ||
        controller.selectedVehicle.value.id!.isEmpty) {
      ShowToastDialog.showToast("Please enter Vehicle type".tr);
    } else if (controller.selectedColor.value.isEmpty) {
      ShowToastDialog.showToast("Please enter Vehicle color".tr);
    } else if (controller.seatsController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter seats".tr);
    } else if (controller.selectedZone.isEmpty) {
      ShowToastDialog.showToast("Please select Zone".tr);
    } else {
      if (controller.driverModel.value.serviceId == null) {
        controller.driverModel.value.serviceId =
            controller.selectedServiceId.value;
        await FireStoreUtils.updateDriverUser(controller.driverModel.value);
      }
      controller.driverModel.value.zoneIds = controller.selectedZone;

      controller.driverModel.value.vehicleInformation = VehicleInformation(
        registrationDate: Timestamp.fromDate(controller.selectedDate.value!),
        vehicleColor: controller.selectedColor.value,
        vehicleNumber: controller.vehicleNumberController.value.text,
        vehicleType: controller.selectedVehicle.value.name,
        vehicleTypeId: controller.selectedVehicle.value.id,
        seats: controller.seatsController.value.text,
        driverRules: controller.selectedDriverRulesList,
      );

      await FireStoreUtils.updateDriverUser(controller.driverModel.value)
          .then((value) {
        ShowToastDialog.closeLoader();
        if (value == true) {
          ShowToastDialog.showToast("Information updated successfully".tr);
        }
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
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: themeChange.getThem() ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Vehicle Type'.tr,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color:
                          themeChange.getThem() ? Colors.white : Colors.black87,
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
                        color: themeChange.getThem()
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Vehicle Type List
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
                            color: themeChange.getThem()
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),

            // Action Buttons
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
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: themeChange.getThem() ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Vehicle Color'.tr,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color:
                          themeChange.getThem() ? Colors.white : Colors.black87,
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
                        color: themeChange.getThem()
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Color List
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
                                  color: themeChange.getThem()
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )),
            ),

            // Action Buttons
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
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: themeChange.getThem() ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Number of Seats'.tr,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color:
                          themeChange.getThem() ? Colors.white : Colors.black87,
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
                        color: themeChange.getThem()
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Seats List
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
                              color: themeChange.getThem()
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  )),
            ),

            // Action Buttons
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
      VehicleInformationController controller, DarkThemeProvider themeChange) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: themeChange.getThem() ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Zones'.tr,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color:
                          themeChange.getThem() ? Colors.white : Colors.black87,
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
                        color: themeChange.getThem()
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Zone List
            Expanded(
              child: controller.zoneList.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : Obx(() => ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: controller.zoneList.length,
                        itemBuilder: (context, index) {
                          bool isSelected = controller.selectedZone
                              .contains(controller.zoneList[index].id);

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
                              value: isSelected,
                              onChanged: (value) {
                                if (controller.selectedZone
                                    .contains(controller.zoneList[index].id)) {
                                  controller.selectedZone
                                      .remove(controller.zoneList[index].id);
                                } else {
                                  controller.selectedZone
                                      .add(controller.zoneList[index].id);
                                }
                              },
                              activeColor: AppColors.primary,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              title: Text(
                                Constant.localizationName(
                                    controller.zoneList[index].name),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: themeChange.getThem()
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      )),
            ),

            // Action Buttons
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
}
