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
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: _buildAppBar(context),
          body: controller.isLoading.value
              ? _buildLoader(context)
              : _buildBody(context, controller),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.3,
      surfaceTintColor: AppColors.background,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            // color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.primary,
            size: 18,
          ),
        ),
      ),
      title: Text(
        'Vehicle Information'.tr,
        style: AppTypography.appTitle(context),
      ),
      centerTitle: true,
    );
  }

  Widget _buildLoader(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading vehicle information...'.tr,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, VehicleInformationController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressIndicator(),
          const SizedBox(height: 24),
          _buildVehicleDetailsSection(context, controller),
          const SizedBox(height: 24),
          _buildInfoCard(context),
          const SizedBox(height: 32),
          _buildSaveButton(context, controller),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.darkBackground,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grey300),
            ),
            child: Icon(
              Icons.directions_car,
              color: AppColors.background,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Registration'.tr,
                  style: AppTypography.boldHeaders(Get.context!)
                      .copyWith(color: AppColors.background),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete your vehicle information to start driving'.tr,
                  style: AppTypography.caption(Get.context!)
                      .copyWith(color: AppColors.grey300),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailsSection(
      BuildContext context, VehicleInformationController controller) {
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
                Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Vehicle Details'.tr,
                  style: AppTypography.boldHeaders(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildModernTextField(
                  controller: controller.vehicleNumberController.value,
                  label: 'Vehicle Number'.tr,
                  icon: Icons.confirmation_number_outlined,
                  hint: 'Enter your vehicle number'.tr,
                ),
                const SizedBox(height: 20),
                _buildModernDateField(context, controller),
                const SizedBox(height: 20),
                _buildModernSelectorField(
                  value: controller.selectedVehicle.value.id == null
                      ? ''
                      : Constant.localizationName(
                          controller.selectedVehicle.value.name),
                  label: 'Vehicle Type'.tr,
                  icon: Icons.directions_car_outlined,
                  hint: 'Select vehicle type'.tr,
                  onTap: () => _showVehicleTypeSelector(context, controller),
                ),
                const SizedBox(height: 20),
                _buildModernSelectorField(
                  value: controller.selectedColor.value,
                  label: 'Vehicle Color'.tr,
                  icon: Icons.palette_outlined,
                  hint: 'Select vehicle color'.tr,
                  onTap: () => _showColorSelector(context, controller),
                  showColorCircle: true,
                ),
                const SizedBox(height: 20),
                _buildModernSelectorField(
                  value: controller.seatsController.value.text,
                  label: 'Number of Seats'.tr,
                  icon: Icons.event_seat_outlined,
                  hint: 'Select number of seats'.tr,
                  onTap: () => _showSeatsSelector(context, controller),
                ),
                const SizedBox(height: 20),
                _buildModernSelectorField(
                  value: controller.zoneNameController.value.text,
                  label: 'Service Zone'.tr,
                  icon: Icons.location_on_outlined,
                  hint: 'Select service zones'.tr,
                  onTap: () => _showZoneSelector(context, controller),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.boldLabel(Get.context!),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              style: AppTypography.label(Get.context!),
              decoration: InputDecoration(
                prefixIcon: Container(
                  // margin: const EdgeInsets.all(12),
                  // padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          AppColors.primary,
                          Color.lerp(AppColors.primary,
                              AppColors.darkBackground, 0.4)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Icon(
                      icon,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
                hintText: hint,
                hintStyle: AppTypography.label(Get.context!),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDateField(
      BuildContext context, VehicleInformationController controller) {
    return _buildModernTextField(
      controller: controller.registrationDateController.value,
      label: 'Registration Date'.tr,
      icon: Icons.calendar_today_outlined,
      hint: 'Select registration date'.tr,
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

  Widget _buildModernSelectorField({
    required String value,
    required String label,
    required IconData icon,
    required String hint,
    required VoidCallback onTap,
    bool showColorCircle = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.boldLabel(Get.context!),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  // margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          AppColors.primary,
                          Color.lerp(AppColors.primary,
                              AppColors.darkBackground, 0.4)!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Icon(
                      icon,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    children: [
                      if (showColorCircle && value.isNotEmpty) ...[
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _getColorFromString(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        value.isEmpty ? hint : value,
                        style: AppTypography.input(Get.context!).copyWith(
                          color: value.isEmpty
                              ? Colors.grey.shade400
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.darkModePrimary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.grey300)),
            child: Icon(
              Icons.info_outline,
              color: AppColors.background,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Notice'.tr,
                  style: AppTypography.appTitle(context)
                      .copyWith(color: AppColors.background),
                ),
                const SizedBox(height: 4),
                Text(
                  "Your vehicle information will be reviewed by our admin team. You cannot submit another request until the current one is processed."
                      .tr,
                  style: AppTypography.label(context)
                      .copyWith(color: AppColors.grey200),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(
      BuildContext context, VehicleInformationController controller) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            AppColors.darkBackground,
            AppColors.darkBackground.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _handleSave(context, controller),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.save_outlined,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 12),
            Text(
              "Save Vehicle Information".tr,
              style: AppTypography.buttonlight(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave(
      BuildContext context, VehicleInformationController controller) async {
    ShowToastDialog.showLoader("Please wait".tr);

    String? driverId = FireStoreUtils.getCurrentUid();
    if (driverId == null) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("User not authenticated".tr);
      return;
    }

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

  void _showVehicleTypeSelector(
      BuildContext context, VehicleInformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModernBottomSheet(
        context: context,
        title: 'Select Vehicle Type'.tr,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: controller.vehicleList.length,
          itemBuilder: (context, index) {
            VehicleTypeModel vehicleType = controller.vehicleList[index];
            return Obx(() {
              bool isSelected =
                  controller.selectedVehicle.value.id == vehicleType.id;
              return _buildModernListItem(
                title: Constant.localizationName(vehicleType.name),
                isSelected: isSelected,
                onTap: () {
                  controller.selectedVehicle.value = vehicleType;
                  Navigator.pop(context);
                },
              );
            });
          },
        ),
      ),
    );
  }

  void _showColorSelector(
      BuildContext context, VehicleInformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModernBottomSheet(
        context: context,
        title: 'Select Vehicle Color'.tr,
        child: Obx(() => ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: controller.carColorList.length,
              itemBuilder: (context, index) {
                String color = controller.carColorList[index];
                bool isSelected = controller.selectedColor.value == color;
                return _buildModernListItem(
                  title: color,
                  isSelected: isSelected,
                  onTap: () {
                    controller.selectedColor.value = color;
                    Navigator.pop(context);
                  },
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getColorFromString(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            )),
      ),
    );
  }

  void _showSeatsSelector(
      BuildContext context, VehicleInformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModernBottomSheet(
        context: context,
        title: 'Select Number of Seats'.tr,
        child: Obx(() => ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: controller.sheetList.length,
              itemBuilder: (context, index) {
                String seats = controller.sheetList[index];
                bool isSelected =
                    controller.seatsController.value.text == seats;
                return _buildModernListItem(
                  title: '$seats Seats',
                  isSelected: isSelected,
                  onTap: () {
                    controller.seatsController.value.text = seats;
                    Navigator.pop(context);
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.event_seat,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                );
              },
            )),
      ),
    );
  }

  void _showZoneSelector(
      BuildContext context, VehicleInformationController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModernBottomSheet(
        context: context,
        title: 'Select Service Zones'.tr,
        child: controller.zoneList.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('Loading Zones...'.tr)
                    ],
                  ),
                ),
              )
            : Obx(() => ListView.builder(
                  key: ValueKey(controller
                      .selectedZone.length), // Rebuilds on selection change
                  padding: EdgeInsets.zero,
                  itemCount: controller.zoneList.length,
                  itemBuilder: (context, index) {
                    final zone = controller.zoneList[index];
                    final isSelected =
                        controller.selectedZone.contains(zone.id);
                    return _buildModernCheckboxItem(
                      title: Constant.localizationName(zone.name),
                      isSelected: isSelected,
                      onTap: () {
                        if (isSelected) {
                          controller.selectedZone.remove(zone.id);
                        } else {
                          controller.selectedZone.add(zone.id);
                        }
                      },
                    );
                  },
                )),
        showApplyButton: true,
        onApply: () {
          if (controller.selectedZone.isEmpty) {
            ShowToastDialog.showToast("Please select at least one zone".tr);
          } else {
            String nameValue = "";
            for (var element in controller.selectedZone) {
              List<ZoneModel> list =
                  controller.zoneList.where((p0) => p0.id == element).toList();
              if (list.isNotEmpty) {
                nameValue =
                    "$nameValue${nameValue.isEmpty ? "" : ", "} ${Constant.localizationName(list.first.name)}";
              }
            }
            controller.zoneNameController.value.text = nameValue;
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildModernBottomSheet({
    required BuildContext context,
    required String title,
    required Widget child,
    bool showApplyButton = false,
    VoidCallback? onApply,
  }) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
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
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade100,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: AppTypography.appTitle(context),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: child,
            ),
          ),
          if (showApplyButton)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text('Cancel'.tr,
                            style: AppTypography.buttonlight(context).copyWith(
                              color: AppColors.grey500,
                            ))),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                        onPressed: onApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        child: Text(
                          'Apply'.tr,
                          style: AppTypography.buttonlight(context),
                        )),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernListItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Text(
                title,
                style: AppTypography.headers(Get.context!).copyWith(
                  color: isSelected ? AppColors.primary : Colors.black87,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCheckboxItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
