import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/controller/profile_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/bank_details/bank_details_screen.dart';
import 'package:driver/ui/profile_screen/analytics_screen.dart';
import 'package:driver/ui/profile_screen/profile_screen.dart';
import 'package:driver/ui/vehicle_information/vehicle_information_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.put(ProfileController());
    final DashBoardController dashboardController =
        Get.find<DashBoardController>();

    return Scaffold(
      backgroundColor: AppColors.grey75,
      appBar: AppBar(
        elevation: 0.5,
        shadowColor: AppColors.grey50,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'My Profile'.tr,
          style: AppTypography.appBar(context),
        ),
        centerTitle: true,
        // Use back button instead of hamburger menu
        leading: InkWell(
          onTap: () => Get.back(),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Icon(
              Icons.arrow_back_ios,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: Center(
              child: Transform.scale(
                scale: 0.8,
                child: Obx(() => Switch(
                      value: dashboardController.isOnline.value,
                      onChanged: (value) {
                        dashboardController.toggleOnlineStatus(value);
                      },
                      activeColor: AppColors.primary,
                      inactiveThumbColor: AppColors.grey500,
                    )),
              ),
            ),
          )
        ],
      ),
      // Remove the drawer completely
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (controller.driverModel.value.id == null) {
          return Center(
            child: Text('Could not load profile.'.tr,
                style: AppTypography.bodyLarge(context)),
          );
        }

        return _buildProfileBody(context, controller);
      }),
    );
  }

  Widget _buildProfileBody(BuildContext context, ProfileController controller) {
    final driver = controller.driverModel.value;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(context, driver),
          const SizedBox(height: 32),
          _buildProfileMenuCard(
            context,
            icon: Icons.person,
            iconColor: AppColors.darkInvite,
            title: "Edit Profile".tr,
            subtitle: "Manage your profile and details".tr,
            onTap: () => Get.to(() => const ProfileScreen()),
          ),
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context,
            icon: Icons.analytics_outlined,
            iconColor: AppColors.primary,
            title: "Ride Analytics".tr,
            subtitle: "View your earnings and ride statistics".tr,
            onTap: () => Get.to(() => const AnalyticsScreen()),
          ),
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context,
            icon: Icons.directions_car_filled_rounded,
            iconColor: AppColors.danger200,
            title: "Vehicle Information".tr,
            subtitle: "Manage your registered vehicle details".tr,
            onTap: () => Get.to(() => const VehicleInformationScreen()),
          ),
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.darkBackground,
            title: "Bank Details".tr,
            subtitle: "View your account details for payouts".tr,
            onTap: () => Get.to(() => const BankDetailsScreen()),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, DriverUserModel driver) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.darkBackground.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.darkBackground.withOpacity(0.2), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: driver.profilePic ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (context, url, error) =>
                      Image.asset(Constant.userPlaceHolder, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            driver.fullName ?? 'N/A',
            style: AppTypography.appTitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            driver.email ?? 'No email provided'.tr,
            style: AppTypography.boldLabel(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenuCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.darkModePrimary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Icon(
                      icon,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTypography.headers(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 0),
                      Text(
                        subtitle,
                        style: AppTypography.label(context)
                            .copyWith(color: AppColors.grey500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.darkBackground.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.arrow_forward_ios,
                      size: 16, color: AppColors.darkBackground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
