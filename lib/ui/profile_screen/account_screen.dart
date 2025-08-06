import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/controller/profile_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/auth_screen/login_screen.dart'; // Ensure this path is correct
import 'package:driver/ui/bank_details/bank_details_screen.dart';
import 'package:driver/ui/profile_screen/analytics_screen.dart';
import 'package:driver/ui/profile_screen/profile_screen.dart';
import 'package:driver/ui/vehicle_information/vehicle_information_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.put(ProfileController());
    final DashBoardController dashboardController =
        Get.find<DashBoardController>();

    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // If not authenticated, navigate to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAll(() => const LoginScreen());
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Auto-retry profile loading if it fails initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.driverModel.value.id == null &&
          !controller.isLoading.value) {
        Future.delayed(const Duration(seconds: 1), () {
          if (controller.driverModel.value.id == null) {
            controller.fetchInitialData();
          }
        });
      }
    });

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
        leading: InkWell(
          onTap: () => Get.back(),
          child: const Padding(
            padding: EdgeInsets.all(18.0),
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
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (controller.driverModel.value.id == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off,
                    size: 64,
                    color: AppColors.grey500,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load profile.'.tr,
                    style: AppTypography.bodyLarge(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again.'.tr,
                    style: AppTypography.label(context)
                        .copyWith(color: AppColors.grey500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.fetchInitialData(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Retry'.tr),
                  ),
                ],
              ),
            ),
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
            context: context,
            icon: Icons.person_outline,
            title: "Edit Profile".tr,
            subtitle: "Manage your profile and details".tr,
            onTap: () => Get.to(() => const ProfileScreen()),
          ),
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context: context,
            icon: Icons.analytics_outlined,
            title: "Ride Analytics".tr,
            subtitle: "View your earnings and ride statistics".tr,
            onTap: () => Get.to(() => const AnalyticsScreen()),
          ),
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context: context,
            icon: Icons.directions_car_filled_rounded,
            title: "Vehicle Information".tr,
            subtitle: "Manage your registered vehicle details".tr,
            onTap: () => Get.to(() => const VehicleInformationScreen()),
          ),
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context: context,
            icon: Icons.account_balance_wallet_rounded,
            title: "Bank Details".tr,
            subtitle: "View your account details for payouts".tr,
            onTap: () => Get.to(() => const BankDetailsScreen()),
          ),
          const SizedBox(height: 32),
          _buildLogoutButton(context, controller),
          const SizedBox(height: 20),
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

  // ====== ⭐️ WIDGET UPDATED WITH GRADIENT ICON ⭐️ ======
  Widget _buildProfileMenuCard({
    required BuildContext context,
    required IconData icon,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkBackground.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Use ShaderMask to apply a gradient to the icon
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors
                            .darkModePrimary, // A complementary color for the gradient
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Icon(
                      icon,
                      size: 28,
                      color: Colors
                          .white, // IMPORTANT: Must be white for the shader to work
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.headers(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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

  // ====== ⭐️ WIDGET UPDATED WITH GRADIENT ICON ⭐️ ======
  Widget _buildLogoutButton(
      BuildContext context, ProfileController controller) {
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
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () {
            // Show confirmation dialog before logging out
            Get.dialog(
              AlertDialog(
                backgroundColor: AppColors.background,
                title: Text(
                  'Logout'.tr,
                  style: AppTypography.appTitle(context),
                ),
                content: Text(
                  'Are you sure you want to log out?'.tr,
                  style: AppTypography.caption(context),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('Cancel'.tr,
                        style: AppTypography.boldLabel(context)
                            .copyWith(color: AppColors.grey500)),
                    onPressed: () {
                      if (!controller.isLoggingOut.value) {
                        Get.back(); // Close the dialog
                      }
                    },
                  ),
                  // Use Obx to show loading indicator
                  Obx(() {
                    if (controller.isLoggingOut.value) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      );
                    }
                    return TextButton(
                      child: Text('Logout'.tr,
                          style: AppTypography.boldLabel(context).copyWith(
                              color: AppColors
                                  .primary) // Use danger color for text
                          ),
                      onPressed: () {
                        controller.logout();
                      },
                    );
                  }),
                ],
              ),
              // Prevent closing dialog by tapping outside while logging out
              barrierDismissible: !controller.isLoggingOut.value,
            );
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger200.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // Use ShaderMask to apply a gradient to the icon
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        colors: [
                          AppColors.danger200,
                          const Color(
                              0xFFF87171), // A lighter red for the gradient
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: const Icon(
                      Icons.logout,
                      size: 28,
                      color: Colors
                          .white, // IMPORTANT: Must be white for the shader to work
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Logout".tr,
                        style: AppTypography.headers(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "End your session and sign out".tr,
                        style: AppTypography.label(context)
                            .copyWith(color: AppColors.grey500),
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
  }
}
