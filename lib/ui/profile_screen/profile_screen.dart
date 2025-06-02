import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/profile_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ProfileController>(
      init: ProfileController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _buildProfileHeader(context, controller),
              Expanded(
                child: controller.isLoading.value
                    ? Center(child: Constant.loader(context))
                    : _buildProfileForm(context, controller),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.only(bottom: 15, top: 10),
      width: double.infinity,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkBackground.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(75),
                  child: _buildProfileImage(context, controller),
                ),
              ),
              GestureDetector(
                onTap: () => buildBottomSheet(context, controller),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Manage your profile".tr,
            style: AppTypography.boldHeaders(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(
      BuildContext context, ProfileController controller) {
    final size = Responsive.width(25, context);

    if (controller.profileImage.isEmpty) {
      return CachedNetworkImage(
        imageUrl: Constant.userPlaceHolder,
        fit: BoxFit.cover,
        height: size,
        width: size,
        placeholder: (context, url) => Constant.loader(context),
        errorWidget: (context, url, error) =>
            Image.network(Constant.userPlaceHolder),
      );
    } else if (Constant().hasValidUrl(controller.profileImage.value) == false) {
      return Image.file(
        File(controller.profileImage.value),
        height: size,
        width: size,
        fit: BoxFit.cover,
      );
    } else {
      return CachedNetworkImage(
        imageUrl: controller.profileImage.value,
        fit: BoxFit.cover,
        height: size,
        width: size,
        placeholder: (context, url) => Constant.loader(context),
        errorWidget: (context, url, error) =>
            Image.network(Constant.userPlaceHolder),
      );
    }
  }

  Widget _buildProfileForm(BuildContext context, ProfileController controller) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    _buildModernTextField(
                      context,
                      label: "Full Name".tr,
                      hint: "Enter your full name".tr,
                      controller: controller.fullNameController.value,
                      icon: Icons.person,
                    ),
                    _buildModernTextField(
                      context,
                      label: "Email".tr,
                      hint: "Enter your email".tr,
                      controller: controller.emailController.value,
                      icon: Icons.email,
                      // enabled: false,
                    ),
                    _buildModernPhoneField(context, controller),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: _buildModernUpdateButton(context, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField(
    BuildContext context, {
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isOptional = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTypography.boldLabel(context)
                    .copyWith(color: AppColors.darkBackground.withOpacity(0.7)),
              ),
              if (isOptional)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Optional".tr,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
              color: AppColors.background,
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: AppTypography.label(context)
                  .copyWith(color: AppColors.darkBackground.withOpacity(0.7)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.label(context)
                    .copyWith(color: AppColors.darkBackground.withOpacity(0.7)),
                prefixIcon: Container(
                  child: Icon(
                    icon,
                    color: AppColors.darkBackground.withOpacity(0.7),
                    size: 20,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPhoneField(
      BuildContext context, ProfileController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Phone Number".tr,
            style: AppTypography.boldLabel(context)
                .copyWith(color: AppColors.darkBackground.withOpacity(0.7)),
          ),
          const SizedBox(height: 8),
          Container(
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200, width: 1.0),
              color: Colors.grey.shade100,
            ),
            child: TextField(
              controller: controller.phoneNumberController.value,
              enabled: true, // Enable for interaction
              style: AppTypography.input(context).copyWith(
                color: AppColors.darkBackground.withOpacity(0.7),
              ),
              decoration: InputDecoration(
                hintText: "Enter phone number".tr,
                hintStyle: AppTypography.input(context).copyWith(
                  color: AppColors.darkBackground.withOpacity(0.6),
                ),
                prefixIcon: Container(
                  width: 80, // Increased width for better rendering
                  padding: const EdgeInsets.only(left: 0),
                  child: CountryCodePicker(
                    onChanged: (value) {
                      controller.countryCode.value = value.dialCode.toString();
                    },
                    dialogBackgroundColor:
                        Theme.of(context).colorScheme.background,
                    initialSelection: controller.countryCode.value.isEmpty
                        ? "+1" // Fallback to a default code
                        : controller.countryCode.value,
                    comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                    flagDecoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                    textStyle: AppTypography.boldLabel(context).copyWith(
                      color: AppColors.darkBackground.withOpacity(0.7),
                      // fontSize: 14,
                    ),
                    searchDecoration: InputDecoration(
                      hintText: "Search country".tr,
                      hintStyle: AppTypography.input(context).copyWith(
                        color: AppColors.darkBackground.withOpacity(0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernUpdateButton(
      BuildContext context, ProfileController controller) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkBackground,
            AppColors.darkBackground.withOpacity(0.8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBackground.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (controller.fullNameController.value.text.isEmpty) {
              ShowToastDialog.showToast("Please enter full name".tr);
            } else {
              ShowToastDialog.showLoader("Please wait".tr);

              if (controller.profileImage.value.isNotEmpty &&
                  Constant().hasValidUrl(controller.profileImage.value) ==
                      false) {
                controller.profileImage.value =
                    await Constant.uploadUserImageToFireStorage(
                  File(controller.profileImage.value),
                  "profileImage/${FireStoreUtils.getCurrentUid()}",
                  File(controller.profileImage.value).path.split('/').last,
                );
              }

              DriverUserModel driverUserModel = controller.driverModel.value;
              driverUserModel.fullName =
                  controller.fullNameController.value.text;
              driverUserModel.profilePic = controller.profileImage.value;

              await FireStoreUtils.updateDriverUser(driverUserModel)
                  .then((value) {
                ShowToastDialog.closeLoader();
                controller.getData();
                ShowToastDialog.showToast("Profile updated successfully".tr);
              });
            }
          },
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.save_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Text(
                  "Update Profile".tr,
                  style: AppTypography.button(context)
                      .copyWith(color: AppColors.background),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<dynamic> buildBottomSheet(
      BuildContext context, ProfileController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkBackground.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      "Select Media".tr,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkBackground.withOpacity(0.8),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.grey),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMediaOption(
                        context,
                        icon: Icons.camera_alt_rounded,
                        label: "Camera".tr,
                        onTap: () {
                          Navigator.pop(context);
                          controller.pickFile(source: ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildMediaOption(
                        context,
                        icon: Icons.photo_library_rounded,
                        label: "Gallery".tr,
                        onTap: () {
                          Navigator.pop(context);
                          controller.pickFile(source: ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: AppColors.darkBackground,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.darkBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
