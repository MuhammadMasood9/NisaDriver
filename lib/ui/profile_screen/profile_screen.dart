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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

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
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      _buildProfileImage(context, controller),
                      if (controller.driverModel.value.profileVerify == true)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
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
                    ),
                    _buildModernPhoneField(context, controller),
                    // _buildVerificationStatusCard(context, controller),
                    Obx(() => !controller.driverModel.value.profileVerify!
                        ? _buildModernOtpSection(context, controller)
                        : const SizedBox.shrink()),
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
            child: Row(
              children: [
                Container(
                  width: 80,
                  padding: const EdgeInsets.only(left: 0),
                  child: CountryCodePicker(
                    onChanged: (value) {
                      controller.countryCode.value = value.dialCode.toString();
                    },
                    dialogBackgroundColor:
                        Theme.of(context).colorScheme.background,
                    initialSelection: controller.countryCode.value.isEmpty
                        ? "+1"
                        : controller.countryCode.value,
                    comparator: (a, b) => b.name!.compareTo(a.name.toString()),
                    flagDecoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                    textStyle: AppTypography.boldLabel(context).copyWith(
                      color: AppColors.darkBackground.withOpacity(0.7),
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
                Expanded(
                  child: TextField(
                    controller: controller.phoneNumberController.value,
                    enabled: false, // Disabled after modal input
                    style: AppTypography.input(context).copyWith(
                      color: AppColors.darkBackground.withOpacity(0.7),
                    ),
                    decoration: InputDecoration(
                      hintText: "Enter phone number".tr,
                      hintStyle: AppTypography.input(context).copyWith(
                        color: AppColors.darkBackground.withOpacity(0.6),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernOtpSection(
      BuildContext context, ProfileController controller) {
    return Obx(() => controller.isOtpSent.value
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildModernOtpField(context, controller),
            ],
          )
        : const SizedBox.shrink());
  }

  Widget _buildModernOtpField(
      BuildContext context, ProfileController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Enter OTP".tr,
            style: AppTypography.boldLabel(context)
                .copyWith(color: AppColors.darkBackground.withOpacity(0.7)),
          ),
          const SizedBox(height: 8),
          Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
              color: AppColors.background,
            ),
            child: TextField(
              controller: controller.otpController.value,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: AppTypography.label(context)
                  .copyWith(color: AppColors.darkBackground.withOpacity(0.7)),
              decoration: InputDecoration(
                hintText: "Enter 6-digit OTP".tr,
                hintStyle: AppTypography.label(context)
                    .copyWith(color: AppColors.darkBackground.withOpacity(0.7)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: controller.verifyOtp,
            child: Text(
              "Verify OTP".tr,
              style: AppTypography.boldLabel(context).copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
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
              driverUserModel.phoneNumber =
                  controller.phoneNumberController.value.text;
              driverUserModel.countryCode = controller.countryCode.value;

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

  Widget _buildModernUpdateButtonModal(BuildContext context,
      ProfileController controller, TextEditingController phoneController) {
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
          onTap: () {
            if (phoneController.text.isEmpty) {
              ShowToastDialog.showToast("Please enter phone number".tr);
            } else {
              controller.phoneNumberController.value.text =
                  phoneController.text;
              controller.countryCode.value =
                  controller.countryCode.value.isEmpty
                      ? "+1"
                      : controller.countryCode.value;
              Navigator.pop(context);
              controller.sendOtp();
            }
          },
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Text(
                  "Send OTP".tr,
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
}

Widget _buildVerificationStatusCard(
    BuildContext context, ProfileController controller) {
  return Obx(() => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: controller.driverModel.value.profileVerify == true
              ? Colors.green.shade50
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: controller.driverModel.value.profileVerify == true
                ? Colors.green.shade200
                : Colors.orange.shade200,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: controller.driverModel.value.profileVerify == true
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    controller.driverModel.value.profileVerify == true
                        ? Icons.verified_user
                        : Icons.pending_actions,
                    color: controller.driverModel.value.profileVerify == true
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.driverModel.value.profileVerify == true
                            ? "Profile Verified".tr
                            : "Profile Not Verified".tr,
                        style: AppTypography.headers(context).copyWith(
                          color:
                              controller.driverModel.value.profileVerify == true
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.driverModel.value.profileVerify == true
                            ? "Your phone number has been verified".tr
                            : "Verify your phone number to complete your profile"
                                .tr,
                        style: AppTypography.label(context).copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (controller.driverModel.value.profileVerify != true) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _showOtpVerificationModal(context, controller),
                  icon: const Icon(Icons.verified_user, size: 18),
                  label: Text(
                    "Verify Phone Number".tr,
                    style: AppTypography.buttonlight(context),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ));
}

void _showOtpVerificationModal(
    BuildContext context, ProfileController controller) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Obx(() => controller.isOtpSent.value
            ? _buildOtpVerificationStep(context, controller, setState)
            : _buildPhoneVerificationStep(context, controller, setState)),
      ),
    ),
  );
}

Widget _buildPhoneVerificationStep(
    BuildContext context, ProfileController controller, StateSetter setState) {
  TextEditingController phoneController =
      TextEditingController(text: controller.phoneNumberController.value.text);

  return Padding(
    padding: const EdgeInsets.all(24.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                controller.resetOtpProcess();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "Verify Phone Number".tr,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkBackground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_android,
              size: 60,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          "We'll send you a verification code".tr,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            color: Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Container(
                width: 90,
                padding: const EdgeInsets.only(left: 8),
                child: CountryCodePicker(
                  onChanged: (value) {
                    controller.countryCode.value = value.dialCode.toString();
                  },
                  dialogBackgroundColor:
                      Theme.of(context).colorScheme.background,
                  initialSelection: controller.countryCode.value.isEmpty
                      ? "+1"
                      : controller.countryCode.value,
                  flagDecoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  textStyle: AppTypography.boldLabel(context),
                  padding: EdgeInsets.zero,
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: AppTypography.input(context).copyWith(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Enter phone number".tr,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (phoneController.text.isEmpty) {
                  ShowToastDialog.showToast("Please enter phone number".tr);
                  return;
                }
                controller.phoneNumberController.value.text =
                    phoneController.text;
                controller.sendOtp();
                setState(() {}); // Update UI to show OTP step
              },
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Send OTP".tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
      ],
    ),
  );
}

Widget _buildOtpVerificationStep(
    BuildContext context, ProfileController controller, StateSetter setState) {
  return Padding(
    padding: const EdgeInsets.all(24.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                controller.resetOtpProcess();
                setState(() {}); // Update UI to go back to phone input
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "Enter Verification Code".tr,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkBackground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read,
              size: 60,
              color: Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          "We've sent a 6-digit code to".tr,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          "${controller.countryCode.value} ${controller.phoneNumberController.value.text}",
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBackground,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        PinCodeTextField(
          appContext: context,
          length: 6,
          controller: controller.otpController.value,
          keyboardType: TextInputType.number,
          onChanged: (value) {},
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(8),
            fieldHeight: 50,
            fieldWidth: 40,
            activeFillColor: Colors.grey.shade50,
            selectedFillColor: Colors.grey.shade50,
            inactiveFillColor: Colors.grey.shade50,
            activeColor: AppColors.primary,
            selectedColor: AppColors.primary,
            inactiveColor: Colors.grey.shade300,
          ),
          enableActiveFill: true,
          cursorColor: AppColors.primary,
          textStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBackground,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await controller.verifyOtp();
                if (controller.driverModel.value.profileVerify == true) {
                  Navigator.pop(context);
                }
              },
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Verify OTP".tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () {
              controller.sendOtp();
            },
            child: Text(
              "Resend OTP".tr,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
      ],
    ),
  );
}
