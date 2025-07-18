import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/controller/profile_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/bank_details/bank_details_screen.dart';
import 'package:driver/ui/profile_screen/analytics_screen.dart';
import 'package:driver/ui/profile_screen/profile_screen.dart';
import 'package:driver/ui/vehicle_information/vehicle_information_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use findOrPut to avoid re-creating the controller on rebuilds
    final ProfileController controller = Get.put(ProfileController());

    return Scaffold(
      backgroundColor: AppColors.grey75,
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

  Widget _buildProfileBody(BuildContext context, ProfileController controller) {
    final driver = controller.driverModel.value;
    // The DashBoardController is initialized but not used in this snippet.
    final DashBoardController controllerDashboard =
        Get.put(DashBoardController());
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(context, driver),
          const SizedBox(height: 32),
          _buildProfileMenuCard(
            context,
            icon: Icons.person,
            iconColor: AppColors.darkInvite,
            title: "Edit Profile".tr,
            subtitle: "Manage your profile and details".tr,
            onTap: () => Get.to(() => const ProfileScreen()),
          ),
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context,
            icon: Icons.analytics_outlined,
            iconColor: AppColors.primary,
            title: "Ride Analytics".tr,
            subtitle: "View your earnings and ride statistics".tr,
            onTap: () => Get.to(() => const AnalyticsScreen()),
          ),
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context,
            icon: Icons.directions_car_filled_rounded,
            iconColor: AppColors.danger200,
            title: "Vehicle Information".tr,
            subtitle: "Manage your registered vehicle details".tr,
            onTap: () => Get.to(() => const VehicleInformationScreen()),
          ),
          const SizedBox(height: 12),
          _buildProfileMenuCard(
            context,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.darkBackground,
            title: "Bank Details".tr,
            subtitle: "View your account details for payouts".tr,
            onTap: () => Get.to(() => const BankDetailsScreen()),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, DriverUserModel driver) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.darkBackground.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.darkBackground.withOpacity(0.2), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: driver.profilePic ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (context, url, error) =>
                      Image.asset(Constant.userPlaceHolder, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            driver.fullName ?? 'N/A',
            style: AppTypography.appTitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            driver.email ?? 'No email provided'.tr,
            style: AppTypography.boldLabel(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [AppColors.primary, AppColors.darkBackground],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Icon(
                      icon,
                      size: 30,
                      color: Colors.white, // Base color for gradient to show
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTypography.headers(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 0),
                      Text(
                        subtitle,
                        style: AppTypography.label(context)
                            .copyWith(color: AppColors.grey500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.darkBackground.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.arrow_forward_ios,
                      size: 16, color: AppColors.darkBackground),
                ),
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
          initialChildSize: 1,
          maxChildSize: 1,
          minChildSize: 1,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.only(top: 30.0),
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: AppColors.grey75,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          onPressed: () => Get.back(),
                          icon: Icon(Icons.arrow_back_ios_new,
                              size: 18, color: AppColors.primary)),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(title,
                              style: AppTypography.appTitle(context)),
                        ),
                      ),
                      IconButton(
                          onPressed: () => Get.back(),
                          icon: Icon(Icons.arrow_back_ios_new,
                              size: 18, color: AppColors.grey75)),
                    ],
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

  // --- NEW DYNAMIC IMPLEMENTATION FOR RIDE ANALYTICS ---

  void _showAnalyticsModal(BuildContext context, ProfileController controller) {
    _showDetailModal(
      context,
      title: 'Ride Analytics'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEarningsOverview(context, controller),
          const SizedBox(height: 24),
          _buildTimeFilterChips(controller),
          const SizedBox(height: 16),
          _buildFilteredStats(context, controller),
          const SizedBox(height: 24),
          _buildQuickStatsCards(context, controller),
          const SizedBox(height: 24),
          _buildEarningsChart(context, controller),
          const SizedBox(height: 24),
          _buildPerformanceMetrics(context, controller),
          const SizedBox(height: 24),
          _buildRideDistributionChart(context, controller),
          const SizedBox(height: 24),
          _buildPaymentMethodChart(context, controller),
          const SizedBox(height: 24),
          _buildTimeDistributionChart(context, controller),
          const SizedBox(height: 24),
          _buildPeakHoursAnalysis(context, controller),
          const SizedBox(height: 24),
          _buildWeeklyRidesChart(context, controller),
          const SizedBox(height: 24),
          _buildMonthlyComparison(context, controller),
        ],
      ),
    );
  }

  Widget _buildEarningsOverview(
      BuildContext context, ProfileController controller) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.darkBackground],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                    style: AppTypography.appTitle(context)
                        .copyWith(color: Colors.white.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 4),
                  Obx(() {
                    return Text(
                      NumberFormat.currency(locale: 'en_US', symbol: '\$')
                          .format(controller.lifetimeEarnings.value),
                      style: AppTypography.h1(context).copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                const SizedBox(width: 16),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption(context)
                .copyWith(color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.h3(context)
                .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: isPositive ? Colors.greenAccent : Colors.redAccent,
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: AppTypography.caption(context).copyWith(
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredStats(
      BuildContext context, ProfileController controller) {
    return Obx(() => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${controller.selectedFilter.value} Stats".tr,
                style: AppTypography.boldHeaders(context).copyWith(
                    fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total Earnings:".tr,
                      style: AppTypography.headers(context).copyWith(
                          fontWeight: FontWeight.normal,
                          color: AppColors.grey600)),
                  Text(
                    NumberFormat.currency(locale: 'en_US', symbol: '\$')
                        .format(controller.totalEarnings.value),
                    style: AppTypography.headers(context)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(
                height: 16,
                color: AppColors.grey100,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Completed Rides:".tr,
                      style: AppTypography.headers(context).copyWith(
                          fontWeight: FontWeight.normal,
                          color: AppColors.grey600)),
                  Text(
                    controller.completedRides.value.toString(),
                    style: AppTypography.headers(context)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(
                height: 16,
                color: AppColors.grey100,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total Distance:".tr,
                      style: AppTypography.headers(context).copyWith(
                          fontWeight: FontWeight.normal,
                          color: AppColors.grey600)),
                  Text(
                    "${controller.totalDistance.value.toStringAsFixed(1)} km",
                    style: AppTypography.headers(context)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(
                height: 16,
                color: AppColors.grey100,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total Tips:".tr,
                      style: AppTypography.headers(context).copyWith(
                          fontWeight: FontWeight.normal,
                          color: AppColors.grey600)),
                  Text(
                    NumberFormat.currency(locale: 'en_US', symbol: '\$')
                        .format(controller.totalTips.value),
                    style: AppTypography.headers(context)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(
                height: 16,
                color: AppColors.grey100,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Ride Offers:".tr,
                      style: AppTypography.headers(context).copyWith(
                          fontWeight: FontWeight.normal,
                          color: AppColors.grey600)),
                  Text(
                    controller.totalRideOffers.value.toString(),
                    style: AppTypography.headers(context)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  Widget _buildQuickStatsCards(
      BuildContext context, ProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "All-Time Stats".tr,
          style:
              AppTypography.h2(context).copyWith(fontWeight: FontWeight.bold),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTypography.h2(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBackground,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: AppTypography.caption(context)
                    .copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTypography.caption(context)
                .copyWith(color: Colors.grey.shade600),
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
              labelStyle: AppTypography.boldLabel(context).copyWith(
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary,
              shape: const StadiumBorder(),
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
              ),
            );
          });
        },
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                style: AppTypography.h3(context)
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('MMMM d').format(DateTime.now()),
                  style: AppTypography.caption(context).copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
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
                      style: AppTypography.bodyMedium(context)),
                );
              }

              return LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                          color: Colors.grey.shade200, strokeWidth: 1);
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
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12);
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
                        interval: maxY / 4,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value == 0 || value == maxY)
                            return const Text('');
                          return Text(
                            '\$${value.toInt()}',
                            style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
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
                      gradient: LinearGradient(colors: [
                        AppColors.primary.withOpacity(0.8),
                        AppColors.primary
                      ]),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.2),
                            AppColors.primary.withOpacity(0.05)
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Performance Metrics".tr,
            style:
                AppTypography.h3(context).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Obx(() => _buildMetricRow(
              context,
              "Acceptance Rate".tr,
              "${controller.acceptanceRate.value.toStringAsFixed(0)}%",
              controller.acceptanceRate.value / 100,
              AppColors.primary)),
          const SizedBox(height: 16),
          Obx(() => _buildMetricRow(
              context,
              "Cancellation Rate".tr,
              "${controller.cancellationRate.value.toStringAsFixed(0)}%",
              controller.cancellationRate.value / 100,
              AppColors.danger200)),
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
              style: AppTypography.bodyMedium(context)
                  .copyWith(color: Colors.grey.shade600),
            ),
            Text(
              value,
              style: AppTypography.bodyMedium(context)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Ride Distribution".tr,
            style:
                AppTypography.h3(context).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Obx(() => controller.rideDistributionData.isEmpty
                ? Center(
                    child: Text("No ride data available".tr,
                        style: AppTypography.bodyMedium(context)))
                : PieChart(
                    PieChartData(
                      sections: controller.rideDistributionData.toList(),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment Methods".tr,
            style:
                AppTypography.h3(context).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Obx(() => controller.paymentMethodData.isEmpty
                ? Center(
                    child: Text("No payment data available".tr,
                        style: AppTypography.bodyMedium(context)))
                : PieChart(
                    PieChartData(
                      sections: controller.paymentMethodData.toList(),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Time Distribution".tr,
            style:
                AppTypography.h3(context).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Obx(() => controller.timeDistributionData.isEmpty
                ? Center(
                    child: Text("No time data available".tr,
                        style: AppTypography.bodyMedium(context)))
                : PieChart(
                    PieChartData(
                      sections: controller.timeDistributionData.toList(),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  )),
          ),
          const SizedBox(height: 20),
          Obx(() => _buildLegend(context, controller.timeDistributionData)),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Weekly Rides".tr,
            style:
                AppTypography.h3(context).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Obx(() {
              final double maxY = controller.weeklyRidesData
                  .map((group) => group.barRods.first.toY)
                  .fold(0.0, (max, current) => current > max ? current : max);
              return controller.weeklyRidesData.isEmpty
                  ? Center(
                      child: Text("No ride data available".tr,
                          style: AppTypography.bodyMedium(context)))
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
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
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
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 4,
                                  child: Text(titles[value.toInt()],
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                );
                              },
                              reservedSize: 20,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Monthly Comparison".tr,
            style:
                AppTypography.h3(context).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Obx(() {
              final double maxY = controller.monthlyComparisonData
                  .map((group) => group.barRods.first.toY)
                  .fold(0.0, (max, current) => current > max ? current : max);
              return controller.monthlyComparisonData.isEmpty
                  ? Center(
                      child: Text("No comparison data available".tr,
                          style: AppTypography.bodyMedium(context)))
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
                              interval: maxY / 4,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value == 0 || value == maxY)
                                  return const Text('');
                                return Text(
                                  '\$${value.toInt()}',
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10),
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
                                  child: Text(titles[value.toInt()],
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                );
                              },
                              reservedSize: 20,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: controller.monthlyComparisonData.toList(),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption(context)
              .copyWith(color: Colors.grey.shade600),
        ),
      ],
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Peak Hours".tr,
            style:
                AppTypography.h3(context).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Obx(() {
              final double maxY = controller.peakHoursData
                  .map((group) => group.barRods.first.toY)
                  .fold(0.0, (max, current) => current > max ? current : max);
              return controller.peakHoursData.isEmpty
                  ? Center(
                      child: Text("No ride data available".tr,
                          style: AppTypography.bodyMedium(context)))
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
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
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
                                  child: Text(titles[value.toInt()],
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                );
                              },
                              reservedSize: 20,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: controller.peakHoursData.toList(),
                      ),
                    );
            }),
          ),
        ],
      ),
    );
  }

  void _showVehicleInfoModal(
      BuildContext context, VehicleInformation? vehicleInfo) {
    if (vehicleInfo == null) {
      _showDetailModal(context,
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
            _buildInfoRow(
                context,
                Icons.drive_eta_rounded,
                'Vehicle Type'.tr,
                (vehicleInfo.vehicleType?.isNotEmpty ?? false)
                    ? vehicleInfo.vehicleType!.first.name ?? 'N/A'
                    : 'N/A'),
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
