import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/scheduled_ride_model.dart';
// NEW: Import the details screen
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
import 'package:intl/intl.dart';

class ScheduledRidesScreen extends StatelessWidget {
  const ScheduledRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // By removing the AppBar, we create a more seamless UI where the tabs
    // are integrated directly into the body.
    return DefaultTabController(
      length: 2, // New Schedules, My Schedules
      child: Scaffold(
        backgroundColor: AppColors.grey50.withOpacity(0.6),
        // The AppBar is removed to bring the tabs to the top of the screen content.
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          // We manually apply the SystemUiOverlayStyle that the AppBar previously handled.
          // This ensures the status bar icons are dark, fitting the light background.
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: SafeArea(
            bottom: false, // Only apply padding to the top, not the bottom.
            child: Column(
              children: [
                // This container provides the background for the TabBar.
                Container(
                  color: AppColors.background,
                  child: TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3.0,
                    labelStyle: AppTypography.boldLabel(context),
                    tabs: [
                      Tab(text: 'New Schedules'.tr),
                      Tab(text: 'My Schedules'.tr),
                    ],
                  ),
                ),
                // The TabBarView must be wrapped in an Expanded widget to fill the remaining
                // vertical space within the Column.
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildNewSchedulesView(context),
                      _buildMySchedulesView(context),
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
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            ScheduleRideModel scheduleModel = ScheduleRideModel.fromJson(
                snapshot.data!.docs[index].data() as Map<String, dynamic>);
            // MODIFIED: Wrap the card in an InkWell for navigation
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
          // MODIFIED: Also show 'accepted' status so driver sees it immediately after accepting
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
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            ScheduleRideModel scheduleModel = ScheduleRideModel.fromJson(
                snapshot.data!.docs[index].data() as Map<String, dynamic>);
            // MODIFIED: Wrap the card in an InkWell for navigation
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

  Widget _buildScheduleCard(BuildContext context, ScheduleRideModel model,
      {required bool isAcceptable}) {
    String formattedStartDate = model.startDate != null
        ? DateFormat('MMM d').format(model.startDate!.toDate())
        : '';
    String formattedEndDate = model.endDate != null
        ? DateFormat('MMM d, yyyy').format(model.endDate!.toDate())
        : '';
    String time = model.scheduledTime ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Weekly Payout".tr, style: AppTypography.caption(context)),
              const Spacer(),
              Text(
                model.weeklyRate ?? 'N/A',
                style: AppTypography.headers(context)
                    .copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          LocationView(
            sourceLocation: model.sourceLocationName.toString(),
            destinationLocation: model.destinationLocationName.toString(),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '$formattedStartDate - $formattedEndDate',
                style: AppTypography.label(context),
              ),
              const Spacer(),
              const Icon(Icons.access_time_filled_rounded,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                time,
                style: AppTypography.boldLabel(context),
              )
            ],
          ),
          const SizedBox(height: 12),
          _buildDaysRow(context, model.recursOnDays ?? []),
          if (isAcceptable) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ButtonThem.buildButton(context,
                  title: "Accept Schedule".tr,
                  bgColors: AppColors.primary,
                  onPress: () => _acceptSchedule(context, model)),
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
      'Sunday': 'S',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dayAbbreviations.keys.map((dayName) {
        final bool isSelected = days.contains(dayName);
        return Container(
          width: Responsive.width(8, context),
          height: Responsive.width(8, context),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.darkBackground
                : AppColors.containerBackground,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              dayAbbreviations[dayName]!,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppColors.darkBackground.withOpacity(0.5),
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

  // --- ACTION HANDLER ---
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

      // TODO: Send a notification to the customer
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to accept schedule: ${e.toString()}");
      print(e);
    }
  }
}