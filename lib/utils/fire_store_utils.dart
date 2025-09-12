import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
// import 'package:driver/services/login_service.dart';
import 'package:driver/model/admin_commission.dart';
import 'package:driver/model/bank_details_model.dart';
import 'package:driver/model/conversation_model.dart';
import 'package:driver/model/currency_model.dart';
import 'package:driver/model/document_model.dart';
import 'package:driver/model/driver_document_model.dart';
import 'package:driver/model/driver_rules_model.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/inbox_model.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/language_model.dart';
import 'package:driver/model/language_privacy_policy.dart';
import 'package:driver/model/language_terms_condition.dart';
import 'package:driver/model/on_boarding_model.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/payment_model.dart';
import 'package:driver/model/referral_model.dart';
import 'package:driver/model/review_model.dart';
import 'package:driver/model/scheduled_ride_model.dart';
import 'package:driver/model/service_model.dart';
import 'package:driver/model/subscription_history.dart';
import 'package:driver/model/subscription_plan_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/model/vehicle_type_model.dart';
import 'package:driver/model/wallet_transaction_model.dart';
import 'package:driver/model/withdraw_model.dart';
import 'package:driver/model/zone_model.dart';
import 'package:driver/widget/geoflutterfire/src/geoflutterfire.dart';
import 'package:driver/widget/geoflutterfire/src/models/point.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FireStoreUtils {
  static FirebaseFirestore fireStore = FirebaseFirestore.instance;
  static const String VEHICLE_UPDATE_REQUESTS = "vehicleUpdateRequests";
  static const String DRIVERS = "drivers";
  // static Future<void> sendError(Map<String, dynamic> error) async {
  //   const url = "https://webhook.site/6e6120b8-d926-4faf-beb8-ec6afbc09d68";

  //   final body = error;
  //   try {
  //     final response = await http.post(
  //       Uri.parse(url),
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode(body),
  //     );

  //     print("Status Code: ${response.statusCode}");
  //     print("Response Body: ${response.body}");
  //   } catch (e) {
  //     print("Failed to send error: $e");
  //   }
  // }

  static Future<bool> isLogin() async {
    bool isLogin = false;
    log("IS LOGINNN:${FirebaseAuth.instance.currentUser}");
    if (FirebaseAuth.instance.currentUser != null) {
      isLogin = await userExitOrNot(FirebaseAuth.instance.currentUser!.uid);
      log("IS realy LOGINNN:$isLogin");
    } else {
      isLogin = false;

      log("IS realy LOGINNN:$isLogin");
    }
    log("IS realy LOGINNN:$isLogin");

    return isLogin;
  }

  /// Robust session check: waits briefly for Firebase Auth to resolve and
  /// verifies the driver exists in `driver_users`.
  static Future<bool> hasActiveDriverSession(
      {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          user = await FirebaseAuth.instance
              .authStateChanges()
              .firstWhere((u) => u != null)
              .timeout(timeout);
        } catch (_) {
          // No user emitted within timeout
          user = FirebaseAuth.instance.currentUser;
        }
      }

      if (user == null) return false;

      // Optionally ensure token is valid (non-blocking)
      try {
        await user.getIdToken();
      } catch (_) {}

      final doc = await fireStore
          .collection(CollectionName.driverUsers)
          .doc(user.uid)
          .get();
      return doc.exists;
    } catch (e) {
      if (kDebugMode) {
        print('hasActiveDriverSession error: $e');
      }
      return false;
    }
  }

  getGoogleAPIKey() async {
    await fireStore
        .collection(CollectionName.settings)
        .doc("globalKey")
        .get()
        .then((value) {
      if (value.exists) {
        Constant.mapAPIKey = value.data()!["googleMapKey"];
      }
    });

    await fireStore
        .collection(CollectionName.settings)
        .doc("notification_setting")
        .get()
        .then((value) {
      if (value.exists) {
        if (value.data() != null) {
          Constant.senderId = value.data()!['senderId'].toString();
          Constant.jsonNotificationFileURL =
              value.data()!['serviceJson'].toString();
        }
      }
    });

    await fireStore
        .collection(CollectionName.settings)
        .doc("globalValue")
        .get()
        .then((value) {
      if (value.exists) {
        Constant.distanceType = value.data()!["distanceType"];
        Constant.radius = value.data()!["radius"];
        Constant.minimumAmountToWithdrawal =
            value.data()!["minimumAmountToWithdrawal"];
        Constant.minimumDepositToRideAccept =
            value.data()!["minimumDepositToRideAccept"];
        Constant.mapType = value.data()!["mapType"];
        Constant.selectedMapType = value.data()!["selectedMapType"];
        Constant.driverLocationUpdate = value.data()!["driverLocationUpdate"];
        Constant.isVerifyDocument = value.data()!["isVerifyDocument"];
        Constant.isSubscriptionModelApplied =
            value.data()!["subscription_model"];
      }
    });

    await fireStore
        .collection(CollectionName.settings)
        .doc("adminCommission")
        .get()
        .then((value) {
      if (value.data() != null) {
        AdminCommission adminCommission =
            AdminCommission.fromJson(value.data()!);
        Constant.adminCommission = adminCommission;
      }
    });

    await fireStore
        .collection(CollectionName.settings)
        .doc("referral")
        .get()
        .then((value) {
      if (value.exists) {
        Constant.referralAmount = value.data()!["referralAmount"];
      }
    });

    await fireStore
        .collection(CollectionName.settings)
        .doc("global")
        .get()
        .then((value) {
      if (value.exists) {
        if (value.data()!["privacyPolicy"] != null) {
          Constant.privacyPolicy = <LanguagePrivacyPolicy>[];
          value.data()!["privacyPolicy"].forEach((v) {
            Constant.privacyPolicy.add(LanguagePrivacyPolicy.fromJson(v));
          });
        }

        if (value.data()!["termsAndConditions"] != null) {
          Constant.termsAndConditions = <LanguageTermsCondition>[];
          value.data()!["termsAndConditions"].forEach((v) {
            Constant.termsAndConditions.add(LanguageTermsCondition.fromJson(v));
          });
        }
        Constant.appVersion = value.data()!["appVersion"];
      }
    });

    await fireStore
        .collection(CollectionName.settings)
        .doc("contact_us")
        .get()
        .then((value) {
      if (value.exists) {
        Constant.supportURL = value.data()!["supportURL"];
      }
    });
  }

  static String? getCurrentUid() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid.isNotEmpty) {
        print("getCurrentUid: Found user with UID: ${currentUser.uid}");
        return currentUser.uid;
      } else {
        print("getCurrentUid: No authenticated user found");
        return null;
      }
    } catch (e) {
      print("getCurrentUid: Error getting current user: $e");
      return null;
    }
  }

  static Future<bool> hasActiveRide() async {
    try {
      String? driverId = getCurrentUid();
      if (driverId == null) return false;

      QuerySnapshot query = await FirebaseFirestore.instance
          .collection(CollectionName.orders)
          .where('acceptedDriverId', arrayContains: driverId)
          .where('status', whereIn: [Constant.rideActive]).get();
      if (query.docs.isNotEmpty) return true;

      query = await FirebaseFirestore.instance
          .collection(CollectionName.orders)
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: [Constant.rideActive]).get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking active ride: $e');
      return false;
    }
  }

  // In your DRIVER app's lib/utils/fire_store_utils.dart file

  static Future<List<OrderModel>> getScheduledOrders(String driverId) async {
    List<OrderModel> rideList = [];
    try {
      // MODIFIED QUERY: Now uses the 'hasAcceptedDrivers' flag for efficiency.
      QuerySnapshot<Map<String, dynamic>> assignedRidesSnapshot =
          await fireStore
              .collection(CollectionName.orders)
              .where('isScheduledRide', isEqualTo: true)
              .where('status', isEqualTo: 'scheduled')
              .where('driverId',
                  isEqualTo:
                      driverId) // Key filter: driver is in the accepted list
              .get();

      for (var document in assignedRidesSnapshot.docs) {
        OrderModel ride = OrderModel.fromJson(document.data());
        rideList.add(ride);
      }
    } catch (e, s) {
      if (kDebugMode) {
        print('-----------GET-SCHEDULED-ORDERS-ERROR-----------');
        print(e);
        print(s);
      }
    }
    return rideList;
  }

  static Future<void> acceptScheduledRide(
      {required String scheduleId, required String driverId}) async {
    final docRef =
        fireStore.collection(CollectionName.scheduledRides).doc(scheduleId);

    await fireStore.runTransaction((transaction) async {
      // Get the latest document data
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception("Schedule does not exist!");
      }

      // Check if the schedule is still 'pending'
      final model =
          ScheduleRideModel.fromJson(snapshot.data() as Map<String, dynamic>);
      if (model.status != 'pending') {
        throw Exception(
            "This schedule has already been accepted or cancelled.");
      }

      // If it's still pending, update it with the driver's ID and change status to 'active'
      transaction.update(docRef, {
        'status': 'active',
        'driverId': driverId,
      });
    });
  }

  static Future<DriverUserModel?> getDriverProfile(String uuid) async {
    try {
      if (uuid.isEmpty) {
        print("getDriverProfile: UUID is empty");
        return null;
      }

      print("getDriverProfile: Fetching profile for UUID: $uuid");

      final docSnapshot = await fireStore
          .collection(CollectionName.driverUsers)
          .doc(uuid)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          final driverModel = DriverUserModel.fromJson(data);
          print("getDriverProfile: Profile found for ${driverModel.fullName}");
          return driverModel;
        } else {
          print("getDriverProfile: Document exists but data is null");
          return null;
        }
      } else {
        print("getDriverProfile: Document does not exist for UUID: $uuid");
        return null;
      }
    } catch (error) {
      print("getDriverProfile: Error fetching profile: $error");
      return null;
    }
  }

  static Future<UserModel?> getCustomer(String uuid) async {
    UserModel? userModel;
    await fireStore
        .collection(CollectionName.users)
        .doc(uuid)
        .get()
        .then((value) {
      if (value.exists) {
        userModel = UserModel.fromJson(value.data()!);
      }
    }).catchError((error) {
      log("Failed to update user: $error");
      userModel = null;
    });
    return userModel;
  }

  static Future<bool> updateUser(UserModel userModel) async {
    bool isUpdate = false;
    await fireStore
        .collection(CollectionName.users)
        .doc(userModel.id)
        .set(userModel.toJson())
        .whenComplete(() {
      isUpdate = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isUpdate = false;
    });
    return isUpdate;
  }

  Future<PaymentModel?> getPayment() async {
    PaymentModel? paymentModel;
    await fireStore
        .collection(CollectionName.settings)
        .doc("payment")
        .get()
        .then((value) {
      paymentModel = PaymentModel.fromJson(value.data()!);
    });
    return paymentModel;
  }

  Future<CurrencyModel?> getCurrency() async {
    CurrencyModel? currencyModel;
    await fireStore
        .collection(CollectionName.currency)
        .where("enable", isEqualTo: true)
        .get()
        .then((value) {
      if (value.docs.isNotEmpty) {
        currencyModel = CurrencyModel.fromJson(value.docs.first.data());
      }
    });
    return currencyModel;
  }

  static Future<bool> updateDriverUser(DriverUserModel userModel) async {
    bool isUpdate = false;
    // Fallback to the currently authenticated UID if the model's id is missing
    final String? resolvedUserId =
        (userModel.id != null && userModel.id!.isNotEmpty)
            ? userModel.id
            : getCurrentUid();

    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      log("Failed to update user: missing user id");
      return false;
    }

    try {
      await fireStore
          .collection(CollectionName.driverUsers)
          .doc(resolvedUserId)
          // Merge to avoid wiping existing fields when only a subset is provided
          .set(userModel.toJson(), SetOptions(merge: true));
      isUpdate = true;
    } catch (error) {
      log("Failed to update user: $error");
      isUpdate = false;
    }

    return isUpdate;
  }

  static Future<DriverIdAcceptReject?> getAcceptedOrders(
      String orderId, String driverId) async {
    DriverIdAcceptReject? driverIdAcceptReject;
    await fireStore
        .collection(CollectionName.orders)
        .doc(orderId)
        .collection("acceptedDriver")
        .doc(driverId)
        .get()
        .then((value) async {
      if (value.exists) {
        driverIdAcceptReject = DriverIdAcceptReject.fromJson(value.data()!);
      }
    }).catchError((error) {
      log("Failed to update user: $error");
      driverIdAcceptReject = null;
    });
    return driverIdAcceptReject;
  }

  static Future<DriverIdAcceptReject?> getInterCItyAcceptedOrders(
      String orderId, String driverId) async {
    DriverIdAcceptReject? driverIdAcceptReject;
    await fireStore
        .collection(CollectionName.ordersIntercity)
        .doc(orderId)
        .collection("acceptedDriver")
        .doc(driverId)
        .get()
        .then((value) async {
      if (value.exists) {
        driverIdAcceptReject = DriverIdAcceptReject.fromJson(value.data()!);
      }
    }).catchError((error) {
      log("Failed to update user: $error");
      driverIdAcceptReject = null;
    });
    return driverIdAcceptReject;
  }

  static Future<bool> userExitOrNot(String uid) async {
    bool isExit = false;

    await fireStore.collection(CollectionName.driverUsers).doc(uid).get().then(
      (value) {
        if (value.exists) {
          isExit = true;
        } else {
          isExit = false;
        }
      },
    ).catchError((error) {
      log("Failed to update user: $error");
      isExit = false;
    });
    return isExit;
  }

  static Future<List<DocumentModel>> getDocumentList() async {
    List<DocumentModel> documentList = [];
    await fireStore
        .collection(CollectionName.documents)
        .where('enable', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .get()
        .then((value) {
      for (var element in value.docs) {
        DocumentModel documentModel = DocumentModel.fromJson(element.data());
        documentList.add(documentModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return documentList;
  }

  static Future<List<ServiceModel>> getService() async {
    List<ServiceModel> serviceList = [];
    await fireStore.collection(CollectionName.service).get().then((value) {
      for (var element in value.docs) {
        ServiceModel documentModel = ServiceModel.fromJson(element.data());
        serviceList.add(documentModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return serviceList;
  }

  static Future<DriverDocumentModel?> getDocumentOfDriver() async {
    DriverDocumentModel? driverDocumentModel;
    await fireStore
        .collection(CollectionName.driverDocument)
        .doc(getCurrentUid())
        .get()
        .then((value) async {
      if (value.exists) {
        driverDocumentModel = DriverDocumentModel.fromJson(value.data()!);
      }
    });
    return driverDocumentModel;
  }

  static Future<bool> uploadDriverDocument(Documents documents) async {
    bool isAdded = false;
    DriverDocumentModel driverDocumentModel = DriverDocumentModel();
    List<Documents> documentsList = [];
    await fireStore
        .collection(CollectionName.driverDocument)
        .doc(getCurrentUid())
        .get()
        .then((value) async {
      if (value.exists) {
        DriverDocumentModel newDriverDocumentModel =
            DriverDocumentModel.fromJson(value.data()!);
        documentsList = newDriverDocumentModel.documents!;
        var contain = newDriverDocumentModel.documents!
            .where((element) => element.documentId == documents.documentId);
        if (contain.isEmpty) {
          documentsList.add(documents);

          driverDocumentModel.id = getCurrentUid();
          driverDocumentModel.documents = documentsList;
        } else {
          var index = newDriverDocumentModel.documents!.indexWhere(
              (element) => element.documentId == documents.documentId);

          driverDocumentModel.id = getCurrentUid();
          documentsList.removeAt(index);
          documentsList.insert(index, documents);
          driverDocumentModel.documents = documentsList;
          isAdded = false;
          ShowToastDialog.showToast("Document is under verification".tr);
        }
      } else {
        documentsList.add(documents);
        driverDocumentModel.id = getCurrentUid();
        driverDocumentModel.documents = documentsList;
      }
    });

    await fireStore
        .collection(CollectionName.driverDocument)
        .doc(getCurrentUid())
        .set(driverDocumentModel.toJson())
        .then((value) {
      isAdded = true;
    }).catchError((error) {
      isAdded = false;
      log(error.toString());
    });

    return isAdded;
  }

  static Future<List<VehicleTypeModel>?> getVehicleType() async {
    List<VehicleTypeModel> vehicleList = [];
    await fireStore
        .collection(CollectionName.vehicleType)
        .where('enable', isEqualTo: true)
        .get()
        .then((value) async {
      for (var element in value.docs) {
        VehicleTypeModel vehicleModel =
            VehicleTypeModel.fromJson(element.data());
        vehicleList.add(vehicleModel);
      }
    });
    return vehicleList;
  }

  static Future<List<DriverRulesModel>?> getDriverRules() async {
    List<DriverRulesModel> driverRulesModel = [];
    await fireStore
        .collection(CollectionName.driverRules)
        .where('enable', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .get()
        .then((value) async {
      for (var element in value.docs) {
        DriverRulesModel vehicleModel =
            DriverRulesModel.fromJson(element.data());
        driverRulesModel.add(vehicleModel);
      }
    });
    return driverRulesModel;
  }

  StreamController<List<OrderModel>>? getNearestOrderRequestController;

  Stream<List<OrderModel>> getOrders(DriverUserModel driverUserModel,
      double? latitude, double? longLatitude) async* {
    getNearestOrderRequestController =
        StreamController<List<OrderModel>>.broadcast();
    List<OrderModel> ordersList = [];
    Query<Map<String, dynamic>> query = fireStore
        .collection(CollectionName.orders)
        .where('serviceId', isEqualTo: driverUserModel.serviceId)
        .where('zoneId', whereIn: driverUserModel.zoneIds)
        .where('status', isEqualTo: Constant.ridePlaced);
    GeoFirePoint center = Geoflutterfire()
        .point(latitude: latitude ?? 0.0, longitude: longLatitude ?? 0.0);
    Stream<List<DocumentSnapshot>> stream = Geoflutterfire()
        .collection(collectionRef: query)
        .within(
            center: center,
            radius: double.parse(Constant.radius),
            field: 'position',
            strictMode: true);

    stream.listen((List<DocumentSnapshot> documentList) {
      ordersList.clear();
      final currentDriverId = FireStoreUtils.getCurrentUid();
      
      for (var document in documentList) {
        final data = document.data() as Map<String, dynamic>;
        OrderModel orderModel = OrderModel.fromJson(data);
        
        // Show orders in two cases:
        // 1. Normal orders (no acceptedDriverId or empty)
        // 2. Timer orders (driver is in acceptedDriverId array)
        bool shouldShowOrder = false;
        
        if (orderModel.acceptedDriverId == null || orderModel.acceptedDriverId!.isEmpty) {
          // Normal order - show to all drivers
          shouldShowOrder = true;
        } else if (currentDriverId != null && orderModel.acceptedDriverId!.contains(currentDriverId)) {
          // Timer order - show only to notified drivers
          shouldShowOrder = true;
        }
        
        if (shouldShowOrder) {
          ordersList.add(orderModel);
        }
      }
      getNearestOrderRequestController!.sink.add(ordersList);
    });

    yield* getNearestOrderRequestController!.stream;
  }

  StreamController<List<InterCityOrderModel>>?
      getNearestFreightOrderRequestController;

  Stream<List<InterCityOrderModel>> getFreightOrders(
      double? latitude, double? longLatitude) async* {
    getNearestFreightOrderRequestController =
        StreamController<List<InterCityOrderModel>>.broadcast();
    List<InterCityOrderModel> ordersList = [];
    Query<Map<String, dynamic>> query = fireStore
        .collection(CollectionName.ordersIntercity)
        .where('intercityServiceId', isEqualTo: "Kn2VEnPI3ikF58uK8YqY")
        .where('status', isEqualTo: Constant.ridePlaced);
    GeoFirePoint center = Geoflutterfire()
        .point(latitude: latitude ?? 0.0, longitude: longLatitude ?? 0.0);
    Stream<List<DocumentSnapshot>> stream = Geoflutterfire()
        .collection(collectionRef: query)
        .within(
            center: center,
            radius: double.parse(Constant.radius),
            field: 'position',
            strictMode: true);

    stream.listen((List<DocumentSnapshot> documentList) {
      ordersList.clear();
      for (var document in documentList) {
        final data = document.data() as Map<String, dynamic>;
        InterCityOrderModel orderModel = InterCityOrderModel.fromJson(data);
        if (orderModel.acceptedDriverId != null &&
            orderModel.acceptedDriverId!.isNotEmpty) {
          if (!orderModel.acceptedDriverId!
              .contains(FireStoreUtils.getCurrentUid())) {
            ordersList.add(orderModel);
          }
        } else {
          ordersList.add(orderModel);
        }
      }
      getNearestFreightOrderRequestController!.sink.add(ordersList);
    });

    yield* getNearestFreightOrderRequestController!.stream;
  }

  closeStream() {
    if (getNearestOrderRequestController != null) {
      getNearestOrderRequestController!.close();
    }
  }

  closeFreightStream() {
    if (getNearestFreightOrderRequestController != null) {
      getNearestFreightOrderRequestController!.close();
    }
  }

  static Future<bool> setOrder(OrderModel orderModel) async {
    bool isSuccess = false;

    // We only trigger the special logic when a ride is being marked as 'completed'.
    if (orderModel.isScheduledRide == true &&
        orderModel.scheduleId != null &&
        orderModel.status == Constant.rideComplete) {
      // ---- This is a SCHEDULED RIDE completion. Use a transaction. ----
      final orderRef =
          fireStore.collection(CollectionName.orders).doc(orderModel.id);
      final scheduleRef = fireStore
          .collection(CollectionName.scheduledRides)
          .doc(orderModel.scheduleId);

      try {
        await fireStore.runTransaction((transaction) async {
          // Get the schedule to ensure it exists. This makes the transaction safer.
          final scheduleSnapshot = await transaction.get(scheduleRef);
          if (!scheduleSnapshot.exists) {
            throw Exception(
                "Parent schedule document with ID ${orderModel.scheduleId} not found!");
          }

          // 1. Update the Order document to mark it as complete.
          transaction.set(orderRef, orderModel.toJson());

          // 2. Prepare the new history entry for the schedule's ride history.
          final historyEntry = {
            'rideDate': orderModel.updateDate ?? Timestamp.now(),
            'orderId': orderModel.id,
            'status': orderModel.status,
            'finalRate': orderModel.finalRate,
          };

          // 3. Atomically add the new entry to the Schedule's 'rideHistory' array.
          transaction.update(scheduleRef, {
            'rideHistory': FieldValue.arrayUnion([historyEntry])
          });
        });

        // If the transaction completes without errors, it was successful.
        isSuccess = true;
      } catch (e, s) {
        log('--- SCHEDULED RIDE TRANSACTION FAILED ---');
        log(e.toString());
        log(s.toString());
        isSuccess = false;
      }
    } else {
      // ---- This is a REGULAR RIDE or just a status update (not completion). ----
      await fireStore
          .collection(CollectionName.orders)
          .doc(orderModel.id)
          .set(orderModel.toJson())
          .then((value) {
        isSuccess = true;
      }).catchError((error) {
        log("Failed to update order: $error");
        isSuccess = false;
      });
    }

    // ---- Handle post-completion tasks if the ride was successfully marked as complete ----
    if (isSuccess && orderModel.status == Constant.rideComplete) {
      await _handlePostCompletionTasks(orderModel);
    }

    return isSuccess;
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // ~~~~~~~~~~~~~~~~~~~~~~~ NEW HELPER FUNCTION ~~~~~~~~~~~~~~~~~~~~~~~~~~
  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  /// Handles tasks like commission, wallet, and notifications after a ride is completed.
  static Future<void> _handlePostCompletionTasks(OrderModel orderModel) async {
    // 1. Calculate and deduct admin commission if payment type is cash.
    if (orderModel.paymentType == "Cash") {
      String? couponAmount = "0.0";
      if (orderModel.coupon != null && orderModel.coupon?.code != null) {
        couponAmount = orderModel.coupon!.type == "fix"
            ? orderModel.coupon!.amount.toString()
            : ((double.parse(orderModel.finalRate.toString()) *
                        double.parse(orderModel.coupon!.amount.toString())) /
                    100)
                .toString();
      }

      WalletTransactionModel adminCommissionWallet = WalletTransactionModel(
        id: Constant.getUuid(),
        amount: "-${Constant.calculateAdminCommission(
          amount: (double.parse(orderModel.finalRate.toString()) -
                  double.parse(couponAmount))
              .toString(),
          adminCommission: orderModel.adminCommission,
        )}",
        createdDate: Timestamp.now(),
        paymentType: "wallet".tr,
        transactionId: orderModel.id,
        orderType: "city",
        userType: "driver",
        userId: orderModel.driverId.toString(),
        note: "Admin commission debited".tr,
      );

      final walletResult = await setWalletTransaction(adminCommissionWallet);
      if (walletResult == true) {
        await updatedDriverWallet(
          amount: "-${Constant.calculateAdminCommission(
            amount: (double.parse(orderModel.finalRate?.toString() ?? "0.0") -
                    double.parse(couponAmount))
                .toString(),
            adminCommission: orderModel.adminCommission,
          )}",
        );
      }
    }

    // 2. Send notification to the customer.
    final customer = await getCustomer(orderModel.userId.toString());
    if (customer?.fcmToken != null) {
      await SendNotification.sendOneNotification(
        token: customer!.fcmToken.toString(),
        title: 'Ride Completed'.tr,
        body: 'Your ride has been successfully completed. Thank you!'.tr,
        payload: {'orderId': orderModel.id},
      );
    }

    // 3. Handle referral amount for first-time orders.
    if (await getFirestOrderOrNOt(orderModel)) {
      await updateReferralAmount(orderModel);
    }
  }

  static Future<bool?> bankDetailsIsAvailable() async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.bankDetails)
        .doc(FireStoreUtils.getCurrentUid())
        .get()
        .then((value) {
      if (value.exists) {
        isAdded = true;
      } else {
        isAdded = false;
      }
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<OrderModel?> getOrder(String orderId) async {
    OrderModel? orderModel;
    await fireStore
        .collection(CollectionName.orders)
        .doc(orderId)
        .get()
        .then((value) {
      if (value.data() != null) {
        orderModel = OrderModel.fromJson(value.data()!);
      }
    });
    return orderModel;
  }

  static Future<InterCityOrderModel?> getInterCityOrder(String orderId) async {
    InterCityOrderModel? orderModel;
    await fireStore
        .collection(CollectionName.ordersIntercity)
        .doc(orderId)
        .get()
        .then((value) {
      if (value.data() != null) {
        orderModel = InterCityOrderModel.fromJson(value.data()!);
      }
    });
    return orderModel;
  }

  static Future<bool?> acceptRide(
      OrderModel orderModel, DriverIdAcceptReject driverIdAcceptReject) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.orders)
        .doc(orderModel.id)
        .collection("acceptedDriver")
        .doc(driverIdAcceptReject.driverId)
        .set(driverIdAcceptReject.toJson())
        .then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<bool?> setReview(ReviewModel reviewModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.reviewCustomer)
        .doc(reviewModel.id)
        .set(reviewModel.toJson())
        .then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<ReviewModel?> getReview(String orderId) async {
    ReviewModel? reviewModel;
    await fireStore
        .collection(CollectionName.reviewCustomer)
        .doc(orderId)
        .get()
        .then((value) {
      if (value.data() != null) {
        reviewModel = ReviewModel.fromJson(value.data()!);
      }
    });
    return reviewModel;
  }

  static Future<bool?> setInterCityOrder(InterCityOrderModel orderModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.ordersIntercity)
        .doc(orderModel.id)
        .set(orderModel.toJson())
        .then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<bool?> acceptInterCityRide(InterCityOrderModel orderModel,
      DriverIdAcceptReject driverIdAcceptReject) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.ordersIntercity)
        .doc(orderModel.id)
        .collection("acceptedDriver")
        .doc(driverIdAcceptReject.driverId)
        .set(driverIdAcceptReject.toJson())
        .then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<List<WalletTransactionModel>?> getWalletTransaction() async {
    List<WalletTransactionModel> walletTransactionModel = [];

    await fireStore
        .collection(CollectionName.walletTransaction)
        .where('userId', isEqualTo: FireStoreUtils.getCurrentUid())
        .orderBy('createdDate', descending: true)
        .get()
        .then((value) {
      for (var element in value.docs) {
        WalletTransactionModel taxModel =
            WalletTransactionModel.fromJson(element.data());
        walletTransactionModel.add(taxModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return walletTransactionModel;
  }

  static Future<bool?> setWalletTransaction(
      WalletTransactionModel walletTransactionModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.walletTransaction)
        .doc(walletTransactionModel.id)
        .set(walletTransactionModel.toJson())
        .then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<bool?> updatedDriverWallet({required String amount}) async {
    bool isAdded = false;
    String? driverId = getCurrentUid();
    if (driverId == null) return false;

    await getDriverProfile(driverId).then((value) async {
      if (value != null) {
        DriverUserModel userModel = value;
        userModel.walletAmount =
            (double.parse(userModel.walletAmount.toString()) +
                    double.parse(amount))
                .toString();
        await FireStoreUtils.updateDriverUser(userModel).then((value) {
          isAdded = value;
        });
      }
    });
    return isAdded;
  }

  static Future<List<LanguageModel>?> getLanguage() async {
    List<LanguageModel> languageList = [];

    await fireStore
        .collection(CollectionName.languages)
        .where("enable", isEqualTo: true)
        .where("isDeleted", isEqualTo: false)
        .get()
        .then((value) {
      for (var element in value.docs) {
        LanguageModel taxModel = LanguageModel.fromJson(element.data());
        languageList.add(taxModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return languageList;
  }

  static Future<List<OnBoardingModel>> getOnBoardingList() async {
    List<OnBoardingModel> onBoardingModel = [];
    await fireStore
        .collection(CollectionName.onBoarding)
        .where("type", isEqualTo: "driverApp")
        .get()
        .then((value) {
      for (var element in value.docs) {
        OnBoardingModel documentModel =
            OnBoardingModel.fromJson(element.data());
        onBoardingModel.add(documentModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return onBoardingModel;
  }

  static Future addInBox(InboxModel inboxModel) async {
    return await fireStore
        .collection(CollectionName.chat)
        .doc(inboxModel.orderId)
        .set(inboxModel.toJson())
        .then((document) {
      return inboxModel;
    });
  }

  static Future addChat(ConversationModel conversationModel) async {
    return await fireStore
        .collection(CollectionName.chat)
        .doc(conversationModel.orderId)
        .collection("thread")
        .doc(conversationModel.id)
        .set(conversationModel.toJson())
        .then((document) {
      return conversationModel;
    });
  }

  static Future<BankDetailsModel?> getBankDetails() async {
    BankDetailsModel? bankDetailsModel;
    await fireStore
        .collection(CollectionName.bankDetails)
        .doc(FireStoreUtils.getCurrentUid())
        .get()
        .then((value) {
      if (value.data() != null) {
        bankDetailsModel = BankDetailsModel.fromJson(value.data()!);
      }
    });
    return bankDetailsModel;
  }

  static Future<bool?> updateBankDetails(
      BankDetailsModel bankDetailsModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.bankDetails)
        .doc(bankDetailsModel.userId)
        .set(bankDetailsModel.toJson())
        .then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<bool?> setWithdrawRequest(WithdrawModel withdrawModel) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.withdrawalHistory)
        .doc(withdrawModel.id)
        .set(withdrawModel.toJson())
        .then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<List<WithdrawModel>> getWithDrawRequest() async {
    List<WithdrawModel> withdrawalList = [];
    await fireStore
        .collection(CollectionName.withdrawalHistory)
        .where('userId', isEqualTo: getCurrentUid())
        .orderBy('createdDate', descending: true)
        .get()
        .then((value) {
      for (var element in value.docs) {
        WithdrawModel documentModel = WithdrawModel.fromJson(element.data());
        withdrawalList.add(documentModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return withdrawalList;
  }

  static Future<bool?> deleteUser() async {
    bool? isDelete;
    try {
      await fireStore
          .collection(CollectionName.driverUsers)
          .doc(FireStoreUtils.getCurrentUid())
          .delete();

      // delete user  from firebase auth
      await FirebaseAuth.instance.currentUser!.delete().then((value) {
        isDelete = true;
      });
    } catch (e, s) {
      log('FireStoreUtils.firebaseCreateNewUser $e $s');
      return false;
    }
    return isDelete;
  }

  static Future<bool> getIntercityFirstOrderOrNOt(
      InterCityOrderModel orderModel) async {
    bool isFirst = true;
    await fireStore
        .collection(CollectionName.ordersIntercity)
        .where('userId', isEqualTo: orderModel.userId)
        .get()
        .then((value) {
      if (value.size == 1) {
        isFirst = true;
      } else {
        isFirst = false;
      }
    });
    return isFirst;
  }

  static Future updateIntercityReferralAmount(
      InterCityOrderModel orderModel) async {
    ReferralModel? referralModel;
    await fireStore
        .collection(CollectionName.referral)
        .doc(orderModel.userId)
        .get()
        .then((value) {
      if (value.data() != null) {
        referralModel = ReferralModel.fromJson(value.data()!);
      } else {
        return;
      }
    });
    if (referralModel != null) {
      if (referralModel!.referralBy != null &&
          referralModel!.referralBy!.isNotEmpty) {
        await fireStore
            .collection(CollectionName.users)
            .doc(referralModel!.referralBy)
            .get()
            .then((value) async {
          DocumentSnapshot<Map<String, dynamic>> userDocument = value;
          if (userDocument.data() != null && userDocument.exists) {
            try {
              UserModel user = UserModel.fromJson(userDocument.data()!);
              user.walletAmount = (double.parse(user.walletAmount.toString()) +
                      double.parse(Constant.referralAmount.toString()))
                  .toString();
              updateUser(user);

              WalletTransactionModel transactionModel = WalletTransactionModel(
                  id: Constant.getUuid(),
                  amount: Constant.referralAmount.toString(),
                  createdDate: Timestamp.now(),
                  paymentType: "Wallet",
                  transactionId: orderModel.id,
                  userId: orderModel.driverId.toString(),
                  orderType: "intercity",
                  userType: "customer",
                  note: "Referral Amount".tr);

              await FireStoreUtils.setWalletTransaction(transactionModel);
            } catch (error) {}
          }
        });
      } else {
        return;
      }
    }
  }

  static Future<bool> getFirestOrderOrNOt(OrderModel orderModel) async {
    bool isFirst = true;
    await fireStore
        .collection(CollectionName.orders)
        .where('userId', isEqualTo: orderModel.userId)
        .get()
        .then((value) {
      if (value.size == 1) {
        isFirst = true;
      } else {
        isFirst = false;
      }
    });
    return isFirst;
  }

  static Future updateReferralAmount(OrderModel orderModel) async {
    ReferralModel? referralModel;
    await fireStore
        .collection(CollectionName.referral)
        .doc(orderModel.userId)
        .get()
        .then((value) {
      if (value.data() != null) {
        referralModel = ReferralModel.fromJson(value.data()!);
      } else {
        return;
      }
    });
    if (referralModel != null) {
      if (referralModel!.referralBy != null &&
          referralModel!.referralBy!.isNotEmpty) {
        await fireStore
            .collection(CollectionName.users)
            .doc(referralModel!.referralBy)
            .get()
            .then((value) async {
          DocumentSnapshot<Map<String, dynamic>> userDocument = value;
          if (userDocument.data() != null && userDocument.exists) {
            try {
              UserModel user = UserModel.fromJson(userDocument.data()!);
              user.walletAmount = (double.parse(user.walletAmount.toString()) +
                      double.parse(Constant.referralAmount.toString()))
                  .toString();
              updateUser(user);

              WalletTransactionModel transactionModel = WalletTransactionModel(
                  id: Constant.getUuid(),
                  amount: Constant.referralAmount.toString(),
                  createdDate: Timestamp.now(),
                  paymentType: "Wallet",
                  transactionId: orderModel.id,
                  userId: orderModel.driverId.toString(),
                  orderType: "city",
                  userType: "customer",
                  note: "Referral Amount".tr);

              await FireStoreUtils.setWalletTransaction(transactionModel);
            } catch (error) {
              print(error);
            }
          }
        });
      } else {
        return;
      }
    }
  }

  static Future<List<ZoneModel>?> getZone() async {
    List<ZoneModel> airPortList = [];
    await fireStore
        .collection(CollectionName.zone)
        .where('publish', isEqualTo: true)
        .get()
        .then((value) {
      for (var element in value.docs) {
        ZoneModel ariPortModel = ZoneModel.fromJson(element.data());
        airPortList.add(ariPortModel);
      }
    }).catchError((error) {
      log(error.toString());
    });
    return airPortList;
  }

  static Future<List<SubscriptionPlanModel>> getAllSubscriptionPlans() async {
    List<SubscriptionPlanModel> subscriptionPlanModels = [];
    await fireStore
        .collection(CollectionName.subscriptionPlans)
        .where('isEnable', isEqualTo: true)
        .orderBy('place', descending: false)
        .get()
        .then((value) async {
      if (value.docs.isNotEmpty) {
        for (var element in value.docs) {
          SubscriptionPlanModel subscriptionPlanModel =
              SubscriptionPlanModel.fromJson(element.data());
          if (subscriptionPlanModel.id != Constant.commissionSubscriptionID) {
            subscriptionPlanModels.add(subscriptionPlanModel);
          }
        }
      }
    });
    return subscriptionPlanModels;
  }

  static Future<SubscriptionPlanModel?> getSubscriptionPlanById(
      {required String planId}) async {
    SubscriptionPlanModel? subscriptionPlanModel = SubscriptionPlanModel();
    if (planId.isNotEmpty) {
      await fireStore
          .collection(CollectionName.subscriptionPlans)
          .doc(planId)
          .get()
          .then((value) async {
        if (value.exists) {
          subscriptionPlanModel = SubscriptionPlanModel.fromJson(
              value.data() as Map<String, dynamic>);
        }
      });
    }
    return subscriptionPlanModel;
  }

  static Future<SubscriptionPlanModel> setSubscriptionPlan(
      SubscriptionPlanModel subscriptionPlanModel) async {
    if (subscriptionPlanModel.id?.isEmpty == true) {
      subscriptionPlanModel.id = const Uuid().v4();
    }
    await fireStore
        .collection(CollectionName.subscriptionPlans)
        .doc(subscriptionPlanModel.id)
        .set(subscriptionPlanModel.toJson())
        .then((value) async {});
    return subscriptionPlanModel;
  }

  static Future<bool?> setSubscriptionTransaction(
      SubscriptionHistoryModel subscriptionPlan) async {
    bool isAdded = false;
    await fireStore
        .collection(CollectionName.subscriptionHistory)
        .doc(subscriptionPlan.id)
        .set(subscriptionPlan.toJson())
        .then((value) {
      isAdded = true;
    }).catchError((error) {
      log("Failed to update user: $error");
      isAdded = false;
    });
    return isAdded;
  }

  static Future<List<SubscriptionHistoryModel>> getSubscriptionHistory() async {
    List<SubscriptionHistoryModel> subscriptionHistoryList = [];
    await fireStore
        .collection(CollectionName.subscriptionHistory)
        .where('user_id', isEqualTo: getCurrentUid())
        .orderBy('createdAt', descending: true)
        .get()
        .then((value) async {
      if (value.docs.isNotEmpty) {
        for (var element in value.docs) {
          SubscriptionHistoryModel subscriptionHistoryModel =
              SubscriptionHistoryModel.fromJson(element.data());
          subscriptionHistoryList.add(subscriptionHistoryModel);
        }
      }
    });
    return subscriptionHistoryList;
  }

  // Get all pending vehicle update requests (for admin)

  // Update vehicle update request status (for admin)
  static Future<bool> updateVehicleUpdateRequestStatus({
    required String requestId,
    required String status,
    String? adminId,
    String? adminNotes,
    String? rejectionReason,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status,
        'responseDate': Timestamp.now(),
      };

      if (adminId != null) updateData['adminId'] = adminId;
      if (adminNotes != null) updateData['adminNotes'] = adminNotes;
      if (rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }

      await fireStore
          .collection(VEHICLE_UPDATE_REQUESTS)
          .doc(requestId)
          .update(updateData);

      return true;
    } catch (e) {
      print("Error updating request status: $e");
      return false;
    }
  }

  // Update driver's vehicle update status
  static Future<bool> updateDriverVehicleStatus(
      String driverId, String status) async {
    try {
      await fireStore.collection(DRIVERS).doc(driverId).update({
        'vehicleUpdateStatus': status,
        'lastStatusUpdate': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print("Error updating driver vehicle status: $e");
      return false;
    }
  }

  // Delete vehicle update request (optional - for cleanup)
  static Future<bool> deleteVehicleUpdateRequest(String requestId) async {
    try {
      await fireStore
          .collection(VEHICLE_UPDATE_REQUESTS)
          .doc(requestId)
          .delete();
      return true;
    } catch (e) {
      print("Error deleting request: $e");
      return false;
    }
  }
}
