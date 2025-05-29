import 'package:driver/constant/constant.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controller/subscription_history_controller.dart'; // Corrected typo in import

class SubscriptionHistory extends StatelessWidget {
  const SubscriptionHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<SubscriptionHistoryController>(
      init: SubscriptionHistoryController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // Modern SliverAppBar with gradient
              // Content area
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                   
                  ),
                  child: controller.isLoading.value
                      ? Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                            ),
                          ),
                        )
                      : controller.subscriptionHistoryList.isEmpty
                          ? _buildEmptyState(context, themeChange)
                          : _buildSubscriptionList(
                              context, controller, themeChange),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, DarkThemeProvider themeChange) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: themeChange.getThem()
                    ? AppColors.grey800
                    : AppColors.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_outlined,
                size: 60,
                color: themeChange.getThem()
                    ? AppColors.grey400
                    : AppColors.grey600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Subscription History",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: themeChange.getThem()
                    ? AppColors.grey200
                    : AppColors.grey800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You haven't purchased any subscription plans yet.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: themeChange.getThem()
                    ? AppColors.grey400
                    : AppColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionList(BuildContext context,
      SubscriptionHistoryController controller, DarkThemeProvider themeChange) {
    return RefreshIndicator(
      onRefresh: () async {
        // Add refresh functionality here if needed
      },
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(15),
        itemCount: controller.subscriptionHistoryList.length,
        itemBuilder: (context, index) {
          final subscriptionHistoryModel =
              controller.subscriptionHistoryList[index];
          final bool isActive = index == 0; // Assuming the first item is active

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: isActive
                  ? const LinearGradient(
                      colors: [AppColors.primary, AppColors.darkModePrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isActive ? null : AppColors.background,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? AppColors.primary.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header with plan info and status
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Plan image
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isActive
                              ? Colors.white.withOpacity(0.2)
                              : AppColors.grey100.withOpacity(0.1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: NetworkImageWidget(
                            imageUrl: subscriptionHistoryModel
                                    .subscriptionPlan?.image ??
                                '',
                            fit: BoxFit.cover,
                            width: 50,
                            height: 50,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Plan name and details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subscriptionHistoryModel.subscriptionPlan?.name ??
                                  '',
                              style: AppTypography.boldHeaders(context).copyWith(color: isActive
                                    ? Colors.white
                                    : AppColors.darkTextFieldBorder,),
                            ),
                            const SizedBox(height: 0),
                            Text(
                              Constant.amountShow(
                                  amount: subscriptionHistoryModel
                                          .subscriptionPlan?.price ??
                                      '0'),
                              style: AppTypography.headers(context).copyWith( color: isActive
                                    ? Colors.white.withOpacity(0.8)
                                    : AppColors.primary,),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.ratingColour,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 10,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Active',
                                style:AppTypography.smBoldLabel(context).copyWith( color: Colors.white,),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: isActive
                      ? Colors.white.withOpacity(0.2)
                      : AppColors.grey200,
                ),
                // Details section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'Validity',
                        subscriptionHistoryModel.subscriptionPlan?.expiryDay ==
                                '-1'
                            ? "Unlimited"
                            : '${subscriptionHistoryModel.subscriptionPlan?.expiryDay ?? '0'} Days',
                        Icons.schedule_outlined,
                        themeChange,
                        isActive: isActive,
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        'Payment Type',
                        (subscriptionHistoryModel.paymentType ?? ''),
                        Icons.payment_outlined,
                        themeChange,
                        isActive: isActive,
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        'Purchase Date',
                        Constant.timestampToDateTime(subscriptionHistoryModel
                            .subscriptionPlan!.createdAt!),
                        Icons.calendar_today_outlined,
                        themeChange,
                        isActive: isActive,
                      ),
                      const SizedBox(height: 10),
                      _buildDetailRow(
                        'Expiry Date',
                        subscriptionHistoryModel.expiryDate == null
                            ? "Unlimited"
                            : Constant.timestampToDateTime(
                                subscriptionHistoryModel.expiryDate!),
                        Icons.event_outlined,
                        themeChange,
                        isActive: isActive,
                        isExpiry: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(
      String label, String value, IconData icon, DarkThemeProvider themeChange,
      {bool isActive = false, bool isExpiry = false}) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color:
                themeChange.getThem() ? AppColors.grey800 : AppColors.grey100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 14,
            color: isActive
                ? AppColors.primary
                : (themeChange.getThem()
                    ? AppColors.grey400
                    : AppColors.grey600),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:AppTypography.label(Get.context!).copyWith( color: isActive
                      ? Colors.white.withOpacity(0.7)
                      : (themeChange.getThem()
                          ? AppColors.grey400
                          : AppColors.grey600)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.boldLabel(Get.context!).copyWith( color: isActive
                      ? Colors.white
                      : (isExpiry && value != "Unlimited"
                          ? _getExpiryColor(value)
                          : (themeChange.getThem()
                              ? AppColors.grey50
                              : AppColors.grey800)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getExpiryColor(String expiryDate) {
    // Placeholder logic for expiry color; customize as needed
    return Colors.orange;
  }
}

extension StringExtension on String {
  String capitalizeString() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
