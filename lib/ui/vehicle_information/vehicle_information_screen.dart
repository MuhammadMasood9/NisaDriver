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
          backgroundColor: themeChange.getThem() ? AppColors.darkBackground : AppColors.background,
          body: Column(
            children: [
              // Header with gradient and curved bottom
             
              // Main content with curved overlap
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: themeChange.getThem() ? AppColors.darkTextFieldBorder : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                   
                  ),
                  child: controller.isLoading.value
                      ? Constant.loader(context)
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Service Selection
                              _buildSectionHeader(context, 'Select Service'.tr, Icons.design_services),
                              const SizedBox(height: 16),
                              _buildServiceSelectionGrid(context, controller, themeChange),
                              
                              const SizedBox(height: 24),
                              
                              // Vehicle Details
                              _buildSectionHeader(context, 'Vehicle Details'.tr, Icons.directions_car),
                              const SizedBox(height: 16),
                              _buildVehicleDetailsCard(context, controller, themeChange),
                              
                              const SizedBox(height: 24),
                              
                              // Driver Rules
                              _buildSectionHeader(context, 'Driver Rules'.tr, Icons.rule),
                              const SizedBox(height: 16),
                              _buildDriverRulesCard(context, controller, themeChange),
                              
                              const SizedBox(height: 24),
                              
                              // Save Button
                              _buildSaveButton(context, controller),
                              
                              const SizedBox(height: 16),
                              
                              // Info Message
                              _buildInfoMessage(context),
                              
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceSelectionGrid(
      BuildContext context, VehicleInformationController controller, DarkThemeProvider themeChange) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        itemCount: controller.serviceList.length,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          ServiceModel serviceModel = controller.serviceList[index];
          
          return Obx(() {
            bool isSelected = controller.selectedServiceId.value == serviceModel.id;
            return GestureDetector(
              onTap: () async {
                if (controller.driverModel.value.serviceId == null) {
                  controller.selectedServiceId.value = serviceModel.id;
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(right: 16),
                width: 110,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.85),
                          ],
                        )
                      : null,
                  color: !isSelected
                      ? (themeChange.getThem() ? AppColors.darkTextFieldBorder : Colors.white)
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.4)
                          : Colors.black.withOpacity(0.1),
                      blurRadius: isSelected ? 15 : 8,
                      offset: Offset(0, isSelected ? 8 : 4),
                    ),
                  ],
                  border: !isSelected
                      ? Border.all(
                          color: themeChange.getThem()
                              ? Colors.grey.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: serviceModel.image.toString(),
                        fit: BoxFit.contain,
                        height: 50,
                        width: 50,
                        placeholder: (context, url) => const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        Constant.localizationTitle(serviceModel.title),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: isSelected
                              ? Colors.white
                              : (themeChange.getThem() ? Colors.white : Colors.black87),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildVehicleDetailsCard(
      BuildContext context, VehicleInformationController controller, DarkThemeProvider themeChange) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: themeChange.getThem() ? AppColors.darkTextFieldBorder : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Vehicle Number
            _buildModernTextField(
              context: context,
              controller: controller.vehicleNumberController.value,
              hintText: 'Vehicle Number'.tr,
              icon: Icons.confirmation_number,
              themeChange: themeChange,
            ),
            const SizedBox(height: 16),
            
            // Registration Date
            _buildDatePickerField(context, controller, themeChange),
            const SizedBox(height: 16),
            
            // Vehicle Type Dropdown
            _buildModernDropdown<VehicleTypeModel>(
              context: context,
              value: controller.selectedVehicle.value.id == null ? null : controller.selectedVehicle.value,
              hint: 'Select vehicle type'.tr,
              icon: Icons.category,
              items: controller.vehicleList.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    Constant.localizationName(item.name),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                controller.selectedVehicle.value = value!;
              },
              themeChange: themeChange,
            ),
            const SizedBox(height: 16),
            
            // Vehicle Color
            _buildModernDropdown<String>(
              context: context,
              value: controller.selectedColor.value.isEmpty ? null : controller.selectedColor.value,
              hint: 'Select vehicle color'.tr,
              icon: Icons.palette,
              items: controller.carColorList.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _getColorFromString(item),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item,
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                controller.selectedColor.value = value!;
              },
              themeChange: themeChange,
            ),
            const SizedBox(height: 16),
            
            // Seats
            _buildModernDropdown<String>(
              context: context,
              value: controller.seatsController.value.text.isEmpty ? null : controller.seatsController.value.text,
              hint: 'How Many Seats'.tr,
              icon: Icons.event_seat,
              items: controller.sheetList.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    '$item Seats',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                controller.seatsController.value.text = value!;
              },
              themeChange: themeChange,
            ),
            const SizedBox(height: 16),
            
            // Zone Selection
            _buildZoneSelector(context, controller, themeChange),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required DarkThemeProvider themeChange,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: themeChange.getThem() ? AppColors.darkTextField : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: themeChange.getThem()
                ? AppColors.darkTextFieldBorder.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: themeChange.getThem() ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField(
      BuildContext context, VehicleInformationController controller, DarkThemeProvider themeChange) {
    return _buildModernTextField(
      context: context,
      controller: controller.registrationDateController.value,
      hintText: 'Registration Date'.tr,
      icon: Icons.calendar_today,
      themeChange: themeChange,
      enabled: false,
      onTap: () async {
        await Constant.selectDate(context).then((value) {
          if (value != null) {
            controller.selectedDate.value = value;
            controller.registrationDateController.value.text = DateFormat("dd-MM-yyyy").format(value);
          }
        });
      },
    );
  }

  Widget _buildModernDropdown<T>({
    required BuildContext context,
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    required DarkThemeProvider themeChange,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: themeChange.getThem() ? AppColors.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: themeChange.getThem()
              ? AppColors.darkTextFieldBorder.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        items: items,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: themeChange.getThem() ? Colors.white : Colors.black87,
        ),
        dropdownColor: themeChange.getThem() ? AppColors.darkTextField : Colors.white,
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: AppColors.primary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildZoneSelector(
      BuildContext context, VehicleInformationController controller, DarkThemeProvider themeChange) {
    return _buildModernTextField(
      context: context,
      controller: controller.zoneNameController.value,
      hintText: 'Select Zone'.tr,
      icon: Icons.location_on,
      themeChange: themeChange,
      enabled: false,
      onTap: () {
        zoneDialog(context, controller);
      },
    );
  }

  Widget _buildDriverRulesCard(
      BuildContext context, VehicleInformationController controller, DarkThemeProvider themeChange) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: themeChange.getThem() ? AppColors.darkTextFieldBorder : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: controller.driverRulesList.map((item) {
            bool isSelected = controller.selectedDriverRulesList.indexWhere((element) => element.id == item.id) != -1;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (value) {
                  if (value == true) {
                    controller.selectedDriverRulesList.add(item);
                  } else {
                    controller.selectedDriverRulesList.removeWhere((element) => element.id == item.id);
                  }
                },
                activeColor: AppColors.primary,
                title: Text(
                  Constant.localizationName(item.name),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, VehicleInformationController controller) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          ShowToastDialog.showLoader("Please wait".tr);

          if (controller.selectedServiceId.value!.isEmpty) {
            ShowToastDialog.showToast("Please select service".tr);
          } else if (controller.vehicleNumberController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please enter Vehicle number".tr);
          } else if (controller.registrationDateController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please select registration date".tr);
          } else if (controller.selectedVehicle.value.id == null || controller.selectedVehicle.value.id!.isEmpty) {
            ShowToastDialog.showToast("Please enter Vehicle type".tr);
          } else if (controller.selectedColor.value.isEmpty) {
            ShowToastDialog.showToast("Please enter Vehicle color".tr);
          } else if (controller.seatsController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please enter seats".tr);
          } else if (controller.selectedZone.isEmpty) {
            ShowToastDialog.showToast("Please select Zone".tr);
          } else {
            if (controller.driverModel.value.serviceId == null) {
              controller.driverModel.value.serviceId = controller.selectedServiceId.value;
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

            await FireStoreUtils.updateDriverUser(controller.driverModel.value).then((value) {
              ShowToastDialog.closeLoader();
              if (value == true) {
                ShowToastDialog.showToast("Information updated successfully".tr);
              }
            });
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          "Save".tr,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoMessage(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You cannot change service type once selected. Contact administrator to change.".tr,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.orange.shade700,
                  height: 1.5,
                ),
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

  zoneDialog(BuildContext context, VehicleInformationController controller) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.85),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Select Zones'.tr,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Zone List
                Flexible(
                  child: controller.zoneList.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : Obx(() => ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: controller.zoneList.length,
                            itemBuilder: (BuildContext context, int index) {
                              return Obx(() {
                                bool isSelected = controller.selectedZone.contains(controller.zoneList[index].id);
                                
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary.withOpacity(0.3)
                                          : Colors.grey.withOpacity(0.2),
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (value) {
                                      if (controller.selectedZone.contains(controller.zoneList[index].id)) {
                                        controller.selectedZone.remove(controller.zoneList[index].id);
                                      } else {
                                        controller.selectedZone.add(controller.zoneList[index].id);
                                      }
                                    },
                                    activeColor: AppColors.primary,
                                    title: Text(
                                      Constant.localizationName(controller.zoneList[index].name),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                );
                              });
                            },
                          )),
                ),
                
                // Buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            "Cancel".tr,
                            style: GoogleFonts.poppins(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
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
                                List<ZoneModel> list = controller.zoneList.where((p0) => p0.id == element).toList();
                                if (list.isNotEmpty) {
                                  nameValue = "$nameValue${nameValue.isEmpty ? "" : ", "} ${Constant.localizationName(list.first.name)}";
                                }
                              }
                              controller.zoneNameController.value.text = nameValue;
                              Get.back();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Continue".tr,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
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
      },
    );
  }
}