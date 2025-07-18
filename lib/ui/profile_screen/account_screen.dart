import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/profile_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.put(ProfileController());

    return Scaffold(
      backgroundColor: AppColors.grey75,
      // MODIFICATION: Added a standard AppBar
      
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (controller.driverModel.value.id == null) {
          return Center(
            child: Text('Could not load profile.'.tr,
                style: AppTypography.bodyLarge(context)),
          );
        }

        return _buildProfileBody(context, controller);
      }),
    );
  }

  // MODIFICATION: Changed from CustomScrollView to SingleChildScrollView
  Widget _buildProfileBody(BuildContext context, ProfileController controller) {
    final driver = controller.driverModel.value;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NEW WIDGET: Re-created the profile header here
          _buildProfileHeader(context, driver),
          const SizedBox(height: 32),
           _buildProfileMenuCard(
            context,
            icon: Icons.person,
            iconColor: AppColors.darkInvite,
            title: "Edit Profile".tr,
            subtitle: "Manage your profile and details".tr,
            onTap: () => _showAnalyticsModal(context, controller),
          ),
           const SizedBox(height: 12),
          _buildProfileMenuCard(
            context,
            icon: Icons.bar_chart_rounded,
            iconColor: AppColors.primary,
            title: "Ride Analytics".tr,
            subtitle: "View your earnings and ride statistics".tr,
            onTap: () => _showAnalyticsModal(context, controller),
          ),
          
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context,
            icon: Icons.directions_car_filled_rounded,
            iconColor: AppColors.danger200,
            title: "Vehicle Information".tr,
            subtitle: "Manage your registered vehicle details".tr,
            onTap: () =>
                _showVehicleInfoModal(context, driver.vehicleInformation),
          ),
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.darkBackground,
            title: "Bank Details".tr,
            subtitle: "View your account details for payouts".tr,
            onTap: () => _showBankDetailsModal(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // NEW WIDGET: Contains the profile info previously in the SliverAppBar
  Widget _buildProfileHeader(BuildContext context, DriverUserModel driver) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: driver.profilePic ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (context, url, error) =>
                      Image.asset(Constant.userPlaceHolder, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            driver.fullName ?? 'N/A',
            style: AppTypography.h3(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            driver.email ?? 'No email provided'.tr,
            style: AppTypography.bodyMedium(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  // REMOVED: _buildSliverAppBar method is no longer needed.

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: AppTypography.bodyMedium(context)
          .copyWith(fontWeight: FontWeight.bold, color: AppColors.darkBackground),
    );
  }

  Widget _buildProfileMenuCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style:
                            AppTypography.appTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.label(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: AppColors.tabBarSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailModal(BuildContext context,
      {required String title, required Widget child}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(title, style: AppTypography.h2(context)),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      physics: const BouncingScrollPhysics(),
                      child: child,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAnalyticsModal(BuildContext context, ProfileController controller) {
    _showDetailModal(
      context,
      title: 'Ride Analytics'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsHeader(context, controller),
          const SizedBox(height: 24),
          _buildTimeFilterChips(controller),
          const SizedBox(height: 24),
          _buildBarChart(context, controller),
          const SizedBox(height: 16),
          Text("Key Metrics".tr, style: AppTypography.appTitle(context)),
          const SizedBox(height: 16),
          _buildStatsGrid(context, controller),
        ],
      ),
    );
  }

  void _showVehicleInfoModal(
      BuildContext context, VehicleInformation? vehicleInfo) {
    if (vehicleInfo == null) {
      _showDetailModal(
          context,
          title: "Vehicle Information".tr,
          child: Center(
              child: Text("No vehicle information available.".tr,
                  style: AppTypography.bodyMedium(context))));
      return;
    }

    _showDetailModal(
      context,
      title: "Vehicle Information".tr,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildInfoRow(context, Icons.drive_eta_rounded, 'Vehicle Type'.tr,
                vehicleInfo.vehicleType?.first.name ?? 'N/A'),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow(context, Icons.pin_outlined, 'Vehicle Number'.tr,
                vehicleInfo.vehicleNumber ?? 'N/A'),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow(context, Icons.color_lens_rounded, 'Color'.tr,
                vehicleInfo.vehicleColor ?? 'N/A'),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow(context, Icons.event_seat_rounded, 'Seats'.tr,
                vehicleInfo.seats ?? 'N/A'),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildInfoRow(
              context,
              Icons.date_range_rounded,
              'Registration Date'.tr,
              vehicleInfo.registrationDate != null
                  ? DateFormat('dd MMM, yyyy')
                      .format(vehicleInfo.registrationDate!.toDate())
                  : 'N/A',
            ),
          ],
        ),
      ),
    );
  }

  void _showBankDetailsModal(BuildContext context) {
    _showDetailModal(
      context,
      title: "Bank Details".tr,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildInfoRow(context, Icons.person_rounded,
                    'Account Holder Name'.tr, 'John Doe'),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildInfoRow(context, Icons.account_balance, 'Bank Name'.tr,
                    'Global Bank Ltd.'),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildInfoRow(context, Icons.fingerprint, 'Account Number'.tr,
                    '**** **** **** 1234'),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildInfoRow(context, Icons.code_rounded, 'SWIFT/IFSC Code'.tr,
                    'GLBLINBBXXX'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "To update your bank details, please contact support.".tr,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(context)
                  .copyWith(color: AppColors.primary),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAnalyticsHeader(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [AppColors.darkBackground, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total Earnings".tr,
                    style: AppTypography.bodyMedium(context)
                        .copyWith(color: Colors.white.withOpacity(0.8))),
                const SizedBox(height: 4),
                Obx(() => Text(
                      NumberFormat.currency(locale: 'en_US', symbol: '\$')
                          .format(controller.totalEarnings.value),
                      style: AppTypography.h2(context)
                          .copyWith(color: Colors.white),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterChips(ProfileController controller) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: controller.timeFilters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = controller.timeFilters[index];
          return Obx(() {
            bool isSelected = controller.selectedFilter.value == filter;
            return ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) controller.changeFilter(filter);
              },
              labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w600),
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary,
              shape: const StadiumBorder(),
              side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300),
            );
          });
        },
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, ProfileController controller) {
    return Obx(() {
      if (controller.selectedFilter.value != 'Weekly') {
        return const SizedBox.shrink();
      }

      if (controller.weeklyEarningsData.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    "No chart data available for this week".tr,
                    style: AppTypography.caption(context)
                        .copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Weekly Earnings".tr, style: AppTypography.appTitle(context)),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: controller.maxWeeklyEarning.value > 0
                    ? controller.maxWeeklyEarning.value * 1.1
                    : 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final currencyFormat =
                          NumberFormat.currency(locale: 'en_US', symbol: '\$');
                      return BarTooltipItem(
                        currencyFormat.format(rod.toY),
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final titles = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ];
                        final index = value.toInt();
                        if (index >= 0 && index < titles.length) {
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(
                              titles[index],
                              style: AppTypography.caption(context)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: controller.maxWeeklyEarning.value > 0
                          ? controller.maxWeeklyEarning.value / 4
                          : 25,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == meta.max)
                          return const SizedBox.shrink();
                        return Text(
                          '\$${value.toInt()}',
                          style:
                              AppTypography.caption(context).copyWith(fontSize: 10),
                          textAlign: TextAlign.left,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: controller.maxWeeklyEarning.value > 0
                      ? controller.maxWeeklyEarning.value / 4
                      : 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                barGroups:
                    controller.weeklyEarningsData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: data.barRods.first.toY,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6)),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.7),
                            AppColors.primary,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    });
  }

  Widget _buildStatsGrid(BuildContext context, ProfileController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

        return Obx(() => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatItem(
                  context,
                  width: itemWidth,
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.darkBackground,
                  title: "Rides Completed".tr,
                  value: controller.completedRides.value.toString(),
                ),
                _buildStatItem(
                  context,
                  width: itemWidth,
                  icon: Icons.cancel_outlined,
                  color: AppColors.danger200,
                  title: "Rides Canceled".tr,
                  value: controller.canceledRides.value.toString(),
                ),
                _buildStatItem(
                  context,
                  width: itemWidth,
                  icon: Icons.map_outlined,
                  color: AppColors.primary,
                  title: "Total Distance".tr,
                  value:
                      "${controller.totalDistance.value.toStringAsFixed(1)} km",
                ),
                _buildStatItem(
                  context,
                  width: itemWidth,
                  icon: Icons.timer_outlined,
                  color: AppColors.darkContainerBackground,
                  title: "Time Online".tr,
                  value: "${controller.timeOnline.value.toStringAsFixed(1)} hrs",
                ),
              ],
            ));
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required double width,
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      width: width,
      height: width * 0.8, // Using aspect ratio for consistent sizing
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(), // Pushes the text content to the bottom
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: AppTypography.h3(context).copyWith(
                  color: AppColors.darkBackground,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTypography.caption(context).copyWith(
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.caption(context).copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.bodyLarge(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkBackground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}