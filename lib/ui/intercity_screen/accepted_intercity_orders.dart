import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/intercity_screen/pacel_details_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AcceptedIntercityOrders extends StatelessWidget {
  const AcceptedIntercityOrders({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                      .where('acceptedDriverId',
                          arrayContains: FireStoreUtils.getCurrentUid())
                      .where('intercityServiceId', whereIn: [
                    "647f340e35553",
                    '647f350983ba2',
                    'UmQ2bjWTnlwoKqdCIlTr'
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Constant.loader(context);
                    }
                    return snapshot.data!.docs.isEmpty
                        ? Center(
                            child: Text(
                              "No accepted ride found".tr,
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
                                  if (orderModel.intercityServiceId ==
                                      "647f350983ba2") {
                                    Get.to(const ParcelDetailsScreen(),
                                        arguments: {"orderModel": orderModel});
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(10)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.3),
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
                                                  builder: (context, snapshot) {
                                                    switch (snapshot
                                                        .connectionState) {
                                                      case ConnectionState
                                                          .waiting:
                                                        return Constant.loader(
                                                            context);
                                                      case ConnectionState.done:
                                                        if (snapshot.hasError) {
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
                                                              snapshot.data!;
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
                                                          .boldLabel(context),
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
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey
                                                            .withOpacity(0.3),
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
                                                                vertical: 6),
                                                        child: Text(
                                                          orderModel.paymentType
                                                              .toString(),
                                                          style: AppTypography
                                                              .boldLabel(
                                                                  context),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary
                                                            .withOpacity(0.3),
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
                                                                vertical: 6),
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
                                                    style:
                                                        AppTypography.boldLabel(
                                                                context)
                                                            .copyWith(
                                                                color: AppColors
                                                                    .primary),
                                                  ),
                                                ),
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
  }
}
