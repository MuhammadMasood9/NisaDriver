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
import 'package:pin_code_fields/pin_code_fields.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<ProfileController>(
      init: ProfileController(),
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
        onPressed: () => Get.back(),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
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
        'Profile'.tr,
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
              color: Colors.black.withValues(alpha: 0.1),
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
              'Loading your profile...'.tr,
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

  Widget _buildBody(BuildContext context, ProfileController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildProfileHeader(context, controller),
          const SizedBox(height: 24),
          _buildProfileFormSection(context, controller),
          const SizedBox(height: 32),
          _buildUpdateButton(context, controller),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, ProfileController controller) {
    return Column(
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
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(75),
                child: _buildProfileImage(context, controller),
              ),
            ),
            GestureDetector(
              onTap: () => _buildImagePickerSheet(context, controller),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      Color.lerp(
                          AppColors.primary, AppColors.darkBackground, 0.4)!,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          controller.driverModel.value.fullName ?? "Driver",
          style: AppTypography.appTitle(context),
        ),
        const SizedBox(height: 4),
        Text(
          "Manage your profile information".tr,
          style: AppTypography.label(context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProfileImage(
      BuildContext context, ProfileController controller) {
    final size = Responsive.width(30, context);

    Widget placeholder = Image.network(
      Constant.userPlaceHolder,
      height: size,
      width: size,
      fit: BoxFit.cover,
    );

    return Obx(() {
      if (controller.profileImage.value.isEmpty) {
        return CachedNetworkImage(
          imageUrl: Constant.userPlaceHolder,
          fit: BoxFit.cover,
          height: size,
          width: size,
          placeholder: (context, url) => Constant.loader(context),
          errorWidget: (context, url, error) => placeholder,
        );
      } else if (Constant().hasValidUrl(controller.profileImage.value) ==
          false) {
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
          errorWidget: (context, url, error) => placeholder,
        );
      }
    });
  }

  Widget _buildProfileFormSection(
      BuildContext context, ProfileController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
                  Icons.person_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Personal Details'.tr,
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
                  controller: controller.fullNameController.value,
                  label: "Full Name".tr,
                  icon: Icons.badge_outlined,
                  hint: "Enter your full name".tr,
                ),
                const SizedBox(height: 20),
                _buildModernTextField(
                  controller: controller.emailController.value,
                  label: "Email".tr,
                  icon: Icons.email_outlined,
                  hint: "Enter your email".tr,
                  enabled: false,
                ),
                const SizedBox(height: 20),
                _buildModernPhoneField(context, controller),
                const SizedBox(height: 20),
                _buildEmailVerificationCard(context, controller),
                const SizedBox(height: 20),
                _buildVerificationStatusCard(context, controller),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.boldLabel(Get.context!),
        ),
        const SizedBox(height: 8),
        Container(
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
              prefixIcon: _buildShaderIcon(icon),
              hintText: hint,
              hintStyle: AppTypography.label(Get.context!),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernPhoneField(
      BuildContext context, ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Phone Number".tr,
          style: AppTypography.boldLabel(context),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            color: Colors.grey.shade50, // Disabled look
          ),
          child: Row(
            children: [
              CountryCodePicker(
                onChanged: (value) {
                  controller.countryCode.value = value.dialCode.toString();
                },
                dialogBackgroundColor: Theme.of(context).colorScheme.surface,
                initialSelection: controller.countryCode.value.isEmpty
                    ? "PK"
                    : controller.countryCode.value,
                flagDecoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
                textStyle: AppTypography.label(context),
                enabled: false, // Make picker unclickable
                padding: const EdgeInsets.only(left: 4),
              ),
              Expanded(
                child: TextField(
                  controller: controller.phoneNumberController.value,
                  enabled: false, // Make text field un-editable directly
                  style: AppTypography.label(context),
                  decoration: InputDecoration(
                    hintText: "Enter phone number".tr,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailVerificationCard(
      BuildContext context, ProfileController controller) {
    return Obx(() {
      bool isEmailVerified = controller.isEmailVerified.value;
      bool isEmailSent = controller.isEmailVerificationSent.value;
      
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEmailVerified ? Colors.green.shade50 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isEmailVerified ? Colors.green.shade200 : Colors.blue.shade200,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isEmailVerified 
                  ? Icons.verified_user_outlined 
                  : isEmailSent 
                      ? Icons.email_outlined 
                      : Icons.email_outlined,
              color: isEmailVerified 
                  ? Colors.green.shade700 
                  : Colors.blue.shade700,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEmailVerified
                        ? "Email Verified".tr
                        : isEmailSent
                            ? "Check Your Email".tr
                            : "Email Verification".tr,
                    style: AppTypography.headers(context).copyWith(
                      color: isEmailVerified
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEmailVerified
                        ? "Your email address is verified.".tr
                        : isEmailSent
                            ? "We sent a verification link to your email.".tr
                            : "Verify your email to complete your profile.".tr,
                    style: AppTypography.caption(context)
                        .copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (!isEmailVerified) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (isEmailSent) {
                    controller.checkEmailVerificationStatus();
                  } else {
                    controller.sendEmailVerification();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isEmailSent ? 'Check Status'.tr : 'Verify Email'.tr,
                    style: AppTypography.boldLabel(context)
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ),
            ]
          ],
        ),
      );
    });
  }

  Widget _buildVerificationStatusCard(
      BuildContext context, ProfileController controller) {
    bool isVerified = controller.driverModel.value.profileVerify == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isVerified ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isVerified ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? Icons.verified_user_outlined : Icons.pending_outlined,
            color: isVerified ? Colors.green.shade700 : Colors.orange.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified
                      ? "Profile Verified".tr
                      : "Verification Required".tr,
                  style: AppTypography.headers(context).copyWith(
                    color: isVerified
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified
                      ? "Your profile is fully verified.".tr
                      : "Complete verification to access all features.".tr,
                  style: AppTypography.caption(context)
                      .copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (!isVerified) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _showOtpVerificationModal(context, controller),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Verify Phone'.tr,
                  style: AppTypography.boldLabel(context)
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildUpdateButton(
      BuildContext context, ProfileController controller) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            AppColors.darkBackground,
            AppColors.darkBackground.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ElevatedButton(
        onPressed: () => _handleUpdate(controller),
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
            const Icon(Icons.save_outlined, color: Colors.white, size: 16),
            const SizedBox(width: 12),
            Text(
              "Update Profile".tr,
              style: AppTypography.buttonlight(context),
            ),
          ],
        ),
      ),
    );
  }

  void _handleUpdate(ProfileController controller) async {
    if (controller.fullNameController.value.text.isEmpty) {
      ShowToastDialog.showToast("Please enter full name".tr);
      return;
    }

    ShowToastDialog.showLoader("Please wait".tr);

    if (controller.profileImage.value.isNotEmpty &&
        !Constant().hasValidUrl(controller.profileImage.value)) {
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
      ShowToastDialog.showToast("Profile updated successfully".tr);
    });
  }

  Widget _buildShaderIcon(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            colors: [
              AppColors.primary,
              Color.lerp(AppColors.primary, AppColors.darkBackground, 0.4)!,
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
    );
  }

  // --- Image Picker Bottom Sheet ---
  void _buildImagePickerSheet(
      BuildContext context, ProfileController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildModernBottomSheet(
        context: context,
        title: 'Select Profile Photo'.tr,
        child: Column(
          children: [
            _buildModernListItem(
              title: "Take a Photo".tr,
              onTap: () {
                Navigator.pop(context);
                controller.pickFile(source: ImageSource.camera);
              },
              leading: _buildShaderIcon(Icons.camera_alt_outlined),
            ),
            _buildModernListItem(
              title: "Choose from Gallery".tr,
              onTap: () {
                Navigator.pop(context);
                controller.pickFile(source: ImageSource.gallery);
              },
              leading: _buildShaderIcon(Icons.photo_library_outlined),
            ),
          ],
        ),
      ),
    );
  }

  // --- OTP Verification Modal and Steps ---
  void _showOtpVerificationModal(
      BuildContext context, ProfileController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Obx(
          () => _buildModernBottomSheet(
            context: context,
            title: controller.isOtpSent.value
                ? "Enter OTP".tr
                : "Verify Your Number".tr,
            showBackButton: controller.isOtpSent.value,
            onBack: () {
              controller.resetOtpProcess();
              setState(() {});
            },
            child: controller.isOtpSent.value
                ? _buildOtpVerificationStep(context, controller, setState)
                : _buildPhoneVerificationStep(context, controller, setState),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneVerificationStep(BuildContext context,
      ProfileController controller, StateSetter setState) {
    TextEditingController phoneController = TextEditingController(
        text: controller.phoneNumberController.value.text);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          _buildModernPhoneField(context, controller),
          const SizedBox(height: 20),
          _buildModalButton(
            context: context,
            label: "Send OTP".tr,
            onTap: () {
              if (phoneController.text.isEmpty) {
                ShowToastDialog.showToast("Please enter phone number".tr);
                return;
              }
              controller.phoneNumberController.value.text =
                  phoneController.text;
              controller.sendOtp();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOtpVerificationStep(BuildContext context,
      ProfileController controller, StateSetter setState) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          Text(
            "${"We've sent a 6-digit code to".tr}\n${controller.countryCode.value} ${controller.phoneNumberController.value.text}",
            style: AppTypography.label(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
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
              inactiveColor: Colors.grey.shade200,
            ),
            enableActiveFill: true,
            cursorColor: AppColors.primary,
            textStyle: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkBackground,
            ),
          ),
          const SizedBox(height: 20),
          _buildModalButton(
            context: context,
            label: "Verify OTP".tr,
            onTap: () async {
              await controller.verifyOtp();
              if (controller.driverModel.value.profileVerify == true) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => controller.sendOtp(),
            child: Text(
              "Resend Code".tr,
              style: AppTypography.label(context)
                  .copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // --- Generic Modern Bottom Sheet & List Item Widgets ---
  Widget _buildModernBottomSheet({
    required BuildContext context,
    required String title,
    required Widget child,
    bool showBackButton = false,
    VoidCallback? onBack,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                bottom: BorderSide(color: Colors.grey.shade100, width: 1),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showBackButton)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack,
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: AppTypography.appTitle(context),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () {
                      // controller.resetOtpProcess();
                      Navigator.pop(context);
                    },
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
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildModernListItem({
    required String title,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
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
                style: AppTypography.headers(Get.context!),
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
    );
  }

  Widget _buildModalButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
        child: Text(label, style: AppTypography.buttonlight(context)),
      ),
    );
  }
}
