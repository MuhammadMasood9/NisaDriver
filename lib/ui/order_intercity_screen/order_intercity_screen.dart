import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/intercity_order_controller.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/order_intercity_screen/complete_intecity_order_screen.dart';
import 'package:driver/ui/review/review_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderIntercityScreen extends StatelessWidget {
  const OrderIntercityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<InterCityOrderController>(
      init: InterCityOrderController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.grey75,
          body: controller.isLoading.value
              ? Constant.loader(context)
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(CollectionName.ordersIntercity)
                      .where('driverId',
                          isEqualTo: FireStoreUtils.getCurrentUid())
                      .where('status', isEqualTo: Constant.rideComplete)
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
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: snapshot.data!.docs.length,
                            padding: const EdgeInsets.only(
                                left: 6, right: 6, bottom: 80),
                            itemBuilder: (context, index) {
                              InterCityOrderModel orderModel =
                                  InterCityOrderModel.fromJson(
                                      snapshot.data!.docs[index].data()
                                          as Map<String, dynamic>);
                              return _buildOrderCard(context, orderModel);
                            },
                          );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_off_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text("No Ride History".tr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            Text("Your completed inter-city rides will appear here.".tr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 15, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, InterCityOrderModel orderModel) {
    return InkWell(
      onTap: () {
        Get.to(() => const CompleteIntercityOrderScreen(),
            arguments: {"orderModel": orderModel});
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            _buildStatusHeader(context, orderModel),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationAndPriceSection(context, orderModel),
                  const Divider(
                    height: 20,
                    thickness: 1,
                    color: AppColors.grey200,
                  ),
                  _buildActionButtons(context, orderModel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(
      BuildContext context, InterCityOrderModel orderModel) {
    Color statusColor = AppColors.primary;
    String statusText = "Ride Completed".tr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            statusText,
            style:
                AppTypography.boldLabel(context).copyWith(color: statusColor),
          ),
          Text(
            Constant().formatTimestamp(orderModel.createdDate),
            style: AppTypography.caption(context)
                .copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAndPriceSection(
      BuildContext context, InterCityOrderModel orderModel) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.arrow_circle_down,
                size: 22, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(orderModel.sourceLocationName.toString(),
                      style: AppTypography.boldLabel(context)
                          .copyWith(fontWeight: FontWeight.w500, height: 1.3)),
                  Text("Pickup point".tr,
                      style: AppTypography.caption(context)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                Constant.amountShow(amount: orderModel.finalRate.toString()),
                style: AppTypography.boldLabel(context)
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 22,
              alignment: Alignment.center,
              child:
                  Container(height: 20, width: 1.5, color: AppColors.grey200),
            ),
            Expanded(child: Container()),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, size: 22, color: Colors.black),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(orderModel.destinationLocationName.toString(),
                      style: AppTypography.boldLabel(context)
                          .copyWith(fontWeight: FontWeight.w500, height: 1.3)),
                  Text("Destination".tr, style: AppTypography.caption(context)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("Distance".tr, style: AppTypography.caption(context)),
                Text(
                  '${orderModel.distance.toString()} ${orderModel.distanceType.toString()}',
                  style: AppTypography.boldLabel(context),
                ),
              ],
            )
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(
      BuildContext context, InterCityOrderModel orderModel) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 35,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: Text(
                "Review".tr,
                style: AppTypography.button(context)
                    .copyWith(color: AppColors.grey600),
              ),
              onPressed: () {
                Get.to(() => const ReviewScreen(), arguments: {
                  "type": "interCityOrderModel",
                  "interCityOrderModel": orderModel,
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.grey600,
                padding: const EdgeInsets.symmetric(vertical: 6),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
