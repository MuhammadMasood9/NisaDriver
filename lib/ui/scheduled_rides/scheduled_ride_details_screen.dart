import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/scheduled_ride_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/order_screen/order_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ScheduledRideDetailsScreen extends StatefulWidget {
  final String scheduleId;

  const ScheduledRideDetailsScreen({Key? key, required this.scheduleId})
      : super(key: key);

  @override
  State<ScheduledRideDetailsScreen> createState() =>
      _ScheduledRideDetailsScreenState();
}

class _ScheduledRideDetailsScreenState
    extends State<ScheduledRideDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey75,
      appBar: AppBar(
        title:
            Text("Schedule Details".tr, style: AppTypography.headers(context)),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: AppColors.background,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(CollectionName.scheduledRides)
            .doc(widget.scheduleId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Something went wrong: ${snapshot.error}'.tr));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Constant.loader(context);
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Schedule not found'.tr));
          }

          ScheduleRideModel model = ScheduleRideModel.fromJson(
              snapshot.data!.data() as Map<String, dynamic>);

          return SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildScheduleSummaryCard(context, model),
                const SizedBox(height: 16),
                _buildCustomerInfoCard(context, model.userId!),
                const SizedBox(height: 16),
                _buildRideLogbookSection(context, model),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI WIDGETS ---

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(title, style: AppTypography.headers(Get.context!)),
    );
  }

  Widget _buildScheduleSummaryCard(
      BuildContext context, ScheduleRideModel model) {
    bool isScheduleActive = model.status == 'active';

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader("Schedule Summary".tr),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInfoRow(
                    context,
                    Icons.wallet_giftcard,
                    "Weekly Payout".tr,
                    Constant.amountShow(amount: model.weeklyRate ?? '0'),
                    valueColor: AppColors.primary,
                    isLarge: true),
                const SizedBox(height: 12),
                _buildInfoRow(context, Icons.access_time_filled,
                    "Daily Pickup".tr, model.scheduledTime ?? ''),
              ],
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Route".tr.toUpperCase(),
                    style: AppTypography.caption(context).copyWith(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LocationView(
                  destinationLocation: model.destinationLocationName ?? '',
                  sourceLocation: model.sourceLocationName ?? '',
                ),
                const SizedBox(height: 16),
                Text("Recurring Days".tr.toUpperCase(),
                    style: AppTypography.caption(context).copyWith(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDaysRow(context, model.recursOnDays ?? []),
              ],
            ),
          ),
          if (isScheduleActive && model.currentWeekOtp != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primary.withOpacity(0.04),
              child: Column(
                children: [
                  Center(
                      child: Text("FIRST RIDE OTP".tr,
                          style: AppTypography.caption(context)
                              .copyWith(letterSpacing: 1.2))),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        model.currentWeekOtp!,
                        style: AppTypography.headers(context).copyWith(
                            fontSize: 22,
                            color: AppColors.primary,
                            letterSpacing: 4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                      child: Text(
                          "Enter this OTP on the trip screen to start.".tr,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption(context)
                              .copyWith(fontSize: 11)))
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard(BuildContext context, String customerId) {
    return _buildCard(
      child: FutureBuilder<UserModel?>(
        future: FireStoreUtils.getCustomer(customerId),
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == null) {
            return const SizedBox.shrink();
          }
          UserModel customer = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader("Customer Details".tr),
              const Divider(height: 0),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: CachedNetworkImage(
                        imageUrl: customer.profilePic.toString(),
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Constant.loader(context),
                        errorWidget: (c, u, e) => Image.asset(
                            'assets/images/placeholder.png',
                            height: 50,
                            width: 50),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.fullName ?? '',
                              style: AppTypography.boldHeaders(context)),
                          const SizedBox(height: 2),
                          Text(customer.phoneNumber ?? '',
                              style: AppTypography.caption(context)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => Constant.makePhoneCall(
                          customer.phoneNumber.toString()),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                        child: const Icon(Icons.call,
                            color: AppColors.primary, size: 24),
                      ),
                    )
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRideLogbookSection(
      BuildContext context, ScheduleRideModel model) {
    final List<DateTime> scheduledDates = _getScheduledDatesForWeek(model);
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader("This Week's Ride Logbook".tr),
          const Divider(height: 0),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(CollectionName.orders)
                .where('scheduleId', isEqualTo: model.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final Map<String, OrderModel> spawnedOrders = {};
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  OrderModel order =
                      OrderModel.fromJson(doc.data() as Map<String, dynamic>);
                  if (order.createdDate != null) {
                    String dateKey = DateFormat('yyyy-MM-dd')
                        .format(order.createdDate!.toDate());
                    spawnedOrders[dateKey] = order;
                  }
                }
              }
              if (scheduledDates.isEmpty) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30.0),
                        child: Text("No rides scheduled for this week.".tr,
                            textAlign: TextAlign.center)));
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: scheduledDates.length,
                padding: EdgeInsets.zero,
                separatorBuilder: (context, index) =>
                    const Divider(height: 0, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final DateTime date = scheduledDates[index];
                  final String dateKey = DateFormat('yyyy-MM-dd').format(date);
                  final OrderModel? orderForThisDate = spawnedOrders[dateKey];
                  return _buildLogbookRideTile(context, date, orderForThisDate);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogbookRideTile(
      BuildContext context, DateTime rideDate, OrderModel? dailyOrder) {
    String dateDisplay = DateFormat('EEEE, MMM d').format(rideDate);
    String statusText;
    IconData statusIcon;
    Color iconColor;
    Widget? actionButton;

    if (dailyOrder != null) {
      statusText = dailyOrder.status.toString().tr;
      switch (dailyOrder.status) {
        case Constant.rideComplete:
          statusIcon = Icons.check_circle_rounded;
          iconColor = Colors.green.shade600;
          statusText = "Completed".tr;
          actionButton = ButtonThem.buildBorderButton(context,
              title: "Details",
              btnHeight: 32,
              onPress: () => Get.to(() => const OrderScreen()));
          break;
        case Constant.rideCanceled:
          statusIcon = Icons.cancel_rounded;
          iconColor = Colors.red.shade600;
          statusText = "Cancelled".tr;
          break;
        case Constant.rideActive:
          statusIcon = Icons.play_circle_fill_rounded;
          iconColor = Colors.blue.shade600;
          statusText = "Ready to Start".tr;
          actionButton = ButtonThem.buildButton(context,
              title: "Start Ride",
              btnHeight: 32,
              onPress: () => Get.to(() => const OrderScreen()));
          break;
        default:
          statusIcon = Icons.route_rounded;
          iconColor = Colors.orange.shade700;
          statusText = "In Progress".tr;
          actionButton = ButtonThem.buildButton(context,
              title: "View Ride",
              btnHeight: 32,
              bgColors: Colors.orange.shade700,
              onPress: () => Get.to(() => const OrderScreen()));
      }
    } else {
      statusIcon = Icons.event_available_rounded;
      iconColor = Colors.grey.shade500;
      statusText = "Upcoming".tr;
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(statusIcon, color: iconColor, size: 22),
      ),
      title: Text(dateDisplay, style: AppTypography.boldLabel(context)),
      subtitle:
          Text("Status: $statusText", style: AppTypography.caption(context)),
      trailing: actionButton != null
          ? SizedBox(width: 100, child: actionButton)
          : null,
    );
  }

  List<DateTime> _getScheduledDatesForWeek(ScheduleRideModel model) {
    if (model.recursOnDays == null ||
        model.recursOnDays!.isEmpty ||
        model.startDate == null) return [];

    final List<DateTime> dates = [];
    DateTime currentDate = model.startDate!.toDate();

    for (int i = 0; i < 7; i++) {
      final String dayName = DateFormat('EEEE').format(currentDate);
      if (model.recursOnDays!.contains(dayName)) {
        dates.add(currentDate);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    dates.sort((a, b) => a.compareTo(b));
    return dates;
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
          width: Responsive.width(8.5, context),
          height: Responsive.width(8.5, context),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.darkBackground
                : AppColors.containerBackground,
            shape: BoxShape.circle,
            border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade300),
          ),
          child: Center(
            child: Text(dayAbbreviations[dayName]!,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String title, String value,
      {Color? valueColor, bool isLarge = false}) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade500, size: 18),
        const SizedBox(width: 12),
        Text(title, style: AppTypography.label(context)),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: (isLarge
                    ? AppTypography.appTitle(context)
                    : AppTypography.boldLabel(context))
                .copyWith(color: valueColor ?? AppColors.darkBackground),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
