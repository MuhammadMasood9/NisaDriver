import 'package:driver/constant/constant.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:badges/badges.dart' as badges;

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<HomeController>(
      init: HomeController(),
      dispose: (state) {
        FireStoreUtils().closeStream();
      },
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: controller.isLoading.value
              ? Constant.loader(context)
              : SafeArea(
                  child: Column(
                    children: [
                      // Wallet Warning Banner
                      double.parse(controller.driverModel.value.walletAmount
                                      ?.toString() ??
                                  '0.0') >=
                              double.parse(
                                  Constant.minimumDepositToRideAccept ?? '0.0')
                          ? const SizedBox(height: 16)
                          : Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                                    color: const Color(0xFFE74C3C)
                                        .withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
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
                                      style:  AppTypography.boldLabel(context).copyWith(color: Colors.white,height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                      // Main Content
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
                              padding: const EdgeInsets.only(
                                  top: 8, left: 12, right: 12),
                              child: controller.widgetOptions
                                  .elementAt(controller.selectedIndex.value),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: _buildResponsiveBottomNav(context, controller),
        );
      },
    );
  }

  Widget _buildResponsiveBottomNav(
      BuildContext context, HomeController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return Container(
      margin: EdgeInsets.fromLTRB(
        isCompact ? 8 : 12,
        0,
        isCompact ? 8 : 12,
        isCompact ? 8 : 12,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 8,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 28 : 32),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
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
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildResponsiveNavItem(
            context,
            controller,
            controller.selectedIndex.value == 0,
            Icons.fiber_new_rounded,
            'New',
            0,
            isCompact,
          ),
          _buildResponsiveNavItem(
            context,
            controller,
            controller.selectedIndex.value == 1,
            Icons.check_circle_rounded,
            'Accepted',
            1,
            isCompact,
          ),
          _buildResponsiveNavItem(
            context,
            controller,
            controller.selectedIndex.value == 2,
            Icons.local_taxi_rounded,
            'Active',
            2,
            isCompact,
            badgeCount: controller.isActiveValue.value,
          ),
          _buildResponsiveNavItem(
            context,
            controller,
            controller.selectedIndex.value == 3,
            Icons.task_alt_rounded,
            'Completed',
            3,
            isCompact,
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveNavItem(
    BuildContext context,
    HomeController controller,
    bool isSelected,
    IconData icon,
    String label,
    int index,
    bool isCompact, {
    int? badgeCount,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          margin: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 3),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? (isCompact ? 8 : 12) : (isCompact ? 6 : 8),
            vertical: isCompact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
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
            border: isSelected
                ? null
                : Border.all(
                    color: Colors.transparent,
                    width: 1,
                  ),
            boxShadow: isSelected
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
          child: _buildNavContent(
            context,
            isSelected,
            icon,
            label,
            badgeCount,
            isCompact,
          ),
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
        // Always show text, but with different styling for selected/unselected
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
