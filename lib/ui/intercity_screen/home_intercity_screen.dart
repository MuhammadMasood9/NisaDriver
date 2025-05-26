import 'package:driver/controller/home_intercity_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
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
        return controller.selectedService.value.intercityType == null ||
                controller.selectedService.value.intercityType == false
            ? _buildDisabledScreen(context, controller)
            : _buildMainScreen(context, controller);
      },
    );
  }

  Widget _buildDisabledScreen(
      BuildContext context, HomeIntercityController controller) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar

            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Icon Container
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

                      // Title
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

                      // Description
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "Intercity/Outstation feature is currently disabled for ${controller.selectedService.value.title}",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: const Color(0xFF636E72),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Action Button
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
                              // Handle contact support or go back
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
//  Container(
//                   padding: const EdgeInsets.only(bottom: 30, top: 20),
//                   child: Column(
//                     children: [
//                       Container(
//                         width: 70,
//                         height: 70,
//                         decoration: BoxDecoration(
//                           color: AppColors.darkBackground.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: const Icon(
//                           Icons.account_balance,
//                           color: AppColors.darkBackground,
//                           size: 40,
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 36),
//                         child: Text(
//                           "Manage your banking information".tr,
//                           style: GoogleFonts.poppins(
//                             color: AppColors.darkBackground.withOpacity(0.8),
//                             fontSize: 20,
//                             fontWeight: FontWeight.w500,
//                           ),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

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
      bottomNavigationBar: _buildModernBottomNav(context, controller),
    );
  }

  Widget _buildModernBottomNav(
      BuildContext context, HomeIntercityController controller) {
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
              Icons.add_road_rounded,
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
