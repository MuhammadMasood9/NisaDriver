import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/intercity_controller.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/ui/intercity_screen/pacel_details_screen.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
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
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX<IntercityController>(
        init: IntercityController()..getOrder(), // Fetch data on init
        builder: (controller) {
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            resizeToAvoidBottomInset: true,
            body: Column(
              children: [
                SizedBox(
                  // height: Responsive.width(8, context),
                  width: Responsive.width(100, context),
                ),
                Expanded(
                  child: Container(
                    height: Responsive.height(100, context),
                    width: Responsive.width(100, context),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.background,
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25))),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          children: [
                            Expanded(
                              child: controller.isLoading.value
                                  ? Constant.loader(context)
                                  : controller.intercityServiceOrder.isEmpty
                                      ? Center(
                                          child: Text("No Rides found".tr),
                                        )
                                      : ListView.builder(
                                          itemCount: controller
                                              .intercityServiceOrder.length,
                                          shrinkWrap: true,
                                          itemBuilder: (context, index) {
                                            InterCityOrderModel orderModel =
                                                controller
                                                        .intercityServiceOrder[
                                                    index];
                                            String amount;
                                            if (Constant.distanceType == "Km") {
                                              amount = Constant.amountCalculate(
                                                      orderModel
                                                          .intercityService!
                                                          .kmCharge
                                                          .toString(),
                                                      orderModel.distance
                                                          .toString())
                                                  .toStringAsFixed(Constant
                                                      .currencyModel!
                                                      .decimalDigits!);
                                            } else {
                                              amount = Constant.amountCalculate(
                                                      orderModel
                                                          .intercityService!
                                                          .kmCharge
                                                          .toString(),
                                                      orderModel.distance
                                                          .toString())
                                                  .toStringAsFixed(Constant
                                                      .currencyModel!
                                                      .decimalDigits!);
                                            }
                                            return InkWell(
                                              onTap: () {
                                                if (orderModel
                                                            .acceptedDriverId !=
                                                        null &&
                                                    orderModel.acceptedDriverId!
                                                        .contains(FireStoreUtils
                                                            .getCurrentUid())) {
                                                  ShowToastDialog.showToast(
                                                      "Ride already accepted"
                                                          .tr);
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
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: themeChange.getThem()
                                                        ? AppColors
                                                            .darkContainerBackground
                                                        : AppColors
                                                            .containerBackground,
                                                    borderRadius:
                                                        const BorderRadius.all(
                                                            Radius.circular(
                                                                10)),
                                                    border: Border.all(
                                                        color: themeChange
                                                                .getThem()
                                                            ? AppColors
                                                                .darkContainerBorder
                                                            : AppColors
                                                                .containerBorder,
                                                        width: 0.5),
                                                    boxShadow: themeChange
                                                            .getThem()
                                                        ? null
                                                        : [
                                                            BoxShadow(
                                                              color: Colors.grey
                                                                  .withOpacity(
                                                                      0.5),
                                                              blurRadius: 8,
                                                              offset:
                                                                  const Offset(
                                                                      0, 2),
                                                            ),
                                                          ],
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 10,
                                                        horizontal: 10),
                                                    child: Column(
                                                      children: [
                                                        UserView(
                                                          userId:
                                                              orderModel.userId,
                                                          amount: orderModel
                                                              .offerRate,
                                                          distance: orderModel
                                                              .distance,
                                                          distanceType:
                                                              orderModel
                                                                  .distanceType,
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
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
                                                                style: GoogleFonts.poppins(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        18)),
                                                            orderModel.intercityServiceId ==
                                                                    "647f350983ba2"
                                                                ? const SizedBox()
                                                                : Text(
                                                                    " For ${orderModel.numberOfPassenger} Person"
                                                                        .tr,
                                                                    style: GoogleFonts.poppins(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        fontSize:
                                                                            18)),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    decoration: BoxDecoration(
                                                                        color: Colors
                                                                            .grey
                                                                            .withOpacity(
                                                                                0.30),
                                                                        borderRadius: const BorderRadius
                                                                            .all(
                                                                            Radius.circular(5))),
                                                                    child:
                                                                        Padding(
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              10,
                                                                          vertical:
                                                                              4),
                                                                      child: Text(orderModel
                                                                          .paymentType
                                                                          .toString()),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 10,
                                                                  ),
                                                                  Container(
                                                                    decoration: BoxDecoration(
                                                                        color: AppColors
                                                                            .primary
                                                                            .withOpacity(
                                                                                0.30),
                                                                        borderRadius: const BorderRadius
                                                                            .all(
                                                                            Radius.circular(5))),
                                                                    child:
                                                                        Padding(
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              10,
                                                                          vertical:
                                                                              4),
                                                                      child: Text(Constant.localizationName(orderModel
                                                                          .intercityService!
                                                                          .name)),
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
                                                                    "View details"
                                                                        .tr,
                                                                    style: GoogleFonts
                                                                        .poppins(),
                                                                  )),
                                                            )
                                                          ],
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 14),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                                color: themeChange
                                                                        .getThem()
                                                                    ? AppColors
                                                                        .darkGray
                                                                    : AppColors
                                                                        .gray,
                                                                borderRadius:
                                                                    const BorderRadius
                                                                        .all(
                                                                        Radius.circular(
                                                                            10))),
                                                            child: Padding(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical:
                                                                        12),
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
                                                                        style: GoogleFonts.poppins(
                                                                            fontWeight:
                                                                                FontWeight.w600)),
                                                                    const SizedBox(
                                                                      width: 10,
                                                                    ),
                                                                    Text(
                                                                        orderModel
                                                                            .whenTime
                                                                            .toString(),
                                                                        style: GoogleFonts.poppins(
                                                                            fontWeight:
                                                                                FontWeight.w600)),
                                                                  ],
                                                                )),
                                                          ),
                                                        ),
                                                        LocationView(
                                                          sourceLocation: orderModel
                                                              .sourceLocationName
                                                              .toString(),
                                                          destinationLocation:
                                                              orderModel
                                                                  .destinationLocationName
                                                                  .toString(),
                                                        ),
                                                        Column(
                                                          children: [
                                                            const SizedBox(
                                                              height: 10,
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          10,
                                                                      vertical:
                                                                          5),
                                                              child: Container(
                                                                width: Responsive
                                                                    .width(100,
                                                                        context),
                                                                decoration: BoxDecoration(
                                                                    color: themeChange.getThem()
                                                                        ? AppColors
                                                                            .darkGray
                                                                        : AppColors
                                                                            .gray,
                                                                    borderRadius:
                                                                        const BorderRadius
                                                                            .all(
                                                                            Radius.circular(10))),
                                                                child: Padding(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            10,
                                                                        vertical:
                                                                            10),
                                                                    child:
                                                                        Center(
                                                                      child:
                                                                          Text(
                                                                        'Recommended Price is ${Constant.amountShow(amount: amount)}. Approx distance ${double.parse(orderModel.distance.toString()).toStringAsFixed(Constant.currencyModel!.decimalDigits!)} ${Constant.distanceType}'
                                                                            .tr,
                                                                        style: GoogleFonts.poppins(
                                                                            fontWeight:
                                                                                FontWeight.w500),
                                                                      ),
                                                                    )),
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                            )
                          ],
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
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(15),
                    topLeft: Radius.circular(15))),
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
                    const SizedBox(
                      height: 10,
                    ),
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
                    const SizedBox(
                      height: 5,
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
