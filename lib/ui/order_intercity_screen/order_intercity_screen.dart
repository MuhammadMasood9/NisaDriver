import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/intercity_order_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/model/wallet_transaction_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/ui/order_intercity_screen/complete_intecity_order_screen.dart';
import 'package:driver/ui/review/review_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:math';

class OrderIntercityScreen extends StatelessWidget {
  const OrderIntercityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<InterCityOrderController>(
      init: InterCityOrderController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.grey100, // Applied from example
          body: controller.isLoading.value
              ? Constant.loader(context)
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(CollectionName.ordersIntercity)
                      .where('driverId',
                          isEqualTo: FireStoreUtils.getCurrentUid())
                      .where('intercityServiceId', whereIn: [
                        "647f340e35553",
                        '647f350983ba2',
                        'UmQ2bjWTnlwoKqdCIlTr'
                      ])
                      .orderBy("createdDate", descending: true)
                      .snapshots(),
                  builder: (BuildContext context,
                      AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Something went wrong'.tr));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Constant.loader(context);
                    }
                    return snapshot.data!.docs.isEmpty
                        ? Center(child: Text("No Ride found".tr))
                        : ListView.builder(
                            itemCount: snapshot.data!.docs.length,
                            scrollDirection: Axis.vertical,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              InterCityOrderModel orderModel =
                                  InterCityOrderModel.fromJson(
                                      snapshot.data!.docs[index].data()
                                          as Map<String, dynamic>);
                              return FutureBuilder<Map<String, dynamic>>(
                                future: _buildMapData(orderModel),
                                builder: (context, mapSnapshot) {
                                  Set<Marker> markers =
                                      mapSnapshot.data?['markers'] ?? {};
                                  List<LatLng> polylineCoordinates = mapSnapshot
                                          .data?['polylineCoordinates'] ??
                                      [];
                                  LatLngBounds? bounds =
                                      mapSnapshot.data?['bounds'];

                                  return InkWell(
                                    onTap: () {
                                      Get.to(
                                          const CompleteIntercityOrderScreen(),
                                          arguments: {
                                            "orderModel": orderModel
                                          });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 8), // Applied from example
                                      child: _buildSectionCard(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 6),
                                            UserView(
                                              userId: orderModel.userId,
                                              amount: orderModel.finalRate,
                                              distance: orderModel.distance,
                                              distanceType:
                                                  orderModel.distanceType,
                                            ),
                                            const SizedBox(height: 5),
                                            Divider(
                                              height: 3,
                                              color: AppColors.grey200,
                                            ),
                                            const SizedBox(height: 5),
                                            LocationView(
                                              sourceLocation: orderModel
                                                  .sourceLocationName
                                                  .toString(),
                                              destinationLocation: orderModel
                                                  .destinationLocationName
                                                  .toString(),
                                            ),
                                            const SizedBox(height: 8),
                                            _buildStatusSection(orderModel),
                                            const SizedBox(height: 8),
                                            _buildActionButtons(context,
                                                orderModel, controller),
                                            const SizedBox(height: 8),
                                            Visibility(
                                              visible: controller.paymentModel
                                                          .value.cash!.name ==
                                                      orderModel.paymentType
                                                          .toString() &&
                                                  orderModel.paymentStatus ==
                                                      false &&
                                                  orderModel.status !=
                                                      Constant.rideComplete,
                                              child: ButtonThem.buildButton(
                                                context,
                                                title:
                                                    "Confirm cash payment".tr,
                                                btnHeight: 44,
                                                onPress: () async {
                                                  ShowToastDialog.showLoader(
                                                      "Please wait..".tr);
                                                  orderModel.paymentStatus =
                                                      true;
                                                  orderModel.status =
                                                      Constant.rideComplete;
                                                  orderModel.updateDate =
                                                      Timestamp.now();

                                                  String? couponAmount = "0.0";
                                                  if (orderModel.coupon !=
                                                          null &&
                                                      orderModel.coupon?.code !=
                                                          null) {
                                                    couponAmount = orderModel
                                                                .coupon!.type ==
                                                            "fix"
                                                        ? orderModel
                                                            .coupon!.amount
                                                            .toString()
                                                        : ((double.parse(orderModel
                                                                        .finalRate
                                                                        .toString()) *
                                                                    double.parse(orderModel
                                                                        .coupon!
                                                                        .amount
                                                                        .toString())) /
                                                                100)
                                                            .toString();
                                                  }

                                                  WalletTransactionModel
                                                      adminCommissionWallet =
                                                      WalletTransactionModel(
                                                    id: Constant.getUuid(),
                                                    amount:
                                                        "-${Constant.calculateAdminCommission(
                                                      amount: (double.parse(
                                                                  orderModel
                                                                      .finalRate
                                                                      .toString()) -
                                                              double.parse(
                                                                  couponAmount))
                                                          .toString(),
                                                      adminCommission:
                                                          orderModel
                                                              .adminCommission,
                                                    )}",
                                                    createdDate:
                                                        Timestamp.now(),
                                                    paymentType: "wallet".tr,
                                                    transactionId:
                                                        orderModel.id,
                                                    orderType: "intercity",
                                                    userId: orderModel.driverId
                                                        .toString(),
                                                    userType: "driver",
                                                    note:
                                                        "Admin commission debited"
                                                            .tr,
                                                  );

                                                  await FireStoreUtils
                                                          .setWalletTransaction(
                                                              adminCommissionWallet)
                                                      .then((value) async {
                                                    if (value == true) {
                                                      await FireStoreUtils
                                                          .updatedDriverWallet(
                                                        amount:
                                                            "-${Constant.calculateAdminCommission(
                                                          amount: (double.parse(
                                                                      orderModel
                                                                          .finalRate
                                                                          .toString()) -
                                                                  double.parse(
                                                                      couponAmount ??
                                                                          "0.0"))
                                                              .toString(),
                                                          adminCommission:
                                                              orderModel
                                                                  .adminCommission,
                                                        )}",
                                                      );
                                                    }
                                                  });

                                                  await FireStoreUtils
                                                          .getCustomer(
                                                              orderModel.userId
                                                                  .toString())
                                                      .then((value) async {
                                                    if (value != null) {
                                                      await SendNotification
                                                          .sendOneNotification(
                                                        token: value.fcmToken
                                                            .toString(),
                                                        title:
                                                            'Cash Payment confirmed'
                                                                .tr,
                                                        body:
                                                            'Driver has confirmed your cash payment'
                                                                .tr,
                                                        payload: {},
                                                      );
                                                    }
                                                  });

                                                  await FireStoreUtils
                                                          .getIntercityFirstOrderOrNOt(
                                                              orderModel)
                                                      .then((value) async {
                                                    if (value == true) {
                                                      await FireStoreUtils
                                                          .updateIntercityReferralAmount(
                                                              orderModel);
                                                    }
                                                  });

                                                  await FireStoreUtils
                                                          .setInterCityOrder(
                                                              orderModel)
                                                      .then((value) {
                                                    if (value == true) {
                                                      ShowToastDialog
                                                          .closeLoader();
                                                      ShowToastDialog.showToast(
                                                          "Payment Confirm successfully"
                                                              .tr);
                                                      Get.to(
                                                          () =>
                                                              const ReviewScreen(),
                                                          arguments: {
                                                            "type":
                                                                "interCityOrderModel",
                                                            "interCityOrderModel":
                                                                orderModel,
                                                          });
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                  },
                ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _buildMapData(
      InterCityOrderModel orderModel) async {
    final LatLng sourceLatLng = LatLng(
      orderModel.sourceLocationLAtLng?.latitude ?? 24.905702181412074,
      orderModel.sourceLocationLAtLng?.longitude ?? 67.07225639373064,
    );
    final LatLng destinationLatLng = LatLng(
      orderModel.destinationLocationLAtLng?.latitude ?? 24.94478876378326,
      orderModel.destinationLocationLAtLng?.longitude ?? 67.06306681036949,
    );

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(sourceLatLng.latitude, destinationLatLng.latitude),
        min(sourceLatLng.longitude, destinationLatLng.longitude),
      ),
      northeast: LatLng(
        max(sourceLatLng.latitude, destinationLatLng.latitude),
        max(sourceLatLng.longitude, destinationLatLng.longitude),
      ),
    );

    final iconStart = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(32, 32)),
      'assets/images/green_mark.png',
    );
    final iconEnd = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(32, 32)),
      'assets/images/red_mark.png',
    );

    final markers = {
      Marker(
        markerId: const MarkerId('source'),
        position: sourceLatLng,
        icon: iconStart,
        infoWindow:
            InfoWindow(title: 'Pickup: ${orderModel.sourceLocationName}'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destinationLatLng,
        icon: iconEnd,
        infoWindow: InfoWindow(
            title: 'Drop-off: ${orderModel.destinationLocationName}'),
      ),
    };

    List<LatLng> polylineCoordinates = [];
    try {
      PolylineRequest request = PolylineRequest(
        origin: PointLatLng(sourceLatLng.latitude, sourceLatLng.longitude),
        destination: PointLatLng(
            destinationLatLng.latitude, destinationLatLng.longitude),
        mode: TravelMode.driving,
      );

      PolylineResult result = await PolylinePoints().getRouteBetweenCoordinates(
        request: request,
        googleApiKey: 'AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4',
      );

      if (result.points.isNotEmpty) {
        polylineCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      }
    } catch (e) {
      print('Error fetching polyline: $e');
    }

    return {
      'markers': markers,
      'polylineCoordinates': polylineCoordinates,
      'bounds': bounds,
    };
  }

  Widget _buildSectionCard({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.containerBorder,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatusSection(InterCityOrderModel orderModel) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              orderModel.status.toString(),
              style: AppTypography.boldLabel(Get.context!),
            ),
            Text(
              Constant().formatTimestamp(orderModel.createdDate),
              style: AppTypography.label(Get.context!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    InterCityOrderModel orderModel,
    InterCityOrderController controller,
  ) {
    return Row(
      children: [
        Expanded(
          child: ButtonThem.buildBorderButton(
            context,
            title: "Review".tr,
            btnHeight: 35,
            iconVisibility: false,
            btnWidthRatio: 1,
            onPress: () async {
              Get.to(const ReviewScreen(), arguments: {
                "type": "interCityOrderModel",
                "interCityOrderModel": orderModel,
              });
            },
          ),
        ),
        Visibility(
          child: const SizedBox(width: 10),
          visible: orderModel.status == Constant.rideComplete ? false : true,
        ),
        Visibility(
          visible: orderModel.status == Constant.rideComplete ? false : true,
          child: Row(
            children: [
              InkWell(
                onTap: () async {
                  UserModel? customer = await FireStoreUtils.getCustomer(
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
                    color: AppColors.primary,
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
                  UserModel? customer = await FireStoreUtils.getCustomer(
                      orderModel.userId.toString());
                  Constant.makePhoneCall(
                      "${customer!.countryCode}${customer.phoneNumber}");
                },
                child: Container(
                  height: 35,
                  width: 35,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
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
        ),
      ],
    );
  }
}
