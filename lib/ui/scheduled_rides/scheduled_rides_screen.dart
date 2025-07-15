import 'dart:math';

import 'package:badges/badges.dart' as badges;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/scheduled_ride_model.dart';
import 'package:driver/ui/scheduled_rides/scheduled_ride_details_screen.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// --- NEW: Controller for managing the selected tab state ---
class ScheduledRidesController extends GetxController {
  var selectedIndex = 0.obs;

  void onItemTapped(int index) {
    selectedIndex.value = index;
  }
}

class ScheduledRidesScreen extends StatelessWidget {
  const ScheduledRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We use GetX to manage the state of the selected tab.
    return GetX<ScheduledRidesController>(
      init: ScheduledRidesController(),
      builder: (controller) {
        // List of widgets to display based on the selected tab.
        final List<Widget> widgetOptions = [
          _buildNewSchedulesView(context),
          _buildMySchedulesView(context),
        ];

        return Scaffold(
          // Set a background color for the screen.
          backgroundColor: AppColors.background,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            // Ensure status bar icons are visible on the light background.
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.white,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: SafeArea(
              // Use a Stack to overlay the navigation bar on top of the content.
              child: Stack(
                children: [
                  // Main content area that switches between views.
                  // IndexedStack preserves the state (e.g., scroll position) of each tab.
                  IndexedStack(
                    index: controller.selectedIndex.value,
                    children: widgetOptions,
                  ),
                  // Position the custom navigation bar at the bottom.
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildResponsiveBottomNav(context, controller),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- VIEW 1: NEW SCHEDULES AVAILABLE TO ACCEPT ---
  Widget _buildNewSchedulesView(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(CollectionName.scheduledRides)
          .where("status", isEqualTo: Constant.ridePlaced)
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyListView(
              'Something went wrong'.tr, Icons.error_outline);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Constant.loader(context);
        }
        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyListView(
              "No new weekly schedules available right now.".tr,
              Icons.explore_off_rounded);
        }

        return ListView.builder(
          // Added bottom padding to prevent the nav bar from hiding the last item.
          padding: const EdgeInsets.only(top: 8, bottom: 110),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            ScheduleRideModel scheduleModel = ScheduleRideModel.fromJson(
                snapshot.data!.docs[index].data() as Map<String, dynamic>);
            return InkWell(
              onTap: () => Get.to(() =>
                  ScheduledRideDetailsScreen(scheduleId: scheduleModel.id!)),
              child: _buildScheduleCard(context, scheduleModel,
                  isAcceptable: true),
            );
          },
        );
      },
    );
  }

  // --- VIEW 2: SCHEDULES ALREADY ACCEPTED BY THE DRIVER ---
  Widget _buildMySchedulesView(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(CollectionName.scheduledRides)
          .where("status", whereIn: [Constant.rideActive])
          .where("driverId", isEqualTo: FireStoreUtils.getCurrentUid())
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyListView(
              'Something went wrong'.tr, Icons.error_outline);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Constant.loader(context);
        }
        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyListView(
              "You have not accepted any weekly schedules.".tr,
              Icons.work_off_rounded);
        }

