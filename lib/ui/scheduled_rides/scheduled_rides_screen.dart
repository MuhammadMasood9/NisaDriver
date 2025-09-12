import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/scheduled_ride_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/scheduled_rides/scheduled_ride_details_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Controller for managing the selected tab state and driver data
class ScheduledRidesController extends GetxController {
  var selectedIndex = 0.obs;
  var isLoading = true.obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;

  @override
  void onInit() {
    super.onInit();
    fetchDriverData();
  }

  Future<void> fetchDriverData() async {
    isLoading.value = true;
    update();
    final driver = await FireStoreUtils.getDriverProfile(FireStoreUtils.getCurrentUid() ?? '');
    if (driver != null) {
      driverModel.value = driver;
    }
    isLoading.value = false;
    update();
  }

  void onItemTapped(int index) {
    selectedIndex.value = index;
    update();
  }
}

class ScheduledRidesScreen extends StatelessWidget {
  const ScheduledRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ScheduledRidesController>(
      init: ScheduledRidesController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.grey75,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.white,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: SafeArea(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return Constant.loader(context);
                }

                // ====== ⭐️ DOCUMENT VERIFICATION CHECK (FULL SCREEN) ⭐️ ======
                if (controller.driverModel.value.documentVerification == false) {
                  return _buildEmptyListView(
                    "Documents Not Verified".tr,
                    "Please complete document verification to accept scheduled rides".tr,
                    icon: Icons.description_outlined,
                  );
                }

                final walletAmount = double.tryParse(controller.driverModel.value.walletAmount.toString()) ?? 0.0;
                final minimumAmount = double.tryParse(Constant.minimumDepositToRideAccept ?? '0.0') ?? 0.0;
                final bool isWalletLow = walletAmount < minimumAmount;

                final List<Widget> widgetOptions = [
                  _buildNewSchedulesView(context, controller),
                  _buildMySchedulesView(context, controller),
                ];

                return Column(
                  children: [
                    // ====== ⭐️ LOW WALLET WARNING BANNER ⭐️ ======
                    if (isWalletLow)
                      _buildWarningBanner(
                        context,
                        title: "Low Wallet Balance".tr,
                        subtitle: "You need at least ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept)} to accept new schedules."
                            .tr,
                        icon: Icons.account_balance_wallet_outlined,
                      ),

                    // Expanded to take remaining space
                    Expanded(
                      child: Stack(
                        children: [
                          IndexedStack(
                            index: controller.selectedIndex.value,
                            children: widgetOptions,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _buildResponsiveBottomNav(context, controller),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  // --- VIEW 1: NEW SCHEDULES AVAILABLE TO ACCEPT ---
  Widget _buildNewSchedulesView(BuildContext context, ScheduledRidesController controller) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(CollectionName.scheduledRides).where("status", isEqualTo: Constant.ridePlaced).orderBy("createdAt", descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyListView('Something went wrong'.tr, 'Please try again later.'.tr, icon: Icons.error_outline);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Constant.loader(context);
        }
        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyListView("No new weekly schedules available.".tr, 'Check back later for new schedules.'.tr, icon: Icons.explore_off_rounded);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 110),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            ScheduleRideModel scheduleModel = ScheduleRideModel.fromJson(snapshot.data!.docs[index].data() as Map<String, dynamic>);
            return InkWell(
              onTap: () => Get.to(() => ScheduledRideDetailsScreen(scheduleId: scheduleModel.id!)),
              child: _buildScheduleCard(context, scheduleModel, isAcceptable: true, controller: controller),
            );
          },
        );
      },
    );
  }

  // --- VIEW 2: SCHEDULES ALREADY ACCEPTED BY THE DRIVER ---
  Widget _buildMySchedulesView(BuildContext context, ScheduledRidesController controller) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(CollectionName.scheduledRides)
          .where("status", whereIn: [Constant.rideActive])
          .where("driverId", isEqualTo: FireStoreUtils.getCurrentUid())
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmptyListView('Something went wrong'.tr, 'Please try again later.'.tr, icon: Icons.error_outline);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Constant.loader(context);
        }
        if (snapshot.data!.docs.isEmpty) {
          return _buildEmptyListView("You have not accepted any schedules.".tr, 'Accept schedules to see them here.'.tr, icon: Icons.calendar_today_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 110),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            ScheduleRideModel scheduleModel = ScheduleRideModel.fromJson(snapshot.data!.docs[index].data() as Map<String, dynamic>);
            return InkWell(
              onTap: () => Get.to(() => ScheduledRideDetailsScreen(scheduleId: scheduleModel.id!)),
              child: _buildScheduleCard(context, scheduleModel, isAcceptable: false, controller: controller),
            );
          },
        );
      },
    );
  }

  // --- UI WIDGETS AND HELPERS ---

  Widget _buildWarningBanner(BuildContext context, {required String title, required String subtitle, required IconData icon}) {
    return Container(
      width: double.infinity,
      color: AppColors.darkModePrimary.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.darkModePrimary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.boldLabel(context).copyWith(color: AppColors.darkModePrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.caption(context).copyWith(color: AppColors.darkModePrimary, height: 1.3)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required IconData icon, required String title, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.8)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.caption(context).copyWith(color: Colors.grey.shade600)),
              const SizedBox(height: 1),
              Text(value, style: AppTypography.boldLabel(context).copyWith(color: AppColors.darkBackground, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(BuildContext context, ScheduleRideModel model, {required bool isAcceptable, required ScheduledRidesController controller}) {
    String formattedStartDate = model.startDate != null ? DateFormat('MMM d').format(model.startDate!.toDate()) : 'N/A';
    String formattedEndDate = model.endDate != null ? DateFormat('MMM d, yyyy').format(model.endDate!.toDate()) : 'N/A';
    String time = model.scheduledTime ?? 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 0.8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Weekly Payout".tr, style: AppTypography.boldLabel(context).copyWith(color: AppColors.primary)),
                Text(
                  Constant.amountShow(amount: model.weeklyRate.toString()),
                  style: AppTypography.headers(context).copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Route".tr.toUpperCase(),
                    style: AppTypography.caption(context).copyWith(color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                LocationView(
                  sourceLocation: model.sourceLocationName.toString(),
                  destinationLocation: model.destinationLocationName.toString(),
                ),
                const SizedBox(height: 16),
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
                    const SizedBox(width: 12),
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
                Text("Recurring Days".tr.toUpperCase(),
                    style: AppTypography.caption(context).copyWith(color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                _buildDaysRow(context, model.recursOnDays ?? []),
              ],
            ),
          ),
          if (isAcceptable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ButtonThem.buildButton(context,
                  title: "Accept Schedule".tr, btnHeight: 45, bgColors: AppColors.primary, onPress: () => _acceptSchedule(context, model, controller)),
            ),
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
          width: Responsive.width(8, context),
          height: Responsive.width(8, context),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.darkBackground : AppColors.containerBackground,
            shape: BoxShape.circle,
            border: isSelected ? null : Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              dayAbbreviations[dayName]!,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyListView(String message, String subtitle, {required IconData icon}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 70, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.headers(Get.context!).copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.label(Get.context!).copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ====== ⭐️ WALLET CHECK ADDED HERE ⭐️ ======
  Future<void> _acceptSchedule(BuildContext context, ScheduleRideModel model, ScheduledRidesController controller) async {
    // 1. Perform wallet check before showing the dialog
    final walletAmount = double.tryParse(controller.driverModel.value.walletAmount.toString()) ?? 0.0;
    final minimumAmount = double.tryParse(Constant.minimumDepositToRideAccept ?? '0.0') ?? 0.0;

    if (walletAmount < minimumAmount) {
      ShowToastDialog.showToast("You need at least ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept)} in your wallet to accept.".tr);
      return;
    }

    // 2. Show confirmation dialog
    bool? confirm = await Get.dialog(AlertDialog(
      title: Text('Accept This Schedule?'.tr),
      content: Text('You are committing to all rides for this week. This cannot be undone. Are you sure?'.tr),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('No'.tr)),
        TextButton(
          onPressed: () => Get.back(result: true),
          child: Text('Yes, Accept'.tr, style: const TextStyle(color: AppColors.primary)),
        ),
      ],
    ));

    if (confirm != true) return;

    // 3. Proceed with accepting the schedule
    ShowToastDialog.showLoader("Accepting...");

    final scheduleRef = FirebaseFirestore.instance.collection(CollectionName.scheduledRides).doc(model.id);
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
      ShowToastDialog.showToast("Schedule accepted! It's now in 'My Schedules'.");
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to accept schedule: ${e.toString()}");
    }
  }

  // --- RESPONSIVE BOTTOM NAVIGATION BAR WIDGETS ---

  Widget _buildResponsiveBottomNav(BuildContext context, ScheduledRidesController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return Container(
      margin: EdgeInsets.fromLTRB(isCompact ? 16 : 24, 0, isCompact ? 16 : 24, isCompact ? 12 : 16),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 8, vertical: isCompact ? 6 : 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(isCompact ? 28 : 32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 5)),
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
            'New Schedules',
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
      BuildContext context, ScheduledRidesController controller, bool isSelected, IconData icon, String label, int index, bool isCompact) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? (isCompact ? 12 : 16) : 8,
            vertical: isCompact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(isCompact ? 22 : 26),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: isCompact ? 18 : 20, color: isSelected ? Colors.white : const Color(0xFF636E72)),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    label.tr,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: isCompact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}