import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/profile_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.find<ProfileController>();

    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Ride Analytics'.tr,
          style: AppTypography.appTitle(context).copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.darkBackground,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.primary,
            size: 20,
          ),
          onPressed: () => Get.back(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEarningsOverview(context, controller),
              const SizedBox(height: 20),
              _buildTimeFilterChips(context, controller),
              const SizedBox(height: 20),
              _buildFilteredStats(context, controller),
              const SizedBox(height: 20),
              _buildQuickStatsCards(context, controller),
              const SizedBox(height: 20),
              _buildEarningsChart(context, controller),
              const SizedBox(height: 20),
              _buildPerformanceMetrics(context, controller),
              const SizedBox(height: 20),
              _buildRideDistributionChart(context, controller),
              const SizedBox(height: 20),
              _buildPaymentMethodChart(context, controller),
              const SizedBox(height: 20),
              _buildTimeDistributionChart(context, controller),
              const SizedBox(height: 20),
              _buildPeakHoursAnalysis(context, controller),
              const SizedBox(height: 20),
              _buildWeeklyRidesChart(context, controller),
              const SizedBox(height: 20),
              _buildMonthlyComparison(context, controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsOverview(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.9),
            AppColors.darkBackground
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Lifetime Earnings".tr,
                    style: AppTypography.h3(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    return Text(
                      NumberFormat.currency(locale: 'en_US', symbol: '\$')
                          .format(controller.lifetimeEarnings.value),
                      style: AppTypography.h1(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    );
                  }),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Obx(() {
            final double lastMonth = controller.lastMonthEarnings.value;
            final double thisMonth = controller.thisMonthEarnings.value;
            final double change = lastMonth > 0
                ? ((thisMonth - lastMonth) / lastMonth) * 100
                : thisMonth > 0
                    ? 100
                    : 0;
            final bool isPositive = change >= 0;

            final double lastWeek = controller.lastWeekEarnings.value;
            final double thisWeek = controller.thisWeekEarnings.value;
            final double weekChange = lastWeek > 0
                ? ((thisWeek - lastWeek) / lastWeek) * 100
                : thisWeek > 0
                    ? 100
                    : 0;
            final bool isWeekPositive = weekChange >= 0;

            return Row(
              children: [
                Expanded(
                  child: _buildEarningsMetric(
                    context,
                    "This Week".tr,
                    NumberFormat.currency(locale: 'en_US', symbol: '\$')
                        .format(controller.thisWeekEarnings.value),
                    "${weekChange.toStringAsFixed(1)}%",
                    isWeekPositive,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEarningsMetric(
                    context,
                    "This Month".tr,
                    NumberFormat.currency(locale: 'en_US', symbol: '\$')
                        .format(thisMonth),
                    "${change.toStringAsFixed(1)}%",
                    isPositive,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEarningsMetric(
    BuildContext context,
    String title,
    String value,
    String change,
    bool isPositive,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption(context).copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.h3(context).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: isPositive ? Colors.greenAccent : Colors.redAccent,
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: AppTypography.caption(context).copyWith(
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterChips(
      BuildContext context, ProfileController controller) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: controller.timeFilters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = controller.timeFilters[index];
          return Obx(() {
            bool isSelected = controller.selectedFilter.value == filter;
            return ChoiceChip(
              label: Text(
                filter,
                style: AppTypography.label(context).copyWith(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) controller.changeFilter(filter);
              },
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.grey.shade200,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            );
          });
        },
      ),
    );
  }

  Widget _buildFilteredStats(
      BuildContext context, ProfileController controller) {
    return Obx(() => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${controller.selectedFilter.value} Stats".tr,
                style: AppTypography.h3(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBackground,
                ),
              ),
              const SizedBox(height: 16),
              _buildStatRow(
                context,
                "Total Earnings:".tr,
                NumberFormat.currency(locale: 'en_US', symbol: '\$')
                    .format(controller.totalEarnings.value),
              ),
              const Divider(height: 20, color: AppColors.grey100),
              _buildStatRow(
                context,
                "Completed Rides:".tr,
                controller.completedRides.value.toString(),
              ),
              const Divider(height: 20, color: AppColors.grey100),
              _buildStatRow(
                context,
                "Total Distance:".tr,
                "${controller.totalDistance.value.toStringAsFixed(1)} km",
              ),
              const Divider(height: 20, color: AppColors.grey100),
              _buildStatRow(
                context,
                "Total Tips:".tr,
                NumberFormat.currency(locale: 'en_US', symbol: '\$')
                    .format(controller.totalTips.value),
              ),
              const Divider(height: 20, color: AppColors.grey100),
              _buildStatRow(
                context,
                "Ride Offers:".tr,
                controller.totalRideOffers.value.toString(),
              ),
            ],
          ),
        ));
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium(context).copyWith(
            color: AppColors.grey600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium(context).copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.darkBackground,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsCards(
      BuildContext context, ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "All-Time Stats".tr,
          style: AppTypography.h3(context).copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.darkBackground,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Obx(() => _buildQuickStatCard(
                    context,
                    Icons.directions_car_rounded,
                    AppColors.primary,
                    "Today's Rides".tr,
                    controller.todaysRides.value.toString(),
                    "rides",
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() => _buildQuickStatCard(
                    context,
                    Icons.monetization_on_rounded,
                    AppColors.darkBackground,
                    "Avg. Earnings/Ride".tr,
                    NumberFormat.currency(locale: 'en_US', symbol: '\$')
                        .format(controller.averageEarningsPerRide.value),
                    "",
                  )),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Obx(() => _buildQuickStatCard(
                    context,
                    Icons.speed_rounded,
                    AppColors.danger200,
                    "Avg. Ride Distance".tr,
                    controller.averageRideDistance.value.toStringAsFixed(1),
                    "km",
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() => _buildQuickStatCard(
                    context,
                    Icons.star_rounded,
                    Colors.amber,
                    "Avg Rating".tr,
                    controller.averageRating.value.toStringAsFixed(1),
                    "stars",
                  )),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Obx(() => _buildQuickStatCard(
                    context,
                    Icons.five_g_rounded,
                    Colors.green,
                    "5-Star Rides".tr,
                    controller.totalFiveStarRides.value.toString(),
                    "rides",
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Obx(() => _buildQuickStatCard(
                    context,
                    Icons.trending_up_rounded,
                    AppColors.primary,
                    "Projected Monthly".tr,
                    NumberFormat.currency(locale: 'en_US', symbol: '\$')
                        .format(controller.projectedMonthlyEarnings.value),
                    "",
                  )),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String value,
    String unit,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTypography.h3(context).copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkBackground,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: AppTypography.caption(context).copyWith(
                  color: AppColors.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: AppTypography.caption(context).copyWith(
              color: AppColors.grey600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsChart(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${controller.selectedFilter.value} Earnings".tr,
                style: AppTypography.h3(context).copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBackground,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('MMM d').format(DateTime.now()),
                  style: AppTypography.caption(context).copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Obx(() {
              List<FlSpot> spots;
              double maxY;
              List<String> bottomTitles;

              switch (controller.selectedFilter.value) {
                case 'Today':
                case 'Weekly':
                  spots = controller.weeklyEarningsSpots.toList();
                  maxY = controller.maxWeeklyEarning.value;
                  bottomTitles = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun'
                  ];
                  break;
                case 'Monthly':
                  spots = controller.dailyEarningsSpots.toList();
                  maxY = controller.maxDailyEarning.value;
                  bottomTitles =
                      List.generate(7, (index) => '${index * 5 + 1}');
                  break;
                case 'Yearly':
                  spots = controller.monthlyEarningsSpots.toList();
                  maxY = controller.maxMonthlyEarning.value;
                  bottomTitles = [
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec'
                  ];
                  break;
                default:
                  spots = controller.weeklyEarningsSpots.toList();
                  maxY = controller.maxWeeklyEarning.value;
                  bottomTitles = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun'
                  ];
              }

              if (spots.isEmpty) {
                return Center(
                  child: Text(
                    "No data for ${controller.selectedFilter.value.toLowerCase()}"
                        .tr,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: AppColors.grey600,
                    ),
                  ),
                );
              }

              return LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY == 0 ? 1 : maxY / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade100,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: controller.selectedFilter.value == 'Monthly'
                            ? 5
                            : 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          const style = TextStyle(
                            color: AppColors.grey600,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          );
                          int index = value.toInt();
                          if (index >= 0 && index < bottomTitles.length) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 8.0,
                              child: Text(bottomTitles[index], style: style),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: maxY == 0 ? 1 : maxY / 4,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value == 0 || value == maxY) {
                            return const Text('');
                          }
                          return Text(
                            '\$${value.toInt()}',
                            style: const TextStyle(
                              color: AppColors.grey600,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        },
                        reservedSize: 42,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: controller.selectedFilter.value == 'Yearly'
                      ? 11
                      : controller.selectedFilter.value == 'Monthly'
                          ? 30
                          : 6,
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.9),
                          AppColors.primary,
                        ],
                      ),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.3),
                            AppColors.primary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Performance Metrics".tr,
            style: AppTypography.h3(context).copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkBackground,
            ),
          ),
          const SizedBox(height: 20),
          Obx(() => _buildMetricRow(
                context,
                "Acceptance Rate".tr,
                "${controller.acceptanceRate.value.toStringAsFixed(0)}%",
                controller.acceptanceRate.value / 100,
                AppColors.primary,
              )),
          const SizedBox(height: 16),
          Obx(() => _buildMetricRow(
                context,
                "Cancellation Rate".tr,
                "${controller.cancellationRate.value.toStringAsFixed(0)}%",
                controller.cancellationRate.value / 100,
                AppColors.danger200,
              )),
          const SizedBox(height: 16),
          Obx(() => _buildMetricRow(
                context,
                "Completion Rate".tr,
                "${controller.completionRate.value.toStringAsFixed(0)}%",
                controller.completionRate.value / 100,
                Colors.green,
              )),
          const SizedBox(height: 16),
          Obx(() => _buildMetricRow(
                context,
                "Customer Rating".tr,
                "${controller.averageRating.value.toStringAsFixed(1)}/5",
                controller.averageRating.value / 5,
                Colors.amber,
              )),
        ],
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context, String label, String value,
      double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.bodyMedium(context).copyWith(
                color: AppColors.grey600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: AppTypography.bodyMedium(context).copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.darkBackground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildRideDistributionChart(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Ride Distribution".tr,
            style: AppTypography.h3(context).copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkBackground,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Obx(() => controller.rideDistributionData.isEmpty
                ? Center(
                    child: Text(
                      "No ride data available".tr,
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sections: controller.rideDistributionData.toList(),
                      centerSpaceRadius: 50,
                      sectionsSpace: 3,
                    ),
                  )),
          ),
          const SizedBox(height: 20),
          Obx(() => _buildLegend(context, controller.rideDistributionData)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChart(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment Methods".tr,
            style: AppTypography.h3(context).copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkBackground,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Obx(() => controller.paymentMethodData.isEmpty
                ? Center(
                    child: Text(
                      "No payment data available".tr,
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sections: controller.paymentMethodData.toList(),
                      centerSpaceRadius: 50,
                      sectionsSpace: 3,
                    ),
                  )),
          ),
          const SizedBox(height: 20),
          Obx(() => _buildLegend(context, controller.paymentMethodData)),
        ],
      ),
    );
  }

  Widget _buildTimeDistributionChart(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Time Distribution".tr,
            style: AppTypography.h3(context).copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkBackground,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Obx(() => controller.timeDistributionData.isEmpty
                ? Center(
                    child: Text(
                      "No time data available".tr,
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: AppColors.grey600,
                      ),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sections: controller.timeDistributionData.toList(),
                      centerSpaceRadius: 50,
                      sectionsSpace: 3,
                    ),
                  )),
          ),
          const SizedBox(height: 20),
          Obx(() => _buildLegend(context, controller.timeDistributionData)),
        ],
      ),
    );
  }

  Widget _buildPeakHoursAnalysis(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Peak Hours".tr,
            style: AppTypography.h3(context).copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkBackground,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Obx(() {
              final double maxY = controller.peakHoursData
                  .map((group) => group.barRods.first.toY)
                  .fold(0.0, (max, current) => current > max ? current : max);
              return controller.peakHoursData.isEmpty
                  ? Center(
                      child: Text(
                        "No ride data available".tr,
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY == 0 ? 10 : maxY * 1.2,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: maxY == 0 ? 1 : maxY / 4,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value == 0 || value == maxY) {
                                  return const Text('');
                                }
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: AppColors.grey600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 42,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final titles = [
                                  '6-9a',
                                  '9-12p',
                                  '12-3p',
                                  '3-6p',
                                  '6-9p',
                                  '9-12a'
                                ];
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 4,
                                  child: Text(
                                    titles[value.toInt()],
                                    style: const TextStyle(
                                      color: AppColors.grey600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                              reservedSize: 20,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY == 0 ? 1 : maxY / 4,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade100,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        barGroups: controller.peakHoursData
                            .asMap()
                            .entries
                            .map((entry) => BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.barRods.first.toY,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withValues(alpha: 0.8),
                                          AppColors.primary,
                                        ],
                                      ),
                                      width: 12,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ))
                            .toList(),
                      ),
                    );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyRidesChart(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Weekly Rides".tr,
            style: AppTypography.h3(context).copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkBackground,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Obx(() {
              // Calculate the maximum value from the data
              final double maxY = controller.weeklyRidesData
                  .map((group) => group.barRods.first.toY)
                  .fold(0.0, (max, current) => current > max ? current : max);

              // --- FIX STARTS HERE ---
              // 1. Calculate a safe interval for the Y-axis.
              //    - Use max(1, ...) to ensure the interval is at least 1 for small ride counts.
              //    - If maxY is 0, default to a safe value like 1.
              final double yInterval =
                  maxY > 0 ? max(1, (maxY / 4).roundToDouble()) : 1;

              // 2. Set a default top boundary for the chart if there's no data.
              final double chartMaxY = maxY == 0 ? 5 : maxY * 1.2;
              // --- FIX ENDS HERE ---

              return controller.weeklyRidesData.isEmpty
                  ? Center(
                      child: Text(
                        "No ride data available".tr,
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        // Use the safe max Y value
                        maxY: chartMaxY,
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              // Use the safe, non-zero interval
                              interval: yInterval,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                // Don't show a label for the max value to avoid overlap
                                if (value == meta.max) return const Text('');
                                // Only show integer values for ride counts
                                if (value.toInt().toDouble() != value) {
                                  return const Text('');
                                }

                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: AppColors.grey600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 28, // Adjusted for better spacing
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                const titles = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun'
                                ];
                                if (value.toInt() >= 0 &&
                                    value.toInt() < titles.length) {
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 4,
                                    child: Text(
                                      titles[value.toInt()],
                                      style: const TextStyle(
                                        color: AppColors.grey600,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 20,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          // Use the safe, non-zero interval for grid lines
                          horizontalInterval: yInterval,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade100,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        barGroups: controller.weeklyRidesData.toList(),
                      ),
                    );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyComparison(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Monthly Comparison".tr,
            style: AppTypography.h3(context).copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.darkBackground,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Obx(() {
              final double maxY = controller.monthlyComparisonData
                  .map((group) => group.barRods.first.toY)
                  .fold(0.0, (max, current) => current > max ? current : max);
              return controller.monthlyComparisonData.isEmpty
                  ? Center(
                      child: Text(
                        "No comparison data available".tr,
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: AppColors.grey600,
                        ),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY == 0 ? 100 : maxY * 1.2,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: maxY == 0 ? 1 : maxY / 4,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value == 0 || value == maxY) {
                                  return const Text('');
                                }
                                return Text(
                                  '\$${value.toInt()}',
                                  style: const TextStyle(
                                    color: AppColors.grey600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 42,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                final titles = ['Last Month', 'This Month'];
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 4,
                                  child: Text(
                                    titles[value.toInt()],
                                    style: const TextStyle(
                                      color: AppColors.grey600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                              reservedSize: 20,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY == 0 ? 1 : maxY / 4,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade100,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        barGroups: controller.monthlyComparisonData
                            .asMap()
                            .entries
                            .map((entry) => BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.barRods.first.toY,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withValues(alpha: 0.8),
                                          AppColors.primary,
                                        ],
                                      ),
                                      width: 20,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ))
                            .toList(),
                      ),
                    );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(
      BuildContext context, RxList<PieChartSectionData> legendData) {
    if (legendData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16.0,
      runSpacing: 8.0,
      children: legendData.map((item) {
        final legendLabel = item.title.split('\n').first;
        return _buildLegendItem(context, item.color, legendLabel);
      }).toList(),
    );
  }

  Widget _buildLegendItem(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.caption(context).copyWith(
            color: AppColors.grey600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
