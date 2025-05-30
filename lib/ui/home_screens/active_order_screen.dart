import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/active_order_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/ui/home_screens/live_tracking_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

class ActiveOrderScreen extends StatelessWidget {
  const ActiveOrderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return GetBuilder<ActiveOrderController>(
      init: ActiveOrderController(),
      builder: (controller) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(CollectionName.orders)
              .where('driverId', isEqualTo: FireStoreUtils.getCurrentUid())
              .where('status', whereIn: [
                Constant.rideInProgress,
                Constant.rideActive,
              ])
              .limit(1) // Limit to one active ride
              .snapshots(),
          builder:
              (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) {
              return Text('Something went wrong'.tr);
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Constant.loader(context);
            }
            if (snapshot.data!.docs.isEmpty) {
              return Center(child: Text("No active rides found".tr));
            }

            // Get the single active ride
            OrderModel orderModel = OrderModel.fromJson(
                snapshot.data!.docs.first.data() as Map<String, dynamic>);

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.containerBackground,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    border: Border.all(
                      color: AppColors.containerBorder,
                      width: 0.5,
                    ),
                    boxShadow:  [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 10),
                    child: Column(
                      children: [
                        UserView(
                          userId: orderModel.userId,
                          amount: orderModel.finalRate,
                          distance: orderModel.distance,
                          distanceType: orderModel.distanceType,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 5),
                          child: Divider(),
                        ),
                        LocationView(
                          sourceLocation:
                              orderModel.sourceLocationName.toString(),
                          destinationLocation:
                              orderModel.destinationLocationName.toString(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: orderModel.status ==
                                      Constant.rideInProgress
                                  ? ButtonThem.buildBorderButton(
                                      context,
                                      title: "Complete Ride".tr,
                                      btnHeight: 44,
                                      iconVisibility: false,
                                      onPress: () async {
                                        orderModel.status =
                                            Constant.rideComplete;
                                        await FireStoreUtils.getCustomer(
                                                orderModel.userId.toString())
                                            .then((value) async {
                                          if (value != null &&
                                              value.fcmToken != null) {
                                            Map<String, dynamic> playLoad =
                                                <String, dynamic>{
                                              "type": "city_order_complete",
                                              "orderId": orderModel.id,
                                            };
                                            await SendNotification
                                                .sendOneNotification(
                                              token: value.fcmToken.toString(),
                                              title: 'Ride complete!'.tr,
                                              body:
                                                  'Please complete your payment.'
                                                      .tr,
                                              payload: playLoad,
                                            );
                                          }
                                        });
                                        await FireStoreUtils.setOrder(
                                                orderModel)
                                            .then((value) {
                                          if (value == true) {
                                            ShowToastDialog.showToast(
                                                "Ride completed successfully"
                                                    .tr);
                                            controller.homeController
                                                .selectedIndex.value = 3;
                                          }
                                        });
                                      },
                                    )
                                  : ButtonThem.buildBorderButton(
                                      context,
                                      title: "Pickup Customer".tr,
                                      btnHeight: 35,
                                      iconVisibility: false,
                                      onPress: () async {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) =>
                                              otpDialog(context, controller,
                                                  orderModel),
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () async {
                                    UserModel? customer =
                                        await FireStoreUtils.getCustomer(
                                            orderModel.userId.toString());
                                    DriverUserModel? driver =
                                        await FireStoreUtils.getDriverProfile(
                                            orderModel.driverId.toString());
                                    Get.to(ChatScreens(
                                      driverId: driver!.id,
                                      customerId: customer!.id,
                                      customerName: customer.fullName,
                                      customerProfileImage: customer.profilePic,
                                      driverName: driver.fullName,
                                      driverProfileImage: driver.profilePic,
                                      orderId: orderModel.id,
                                      token: customer.fcmToken,
                                    ));
                                  },
                                  child: Container(
                                    height: 35,
                                    width: 35,
                                    decoration: BoxDecoration(
                                      color:  AppColors.primary,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Icon(
                                      Icons.chat,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () async {
                                    UserModel? customer =
                                        await FireStoreUtils.getCustomer(
                                            orderModel.userId.toString());
                                    Constant.makePhoneCall(
                                        "${customer!.countryCode}${customer.phoneNumber}");
                                  },
                                  child: Container(
                                    height: 35,
                                    width: 35,
                                    decoration: BoxDecoration(
                                      color:  AppColors.primary,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Icon(
                                      Icons.call,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Cancel Ride Button
                        Row(spacing: 10, children: [
                          Expanded(
                            child: ButtonThem.buildBorderButton(
                              context,
                              title: "Cancel Ride".tr,
                              btnHeight: 44,
                              // btnColor: Colors.redAccent,
                              // btnBorderColor: Colors.redAccent,
                              // textColor: Colors.white,
                              iconVisibility: false,
                              onPress: () async {
                                bool? confirmCancel = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text("Confirm Cancel".tr),
                                      content: Text(
                                          "Are you sure you want to cancel this ride?"
                                              .tr),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text("No".tr),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text("Yes".tr),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirmCancel == true) {
                                  ShowToastDialog.showLoader(
                                      "Cancelling ride...".tr);
                                  orderModel.status = Constant.rideCanceled;
                                  await FireStoreUtils.getCustomer(
                                          orderModel.userId.toString())
                                      .then((value) async {
                                    if (value != null &&
                                        value.fcmToken != null) {
                                      Map<String, dynamic> playLoad =
                                          <String, dynamic>{
                                        "type": "city_order_cancelled",
                                        "orderId": orderModel.id,
                                      };
                                      await SendNotification
                                          .sendOneNotification(
                                        token: value.fcmToken.toString(),
                                        title: 'Ride Cancelled'.tr,
                                        body:
                                            'Your ride has been cancelled by the driver.'
                                                .tr,
                                        payload: playLoad,
                                      );
                                    }
                                  });
                                  await FireStoreUtils.setOrder(orderModel)
                                      .then((value) {
                                    if (value == true) {
                                      ShowToastDialog.closeLoader();
                                      ShowToastDialog.showToast(
                                          "Ride cancelled successfully".tr);
                                      controller.homeController.selectedIndex
                                          .value = 3;
                                    }
                                  });
                                }
                              },
                            ),
                          ),

                          // Navigate to LiveTrackingScreen
                          Expanded(
                            child: ButtonThem.buildButton(
                              context,
                              title: "Track Ride".tr,
                              btnHeight: 44,
                              onPress: () {
                                if (Constant.mapType == "inappmap") {
                                  if (orderModel.status ==
                                          Constant.rideActive ||
                                      orderModel.status ==
                                          Constant.rideInProgress) {
                                    Get.to(const LiveTrackingScreen(),
                                        arguments: {
                                          "orderModel": orderModel,
                                          "type": "orderModel",
                                        });
                                  }
                                } else {
                                  if (orderModel.status ==
                                      Constant.rideInProgress) {
                                    Utils.redirectMap(
                                      latitude: orderModel
                                          .destinationLocationLAtLng!.latitude!,
                                      longLatitude: orderModel
                                          .destinationLocationLAtLng!
                                          .longitude!,
                                      name: orderModel.destinationLocationName
                                          .toString(),
                                    );
                                  } else {
                                    Utils.redirectMap(
                                      latitude: orderModel
                                          .sourceLocationLAtLng!.latitude!,
                                      longLatitude: orderModel
                                          .sourceLocationLAtLng!.longitude!,
                                      name: orderModel.destinationLocationName
                                          .toString(),
                                    );
                                  }
                                }
                              },
                            ),
                          )
                        ])
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Dialog otpDialog(BuildContext context, ActiveOrderController controller,
      OrderModel orderModel) {
    final TextEditingController otpController = TextEditingController();
    String otpValue = "";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              "OTP verify from customer".tr,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: PinCodeTextField(
                length: 6,
                appContext: context,
                keyboardType: TextInputType.phone,
                pinTheme: PinTheme(
                  fieldHeight: 40,
                  fieldWidth: 40,
                  activeColor: AppColors.textFieldBorder,
                  selectedColor: AppColors.textFieldBorder,
                  inactiveColor: AppColors.textFieldBorder,
                  activeFillColor: AppColors.textField,
                  inactiveFillColor: AppColors.textField,
                  selectedFillColor: AppColors.textField,
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(10),
                ),
                enableActiveFill: true,
                cursorColor: AppColors.primary,
                controller: otpController,
                onCompleted: (v) async {
                  otpValue = v;
                  print("OTP Completed: $v");
                },
                onChanged: (value) {
                  otpValue = value;
                  print("OTP Changed: $value");
                },
              ),
            ),
            const SizedBox(height: 10),
            ButtonThem.buildButton(
              context,
              title: "OTP verify".tr,
              onPress: () async {
                try {
                  String inputOtp = otpController.text.trim();
                  if (inputOtp.isEmpty) {
                    inputOtp = otpValue.trim();
                  }

                  String modelOtp = orderModel.otp.toString().trim();

                  print(
                      "OTP Verification - Model OTP: '$modelOtp', Input OTP: '$inputOtp', Controller Text: '${otpController.text}'");

                  if (modelOtp == inputOtp) {
                    Get.back();
                    ShowToastDialog.showLoader("Please wait...".tr);
                    orderModel.status = Constant.rideInProgress;

                    await FireStoreUtils.getCustomer(
                            orderModel.userId.toString())
                        .then((value) async {
                      if (value != null) {
                        await SendNotification.sendOneNotification(
                          token: value.fcmToken.toString(),
                          title: 'Ride Started'.tr,
                          body:
                              'The ride has officially started. Please follow the designated route to the destination.'
                                  .tr,
                          payload: {},
                        );
                      }
                    });

                    await FireStoreUtils.setOrder(orderModel).then((value) {
                      if (value == true) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast(
                            "Customer pickup successfully".tr);
                        // Navigate to LiveTrackingScreen after successful pickup
                        if (Constant.mapType == "inappmap") {
                          Get.to(const LiveTrackingScreen(), arguments: {
                            "orderModel": orderModel,
                            "type": "orderModel",
                          });
                        }
                      }
                    });
                  } else {
                    ShowToastDialog.showToast("OTP Invalid".tr,
                        position: EasyLoadingToastPosition.center);
                    print(
                        "OTP Comparison - Model OTP: '$modelOtp', Input OTP: '$inputOtp'");
                  }
                } catch (e) {
                  ShowToastDialog.closeLoader();
                  ShowToastDialog.showToast("Error: ${e.toString()}".tr,
                      position: EasyLoadingToastPosition.center);
                  print("Error in OTP verification: ${e.toString()}");
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
