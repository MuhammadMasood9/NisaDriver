import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/intercity_controller.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/intercity_screen/pacel_details_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class NewOrderInterCityScreen extends StatelessWidget {
  const NewOrderInterCityScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return GetX<IntercityController>(
        init: IntercityController()..getOrder(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: AppColors.background,
            resizeToAvoidBottomInset: true,
            body: Column(
              children: [
                // Wallet Warning Banner
                double.parse(controller.driverModel.value.walletAmount
                                ?.toString() ??
                            '0.0') >=
                        double.parse(
                            Constant.minimumDepositToRideAccept ?? '0.0')
                    ? const SizedBox(height: 10)
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE74C3C),
                              const Color(0xFFE74C3C).withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE74C3C).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "You need a minimum ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} in your wallet to accept orders and place bids."
                                    .tr,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                      child: Padding(
                        padding:
                            const EdgeInsets.only(top: 4, left: 5, right: 5),
                        child: controller.isLoading.value
                            ? Constant.loader(context)
                            : controller.intercityServiceOrder.isEmpty
                                ? Center(
                                    child: Text(
                                      "No Rides found".tr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: const Color(0xFF636E72),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount:
                                        controller.intercityServiceOrder.length,
                                    shrinkWrap: true,
                                    itemBuilder: (context, index) {
                                      InterCityOrderModel orderModel =
                                          controller
                                              .intercityServiceOrder[index];
                                      String amount;
                                      if (Constant.distanceType == "Km") {
                                        amount = Constant.amountCalculate(
                                                orderModel
                                                    .intercityService!.kmCharge
                                                    .toString(),
                                                orderModel.distance.toString())
                                            .toStringAsFixed(Constant
                                                .currencyModel!.decimalDigits!);
                                      } else {
                                        amount = Constant.amountCalculate(
                                                orderModel
                                                    .intercityService!.kmCharge
                                                    .toString(),
                                                orderModel.distance.toString())
                                            .toStringAsFixed(Constant
                                                .currencyModel!.decimalDigits!);
                                      }
                                      return InkWell(
                                        onTap: () {
                                          if (orderModel.acceptedDriverId !=
                                                  null &&
                                              orderModel.acceptedDriverId!
                                                  .contains(FireStoreUtils
                                                      .getCurrentUid())) {
                                            ShowToastDialog.showToast(
                                                "Ride already accepted".tr);
                                          } else {
                                            try {
                                              offerAcceptDialog(context,
                                                  controller, orderModel);
                                            } catch (e) {
                                              ShowToastDialog.showToast(
                                                  "Error processing ride details: ${e.toString()}");
                                              print(
                                                  "Error in ride acceptance: $e");
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
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ],
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 8),
                                              child: Column(
                                                children: [
                                                  UserView(
                                                    userId: orderModel.userId,
                                                    amount:
                                                        orderModel.offerRate,
                                                    distance:
                                                        orderModel.distance,
                                                    distanceType:
                                                        orderModel.distanceType,
                                                  ),
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        Constant.amountShow(
                                                            amount: orderModel
                                                                .offerRate
                                                                .toString()),
                                                        style: AppTypography
                                                            .boldHeaders(
                                                                context),
                                                      ),
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
                                                                color: Colors
                                                                    .grey
                                                                    .withOpacity(
                                                                        0.3),
                                                                borderRadius:
                                                                    const BorderRadius
                                                                        .all(
                                                                        Radius.circular(
                                                                            10)),
                                                              ),
                                                              child: Padding(
                                                                padding: const EdgeInsets
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
                                                                padding: const EdgeInsets
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
                                                                      orderModel
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
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 14),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color:  AppColors.gray,
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
                                                                horizontal: 10,
                                                                vertical: 12),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Text(
                                                              orderModel
                                                                  .whenDates
                                                                  .toString(),
                                                              style: AppTypography
                                                                  .boldLabel(
                                                                      context),
                                                            ),
                                                            const SizedBox(
                                                                width: 10),
                                                            Text(
                                                              orderModel
                                                                  .whenTime
                                                                  .toString(),
                                                              style: AppTypography
                                                                  .boldLabel(
                                                                      context),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                    child: Container(
                                                      width: Responsive.width(
                                                          100, context),
                                                      decoration: BoxDecoration(
                                                        color:  AppColors.gray,
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
                                                                horizontal: 8,
                                                                vertical: 8),
                                                        child: Center(
                                                          child: Text(
                                                            'Recommended Price is ${Constant.amountShow(amount: amount)}. Approx distance ${double.parse(orderModel.distance.toString()).toStringAsFixed(Constant.currencyModel!.decimalDigits!)} ${Constant.distanceType}'
                                                                .tr,
                                                            style: AppTypography
                                                                .boldLabel(
                                                                    context),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  offerAcceptDialog(BuildContext context, IntercityController controller,
      InterCityOrderModel orderModel) {
    return showModalBottomSheet(
        context: context,
        isDismissible: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(15),
                topLeft: Radius.circular(15),
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20),
              child: Padding(
                padding: MediaQuery.of(context).viewInsets,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserView(
                      userId: orderModel.userId,
                      amount: orderModel.offerRate,
                      distance: orderModel.distance,
                      distanceType: orderModel.distanceType,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Divider(),
                    ),
                    LocationView(
                      sourceLocation: orderModel.sourceLocationName.toString(),
                      destinationLocation:
                          orderModel.destinationLocationName.toString(),
                    ),
                    const SizedBox(height: 10),
                    ButtonThem.buildButton(
                      context,
                      title: "Accept Ride".tr,
                      onPress: () async {
                        if (controller
                                .driverModel.value.subscriptionTotalOrders ==
                            "-1") {
                          controller.acceptOrder(orderModel);
                        } else {
                          if (Constant.isSubscriptionModelApplied == false &&
                              Constant.adminCommission!.isEnabled == false) {
                            controller.acceptOrder(orderModel);
                          } else {
                            if ((controller.driverModel.value
                                            .subscriptionExpiryDate !=
                                        null &&
                                    controller.driverModel.value
                                            .subscriptionExpiryDate!
                                            .toDate()
                                            .isBefore(DateTime.now()) ==
                                        false) ||
                                controller.driverModel.value.subscriptionPlan
                                        ?.expiryDay ==
                                    '-1') {
                              if (controller.driverModel.value
                                      .subscriptionTotalOrders !=
                                  '0') {
                                controller.acceptOrder(orderModel);
                              } else {
                                ShowToastDialog.showToast(
                                    "Your order limit has reached their maximum order capacity. Please subscribe another subscription");
                              }
                            } else {
                              ShowToastDialog.showToast(
                                  "Your order limit has reached their maximum order capacity. Please subscribe another subscription");
                            }
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
