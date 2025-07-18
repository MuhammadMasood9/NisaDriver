import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart'; // Assuming you have this for the chart color
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart'; // Import for chart data
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class ProfileController extends GetxController {
  // --- General State ---
  RxBool isLoading = true.obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;
  var allRides = <OrderModel>[].obs;

  // --- Observables for Analytics ---
  var selectedFilter = 'Weekly'.obs; // Default to weekly to show the chart initially
  final List<String> timeFilters = ['Today', 'Weekly', 'Yearly', 'Lifetime'];

  // Metrics Observables
  var totalEarnings = 0.0.obs;
  var completedRides = 0.obs;
  var canceledRides = 0.obs;
  var totalDistance = 0.0.obs;
  var timeOnline = 0.0.obs; // Placeholder

  // Chart Data Observables
  final RxDouble maxWeeklyEarning = 100.0.obs; // Default max Y-axis
  final RxList<BarChartGroupData> weeklyEarningsData = <BarChartGroupData>[].obs;

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
    // This single method now handles the entire initial data loading sequence.
    fetchInitialData();
  }

  /// Master method to fetch all necessary data in sequence when the controller is initialized.
  Future<void> fetchInitialData() async {
    isLoading(true);
    await getData(); // Load profile data and populate TextControllers
    final uid = FireStoreUtils.getCurrentUid();
    if (uid != null && driverModel.value.id != null) {
      await fetchRideData(driverModel.value.id!); // Load ride data for analytics
    }
    isLoading(false);
  }

  /// Fetches all ride data for the current driver and triggers analytics calculation.
  Future<void> fetchRideData(String driverId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection(CollectionName.orders).where('driverId', isEqualTo: driverId).get();

      allRides.value = querySnapshot.docs.map((doc) => OrderModel.fromJson(doc.data())).toList();

      // Initially calculate analytics for the default filter ('Weekly')
      calculateAnalytics();
    } catch (e) {
      print("Error fetching ride data: $e");
      ShowToastDialog.showToast("Could not load ride history.".tr);
    }
  }

  /// Called when the user selects a new time filter from the UI.
  void changeFilter(String newFilter) {
    selectedFilter.value = newFilter;
    calculateAnalytics();
  }

  /// Calculates all analytics metrics based on the currently selected filter.
  void calculateAnalytics() {
    List<OrderModel> filteredOrders = [];
    final now = DateTime.now();

    switch (selectedFilter.value) {
      case 'Today':
        final startOfDay = DateTime(now.year, now.month, now.day);
        filteredOrders = allRides.where((order) {
          final orderDate = order.createdDate?.toDate();
          return orderDate != null && orderDate.isAfter(startOfDay);
        }).toList();
        break;
      case 'Weekly':
        // This calculates the start of the current week (assuming Monday is the first day)
        final weekAgo = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeek = DateTime(weekAgo.year, weekAgo.month, weekAgo.day);
        filteredOrders = allRides.where((order) {
          final orderDate = order.createdDate?.toDate();
          return orderDate != null && orderDate.isAfter(startOfWeek);
        }).toList();
        break;
      case 'Yearly':
        final startOfYear = DateTime(now.year);
        filteredOrders = allRides.where((order) {
          final orderDate = order.createdDate?.toDate();
          return orderDate != null && orderDate.isAfter(startOfYear);
        }).toList();
        break;
      case 'Lifetime':
      default:
        filteredOrders = List.from(allRides);
        break;
    }

    // Reset metrics before recalculating
    double currentEarnings = 0.0;
    int completedCount = 0;
    int canceledCount = 0;
    double distance = 0.0;

    for (var order in filteredOrders) {
      if (order.status == Constant.rideComplete) {
        completedCount++;
        currentEarnings += double.tryParse(order.finalRate ?? '0') ?? 0.0;
        
        // ========= FIX IS HERE =========
        // This safely handles if order.distance is a String, a num, or null.
        distance += double.tryParse(order.distance.toString()) ?? 0.0;
        // ===============================

      } else if (order.status == Constant.rideCanceled) {
        canceledCount++;
      }
    }

    totalEarnings.value = currentEarnings;
    completedRides.value = completedCount;
    canceledRides.value = canceledCount;
    totalDistance.value = distance;
    // Placeholder for Time Online, as it's complex to calculate accurately
    timeOnline.value = completedCount * 0.35; // Example calculation

    // Generate chart data specifically for the weekly view
    if (selectedFilter.value == 'Weekly') {
      _generateWeeklyChartData(filteredOrders);
    } else {
      weeklyEarningsData.clear();
    }
  }

  /// Private helper to generate bar chart data from weekly orders.
  void _generateWeeklyChartData(List<OrderModel> weeklyOrders) {
    // Map to hold earnings for each day of the week (1: Mon, 7: Sun)
    Map<int, double> dailyEarnings = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

    for (var order in weeklyOrders) {
      if (order.status == Constant.rideComplete) {
        final orderDate = order.createdDate?.toDate();
        if (orderDate != null) {
          final dayOfWeek = orderDate.weekday;
          final earning = double.tryParse(order.finalRate ?? '0') ?? 0.0;
          dailyEarnings[dayOfWeek] = (dailyEarnings[dayOfWeek] ?? 0) + earning;
        }
      }
    }

    final maxEarning = dailyEarnings.values.fold(0.0, (prev, element) => max(prev, element));
    maxWeeklyEarning.value = maxEarning == 0 ? 100 : (maxEarning * 1.2); // Add 20% padding

    weeklyEarningsData.value = dailyEarnings.entries.map((entry) {
      return BarChartGroupData(
        x: entry.key, // Day of the week (1 to 7)
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: AppColors.primary, // Make sure AppColors is imported
            width: 16,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );
    }).toList();
  }

  /// Fetches profile data from Firestore and populates local state and controllers.
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
        countryCode.value = value.countryCode ?? '+92';
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

  /// Syncs phone verification status if Firebase Auth is verified but Firestore is not.
  Future<void> syncProfileVerification() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.phoneNumber != null) {
      String fullPhoneNumber = '${countryCode.value}${phoneNumberController.value.text}';
      if (currentUser.phoneNumber == fullPhoneNumber && driverModel.value.profileVerify == false) {
        await updateFirestore(fullPhoneNumber);
        ShowToastDialog.showToast("Profile verification synced with Firebase".tr);
      }
    }
  }

  /// Allows user to pick a profile image from the gallery or camera.
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

  // --- OTP VERIFICATION METHODS ---

  /// Sends an OTP to the provided phone number.
  Future<void> sendOtp() async {
    String phoneNumber = '${countryCode.value}${phoneNumberController.value.text}';
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
          if (e.code == 'invalid-phone-number') {
            message = "Invalid phone number format".tr;
          } else if (e.code == 'too-many-requests') {
            message = "Too many attempts. Try again later.".tr;
          } else if (e.code.contains('recaptcha')) {
            message = "reCAPTCHA verification failed. Please try again.".tr;
          }
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

  /// Handles the phone auth credential, either from auto-retrieval or manual OTP entry.
  Future<void> handleCredential(PhoneAuthCredential credential, String phoneNumber) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("No authenticated user found".tr);
        return;
      }

      try {
        await updateFirestore(phoneNumber);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          UserCredential userCredential = await _auth.signInWithCredential(credential);
          if (userCredential.user?.uid == currentUser.uid) {
            await updateFirestore(phoneNumber);
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("Phone number already verified for this account".tr);
          } else {
            ShowToastDialog.closeLoader();
            ShowToastDialog.showToast("This phone number is linked to another account. Please use a different number.".tr);
          }
          resetOtpProcess();
          return;
        } else if (e.code == 'requires-recent-login') {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Please re-authenticate to verify your phone number".tr);
          resetOtpProcess();
          return;
        }
        rethrow;
      }

      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Phone number verified successfully".tr);
      resetOtpProcess();
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error verifying phone number: $e".tr);
    }
  }

  /// Updates the driver's profile in Firestore with verified phone details.
  Future<void> updateFirestore(String phoneNumber) async {
    driverModel.value.profileVerify = true;
    driverModel.value.phoneNumber = phoneNumberController.value.text;
    driverModel.value.countryCode = countryCode.value;
    await FireStoreUtils.updateDriverUser(driverModel.value);
  }

  /// Verifies the manually entered OTP code.
  Future<void> verifyOtp() async {
    if (verificationId == null) {
      ShowToastDialog.showToast("Verification ID is missing".tr);
      return;
    }
    if (otpController.value.text.isEmpty || otpController.value.text.length < 6) {
      ShowToastDialog.showToast("Invalid OTP".tr);
      return;
    }

    ShowToastDialog.showLoader("Verifying OTP...".tr);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: otpController.value.text,
      );
      await handleCredential(credential, '${countryCode.value}${phoneNumberController.value.text}');
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Invalid OTP: $e".tr);
    }
  }

  /// Resets the OTP process UI and state.
  void resetOtpProcess() {
    isOtpSent.value = false;
    otpStep.value = 1;
    otpController.value.clear();
    verificationId = null;
    _resendToken = null;
  }
}