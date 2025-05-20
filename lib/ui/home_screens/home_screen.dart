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
          backgroundColor: const Color.fromARGB(0, 255, 228, 239),
          body: controller.isLoading.value
              ? Constant.loader(context)
              : Column(
                  children: [
                    double.parse(controller.driverModel.value.walletAmount
                                .toString()) >=
                            double.parse(Constant.minimumDepositToRideAccept)
                        ? SizedBox(
                            height: Responsive.width(8, context),
                            width: Responsive.width(100, context),
                          )
                        : Container(
                            width: Responsive.width(100, context),
                            color: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            child: Text(
                              "You need a minimum ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} in your wallet to accept orders and place bids."
                                  .tr,
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                          ),
                    Expanded(
                      child: Container(
                        height: Responsive.height(100, context),
                        width: Responsive.width(100, context),
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 248, 248, 248),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 20, left: 10, right: 10),
                          child: controller.widgetOptions
                              .elementAt(controller.selectedIndex.value),
                        ),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  spreadRadius: 2,
                  blurRadius: 20,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BottomNavigationBar(
                elevation: 0,
                backgroundColor: Colors.white,
                type: BottomNavigationBarType.fixed,
                currentIndex: controller.selectedIndex.value,
                showSelectedLabels: false,
                showUnselectedLabels: false,
                onTap: controller.onItemTapped,
                items: [
                  BottomNavigationBarItem(
                    label: '',
                    icon: _buildNavItem(
                      context,
                      controller.selectedIndex.value == 0,
                      Icons.directions_car,
                      'New',
                    ),
                  ),
                  BottomNavigationBarItem(
                    label: '',
                    icon: _buildNavItem(
                      context,
                      controller.selectedIndex.value == 1,
                      Icons.check_circle_outline,
                      'Accepted',
                    ),
                  ),
                  BottomNavigationBarItem(
                    label: '',
                    icon: badges.Badge(
                      badgeContent:
                          Text(controller.isActiveValue.value.toString()),
                      child: _buildNavItem(
                        context,
                        controller.selectedIndex.value == 2,
                        Icons.local_taxi,
                        'Active',
                      ),
                    ),
                  ),
                  BottomNavigationBarItem(
                    label: '',
                    icon: _buildNavItem(
                      context,
                      controller.selectedIndex.value == 3,
                      Icons.done_all,
                      'Completed',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
      BuildContext context, bool isSelected, IconData icon, String label) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
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
            size: 14,
            color: isSelected ? Colors.white : Colors.grey,
          ),
          if (isSelected) ...[
            const SizedBox(width: 6),
            Text(
              label.tr,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
