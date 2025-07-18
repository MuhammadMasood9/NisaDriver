import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProfileController extends GetxController {
  // --- General State ---
  RxBool isLoading = true.obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;
  var allRides = <OrderModel>[].obs;

  // --- Observables for Analytics ---
  var selectedFilter = 'Weekly'.obs;
  final List<String> timeFilters = [
    'Today',
    'Weekly',
    'Monthly',
    'Yearly',
    'Lifetime'
  ];

  // Core Metrics Observables (Filter-dependent)
  var totalEarnings = 0.0.obs;
  var completedRides = 0.obs;
  var canceledRides = 0.obs;
  var rejectedRides = 0.obs;
  var totalRideOffers = 0.obs;
  var totalDistance = 0.0.obs;
  var totalTips = 0.0.obs;
  var acceptanceRate = 0.0.obs;
  var cancellationRate = 0.0.obs;
  var completionRate = 0.0.obs;

  // Aggregate Metrics (Global - from allRides)
  var averageRating = 0.0.obs;
  var todaysRides = 0.obs;
  var thisWeekEarnings = 0.0.obs;
  var thisMonthEarnings = 0.0.obs;
  var lastMonthEarnings = 0.0.obs;
  var yesterdayEarnings = 0.0.obs;
  var lastWeekEarnings = 0.0.obs;
  var yearlyEarnings = 0.0.obs;
  var lifetimeEarnings = 0.0.obs;
  var averageRideDistance = 0.0.obs;
  var averageEarningsPerRide = 0.0.obs;
  var averageEarningsPerKm = 0.0.obs;
  var averageTipPerRide = 0.0.obs;
  var peakHourEarnings = 0.0.obs;
  var offPeakEarnings = 0.0.obs;
  var bestEarningDay = ''.obs;
  var worstEarningDay = ''.obs;
  var morningRides = 0.obs;
  var afternoonRides = 0.obs;
  var eveningRides = 0.obs;
  var nightRides = 0.obs;
  var weekdayRides = 0.obs;
  var weekendRides = 0.obs;
  var cashRides = 0.obs;
  var cardRides = 0.obs;
  var walletRides = 0.obs;
  var netEarnings = 0.0.obs;
  var projectedMonthlyEarnings = 0.0.obs;
  var totalFiveStarRides = 0.obs;
  var totalOneStarRides = 0.obs;
  var longestRideDistance = 0.0.obs;
  var shortestRideDistance = 0.0.obs;

  // Chart Data Observables
  final RxDouble maxWeeklyEarning = 100.0.obs;
  final RxDouble maxMonthlyEarning = 1000.0.obs;
  final RxDouble maxDailyEarning = 200.0.obs;
  final RxList<FlSpot> weeklyEarningsSpots = <FlSpot>[].obs;
  final RxList<FlSpot> monthlyEarningsSpots = <FlSpot>[].obs;
  final RxList<FlSpot> dailyEarningsSpots = <FlSpot>[].obs;
  final RxList<PieChartSectionData> rideDistributionData =
      <PieChartSectionData>[].obs;

  final RxList<PieChartSectionData> paymentMethodData =
      <PieChartSectionData>[].obs;
  final RxList<PieChartSectionData> timeDistributionData =
      <PieChartSectionData>[].obs;
  final RxList<BarChartGroupData> peakHoursData = <BarChartGroupData>[].obs;
  final RxList<BarChartGroupData> weeklyRidesData = <BarChartGroupData>[].obs;
  final RxList<BarChartGroupData> monthlyComparisonData =
      <BarChartGroupData>[].obs;

  // --- Profile Editing & Verification State ---
  Rx<TextEditingController> fullNameController = TextEditingController().obs;
  Rx<TextEditingController> emailController = TextEditingController().obs;
  Rx<TextEditingController> phoneNumberController = TextEditingController().obs;
  Rx<TextEditingController> otpController = TextEditingController().obs;
  RxString countryCode = "+1".obs;
  RxString profileImage = "".obs;

  // OTP State
  RxBool isOtpSent = false.obs;
  RxInt otpStep = 1.obs;
  String? verificationId;
  int? _resendToken;

  // --- Dependencies ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    isLoading(true);
    await getData();
    final uid = FireStoreUtils.getCurrentUid();
    if (uid != null && driverModel.value.id != null) {
      await fetchRideData(driverModel.value.id!);
    }
    isLoading(false);
  }

  Future<void> fetchRideData(String driverId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(CollectionName.orders)
          .where('driverId', isEqualTo: driverId)
          .orderBy('createdDate', descending: true)
          .get();

      allRides.value = querySnapshot.docs
          .map((doc) => OrderModel.fromJson(doc.data()))
          .toList();
      calculateAnalytics();

     
    } catch (e) {
      print("Error fetching ride data: $e");
      ShowToastDialog.showToast("Could not load ride history.".tr);
    }
  }

  void changeFilter(String newFilter) {
    selectedFilter.value = newFilter;
    calculateAnalytics();
  }

  void calculateAnalytics() {
    List<OrderModel> filteredOrders = _getFilteredOrders();
    List<OrderModel> completedOrders =
        allRides.where((o) => o.status == Constant.rideComplete).toList();

    _calculateCoreMetrics(filteredOrders);
    _calculateSpecialMetrics(completedOrders);
    _calculateAdvancedMetrics(completedOrders);
    _calculateTimeBasedAnalytics(completedOrders);
    _calculateFinancialAnalytics(completedOrders);
    _calculatePerformanceMetrics(completedOrders);
    _calculateDriverRating();

    _generateAllChartData(completedOrders);
  }

  void _calculateCoreMetrics(List<OrderModel> filteredOrders) {
    // Reset filter-dependent metrics
    double currentEarnings = 0.0;
    int completedCount = 0;
    int canceledCount = 0;
    int rejectedCount = 0;
    double distance = 0.0;
    double tips = 0.0;

    for (var order in filteredOrders) {
      if (order.status == Constant.rideComplete) {
        completedCount++;
        currentEarnings += double.tryParse(order.finalRate ?? '0') ?? 0.0;
        distance += double.tryParse(order.distance.toString()) ?? 0.0;
        tips += double.tryParse('0') ?? 0.0;
      } else if (order.status == Constant.rideCanceled) {
        canceledCount++;
      } else if (order.status == Constant.rideCanceled) {
        rejectedCount++;
      }
    }

    totalEarnings.value = currentEarnings;
    completedRides.value = completedCount;
    canceledRides.value = canceledCount;
    rejectedRides.value = rejectedCount;
    totalDistance.value = distance;
    totalTips.value = tips;
    totalRideOffers.value = filteredOrders.length;

    // Calculate rates for the filtered period
    if (totalRideOffers.value > 0) {
      int acceptedOffers = completedCount + canceledCount;
      acceptanceRate.value = (acceptedOffers / totalRideOffers.value) * 100;
      cancellationRate.value = (canceledCount / totalRideOffers.value) * 100;
      completionRate.value = (completedCount / totalRideOffers.value) * 100;
    } else {
      acceptanceRate.value = 0;
      cancellationRate.value = 0;
      completionRate.value = 0;
    }
  }

  void _calculateSpecialMetrics(List<OrderModel> completedOrders) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final startOfLastWeek = startOfWeekDate.subtract(const Duration(days: 7));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final endOfLastMonth =
        DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
    final startOfYear = DateTime(now.year, 1, 1);

    double weeklySum = 0, monthlySum = 0, lastMonthSum = 0;
    double yesterdaySum = 0, lastWeekSum = 0, yearlySum = 0, lifetimeSum = 0;
    int todayRidesCount = 0;

    for (var order in completedOrders) {
      final orderDate = order.createdDate!.toDate();
      final earning = double.tryParse(order.finalRate ?? '0') ?? 0.0;

      if (orderDate.isAfter(startOfToday)) todayRidesCount++;
      if (orderDate.isAfter(startOfYesterday) &&
          orderDate.isBefore(startOfToday)) yesterdaySum += earning;
      if (orderDate.isAfter(startOfWeekDate)) weeklySum += earning;
      if (orderDate.isAfter(startOfLastWeek) &&
          orderDate.isBefore(startOfWeekDate)) lastWeekSum += earning;
      if (orderDate.isAfter(startOfMonth)) monthlySum += earning;
      if (orderDate.isAfter(startOfLastMonth) &&
          orderDate.isBefore(endOfLastMonth)) lastMonthSum += earning;
      if (orderDate.isAfter(startOfYear)) yearlySum += earning;
      lifetimeSum += earning;
    }

    todaysRides.value = todayRidesCount;
    yesterdayEarnings.value = yesterdaySum;
    thisWeekEarnings.value = weeklySum;
    lastWeekEarnings.value = lastWeekSum;
    thisMonthEarnings.value = monthlySum;
    lastMonthEarnings.value = lastMonthSum;
    yearlyEarnings.value = yearlySum;
    lifetimeEarnings.value = lifetimeSum;
  }

  void _calculateAdvancedMetrics(List<OrderModel> completedOrders) {
    double totalLifetimeDistance = 0.0;
    double totalLifetimeTips = 0.0;
    completedOrders.forEach((order) {
      totalLifetimeDistance +=
          double.tryParse(order.distance.toString()) ?? 0.0;
      totalLifetimeTips += double.tryParse('0') ?? 0.0;
    });

    if (completedOrders.isNotEmpty) {
      averageEarningsPerRide.value =
          lifetimeEarnings.value / completedOrders.length;
      averageRideDistance.value =
          totalLifetimeDistance / completedOrders.length;
      averageTipPerRide.value = totalLifetimeTips / completedOrders.length;
    }

    if (totalLifetimeDistance > 0) {
      averageEarningsPerKm.value =
          lifetimeEarnings.value / totalLifetimeDistance;
    }

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed = now.day;
    if (daysPassed > 0 && thisMonthEarnings.value > 0) {
      projectedMonthlyEarnings.value =
          (thisMonthEarnings.value / daysPassed) * daysInMonth;
    }
  }

  void _calculateTimeBasedAnalytics(List<OrderModel> completedOrders) {
    int morning = 0, afternoon = 0, evening = 0, night = 0;
    int weekday = 0, weekend = 0;

    for (var order in completedOrders) {
      final date = order.createdDate!.toDate();
      final hour = date.hour;
      final dayOfWeek = date.weekday;

      if (hour >= 6 && hour < 12)
        morning++;
      else if (hour >= 12 && hour < 17)
        afternoon++;
      else if (hour >= 17 && hour < 21)
        evening++;
      else
        night++;

      if (dayOfWeek <= 5)
        weekday++;
      else
        weekend++;
    }

    morningRides.value = morning;
    afternoonRides.value = afternoon;
    eveningRides.value = evening;
    nightRides.value = night;
    weekdayRides.value = weekday;
    weekendRides.value = weekend;
  }

  void _calculateFinancialAnalytics(List<OrderModel> completedOrders) {
    int cash = 0, card = 0, wallet = 0;
    double peakEarningsVal = 0.0, offPeakEarningsVal = 0.0;

    for (var order in completedOrders) {
      final paymentMethod = order.paymentType?.toLowerCase() ?? 'cash';
      final hour = order.createdDate!.toDate().hour;
      final earning = double.tryParse(order.finalRate ?? '0') ?? 0.0;

      if (paymentMethod.contains('cash'))
        cash++;
      else if (paymentMethod.contains('card') ||
          paymentMethod.contains('stripe'))
        card++;
      else if (paymentMethod.contains('wallet')) wallet++;

      if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
        peakEarningsVal += earning;
      } else {
        offPeakEarningsVal += earning;
      }
    }

    cashRides.value = cash;
    cardRides.value = card;
    walletRides.value = wallet;
    peakHourEarnings.value = peakEarningsVal;
    offPeakEarnings.value = offPeakEarningsVal;
    netEarnings.value = lifetimeEarnings.value *
        (1 -
            (double.tryParse(Constant.adminCommission.toString()) ?? 0.0) /
                100);
  }

  void _calculatePerformanceMetrics(List<OrderModel> completedOrders) {
    if (completedOrders.isEmpty) return;

    Map<String, double> dailyEarnings = {};
    double longest = 0.0, shortest = double.infinity;
    int fiveStars = 0, oneStar = 0;

    for (var order in completedOrders) {
      final date = DateFormat('yyyy-MM-dd').format(order.createdDate!.toDate());
      final earning = double.tryParse(order.finalRate ?? '0') ?? 0.0;
      final distance = double.tryParse(order.distance.toString()) ?? 0.0;
      final rating = int.tryParse(driverModel.value.reviewsCount ?? '0') ?? 0;

      dailyEarnings[date] = (dailyEarnings[date] ?? 0.0) + earning;
      if (distance > longest) longest = distance;
      if (distance < shortest && distance > 0) shortest = distance;
      if (rating == 5) fiveStars++;
      if (rating == 1) oneStar++;
    }

    if (dailyEarnings.isNotEmpty) {
      final sortedDays = dailyEarnings.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      bestEarningDay.value =
          DateFormat('EEE, MMM d').format(DateTime.parse(sortedDays.first.key));
      worstEarningDay.value =
          DateFormat('EEE, MMM d').format(DateTime.parse(sortedDays.last.key));
    }

    longestRideDistance.value = longest;
    shortestRideDistance.value = shortest == double.infinity ? 0.0 : shortest;
    totalFiveStarRides.value = fiveStars;
    totalOneStarRides.value = oneStar;
  }

  void _calculateDriverRating() {
    final double reviewsSumVal =
        double.tryParse(driverModel.value.reviewsSum ?? '0') ?? 0.0;
    final int reviewsCountVal =
        int.tryParse(driverModel.value.reviewsCount ?? '0') ?? 0;
    averageRating.value =
        reviewsCountVal > 0 ? reviewsSumVal / reviewsCountVal : 0.0;
  }

  List<OrderModel> _getFilteredOrders() {
    final now = DateTime.now();
    switch (selectedFilter.value) {
      case 'Today':
        final startOfDay = DateTime(now.year, now.month, now.day);
        return allRides.where((order) {
          final orderDate = order.createdDate?.toDate();
          return orderDate != null && orderDate.isAfter(startOfDay);
        }).toList();
      case 'Weekly':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDate =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return allRides.where((order) {
          final orderDate = order.createdDate?.toDate();
          return orderDate != null && orderDate.isAfter(startOfWeekDate);
        }).toList();
      case 'Monthly':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return allRides.where((order) {
          final orderDate = order.createdDate?.toDate();
          return orderDate != null && orderDate.isAfter(startOfMonth);
        }).toList();
      case 'Yearly':
        final startOfYear = DateTime(now.year);
        return allRides.where((order) {
          final orderDate = order.createdDate?.toDate();
          return orderDate != null && orderDate.isAfter(startOfYear);
        }).toList();
      case 'Lifetime':
      default:
        return List.from(allRides);
    }
  }

  void _generateAllChartData(List<OrderModel> completedOrders) {
    _generateWeeklyEarningsChartData(completedOrders);
    _generateMonthlyEarningsChartData(completedOrders);
    _generateDailyEarningsChartData(completedOrders);
    _generateRideDistributionChartData(completedOrders);
    _generatePaymentMethodChartData(completedOrders);
    _generateTimeDistributionChartData(completedOrders);
    _generatePeakHoursChartData(completedOrders);
    _generateWeeklyRidesChartData(completedOrders);
    _generateMonthlyComparisonChartData();
  }

  void _generateWeeklyEarningsChartData(List<OrderModel> completedOrders) {
    Map<int, double> dailyEarnings = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final weeklyOrders = completedOrders.where((order) {
      final orderDate = order.createdDate?.toDate();
      return orderDate != null && orderDate.isAfter(startOfWeekDate);
    }).toList();

    for (var order in weeklyOrders) {
      final dayOfWeek = order.createdDate!.toDate().weekday;
      dailyEarnings[dayOfWeek] = (dailyEarnings[dayOfWeek] ?? 0) +
          (double.tryParse(order.finalRate ?? '0') ?? 0.0);
    }

    final spots = dailyEarnings.entries
        .map((entry) => FlSpot(entry.key.toDouble() - 1, entry.value))
        .toList();
    final maxEarning =
        dailyEarnings.values.fold(0.0, (prev, element) => max(prev, element));

    weeklyEarningsSpots.value = spots;
    maxWeeklyEarning.value = maxEarning == 0 ? 100 : (maxEarning * 1.25);
  }

  void _generateMonthlyEarningsChartData(List<OrderModel> completedOrders) {
    Map<int, double> earnings = {};
    for (int i = 0; i < 12; i++) earnings[i] = 0;

    final yearlyOrders = completedOrders
        .where((o) => o.createdDate!.toDate().year == DateTime.now().year);
    for (var order in yearlyOrders) {
      final month = order.createdDate!.toDate().month - 1;
      earnings[month] = (earnings[month] ?? 0) +
          (double.tryParse(order.finalRate ?? '0') ?? 0.0);
    }

    final spots =
        earnings.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final maxEarning = earnings.values.fold(0.0, (p, e) => max(p, e));
    monthlyEarningsSpots.value = spots;
    maxMonthlyEarning.value = maxEarning == 0 ? 1000 : (maxEarning * 1.25);
  }

  void _generateDailyEarningsChartData(List<OrderModel> completedOrders) {
    Map<int, double> earnings = {};
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    for (int i = 0; i < daysInMonth; i++) earnings[i] = 0;

    final monthlyOrders = completedOrders.where((o) {
      final date = o.createdDate!.toDate();
      return date.year == now.year && date.month == now.month;
    });

    for (var order in monthlyOrders) {
      final day = order.createdDate!.toDate().day - 1;
      earnings[day] = (earnings[day] ?? 0) +
          (double.tryParse(order.finalRate ?? '0') ?? 0.0);
    }

    final spots =
        earnings.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final maxEarning = earnings.values.fold(0.0, (p, e) => max(p, e));
    dailyEarningsSpots.value = spots;
    maxDailyEarning.value = maxEarning == 0 ? 200 : (maxEarning * 1.25);
  }

  void _generateRideDistributionChartData(List<OrderModel> completedOrders) {
    if (completedOrders.isEmpty) {
      rideDistributionData.clear();
      return;
    }

    Map<String, int> serviceCounts = {};
    for (var order in completedOrders) {
      final serviceName = (order.service?.title ?? 'Standard').toString();
      serviceCounts[serviceName] = (serviceCounts[serviceName] ?? 0) + 1;
    }

    final colors = [
      AppColors.primary,
      Colors.blueAccent,
      Colors.green,
      Colors.orange,
      Colors.purple
    ];
    int colorIndex = 0;
    rideDistributionData.value = serviceCounts.entries.map((entry) {
      final percentage = (entry.value / completedOrders.length) * 100;
      final section = PieChartSectionData(
        color: colors[colorIndex++ % colors.length],
        value: percentage,
        title: '${entry.key}\n${percentage.toStringAsFixed(1)}%',
        radius: 80,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
      return section;
    }).toList();
  }

  void _generatePaymentMethodChartData(List<OrderModel> completedOrders) {
    if (completedOrders.isEmpty) {
      paymentMethodData.clear();
      return;
    }
    final total = completedOrders.length.toDouble();
    final data = [
      {'name': 'Cash', 'value': cashRides.value, 'color': Colors.green},
      {'name': 'Card', 'value': cardRides.value, 'color': Colors.blue},
      {'name': 'Wallet', 'value': walletRides.value, 'color': Colors.orange},
    ];

    paymentMethodData.value =
        data.where((item) => (item['value'] as int) > 0).map((item) {
      final percentage = ((item['value'] as int) / total) * 100;
      return PieChartSectionData(
        color: item['color'] as Color,
        value: percentage,
        title: '${item['name']}\n${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  void _generateTimeDistributionChartData(List<OrderModel> completedOrders) {
    if (completedOrders.isEmpty) {
      timeDistributionData.clear();
      return;
    }
    final total = completedOrders.length.toDouble();
    final data = [
      {
        'name': 'Morning',
        'value': morningRides.value,
        'color': Colors.yellow.shade700
      },
      {
        'name': 'Afternoon',
        'value': afternoonRides.value,
        'color': Colors.orange.shade600
      },
      {
        'name': 'Evening',
        'value': eveningRides.value,
        'color': Colors.red.shade600
      },
      {
        'name': 'Night',
        'value': nightRides.value,
        'color': Colors.indigo.shade700
      },
    ];

    timeDistributionData.value =
        data.where((item) => (item['value'] as int) > 0).map((item) {
      final percentage = ((item['value'] as int) / total) * 100;
      return PieChartSectionData(
        color: item['color'] as Color,
        value: percentage,
        title: '${item['name']}\n${percentage.toStringAsFixed(1)}%',
        radius: 70,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  void _generatePeakHoursChartData(List<OrderModel> completedOrders) {
    Map<int, int> peakHours = {
      0: 0,
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0
    }; // 6-9, 9-12, 12-15, 15-18, 18-21, 21-24

    for (var order in completedOrders) {
      int hour = order.createdDate!.toDate().hour;
      if (hour >= 6 && hour < 9)
        peakHours[0] = (peakHours[0] ?? 0) + 1;
      else if (hour >= 9 && hour < 12)
        peakHours[1] = (peakHours[1] ?? 0) + 1;
      else if (hour >= 12 && hour < 15)
        peakHours[2] = (peakHours[2] ?? 0) + 1;
      else if (hour >= 15 && hour < 18)
        peakHours[3] = (peakHours[3] ?? 0) + 1;
      else if (hour >= 18 && hour < 21)
        peakHours[4] = (peakHours[4] ?? 0) + 1;
      else if (hour >= 21 || hour < 6) peakHours[5] = (peakHours[5] ?? 0) + 1;
    }

    peakHoursData.value = peakHours.entries.map((entry) {
      return BarChartGroupData(x: entry.key, barRods: [
        BarChartRodData(
            toY: entry.value.toDouble(),
            width: 15,
            color: AppColors.primary.withOpacity(0.8),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(4)))
      ]);
    }).toList();
  }

  void _generateWeeklyRidesChartData(List<OrderModel> completedOrders) {
    Map<int, int> dailyRides = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDate =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final weeklyOrders = completedOrders
        .where((o) => o.createdDate!.toDate().isAfter(startOfWeekDate));
    for (var order in weeklyOrders) {
      final dayOfWeek = order.createdDate!.toDate().weekday;
      dailyRides[dayOfWeek] = (dailyRides[dayOfWeek] ?? 0) + 1;
    }

    weeklyRidesData.value = dailyRides.entries.map((e) {
      return BarChartGroupData(x: e.key - 1, barRods: [
        BarChartRodData(
            toY: e.value.toDouble(),
            width: 15,
            color: AppColors.darkBackground,
            borderRadius: const BorderRadius.all(Radius.circular(4)))
      ]);
    }).toList();
  }

  void _generateMonthlyComparisonChartData() {
    monthlyComparisonData.value = [
      BarChartGroupData(x: 0, barRods: [
        BarChartRodData(
            toY: lastMonthEarnings.value,
            width: 22,
            color: Colors.grey.shade400)
      ]),
      BarChartGroupData(x: 1, barRods: [
        BarChartRodData(
            toY: thisMonthEarnings.value, width: 22, color: AppColors.primary)
      ]),
    ];
  }

  // --- Profile Data and OTP Methods ---
  Future<void> getData() async {
    try {
      String? driverId = FireStoreUtils.getCurrentUid();
      if (driverId == null) {
        ShowToastDialog.showToast("User not authenticated".tr);
        return;
      }
      final value = await FireStoreUtils.getDriverProfile(driverId);
      if (value != null) {
        driverModel.value = value;
        phoneNumberController.value.text = value.phoneNumber ?? '';
        countryCode.value = value.countryCode ?? '+1';
        emailController.value.text = value.email ?? '';
        fullNameController.value.text = value.fullName ?? '';
        profileImage.value = value.profilePic ?? '';
        await syncProfileVerification();
      } else {
        ShowToastDialog.showToast("Driver profile not found".tr);
      }
    } catch (e) {
      ShowToastDialog.showToast("Error fetching profile: $e".tr);
    }
  }

  Future<void> syncProfileVerification() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.phoneNumber != null) {
      String fullPhoneNumber =
          '${countryCode.value}${phoneNumberController.value.text}';
      if (currentUser.phoneNumber == fullPhoneNumber &&
          driverModel.value.profileVerify == false) {
        await updateFirestore(fullPhoneNumber);
        ShowToastDialog.showToast(
            "Profile verification synced with Firebase".tr);
      }
    }
  }

  Future<void> pickFile({required ImageSource source}) async {
    try {
      XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        profileImage.value = image.path;
        // TODO: Add logic here to upload the new image to Firebase Storage
        // and then update the profilePic URL in the driver's Firestore document.
      }
    } on PlatformException catch (e) {
      ShowToastDialog.showToast("Failed to pick image: $e".tr);
    }
  }

  Future<void> sendOtp() async {
    String phoneNumber =
        '${countryCode.value}${phoneNumberController.value.text}';
    if (phoneNumber.isEmpty || phoneNumber.length < 10) {
      ShowToastDialog.showToast("Invalid phone number".tr);
      return;
    }

    User? currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.phoneNumber == phoneNumber) {
      await updateFirestore(phoneNumber);
      ShowToastDialog.showToast("Phone number already verified".tr);
      return;
    }

    ShowToastDialog.showLoader("Sending OTP...".tr);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await handleCredential(credential, phoneNumber);
        },
        verificationFailed: (FirebaseAuthException e) {
          ShowToastDialog.closeLoader();
          String message = e.message ?? "Verification failed";
          if (e.code == 'invalid-phone-number')
            message = "Invalid phone number format".tr;
          else if (e.code == 'too-many-requests')
            message = "Too many attempts. Try again later.".tr;
          else if (e.code.contains('recaptcha'))
            message = "reCAPTCHA verification failed. Please try again.".tr;
          ShowToastDialog.showToast(message);
        },
        codeSent: (String verId, int? resendToken) {
          ShowToastDialog.closeLoader();
          verificationId = verId;
          _resendToken = resendToken;
          isOtpSent.value = true;
          otpStep.value = 2;
          ShowToastDialog.showToast("OTP sent to $phoneNumber".tr);
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error sending OTP: $e".tr);
    }
  }

  Future<void> handleCredential(
      PhoneAuthCredential credential, String phoneNumber) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("No authenticated user found".tr);
        return;
      }
      // This is a new verification, so we update the user's phone number
      await currentUser.updatePhoneNumber(credential);
      await updateFirestore(phoneNumber);

      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Phone number verified successfully".tr);
      resetOtpProcess();
    } on FirebaseAuthException catch (e) {
      ShowToastDialog.closeLoader();
      if (e.code == 'credential-already-in-use') {
        ShowToastDialog.showToast(
            "This phone number is linked to another account.".tr);
      } else if (e.code == 'requires-recent-login') {
        ShowToastDialog.showToast(
            "Please re-authenticate to verify your phone number".tr);
      } else {
        ShowToastDialog.showToast("Error: ${e.message}".tr);
      }
      resetOtpProcess();
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error verifying phone number: $e".tr);
    }
  }

  Future<void> updateFirestore(String phoneNumber) async {
    driverModel.value.profileVerify = true;
    driverModel.value.phoneNumber = phoneNumberController.value.text;
    driverModel.value.countryCode = countryCode.value;
    await FireStoreUtils.updateDriverUser(driverModel.value);
  }

  Future<void> verifyOtp() async {
    if (verificationId == null) {
      ShowToastDialog.showToast("Verification ID is missing".tr);
      return;
    }
    if (otpController.value.text.isEmpty ||
        otpController.value.text.length < 6) {
      ShowToastDialog.showToast("Invalid OTP".tr);
      return;
    }

    ShowToastDialog.showLoader("Verifying OTP...".tr);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpController.value.text,
      );
      await handleCredential(credential,
          '${countryCode.value}${phoneNumberController.value.text}');
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Invalid OTP or error verifying".tr);
    }
  }

  void resetOtpProcess() {
    isOtpSent.value = false;
    otpStep.value = 1;
    otpController.value.clear();
    verificationId = null;
    _resendToken = null;
  }
}
