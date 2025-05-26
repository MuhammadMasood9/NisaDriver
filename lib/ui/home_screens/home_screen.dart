import 'package:driver/constant/constant.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
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
                                    color: const Color(0xFFE74C3C)
                                        .withOpacity(0.3),
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
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                      // Main Content
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  top: 4, left: 10, right: 10),
                              child: controller.widgetOptions
                                  .elementAt(controller.selectedIndex.value),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: _buildModernBottomNav(context, controller),
        );
      },
    );
  }

  Widget _buildModernBottomNav(
      BuildContext context, HomeController controller) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BottomNavigationBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          currentIndex: controller.selectedIndex.value,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: controller.onItemTapped,
          items: [
            _buildNavBarItem(
              context,
              controller.selectedIndex.value == 0,
              Icons.directions_car_rounded,
              'New',
              0,
            ),
            _buildNavBarItem(
              context,
              controller.selectedIndex.value == 1,
              Icons.check_circle_rounded,
              'Accepted',
              1,
            ),
            _buildNavBarItem(
              context,
              controller.selectedIndex.value == 2,
              Icons.local_taxi_rounded,
              'Active',
              2,
              badgeCount: controller.isActiveValue.value,
            ),
            _buildNavBarItem(
              context,
              controller.selectedIndex.value == 3,
              Icons.task_alt_rounded,
              'Completed',
              3,
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavBarItem(
    BuildContext context,
    bool isSelected,
    IconData icon,
    String label,
    int index, {
    int? badgeCount,
  }) {
    Widget iconWidget = _buildNavIcon(context, isSelected, icon, label);

    if (badgeCount != null && badgeCount > 0) {
      iconWidget = badges.Badge(
        badgeContent: Text(
          badgeCount.toString(),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        badgeStyle: badges.BadgeStyle(
          badgeColor: const Color(0xFFE74C3C),
          elevation: 0,
          padding: const EdgeInsets.all(6),
        ),
        child: iconWidget,
      );
    }

    return BottomNavigationBarItem(
      label: '',
      icon: iconWidget,
    );
  }

  Widget _buildNavIcon(
      BuildContext context, bool isSelected, IconData icon, String label) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: isSelected ? Colors.white : const Color(0xFF636E72),
          ),
          if (isSelected) ...[
            const SizedBox(height: 4),
            Text(
              label.tr,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
