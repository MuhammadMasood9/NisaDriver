import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/model/bank_details_model.dart';
import 'package:driver/model/payment_model.dart';
import 'package:driver/model/wallet_transaction_model.dart';
import 'package:driver/payment/midtrans_screen.dart';
import 'package:driver/payment/orangePayScreen.dart';
import 'package:driver/payment/xenditModel.dart';
import 'package:driver/payment/xenditScreen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:driver/payment/getPaytmTxtToken.dart';
import 'package:flutter/services.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:developer';
import 'dart:math' as maths;

import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/stripe_failed_model.dart';
import 'package:driver/payment/MercadoPagoScreen.dart';
import 'package:driver/payment/PayFastScreen.dart';
import 'package:driver/payment/paystack/pay_stack_screen.dart';
import 'package:driver/payment/paystack/pay_stack_url_model.dart';
import 'package:driver/payment/paystack/paystack_url_genrater.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WalletController extends GetxController {
  Rx<TextEditingController> withdrawalAmountController =
      TextEditingController().obs;
  Rx<TextEditingController> noteController = TextEditingController().obs;
  Rx<TextEditingController> amountController = TextEditingController().obs;
  Rx<PaymentModel> paymentModel = PaymentModel().obs;
  Rx<DriverUserModel> driverUserModel = DriverUserModel().obs;
  Rx<BankDetailsModel> bankDetailsModel = BankDetailsModel().obs;
  RxString selectedPaymentMethod = "".obs;
  var selectedDateRange = Rx<DateTimeRange?>(null);
  var filteredTransactionList = <WalletTransactionModel>[].obs;
  RxBool isLoading = true.obs;
  RxList<WalletTransactionModel> transactionList =
      <WalletTransactionModel>[].obs;
  var startDate = Rx<DateTime?>(null);
  var endDate = Rx<DateTime?>(null);

  @override
  void onInit() {
    getPaymentData();
    startDate.value = DateTime.now().subtract(const Duration(days: 30));
    endDate.value = DateTime.now();
    _applyDateFilter();
    super.onInit();
  }

  void setStartDate(DateTime date) {
    startDate.value = date;
    _applyDateFilter();
  }

  void setEndDate(DateTime date) {
    endDate.value = date;
    _applyDateFilter();
  }

  void _applyDateFilter() {
    if (startDate.value != null && endDate.value != null) {
      filterTransactionsByDate(startDate.value!, endDate.value!);
    } else if (startDate.value != null) {
      filterTransactionsByDate(startDate.value!, DateTime.now());
    } else if (endDate.value != null) {
      filterTransactionsByDate(DateTime(2000), endDate.value!);
    } else {
      filteredTransactionList.value = transactionList.toList();
    }
  }

  void clearStartDateFilter() {
    startDate.value = null;
    filteredTransactionList.value = transactionList.toList();
  }

  void clearEndDateFilter() {
    endDate.value = null;
    filteredTransactionList.value = transactionList.toList();
  }

  void filterTransactionsByDate(DateTime start, DateTime end) {
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    selectedDateRange.value = DateTimeRange(start: startOfDay, end: endOfDay);
    filteredTransactionList.value = transactionList.where((transaction) {
      if (transaction.createdDate == null) return false;
      final date = transaction.createdDate!.toDate();
      return date
              .isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
          date.isBefore(endOfDay.add(const Duration(milliseconds: 1)));
    }).toList();
  }

  void clearDateFilter() {
    startDate.value = null;
    endDate.value = null;
    selectedDateRange.value = null;
    filteredTransactionList.value = transactionList.toList();
  }

  getPaymentData() async {
    try {
      await getTraction();
      await getUser();
      await FireStoreUtils().getPayment().then((value) {
        if (value != null) {
          paymentModel.value = value;
          Stripe.publishableKey = '';
          Stripe.merchantIdentifier = 'NisaRide';
          Stripe.instance.applySettings();
          log('Stripe initialized with publishable key: ${Stripe.publishableKey}');
          setRef();
        } else {
          log('Failed to load payment model');
          ShowToastDialog.showToast("Payment configuration failed to load.");
        }
      });
      filteredTransactionList.value = transactionList.toList();
    } catch (e) {
      log('Error in getPaymentData: $e');
      ShowToastDialog.showToast("Failed to initialize payment configuration.");
    } finally {
      isLoading.value = false;
      update();
    }
  }

  getUser() async {
    String? currentUid = FireStoreUtils.getCurrentUid();
    if (currentUid != null) {
      await FireStoreUtils.getDriverProfile(currentUid).then((value) {
        if (value != null) {
          driverUserModel.value = value;
        }
      });
      await FireStoreUtils.getBankDetails().then((value) {
        if (value != null) {
          bankDetailsModel.value = value;
        }
      });
    }
  }

  getTraction() async {
    await FireStoreUtils.getWalletTransaction().then((value) {
      if (value != null) {
        transactionList.value = value;
      }
    });
  }

  walletTopUp() async {
    WalletTransactionModel transactionModel = WalletTransactionModel(
        id: Constant.getUuid(),
        amount: amountController.value.text,
        createdDate: Timestamp.now(),
        paymentType: selectedPaymentMethod.value,
        transactionId: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: FireStoreUtils.getCurrentUid(),
        userType: "driver",
        note: "Wallet Topup");
    await FireStoreUtils.setWalletTransaction(transactionModel)
        .then((value) async {
      if (value == true) {
        await FireStoreUtils.updatedDriverWallet(
                amount: amountController.value.text)
            .then((value) {
          getUser();
          getTraction();
        });
      }
    });
    ShowToastDialog.showToast("Amount added in your wallet.");
  }

  Future<void> stripeMakePayment({required String amount}) async {
    // if (Stripe.publishableKey.isEmpty) {
    //   ShowToastDialog.showToast("Payment configuration was not initialized.");
    //   log('Stripe publishable key is empty');
    //   return;
    // }
    try {
      log('Attempting Stripe payment for amount: ${double.parse(amount).toStringAsFixed(0)}');
      Map<String, dynamic>? paymentIntentData =
          await createStripeIntent(amount: amount);
      if (paymentIntentData == null || paymentIntentData.containsKey('error')) {
        ShowToastDialog.showToast(
            "Failed to create payment intent. Please contact admin.");
        return;
      }
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['client_secret'],
          allowsDelayedPaymentMethods: false,
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            testEnv: true,
            currencyCode: 'USD',
          ),
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: AppColors.primary,
            ),
          ),
          merchantDisplayName: 'NisaRide',
        ),
      );
      await displayStripePaymentSheet(amount: amount);
    } catch (e, s) {
      log('Stripe payment error: $e\n$s');
      ShowToastDialog.showToast('Payment error: $e');
    } finally {
      if (Get.isDialogOpen == true) {
        Get.back();
      }
    }
  }

  Future<void> displayStripePaymentSheet({required String amount}) async {
    try {
      await Stripe.instance.presentPaymentSheet();
      ShowToastDialog.showToast('Payment successful');
      await walletTopUp();
    } on StripeException catch (e) {
      final error = StripePayFailedModel.fromJson(jsonDecode(jsonEncode(e)));
      ShowToastDialog.showToast(error.error.message ?? 'Payment failed');
    } catch (e) {
      ShowToastDialog.showToast('Unexpected error: $e');
    } finally {
      if (Get.isDialogOpen == true) {
        Get.back();
      }
    }
  }

  Future<Map<String, dynamic>?> createStripeIntent(
      {required String amount}) async {
    try {
      Map<String, dynamic> body = {
        'amount': ((double.parse(amount) * 100).round()).toString(),
        'currency': 'USD',
        'payment_method_types[]': 'card',
        'description': 'Stripe Payment',
        'shipping[name]': driverUserModel.value.fullName ?? 'Unknown',
        'shipping[address][line1]': '510 Townsend St',
        'shipping[address][postal_code]': '98140',
        'shipping[address][city]': 'San Francisco',
        'shipping[address][state]': 'CA',
        'shipping[address][country]': 'US',
      };
      const stripeSecret = '';
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {
          'Authorization': 'Bearer $stripeSecret',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );
      log('Stripe API response: ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      log('Error creating Stripe intent: $e');
      return {'error': e.toString()};
    }
  }

  flutterWaveInitiatePayment(
      {required BuildContext context, required String amount}) async {
    final url = Uri.parse('https://api.flutterwave.com/v3/payments');
    final headers = {
      'Authorization': 'Bearer ${paymentModel.value.flutterWave!.secretKey}',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      "tx_ref": _ref,
      "amount": amount,
      "currency": "NGN",
      "redirect_url": "${Constant.globalUrl}payment/success",
      "payment_options": "ussd, card, barter, payattitude",
      "customer": {
        "email": driverUserModel.value.email.toString(),
        "phonenumber": driverUserModel.value.phoneNumber ?? '',
        "name": driverUserModel.value.fullName ?? 'Unknown',
      },
      "customizations": {
        "title": "Payment for Services",
        "description": "Payment for XYZ services",
      }
    });
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      Get.to(MercadoPagoScreen(initialURl: data['data']['link']))!
          .then((value) {
        if (value) {
          ShowToastDialog.showToast("Payment Successful!!");
          walletTopUp();
        } else {
          ShowToastDialog.showToast("Payment UnSuccessful!!");
        }
      });
    } else {
      ShowToastDialog.showToast("Something went wrong, please contact admin.");
      log('Payment initialization failed: ${response.body}');
      return null;
    }
  }

  String? _ref;

  setRef() {
    maths.Random numRef = maths.Random();
    int year = DateTime.now().year;
    int refNumber = numRef.nextInt(20000);
    if (Platform.isAndroid) {
      _ref = "AndroidRef$year$refNumber";
    } else if (Platform.isIOS) {
      _ref = "IOSRef$year$refNumber";
    }
  }

  Future<void> startTransaction(context,
      {required String txnTokenBy,
      required orderId,
      required double amount,
      required callBackURL,
      required isStaging}) async {
    // try {
    //   var response = AllInOneSdk.startTransaction(
    //     paymentModel.value.paytm!.paytmMID.toString(),
    //     orderId,
    //     amount.toString(),
    //     txnTokenBy,
    //     callBackURL,
    //     isStaging,
    //     true,
    //     true,
    //   );
    //   response.then((value) {
    //     if (value!["RESPMSG"] == "Txn Success") {
    //       log("Transaction successful");
    //       ShowToastDialog.showToast("Payment Successful!!");
    //       walletTopUp();
    //     }
    //   }).catchError((onError) {
    //     if (onError is PlatformException) {
    //       ShowToastDialog.showToast(onError.message.toString());
    //     } else {
    //       ShowToastDialog.showToast(onError.toString());
    //     }
    //   });
    // } catch (err) {
    //   ShowToastDialog.showToast(err.toString());
    // }
  }

  String generateBasicAuthHeader(String apiKey) {
    String credentials = '$apiKey:';
    String base64Encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $base64Encoded';
  }

  static String accessToken = '';
  static String payToken = '';
  static String orderId = '';
  static String amount = '';

  static reset() {
    accessToken = '';
    payToken = '';
    orderId = '';
    amount = '';
  }
}
