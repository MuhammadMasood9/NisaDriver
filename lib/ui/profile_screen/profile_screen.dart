import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/profile_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ProfileController>(
      init: ProfileController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: Colors.white,
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

  Widget _buildProfileHeader(BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.only(bottom: 30),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
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
        ],
      ),
    );
  }

  Widget _buildProfileImage(BuildContext context, ProfileController controller) {
    final size = Responsive.width(30, context);

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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Personal Information".tr),
            const SizedBox(height: 20),
            _buildInputField(
              context,
              label: "Full Name".tr,
              icon: Icons.person_outline,
              controller: controller.fullNameController.value,
            ),
            const SizedBox(height: 20),
            _buildPhoneField(context, controller),
            const SizedBox(height: 20),
            _buildInputField(
              context,
              label: "Email".tr,
              icon: Icons.email_outlined,
              controller: controller.emailController.value,
              enabled: false,
            ),
            const SizedBox(height: 40),
            _buildUpdateButton(context, controller),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(color: Colors.black38),
              prefixIcon: Icon(icon, color: AppColors.darkBackground),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppColors.darkBackground, width: 1),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey[100],
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(BuildContext context, ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Phone Number".tr,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: TextFormField(
            controller: controller.phoneNumberController.value,
            enabled: false,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: "Phone number".tr,
              hintStyle: TextStyle(color: Colors.black38),
              prefixIcon: CountryCodePicker(
                onChanged: (value) {
                  controller.countryCode.value = value.dialCode.toString();
                },
                dialogBackgroundColor: Colors.white,
                initialSelection: controller.countryCode.value,
                comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                flagDecoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
                textStyle: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                searchDecoration: InputDecoration(
                  hintText: "Search country".tr,
                  hintStyle: TextStyle(color: Colors.black38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateButton(BuildContext context, ProfileController controller) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          if (controller.fullNameController.value.text.isEmpty) {
            ShowToastDialog.showToast("Please enter full name".tr);
          } else {
            ShowToastDialog.showLoader("Please wait".tr);

            if (controller.profileImage.value.isNotEmpty &&
                Constant().hasValidUrl(controller.profileImage.value) == false) {
              controller.profileImage.value =
                  await Constant.uploadUserImageToFireStorage(
                File(controller.profileImage.value),
                "profileImage/${FireStoreUtils.getCurrentUid()}",
                File(controller.profileImage.value).path.split('/').last,
              );
            }

            DriverUserModel driverUserModel = controller.driverModel.value;
            driverUserModel.fullName = controller.fullNameController.value.text;
            driverUserModel.profilePic = controller.profileImage.value;

            await FireStoreUtils.updateDriverUser(driverUserModel).then((value) {
              ShowToastDialog.closeLoader();
              controller.getData();
              ShowToastDialog.showToast("Profile update successfully".tr);
            });
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          "Update Profile".tr,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<dynamic> buildBottomSheet(
      BuildContext context, ProfileController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMediaOption(
                        context,
                        icon: Icons.camera_alt_rounded,
                        label: "Camera".tr,
                        color: AppColors.darkBackground,
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
                        color: AppColors.darkBackground,
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}