        return ListView.builder(
          // Added bottom padding to prevent the nav bar from hiding the last item.
          padding: const EdgeInsets.only(top: 8, bottom: 110),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            ScheduleRideModel scheduleModel = ScheduleRideModel.fromJson(
                snapshot.data!.docs[index].data() as Map<String, dynamic>);
            return InkWell(
              onTap: () => Get.to(() =>
                  ScheduledRideDetailsScreen(scheduleId: scheduleModel.id!)),
              child: _buildScheduleCard(context, scheduleModel,
                  isAcceptable: false),
            );
          },
        );
      },
    );
  }

  // --- UI WIDGETS AND HELPERS ---

  // Helper for creating consistent info rows
  Widget _buildInfoRow(BuildContext context,
      {required IconData icon, required String title, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary.withOpacity(0.8)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTypography.caption(context)
                      .copyWith(color: Colors.grey.shade600)),
              const SizedBox(height: 1),
              Text(value,
                  style: AppTypography.boldLabel(context)
                      .copyWith(color: AppColors.darkBackground, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  // Card UI with Reduced Spacing
  Widget _buildScheduleCard(BuildContext context, ScheduleRideModel model,
      {required bool isAcceptable}) {
    String formattedStartDate = model.startDate != null
        ? DateFormat('MMM d').format(model.startDate!.toDate())
        : 'N/A';
    String formattedEndDate = model.endDate != null
        ? DateFormat('MMM d, yyyy').format(model.endDate!.toDate())
        : 'N/A';
    String time = model.scheduledTime ?? 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header with Payout ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Weekly Payout".tr,
                    style: AppTypography.boldLabel(context)
                        .copyWith(color: AppColors.primary)),
                Text(
                  "Rs: ${model.weeklyRate}" ?? 'N/A',
                  style: AppTypography.headers(context).copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          // --- Main Content Area ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Route Info ---
                Text("Route".tr.toUpperCase(),
                    style: AppTypography.caption(context).copyWith(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                LocationView(
                  sourceLocation: model.sourceLocationName.toString(),
                  destinationLocation: model.destinationLocationName.toString(),
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 12),

                // --- Schedule Details ---

                Row(
                  children: [
                    Expanded(
                      child: _buildInfoRow(
                        context,
                        icon: Icons.calendar_today_outlined,
                        title: 'Duration',
                        value: '$formattedStartDate - $formattedEndDate',
                      ),
                    ),
                    SizedBox(height: 12),
                    Expanded(
                      child: _buildInfoRow(
                        context,
                        icon: Icons.access_time_filled_rounded,
                        title: 'Pickup Time'.tr,
                        value: time,
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),

                // --- Recurring Days ---
                Text("Recurring Days".tr.toUpperCase(),
                    style: AppTypography.caption(context).copyWith(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                _buildDaysRow(context, model.recursOnDays ?? []),
              ],
            ),
          ),

          // --- Action Button ---
          if (isAcceptable) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ButtonThem.buildButton(context,
                    title: "Accept Schedule".tr,
                    bgColors: AppColors.primary,
                    onPress: () => _acceptSchedule(context, model)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDaysRow(BuildContext context, List<String> days) {
    final Map<String, String> dayAbbreviations = {
      'Monday': 'M',
      'Tuesday': 'T',
      'Wednesday': 'W',
      'Thursday': 'T',
      'Friday': 'F',
      'Saturday': 'S',
      'Sunday': 'S'
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: dayAbbreviations.keys.map((dayName) {
        final bool isSelected = days.contains(dayName);
        return Container(
          width: Responsive.width(7.5, context),
          height: Responsive.width(7.5, context),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.darkBackground
                : AppColors.containerBackground,
            shape: BoxShape.circle,
            border: isSelected ? null : Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              dayAbbreviations[dayName]!,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppColors.darkBackground.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyListView(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.headers(Get.context!)
                  .copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptSchedule(
      BuildContext context, ScheduleRideModel model) async {
    bool? confirm = await Get.dialog(AlertDialog(
      title: Text('Accept This Schedule?'.tr),
      content: Text(
          'You are committing to all rides for this week (${model.weeklyRate}). Are you sure?'
              .tr),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false), child: Text('No'.tr)),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: Text('Yes, Accept'.tr,
              style: const TextStyle(color: AppColors.primary)),
        ),
      ],
    ));

    if (confirm != true) return;

    ShowToastDialog.showLoader("Accepting...");

    final scheduleRef = FirebaseFirestore.instance
        .collection(CollectionName.scheduledRides)
        .doc(model.id);
    final driverId = FireStoreUtils.getCurrentUid() ?? '';

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(scheduleRef);
        if (!snapshot.exists) {
          throw Exception("Schedule does not exist.");
        }
        final scheduleData = snapshot.data() as Map<String, dynamic>;
        if (scheduleData['driverId'] != null) {
          throw Exception("This schedule has already been taken.");
        }
        final String firstRideOtp = (1000 + Random().nextInt(9000)).toString();
        transaction.update(scheduleRef, {
          'driverId': driverId,
          'status': Constant.rideActive,
          'currentWeekOtp': firstRideOtp,
        });
      });
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(
          "Schedule accepted! It's now in 'My Schedules'.");
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to accept schedule: ${e.toString()}");
    }
  }

  // --- RESPONSIVE BOTTOM NAVIGATION BAR WIDGETS ---

  Widget _buildResponsiveBottomNav(
      BuildContext context, ScheduledRidesController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return Container(
      margin: EdgeInsets.fromLTRB(
          isCompact ? 8 : 12, 0, isCompact ? 8 : 12, isCompact ? 8 : 12),
      padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 4 : 8, vertical: isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(isCompact ? 28 : 32),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
              spreadRadius: 0),
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
              spreadRadius: 0),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildResponsiveNavItem(
            context,
            controller,
            controller.selectedIndex.value == 0,
            Icons.explore_outlined,
            'New',
            0,
            isCompact,
          ),
          _buildResponsiveNavItem(
            context,
            controller,
            controller.selectedIndex.value == 1,
            Icons.calendar_month_rounded,
            'My Schedules',
            1,
            isCompact,
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveNavItem(
      BuildContext context,
      ScheduledRidesController controller,
      bool isSelected,
      IconData icon,
      String label,
      int index,
      bool isCompact,
      {int? badgeCount}) {
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
                ? LinearGradient(colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.85)
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : LinearGradient(colors: [
                    Colors.grey.withOpacity(0.03),
                    Colors.grey.withOpacity(0.01)
                  ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(isCompact ? 20 : 24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 0),
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        spreadRadius: 0),
                  ]
                : [],
          ),
          child: _buildNavContent(
              context, isSelected, icon, label, badgeCount, isCompact),
        ),
      ),
    );
  }

  Widget _buildNavContent(BuildContext context, bool isSelected, IconData icon,
      String label, int? badgeCount, bool isCompact) {
    Widget iconWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Icon(icon,
          size: isSelected ? (isCompact ? 20 : 22) : (isCompact ? 18 : 20),
          color: isSelected ? Colors.white : const Color(0xFF636E72)),
    );

    if (badgeCount != null && badgeCount > 0) {
      iconWidget = badges.Badge(
        badgeContent: Text(
          badgeCount.toString(),
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: isCompact ? 9 : 10,
              fontWeight: FontWeight.w600),
        ),
        badgeStyle: badges.BadgeStyle(
            badgeColor: const Color(0xFFE74C3C),
            elevation: 2,
            padding: EdgeInsets.all(isCompact ? 3 : 4)),
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
