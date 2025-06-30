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
import 'package:driver/ui/order_screen/order_screen.dart'; // Import the main order screen
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ScheduledRideDetailsScreen extends StatefulWidget {
  final String scheduleId;

  const ScheduledRideDetailsScreen({Key? key, required this.scheduleId}) : super(key: key);

  @override
  State<ScheduledRideDetailsScreen> createState() => _ScheduledRideDetailsScreenState();
}

class _ScheduledRideDetailsScreenState extends State<ScheduledRideDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Schedule Details".tr,style: AppTypography.headers(context),),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: AppColors.background,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection(CollectionName.scheduledRides).doc(widget.scheduleId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong: ${snapshot.error}'.tr));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Constant.loader(context);
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Schedule not found'.tr));
          }

          ScheduleRideModel model = ScheduleRideModel.fromJson(snapshot.data!.data() as Map<String, dynamic>);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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

  Widget _buildScheduleSummaryCard(BuildContext context, ScheduleRideModel model) {
    bool isScheduleActive = model.status == 'active';

    return Card(
      elevation: 0.3,
      color: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Payout & Route".tr, style: AppTypography.headers(context)),
                Text(Constant.amountShow(amount: model.weeklyRate ?? '0'), style: AppTypography.headers(context).copyWith(color: AppColors.primary)),
              ],
            ),
            const Divider(height: 24, thickness: 0.5),
           
            LocationView(destinationLocation: model.destinationLocationName ?? '',sourceLocation: model.sourceLocationName ?? '',),
            const SizedBox(height: 12),
            _buildInfoRow(context, Icons.access_time_filled, "Daily Pickup".tr, model.scheduledTime ?? ''),
            const SizedBox(height: 16),
            _buildDaysRow(context, model.recursOnDays ?? []),
            if (isScheduleActive && model.currentWeekOtp != null) ...[
              const Divider(height: 24, thickness: 0.5),
              Center(child: Text("ENTER THIS OTP TO START".tr, style: AppTypography.caption(context).copyWith(letterSpacing: 1.2))),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    model.currentWeekOtp!,
                    style: AppTypography.headers(context).copyWith(fontSize: 22, color: AppColors.primary, letterSpacing: 4),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(child: Text("Enter this OTP on the trip screen for the first ride.".tr, textAlign: TextAlign.center, style: AppTypography.caption(context).copyWith(fontSize: 11)))
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard(BuildContext context, String customerId) {
    return FutureBuilder<UserModel?>(
      future: FireStoreUtils.getCustomer(customerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == null) {
          return const SizedBox.shrink();
        }
        UserModel customer = snapshot.data!;
        return Card(
          elevation: 0.3,
          color: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Padding(
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
                    errorWidget: (c, u, e) => Image.asset('assets/images/placeholder.png', height: 50, width: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.fullName ?? '', style: AppTypography.boldHeaders(context)),
                      const SizedBox(height: 2),
                      Text(customer.phoneNumber ?? '', style: AppTypography.caption(context)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => Constant.makePhoneCall(customer.phoneNumber.toString()),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.call, color: AppColors.primary, size: 24),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRideLogbookSection(BuildContext context, ScheduleRideModel model) {
    final List<DateTime> scheduledDates = _getScheduledDatesForWeek(model);
    return Card(
      elevation: 0.3,
      color:AppColors.background ,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("This Week's Ride Logbook".tr, style: AppTypography.headers(context)),
            const Divider(height: 24, thickness: 0.5),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection(CollectionName.orders).where('scheduleId', isEqualTo: model.id).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Constant.loader(context);
                final Map<String, OrderModel> spawnedOrders = {};
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    OrderModel order = OrderModel.fromJson(doc.data() as Map<String, dynamic>);
                    if (order.createdDate != null) {
                      String dateKey = DateFormat('yyyy-MM-dd').format(order.createdDate!.toDate());
                      spawnedOrders[dateKey] = order;
                    }
                  }
                }
                if (scheduledDates.isEmpty) return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Text("No rides scheduled for this week.".tr, textAlign: TextAlign.center)));
                
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: scheduledDates.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
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
      ),
    );
  }

  Widget _buildLogbookRideTile(BuildContext context, DateTime rideDate, OrderModel? dailyOrder) {
    String dateDisplay = DateFormat('EEEE, MMM d').format(rideDate);
    String statusText;
    IconData statusIcon;
    Color iconColor;
    Widget? actionButton;

    if (dailyOrder != null) {
        statusText = dailyOrder.status.toString().tr;
        switch (dailyOrder.status) {
          case Constant.rideComplete:
            statusIcon = Icons.check_circle;
            iconColor = Colors.green.shade600;
            statusText = "Completed".tr;
            actionButton = ButtonThem.buildButton(context, title: "Details", btnHeight: 35, onPress: () => Get.to(()=> const OrderScreen()));
            break;
          case Constant.rideCanceled:
            statusIcon = Icons.cancel;
            iconColor = Colors.red.shade600;
            statusText = "Cancelled by customer".tr;
            break;
          case Constant.rideActive:
            statusIcon = Icons.directions_car_filled_rounded;
            iconColor = Colors.blue.shade600;
            statusText = "Ready to Start".tr;
            actionButton = ButtonThem.buildButton(context, title: "Start Ride", btnHeight: 35, onPress: () => Get.to(()=> const OrderScreen()));
            break;
          default: // Ride is 'inProgress' or some other state
            statusIcon = Icons.route_rounded;
            iconColor = Colors.orange.shade700;
            statusText = "In Progress".tr;
            actionButton = ButtonThem.buildButton(context, title: "View Ride", btnHeight: 35, onPress: () => Get.to(()=> const OrderScreen()));
        }
    } else {
        // No order exists for this scheduled day yet.
        statusIcon = Icons.event_available_rounded;
        iconColor = Colors.grey.shade600;
        statusText = "Upcoming".tr;
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(statusIcon, color: iconColor, size: 28)],
      ),
      title: Text(dateDisplay, style: AppTypography.boldLabel(context)),
      subtitle: Text("Status: $statusText", style: AppTypography.caption(context)),
      trailing: actionButton != null ? SizedBox(width: 100, child: actionButton) : null,
    );
  }
  
  List<DateTime> _getScheduledDatesForWeek(ScheduleRideModel model) {
    if (model.recursOnDays == null || model.recursOnDays!.isEmpty || model.startDate == null) return [];
    
    final List<DateTime> dates = [];
    DateTime currentDate = model.startDate!.toDate();
    
    for (int i = 0; i < 7; i++) {
       final String dayName = DateFormat('EEEE').format(currentDate);
       if (model.recursOnDays!.contains(dayName)) {
          dates.add(currentDate);
       }
       currentDate = currentDate.add(const Duration(days: 1));
    }
    dates.sort((a,b) => a.compareTo(b));
    return dates;
  }

  // --- HELPER WIDGETS ---
  Widget _buildDaysRow(BuildContext context, List<String> days) {
    final Map<String, String> dayAbbreviations = {'Monday': 'M', 'Tuesday': 'T', 'Wednesday': 'W', 'Thursday': 'T', 'Friday': 'F', 'Saturday': 'S', 'Sunday': 'S'};
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dayAbbreviations.keys.map((dayName) {
        final bool isSelected = days.contains(dayName);
        return Container(
          width: Responsive.width(8, context),
          height: Responsive.width(8, context),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.darkBackground : AppColors.containerBackground,
            shape: BoxShape.circle,
            border: Border.all(color: isSelected ? AppColors.darkBackground : Colors.grey.shade300),
          ),
          child: Center(
            child: Text(dayAbbreviations[dayName]!, style: TextStyle(color: isSelected ? Colors.white : AppColors.darkBackground.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildInfoRow(BuildContext context, IconData icon, String title, String value, {int flex = 1}) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 16),
        Text(title, style: AppTypography.label(context)),
        const Spacer(),
        Expanded(
          flex: flex,
          child: Text(
            value,
            style: AppTypography.boldLabel(context),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}