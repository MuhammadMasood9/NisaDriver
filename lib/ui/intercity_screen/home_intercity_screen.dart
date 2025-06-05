import 'package:driver/constant/constant.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/controller/home_intercity_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:badges/badges.dart' as badges;

class HomeIntercityScreen extends StatelessWidget {
  const HomeIntercityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<HomeIntercityController>(
      init: HomeIntercityController(),
      dispose: (state) {
        FireStoreUtils().closeStream();
      },
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: controller.isLoading.value
              ? Constant.loader(context)
              : SafeArea(
                  child: Obx(() {
                    // Check if profile is not verified
                    if (controller.driverModel.value.profileVerify != true) {
                      return _buildProfileNotVerified(context);
                    }
                    // Check intercity service availability
                    if (controller.selectedService.value.intercityType ==
                            null ||
                        controller.selectedService.value.intercityType ==
                            false) {
                      return _buildDisabledScreen(context, controller);
                    }
                    // Main screen for verified profile and active intercity service
                    return _buildMainScreen(context, controller);
                  }),
                ),
          bottomNavigationBar:
              controller.driverModel.value.profileVerify == true &&
                      controller.selectedService.value.intercityType == true
                  ? _buildResponsiveBottomNav(context, controller)
                  : null,
        );
      },
    );
  }

  Widget _buildProfileNotVerified(BuildContext context) {
    final controllerDashBoard = Get.find<DashBoardController>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 60,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Profile Not Verified".tr,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.darkBackground,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Please verify your phone number to access rides and features."
                  .tr,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to profile verification screen
                  controllerDashBoard.onSelectItem(5);
                },
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
        ),
      ),
    );
  }

  Widget _buildWalletWarningBanner(
      BuildContext context, HomeIntercityController controller) {
    return double.parse(controller.driverModel.value.walletAmount?.toString() ??
                '0.0') >=
            double.parse(Constant.minimumDepositToRideAccept ?? '0.0')
        ? const SizedBox(height: 16)
        : Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE74C3C),
                  const Color(0xFFE74C3C).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE74C3C).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "You need a minimum ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} in your wallet to accept orders and place bids."
                        .tr,
                    style: AppTypography.boldLabel(context)
                        .copyWith(color: Colors.white, height: 1.4),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildDisabledScreen(
      BuildContext context, HomeIntercityController controller) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildWalletWarningBanner(context, controller),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 1000),
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.1),
                                    AppColors.primary.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.location_off_rounded,
                                size: 60,
                                color: AppColors.primary.withOpacity(0.7),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "Service Unavailable".tr,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2D3436),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "Intercity/Outstation feature is currently disabled for ${controller.selectedService.value.title}"
                              .tr,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: const Color(0xFF636E72),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        width: double.infinity,
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF74B9FF),
                              const Color(0xFF0984E3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0984E3).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Get.back();
                            },
                            child: Center(
                              child: Text(
                                "Contact Support".tr,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainScreen(
      BuildContext context, HomeIntercityController controller) {
    final double walletAmount = double.parse(
        controller.driverModel.value.walletAmount?.toString() ?? '0.0');
    final double minimumDeposit =
        double.parse(Constant.minimumDepositToRideAccept ?? '0.0');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            walletAmount < minimumDeposit
                ? _buildWalletWarningBanner(context, controller)
                : const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, left: 10, right: 10),
                    child: controller.widgetOptions
                        .elementAt(controller.selectedIndex.value),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // bottomNavigationBar: _buildResponsiveBottomNav(context, controller),
    );
  }

  Widget _buildResponsiveBottomNav(
      BuildContext context, HomeIntercityController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return Container(
      margin: EdgeInsets.fromLTRB(
          isCompact ? 8 : 12, 0, isCompact ? 8 : 12, isCompact ? 8 : 12),
      padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 4 : 8, vertical: isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 28 : 32),
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, -8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildResponsiveNavItem(
              context,
              controller,
              controller.selectedIndex.value == 0,
              Icons.add_road_rounded,
              'New',
              0,
              isCompact,
              isEnabled: controller.driverModel.value.profileVerify == true),
          _buildResponsiveNavItem(
              context,
              controller,
              controller.selectedIndex.value == 1,
              Icons.check_circle_rounded,
              'Accepted',
              1,
              isCompact,
              isEnabled: controller.driverModel.value.profileVerify == true),
          _buildResponsiveNavItem(
              context,
              controller,
              controller.selectedIndex.value == 2,
              Icons.local_taxi_rounded,
              'Active',
              2,
              isCompact,
              badgeCount: controller.isActiveValue.value,
              isEnabled: controller.driverModel.value.profileVerify == true),
          _buildResponsiveNavItem(
              context,
              controller,
              controller.selectedIndex.value == 3,
              Icons.task_alt_rounded,
              'Completed',
              3,
              isCompact,
              isEnabled: controller.driverModel.value.profileVerify == true),
        ],
      ),
    );
  }

  Widget _buildResponsiveNavItem(
    BuildContext context,
    HomeIntercityController controller,
    bool isSelected,
    IconData icon,
    String label,
    int index,
    bool isCompact, {
    int? badgeCount,
    required bool isEnabled,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isEnabled ? () => controller.onItemTapped(index) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          margin: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 3),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? (isCompact ? 8 : 12) : (isCompact ? 6 : 8),
            vertical: isCompact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            gradient: isSelected && isEnabled
                ? LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.grey.withOpacity(0.03),
                      Colors.grey.withOpacity(0.01),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            borderRadius: BorderRadius.circular(isCompact ? 20 : 24),
            border: isSelected && isEnabled
                ? null
                : Border.all(
                    color: Colors.transparent,
                    width: 1,
                  ),
            boxShadow: isSelected && isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: _buildNavContent(context, isSelected && isEnabled, icon, label,
              badgeCount, isCompact),
        ),
      ),
    );
  }

  Widget _buildNavContent(
    BuildContext context,
    bool isSelected,
    IconData icon,
    String label,
    int? badgeCount,
    bool isCompact,
  ) {
    Widget iconWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Icon(
        icon,
        size: isSelected ? (isCompact ? 20 : 22) : (isCompact ? 18 : 20),
        color: isSelected ? Colors.white : const Color(0xFF636E72),
      ),
    );

    if (badgeCount != null && badgeCount > 0) {
      iconWidget = badges.Badge(
        badgeContent: Text(
          badgeCount.toString(),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isCompact ? 9 : 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        badgeStyle: badges.BadgeStyle(
          badgeColor: const Color(0xFFE74C3C),
          elevation: 2,
          padding: EdgeInsets.all(isCompact ? 3 : 4),
        ),
        child: iconWidget,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        iconWidget,
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label.tr,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : const Color(0xFF636E72),
                fontSize: isCompact ? 9 : 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
