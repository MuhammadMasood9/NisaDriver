import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/order_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/ui/order_screen/complete_order_screen.dart';
import 'package:driver/ui/review/review_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<OrderController>(
      init: OrderController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.grey75,
          body: controller.isLoading.value
              ? Constant.loader(context)
              : StreamBuilder<QuerySnapshot>(
                  // MODIFICATION: Added a .where() clause to filter for completed rides only.
                  stream: FirebaseFirestore.instance
                      .collection(CollectionName.orders)
                      .where('driverId',
                          isEqualTo: FireStoreUtils.getCurrentUid())
                      .where('status',
                          isEqualTo:
                              Constant.rideComplete) // This line is added
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
                        ? Center(
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
                                // MODIFICATION: Updated the empty state message.
                                Text(
                                    "Your completed rides will appear here.".tr,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                          ))
                        : ListView.builder(
                            itemCount: snapshot.data!.docs.length,
                            padding: const EdgeInsets.only(
                                left: 6, right: 6, bottom: 80),
                            itemBuilder: (context, index) {
                              OrderModel orderModel = OrderModel.fromJson(
                                  snapshot.data!.docs[index].data()
                                      as Map<String, dynamic>);
                              return _buildOrderCard(
                                  context, orderModel, controller);
                            },
                          );
                  },
                ),
        );
      },
    );
  }

  /// Builds the main card for displaying an order.
  Widget _buildOrderCard(
      BuildContext context, OrderModel orderModel, OrderController controller) {
    return InkWell(
      onTap: () {
        Get.to(() => const CompleteOrderScreen(),
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
                    height: 10,
                    thickness: 1,
                    color: AppColors.background,
                  ),
                  _buildActionButtons(context, orderModel),
                  const SizedBox(height: 0),
                  _buildCashConfirmationButton(context, orderModel, controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the top header showing the ride status and date.
  Widget _buildStatusHeader(BuildContext context, OrderModel orderModel) {
    // This logic already handles completed status correctly, no changes needed here.
    bool isCompleted = orderModel.status == Constant.rideComplete;
    Color statusColor = isCompleted ? AppColors.primary : AppColors.primary;
    String statusText =
        isCompleted ? "Ride Completed".tr : orderModel.status.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
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

  /// Builds the section with pickup/destination, fare, and distance.
  Widget _buildLocationAndPriceSection(
      BuildContext context, OrderModel orderModel) {
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
                color: AppColors.primary.withValues(alpha: 0.1),
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
                  "${(double.parse(orderModel.distance.toString())).toStringAsFixed(Constant.currencyModel!.decimalDigits!)} ${orderModel.distanceType}",
                  style: AppTypography.boldLabel(context),
                ),
              ],
            )
          ],
        ),
      ],
    );
  }

  /// Builds the action buttons (Review, Chat, Call).
  Widget _buildActionButtons(BuildContext context, OrderModel orderModel) {
    // This logic automatically hides Chat/Call for completed rides, so no changes are needed.
    bool isRideActive = orderModel.status != Constant.rideComplete;

    return Row(
      children: [
        Expanded(
          flex: 2,
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
                  "type": "orderModel",
                  "orderModel": orderModel,
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
        if (isRideActive) const SizedBox(width: 10),
        if (isRideActive)
          _buildCircleIconButton(
            icon: Icons.chat_bubble_outline,
            onTap: () async {
              UserModel? customer = await FireStoreUtils.getCustomer(
                  orderModel.userId.toString());
              DriverUserModel? driver = await FireStoreUtils.getDriverProfile(
                  orderModel.driverId.toString());
              if (customer != null && driver != null) {
                Get.to(() => ChatScreens(
                      driverId: driver.id,
                      customerId: customer.id,
                      customerName: customer.fullName,
                      customerProfileImage: customer.profilePic,
                      driverName: driver.fullName,
                      driverProfileImage: driver.profilePic,
                      orderId: orderModel.id,
                      token: customer.fcmToken,
                    ));
              }
            },
          ),
        if (isRideActive) const SizedBox(width: 10),
        if (isRideActive)
          _buildCircleIconButton(
            icon: Icons.call_outlined,
            onTap: () async {
              UserModel? customer = await FireStoreUtils.getCustomer(
                  orderModel.userId.toString());
              if (customer != null) {
                Constant.makePhoneCall(
                    "${customer.countryCode}${customer.phoneNumber}");
              }
            },
          ),
      ],
    );
  }

  Widget _buildCircleIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Expanded(
      flex: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
      ),
    );
  }

  /// Builds the "Confirm Cash Payment" button, which is only visible when needed.
  Widget _buildCashConfirmationButton(
      BuildContext context, OrderModel orderModel, OrderController controller) {
    // This button will now always be hidden because of the status check, which is correct.
    return Visibility(
      visible: controller.paymentModel.value.cash!.name ==
              orderModel.paymentType.toString() &&
          orderModel.paymentStatus == false &&
          orderModel.status != Constant.rideComplete,
      child: Padding(
        padding: const EdgeInsets.only(top: 3.0),
        child: ButtonThem.buildBorderButton(
          context,
          title: "Confirm cash payment".tr,
          btnHeight: 44,
          onPress: () async {
            ShowToastDialog.showLoader("Please wait..".tr);

            orderModel.paymentStatus = true;
            orderModel.status = Constant.rideComplete;
            orderModel.updateDate = Timestamp.now();

            bool success = await FireStoreUtils.setOrder(orderModel);

            ShowToastDialog.closeLoader();

            if (success) {
              ShowToastDialog.showToast(
                  "Payment confirmed and ride completed.".tr);
              Get.to(() => const ReviewScreen(), arguments: {
                "type": "orderModel",
                "orderModel": orderModel,
              });
            } else {
              ShowToastDialog.showToast(
                  "An error occurred. Please try again.".tr);
            }
          },
        ),
      ),
    );
  }
}
