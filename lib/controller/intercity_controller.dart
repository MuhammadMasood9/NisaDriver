import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/home_intercity_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/ui/home_screens/live_tracking_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class IntercityController extends GetxController {
  HomeIntercityController homeController = Get.put(HomeIntercityController());

  Rx<TextEditingController> sourceCityController = TextEditingController().obs;
  Rx<TextEditingController> destinationCityController =
      TextEditingController().obs;
  Rx<TextEditingController> whenController = TextEditingController().obs;
  Rx<TextEditingController> suggestedTimeController =
      TextEditingController().obs;
  DateTime? suggestedTime = DateTime.now();
  DateTime? dateAndTime = DateTime.now();

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
  }

  RxList<InterCityOrderModel> intercityServiceOrder =
      <InterCityOrderModel>[].obs;
  RxBool isLoading = false.obs;
  RxString newAmount = "0.0".obs;
  Rx<TextEditingController> enterOfferRateController =
      TextEditingController().obs;

  Rx<DriverUserModel> driverModel = DriverUserModel().obs;

  Future<void> acceptOrder(InterCityOrderModel orderModel) async {
    if (double.parse(driverModel.value.walletAmount.toString()) >=
        double.parse(Constant.minimumDepositToRideAccept)) {
      ShowToastDialog.showLoader("Please wait".tr);

      try {
        // Update Firestore document
        Map<String, dynamic> updatedData = {
          'acceptedDriverId': [
            ...(orderModel.acceptedDriverId ?? []),
            FireStoreUtils.getCurrentUid()
          ],
          'driverId': FireStoreUtils.getCurrentUid(),
          'status': Constant.rideActive,
          'finalRate': newAmount.value,
        };

        await FireStoreUtils.fireStore
            .collection(CollectionName.ordersIntercity)
            .doc(orderModel.id)
            .update(updatedData);

        // Update local orderModel
        orderModel.driverId = FireStoreUtils.getCurrentUid();
        orderModel.status = Constant.rideActive;
        orderModel.finalRate = newAmount.value;
        orderModel.acceptedDriverId = [
          ...(orderModel.acceptedDriverId ?? []),
          FireStoreUtils.getCurrentUid()
        ];

        // Notify customer
        var customer =
            await FireStoreUtils.getCustomer(orderModel.userId.toString());
        if (customer != null) {
          await SendNotification.sendOneNotification(
            token: customer.fcmToken.toString(),
            title: 'Ride Accepted'.tr,
            body:
                'Your ride has been accepted by the driver for ${Constant.amountShow(amount: newAmount.value)}.'
                    .tr,
            payload: {'orderId': orderModel.id},
          );
        }

        // Save driver acceptance details
        DriverIdAcceptReject driverIdAcceptReject = DriverIdAcceptReject(
          driverId: FireStoreUtils.getCurrentUid(),
          acceptedRejectTime: Timestamp.now(),
          offerAmount: newAmount.value,
          suggestedDate: orderModel.whenDates,
          suggestedTime: DateFormat("HH:mm").format(suggestedTime!),
        );
        await FireStoreUtils.acceptInterCityRide(
            orderModel, driverIdAcceptReject);

        // Update driver subscription
        if (driverModel.value.subscriptionTotalOrders != "-1" &&
            driverModel.value.subscriptionTotalOrders != null) {
          try {
            int totalOrders =
                int.parse(driverModel.value.subscriptionTotalOrders.toString());
            driverModel.value.subscriptionTotalOrders =
                (totalOrders - 1).toString();
            await FireStoreUtils.updateDriverUser(driverModel.value);
          } catch (e) {
            if (kDebugMode) {
              print("Error parsing subscriptionTotalOrders: $e");
            }
          }
        }

        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Ride Accepted".tr);

        // Navigate to live tracking screen
        Get.to(() => const LiveTrackingScreen(), arguments: {
          "orderModel": orderModel,
          "type": "interCityOrderModel",
        });
      } catch (e) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Failed to accept ride: $e".tr);
        if (kDebugMode) {
          print("Error accepting order: $e");
        }
      }
    } else {
      ShowToastDialog.showToast(
        "You need at least ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept)} in your wallet to accept this order."
            .tr,
      );
    }
  }

  getOrder() async {
    isLoading.value = true;
    intercityServiceOrder.clear();
    FireStoreUtils.fireStore
        .collection(CollectionName.driverUsers)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen((event) {
      if (event.exists) {
        driverModel.value = DriverUserModel.fromJson(event.data()!);
      }
    });
    if (destinationCityController.value.text.isNotEmpty) {
      if (whenController.value.text.isEmpty) {
        await FireStoreUtils.fireStore
            .collection(CollectionName.ordersIntercity)
            // .where('sourceCity', isEqualTo: sourceCityController.value.text)
            // .where('destinationCity', isEqualTo: destinationCityController.value.text)
            .where('intercityServiceId', isNotEqualTo: "Kn2VEnPI3ikF58uK8YqY")
            .where('zoneId', whereIn: driverModel.value.zoneIds)
            .where('status', isEqualTo: Constant.ridePlaced)
            .get()
            .then((value) {
          isLoading.value = false;

          for (var element in value.docs) {
            InterCityOrderModel documentModel =
                InterCityOrderModel.fromJson(element.data());
            if (documentModel.acceptedDriverId != null &&
                documentModel.acceptedDriverId!.isNotEmpty) {
              if (!documentModel.acceptedDriverId!
                  .contains(FireStoreUtils.getCurrentUid())) {
                intercityServiceOrder.add(documentModel);
              }
            } else {
              intercityServiceOrder.add(documentModel);
            }
          }
        });
      } else {
        await FireStoreUtils.fireStore
            .collection(CollectionName.ordersIntercity)
            .where('sourceCity', isEqualTo: sourceCityController.value.text)
            .where('destinationCity',
                isEqualTo: destinationCityController.value.text)
            .where('intercityServiceId', isNotEqualTo: "Kn2VEnPI3ikF58uK8YqY")
            .where('whenDates',
                isEqualTo: DateFormat("dd-MMM-yyyy").format(dateAndTime!))
            .where('zoneId', whereIn: driverModel.value.zoneIds)
            .where('status', isEqualTo: Constant.ridePlaced)
            .get()
            .then((value) {
          isLoading.value = false;

          for (var element in value.docs) {
            InterCityOrderModel documentModel =
                InterCityOrderModel.fromJson(element.data());
            if (documentModel.acceptedDriverId != null &&
                documentModel.acceptedDriverId!.isNotEmpty) {
              if (!documentModel.acceptedDriverId!
                  .contains(FireStoreUtils.getCurrentUid())) {
                intercityServiceOrder.add(documentModel);
              }
            } else {
              intercityServiceOrder.add(documentModel);
            }
          }
        });
      }
    } else {
      if (whenController.value.text.isEmpty) {
        await FireStoreUtils.fireStore
            .collection(CollectionName.ordersIntercity)
            .where('sourceCity', isEqualTo: sourceCityController.value.text)
            .where('intercityServiceId', isNotEqualTo: "Kn2VEnPI3ikF58uK8YqY")
            .where('zoneId', whereIn: driverModel.value.zoneIds)
            .where('status', isEqualTo: Constant.ridePlaced)
            .get()
            .then((value) {
          isLoading.value = false;
          for (var element in value.docs) {
            InterCityOrderModel documentModel =
                InterCityOrderModel.fromJson(element.data());
            if (documentModel.acceptedDriverId != null &&
                documentModel.acceptedDriverId!.isNotEmpty) {
              if (!documentModel.acceptedDriverId!
                  .contains(FireStoreUtils.getCurrentUid())) {
                intercityServiceOrder.add(documentModel);
              }
            } else {
              intercityServiceOrder.add(documentModel);
            }
          }
        });
      } else {
        await FireStoreUtils.fireStore
            .collection(CollectionName.ordersIntercity)
            .where('sourceCity', isEqualTo: sourceCityController.value.text)
            .where('intercityServiceId', isNotEqualTo: "Kn2VEnPI3ikF58uK8YqY")
            .where('whenDates',
                isEqualTo: DateFormat("dd-MMM-yyyy").format(dateAndTime!))
            .where('status', isEqualTo: Constant.ridePlaced)
            .get()
            .then((value) {
          isLoading.value = false;
          for (var element in value.docs) {
            InterCityOrderModel documentModel =
                InterCityOrderModel.fromJson(element.data());
            if (documentModel.acceptedDriverId != null &&
                documentModel.acceptedDriverId!.isNotEmpty) {
              if (!documentModel.acceptedDriverId!
                  .contains(FireStoreUtils.getCurrentUid())) {
                intercityServiceOrder.add(documentModel);
              }
            } else {
              intercityServiceOrder.add(documentModel);
            }
          }
        });
      }
    }
  }
}
