import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/active_intercity_order_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/ui/home_screens/live_tracking_screen.dart';
import 'package:driver/ui/intercity_screen/pacel_details_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

class ActiveIntercityOrderScreen extends StatelessWidget {
  const ActiveIntercityOrderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ActiveInterCityOrderController>(
        init: ActiveInterCityOrderController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, left: 5, right: 5),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection(CollectionName.ordersIntercity)
                            .where('driverId',
                                isEqualTo: FireStoreUtils.getCurrentUid())
                            .where('status', whereIn: [
                          Constant.rideInProgress,
                          Constant.rideActive
                        ]).snapshots(),
                        builder: (BuildContext context,
                            AsyncSnapshot<QuerySnapshot> snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Something went wrong'.tr,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: const Color(0xFF636E72),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Constant.loader(context);
                          }
                          return snapshot.data!.docs.isEmpty
                              ? Center(
                                  child: Text(
                                    "No active ride found".tr,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: const Color(0xFF636E72),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: snapshot.data!.docs.length,
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    InterCityOrderModel orderModel =
                                        InterCityOrderModel.fromJson(
                                            snapshot.data!.docs[index].data()
                                                as Map<String, dynamic>);
                                    return InkWell(
                                      onTap: () {
                                        if (Constant.mapType == "inappmap") {
                                          if (orderModel.status ==
                                                  Constant.rideActive ||
                                              orderModel.status ==
                                                  Constant.rideInProgress) {
                                            Get.to(const LiveTrackingScreen(),
                                                arguments: {
                                                  "interCityOrderModel":
                                                      orderModel,
                                                  "type": "interCityOrderModel",
                                                });
                                          }
                                        } else {
                                          if (orderModel.status ==
                                              Constant.rideInProgress) {
                                            Utils.redirectMap(
                                                latitude: orderModel
                                                    .destinationLocationLAtLng!
                                                    .latitude!,
                                                longLatitude: orderModel
                                                    .destinationLocationLAtLng!
                                                    .longitude!,
                                                name: orderModel
                                                    .destinationLocationName
                                                    .toString());
                                          } else {
                                            Utils.redirectMap(
                                                latitude: orderModel
                                                    .sourceLocationLAtLng!
                                                    .latitude!,
                                                longLatitude: orderModel
                                                    .sourceLocationLAtLng!
                                                    .longitude!,
                                                name: orderModel
                                                    .destinationLocationName
                                                    .toString());
                                          }
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(5),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius:
                                                const BorderRadius.all(
                                                    Radius.circular(10)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.3),
                                                blurRadius: 5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 8),
                                            child: Column(
                                              children: [
                                                UserView(
                                                  userId: orderModel.userId,
                                                  amount: orderModel.offerRate,
                                                  distance: orderModel.distance,
                                                  distanceType:
                                                      orderModel.distanceType,
                                                ),
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 5),
                                                  child: Divider(),
                                                ),
                                                LocationView(
                                                  sourceLocation: orderModel
                                                      .sourceLocationName
                                                      .toString(),
                                                  destinationLocation: orderModel
                                                      .destinationLocationName
                                                      .toString(),
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    FutureBuilder<
                                                            DriverIdAcceptReject?>(
                                                        future: FireStoreUtils
                                                            .getInterCItyAcceptedOrders(
                                                                orderModel.id
                                                                    .toString(),
                                                                FireStoreUtils
                                                                        .getCurrentUid() ??
                                                                    ''),
                                                        builder: (context,
                                                            snapshot) {
                                                          switch (snapshot
                                                              .connectionState) {
                                                            case ConnectionState
                                                                .waiting:
                                                              return Constant
                                                                  .loader(
                                                                      context);
                                                            case ConnectionState
                                                                .done:
                                                              if (snapshot
                                                                  .hasError) {
                                                                return Text(
                                                                  snapshot.error
                                                                      .toString(),
                                                                  style: AppTypography
                                                                      .boldLabel(
                                                                          context),
                                                                );
                                                              } else {
                                                                DriverIdAcceptReject
                                                                    driverIdAcceptReject =
                                                                    snapshot
                                                                        .data!;
                                                                return Text(
                                                                  Constant.amountShow(
                                                                      amount: driverIdAcceptReject
                                                                          .offerAmount
                                                                          .toString()),
                                                                  style: AppTypography
                                                                      .boldHeaders(
                                                                          context),
                                                                );
                                                              }
                                                            default:
                                                              return Text(
                                                                'Error'.tr,
                                                                style: AppTypography
                                                                    .boldLabel(
                                                                        context),
                                                              );
                                                          }
                                                        }),
                                                    orderModel.intercityServiceId ==
                                                            "647f350983ba2"
                                                        ? const SizedBox()
                                                        : Text(
                                                            " For ${orderModel.numberOfPassenger} Person"
                                                                .tr,
                                                            style: AppTypography
                                                                .boldLabel(
                                                                    context),
                                                          ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors.grey
                                                                  .withOpacity(
                                                                      0.3),
                                                              borderRadius:
                                                                  const BorderRadius
                                                                      .all(
                                                                      Radius.circular(
                                                                          10)),
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          6),
                                                              child: Text(
                                                                orderModel
                                                                    .paymentType
                                                                    .toString(),
                                                                style: AppTypography
                                                                    .boldLabel(
                                                                        context),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppColors
                                                                  .primary
                                                                  .withOpacity(
                                                                      0.3),
                                                              borderRadius:
                                                                  const BorderRadius
                                                                      .all(
                                                                      Radius.circular(
                                                                          10)),
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          6),
                                                              child: Text(
                                                                Constant.localizationName(
                                                                    orderModel
                                                                        .intercityService!
                                                                        .name),
                                                                style: AppTypography
                                                                    .boldLabel(
                                                                        context),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Visibility(
                                                      visible: orderModel
                                                              .intercityServiceId ==
                                                          "647f350983ba2",
                                                      child: InkWell(
                                                        onTap: () {
                                                          Get.to(
                                                              const ParcelDetailsScreen(),
                                                              arguments: {
                                                                "orderModel":
                                                                    orderModel,
                                                              });
                                                        },
                                                        child: Text(
                                                          "View details".tr,
                                                          style: AppTypography
                                                                  .boldLabel(
                                                                      context)
                                                              .copyWith(
                                                                  color: AppColors
                                                                      .primary),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: orderModel
                                                                  .status ==
                                                              Constant
                                                                  .rideInProgress
                                                          ? ButtonThem
                                                              .buildButton(
                                                              context,
                                                              title:
                                                                  "Complete Ride"
                                                                      .tr,
                                                              btnHeight: 44,
                                                              onPress:
                                                                  () async {
                                                                orderModel
                                                                        .status =
                                                                    Constant
                                                                        .rideComplete;

                                                                await FireStoreUtils.getCustomer(
                                                                        orderModel
                                                                            .userId
                                                                            .toString())
                                                                    .then(
                                                                        (value) async {
                                                                  if (value !=
                                                                      null) {
                                                                    Map<String,
                                                                            dynamic>
                                                                        playLoad =
                                                                        <String,
                                                                            dynamic>{
                                                                      "type":
                                                                          "intercity_order_complete",
                                                                      "orderId":
                                                                          orderModel
                                                                              .id
                                                                    };

                                                                    await SendNotification.sendOneNotification(
                                                                        token: value
                                                                            .fcmToken
                                                                            .toString(),
                                                                        title: 'Ride complete!'
                                                                            .tr,
                                                                        body: 'Please complete your payment.'
                                                                            .tr,
                                                                        payload:
                                                                            playLoad);
                                                                  }
                                                                });

                                                                await FireStoreUtils
                                                                        .setInterCityOrder(
                                                                            orderModel)
                                                                    .then(
                                                                        (value) {
                                                                  if (value ==
                                                                      true) {
                                                                    ShowToastDialog.showToast(
                                                                        "Ride Complete successfully"
                                                                            .tr);
                                                                    Get.back();
                                                                  }
                                                                });
                                                              },
                                                            )
                                                          : ButtonThem
                                                              .buildButton(
                                                              context,
                                                              title:
                                                                  "Pickup Customer"
                                                                      .tr,
                                                              btnHeight: 44,
                                                              onPress:
                                                                  () async {
                                                                showDialog(
                                                                    context:
                                                                        context,
                                                                    builder: (BuildContext
                                                                            context) =>
                                                                        otpDialog(
                                                                            context,
                                                                            controller,
                                                                            orderModel));
                                                              },
                                                            ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Row(
                                                      children: [
                                                        InkWell(
                                                          onTap: () async {
                                                            UserModel?
                                                                customer =
                                                                await FireStoreUtils
                                                                    .getCustomer(
                                                                        orderModel
                                                                            .userId
                                                                            .toString());
                                                            DriverUserModel?
                                                                driver =
                                                                await FireStoreUtils
                                                                    .getDriverProfile(orderModel
                                                                        .driverId
                                                                        .toString());

                                                            Get.to(ChatScreens(
                                                              driverId:
                                                                  driver!.id,
                                                              customerId:
                                                                  customer!.id,
                                                              customerName:
                                                                  customer
                                                                      .fullName,
                                                              customerProfileImage:
                                                                  customer
                                                                      .profilePic,
                                                              driverName: driver
                                                                  .fullName,
                                                              driverProfileImage:
                                                                  driver
                                                                      .profilePic,
                                                              orderId:
                                                                  orderModel.id,
                                                              token: customer
                                                                  .fcmToken,
                                                            ));
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppColors
                                                                  .primary,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: Icon(
                                                              Icons.chat,
                                                              color: AppColors
                                                                  .background,
                                                              size: 20,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        InkWell(
                                                          onTap: () async {
                                                            UserModel?
                                                                customer =
                                                                await FireStoreUtils
                                                                    .getCustomer(
                                                                        orderModel
                                                                            .userId
                                                                            .toString());
                                                            Constant.makePhoneCall(
                                                                "${customer!.countryCode}${customer.phoneNumber}");
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppColors
                                                                  .primary,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: Icon(
                                                              Icons.call,
                                                              color: AppColors
                                                                  .background,
                                                              size: 20,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  otpDialog(BuildContext context, ActiveInterCityOrderController controller,
      InterCityOrderModel orderModel) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "OTP verify from customer".tr,
              style: AppTypography.boldHeaders(context),
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
                controller: controller.otpController.value,
                onCompleted: (v) async {},
                onChanged: (value) {},
              ),
            ),
            const SizedBox(height: 10),
            ButtonThem.buildButton(
              context,
              title: "OTP verify".tr,
              onPress: () async {
                String inputOtp = controller.otpController.value.text;
                String modelOtp = orderModel.otp.toString();

                if (orderModel.otp.toString() ==
                    controller.otpController.value.text) {
                  Get.back();
                  ShowToastDialog.showLoader("Please wait...".tr);
                  orderModel.status = Constant.rideInProgress;

                  await FireStoreUtils.getCustomer(orderModel.userId.toString())
                      .then((value) async {
                    if (value != null) {
                      await SendNotification.sendOneNotification(
                          token: value.fcmToken.toString(),
                          title: 'Ride Started'.tr,
                          body:
                              'The ride has officially started. Please follow the designated route to the destination.'
                                  .tr,
                          payload: {});
                    }
                  });

                  await FireStoreUtils.setInterCityOrder(orderModel)
                      .then((value) {
                    if (value == true) {
                      ShowToastDialog.closeLoader();
                      ShowToastDialog.showToast(
                          "Customer pickup successfully".tr);
                    }
                  });
                } else {
                  ShowToastDialog.showToast("OTP Invalid".tr);
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
