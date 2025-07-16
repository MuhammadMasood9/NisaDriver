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
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/ui/home_screens/live_tracking_screen.dart';
import 'package:driver/ui/review/review_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class ScheduledOrderScreen extends StatelessWidget {
  const ScheduledOrderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This controller is suitable for handling actions on any active order.
    final ActiveOrderController controller = Get.put(ActiveOrderController());

    return Scaffold(
      backgroundColor: AppColors.grey75,
      body: StreamBuilder<QuerySnapshot>(
        // MODIFIED QUERY: This now only shows active rides that ARE scheduled.
        stream: FirebaseFirestore.instance
            .collection(CollectionName.orders)
            .where('driverId', isEqualTo: FireStoreUtils.getCurrentUid())
            .where('status', whereIn: [
              Constant.rideInProgress,
              Constant.rideActive,
            ])
            .where('isScheduledRide',
                isEqualTo: true) // The key change for this file.
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong'.tr));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Constant.loader(context);
          }

          if (snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6)
                .copyWith(bottom: 80),
            itemBuilder: (context, index) {
              final orderModel = OrderModel.fromJson(
                  snapshot.data!.docs[index].data() as Map<String, dynamic>);
              return _buildActiveOrderCard(context, orderModel, controller);
            },
          );
        },
      ),
    );
  }

  /// Builds the card for an active order, styled with a ride type tag.
  Widget _buildActiveOrderCard(BuildContext context, OrderModel orderModel,
      ActiveOrderController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildRideTypeTag(context, orderModel),
          Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              children: [
                _buildLocationAndPriceSection(context, orderModel),
                Divider(
                  height: 10,
                  thickness: 1,
                  color: AppColors.background,
                ),
                _buildMainActionAndContactRow(context, orderModel, controller),
                SizedBox(height: 5),
                _buildSecondaryActionRow(context, orderModel),
                Divider(
                  height: 20,
                  color: AppColors.grey200,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  spacing: 30,
                  children: [
                    Text(
                      Constant().formatTimestamp(orderModel.createdDate),
                      style: AppTypography.caption(context)
                          .copyWith(color: Colors.grey.shade600),
                    ),
                    Expanded(
                        child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 5,
                      children: [
                        Container(
                          width: 50,
                          child: _buildCircleIconButton(
                            context: context,
                            icon: Icons.chat_bubble_outline,
                            onTap: () => _openChat(orderModel),
                          ),
                        ),
                        Container(
                          width: 50,
                          child: _buildCircleIconButton(
                            context: context,
                            icon: Icons.call_outlined,
                            onTap: () => _makePhoneCall(orderModel),
                          ),
                        )
                      ],
                    )),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top tag indicating the ride type (On-Demand/Scheduled) and date.
  Widget _buildRideTypeTag(BuildContext context, OrderModel orderModel) {
    // This will always evaluate to true now, showing the "Scheduled Ride" tag.
    bool isScheduled = orderModel.isScheduledRide == true;
    Color tagColor = isScheduled ? Colors.orange.shade700 : AppColors.primary;
    String tagText = isScheduled ? "Scheduled Ride".tr : "On-Demand Ride".tr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            tagText,
            style: AppTypography.boldLabel(context).copyWith(color: tagColor),
          ),
        ],
      ),
    );
  }

  /// Builds the location/price/distance section.
  Widget _buildLocationAndPriceSection(
      BuildContext context, OrderModel orderModel) {
    return Column(
      children: [
        // Pickup row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.arrow_circle_down, size: 22, color: AppColors.primary),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("Payment".tr, style: AppTypography.caption(context)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    Constant.amountShow(
                        amount: orderModel.finalRate.toString()),
                    style: AppTypography.boldLabel(context)
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Connector
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
        // Destination row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, size: 22, color: Colors.black87),
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
            ),
          ],
        ),
      ],
    );
  }

  /// Main action (Pickup/Complete) and contact buttons (Chat/Call).
  Widget _buildMainActionAndContactRow(BuildContext context,
      OrderModel orderModel, ActiveOrderController controller) {
    bool isRideInProgress = orderModel.status == Constant.rideInProgress;

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            height: 35,
            child: ElevatedButton(
              onPressed: () => isRideInProgress
                  ? _completeRide(controller, orderModel)
                  : _showOtpDialog(context, controller, orderModel),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRideInProgress
                    ? AppColors.darkBackground
                    : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3)),
              ),
              child: Text(
                isRideInProgress ? "Complete Ride".tr : "Pickup Customer".tr,
                style: AppTypography.button(context)
                    .copyWith(color: AppColors.background),
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
            child: Container(
          height: 35,
          child: OutlinedButton(
            onPressed: () => _trackRide(orderModel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.grey500,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3)),
            ),
            child: Text("Track Ride".tr,
                style: AppTypography.button(context)
                    .copyWith(color: AppColors.grey600)),
          ),
        )),
      ],
    );
  }

  /// Secondary actions (Cancel/Track).
  Widget _buildSecondaryActionRow(BuildContext context, OrderModel orderModel) {
    return Row(
      children: [
        Expanded(
            child: Container(
          height: 35,
          child: OutlinedButton(
            onPressed: () => _cancelRide(context, orderModel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3)),
            ),
            child: Text("Cancel Ride".tr,
                style: AppTypography.button(context)
                    .copyWith(color: AppColors.primary)),
          ),
        )),
      ],
    );
  }

  /// A circular icon button for chat and call.
  Widget _buildCircleIconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      flex: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
      ),
    );
  }

  /// A widget to display when no active rides are found.
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text("No Active Scheduled Rides".tr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            Text("Your current scheduled rides will appear here.".tr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 15, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  /// Shows the OTP dialog for customer pickup.
  void _showOtpDialog(BuildContext context, ActiveOrderController controller,
      OrderModel orderModel) {
    showDialog(
      context: context,
      builder: (BuildContext context) =>
          otpDialog(context, controller, orderModel),
    );
  }

  // --- Action Handlers ---

  Future<void> _completeRide(
      ActiveOrderController controller, OrderModel orderModel) async {
    ShowToastDialog.showLoader("Completing Ride...".tr);
    orderModel.status = Constant.rideComplete;
    orderModel.paymentStatus = true;
    orderModel.updateDate = Timestamp.now();
    UserModel? customer =
        await FireStoreUtils.getCustomer(orderModel.userId.toString());
    if (customer?.fcmToken != null) {
      await SendNotification.sendOneNotification(
        token: customer!.fcmToken!,
        title: 'Ride complete!'.tr,
        body: 'Please complete your payment.'.tr,
        payload: {"type": "city_order_complete", "orderId": orderModel.id},
      );
    }

    if (await FireStoreUtils.setOrder(orderModel)) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Ride completed successfully".tr);
      Get.to(() => const ReviewScreen(), arguments: {
        "type": "orderModel",
        "orderModel": orderModel,
      });
    } else {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to complete ride".tr);
    }
  }

  Future<void> _cancelRide(BuildContext context, OrderModel orderModel) async {
    bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text("Confirm Cancel".tr),
        content: Text("Are you sure you want to cancel this ride?".tr),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("No".tr)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Yes".tr)),
        ],
      ),
    );

    if (confirmCancel == true) {
      ShowToastDialog.showLoader("Cancelling ride...".tr);
      orderModel.status = Constant.rideCanceled;

      UserModel? customer =
          await FireStoreUtils.getCustomer(orderModel.userId.toString());
      if (customer?.fcmToken != null) {
        await SendNotification.sendOneNotification(
          token: customer!.fcmToken!,
          title: 'Ride Cancelled'.tr,
          body: 'Your ride has been cancelled by the driver.'.tr,
          payload: {"type": "city_order_cancelled", "orderId": orderModel.id},
        );
      }
      await FireStoreUtils.setOrder(orderModel);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Ride cancelled successfully".tr);
    }
  }

  void _trackRide(OrderModel orderModel) {
    if (Constant.mapType == "inappmap") {
      Get.to(() => const LiveTrackingScreen(),
          arguments: {"orderModel": orderModel, "type": "orderModel"});
    } else {
      if (orderModel.status == Constant.rideInProgress) {
        Utils.redirectMap(
          latitude: orderModel.destinationLocationLAtLng!.latitude!,
          longLatitude: orderModel.destinationLocationLAtLng!.longitude!,
          name: orderModel.destinationLocationName.toString(),
        );
      } else {
        Utils.redirectMap(
          latitude: orderModel.sourceLocationLAtLng!.latitude!,
          longLatitude: orderModel.sourceLocationLAtLng!.longitude!,
          name: orderModel.sourceLocationName.toString(),
        );
      }
    }
  }

  Future<void> _openChat(OrderModel orderModel) async {
    UserModel? customer =
        await FireStoreUtils.getCustomer(orderModel.userId.toString());
    DriverUserModel? driver =
        await FireStoreUtils.getDriverProfile(orderModel.driverId.toString());
    if (customer != null && driver != null) {
      Get.to(() => ChatScreens(
          driverId: driver.id,
          customerId: customer.id,
          customerName: customer.fullName,
          customerProfileImage: customer.profilePic,
          driverName: driver.fullName,
          driverProfileImage: driver.profilePic,
          orderId: orderModel.id,
          token: customer.fcmToken));
    }
  }

  Future<void> _makePhoneCall(OrderModel orderModel) async {
    UserModel? customer =
        await FireStoreUtils.getCustomer(orderModel.userId.toString());
    if (customer?.phoneNumber != null) {
      Constant.makePhoneCall("${customer!.countryCode}${customer.phoneNumber}");
    }
  }

  /// OTP verification dialog.
  Dialog otpDialog(BuildContext context, ActiveOrderController controller,
      OrderModel orderModel) {
    final TextEditingController otpController = TextEditingController();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      backgroundColor: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter Customer OTP".tr,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 18)),
            const SizedBox(height: 8),
            Text("Ask the customer for the 6-digit code to start the ride.".tr,
                style: GoogleFonts.poppins(color: Colors.grey.shade600)),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: PinCodeTextField(
                length: 6,
                appContext: context,
                keyboardType: TextInputType.phone,
                pinTheme: PinTheme(
                  fieldHeight: 45,
                  fieldWidth: 40,
                  activeColor: AppColors.primary,
                  selectedColor: AppColors.primary,
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
                onCompleted: (v) async => _verifyOtp(v, orderModel),
                onChanged: (value) {},
              ),
            ),
            const SizedBox(height: 16),
            ButtonThem.buildButton(
              context,
              title: "Verify & Start Ride".tr,
              onPress: () async => _verifyOtp(otpController.text, orderModel),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyOtp(String inputOtp, OrderModel orderModel) async {
    if (inputOtp.length < 6) {
      ShowToastDialog.showToast("Please enter the full 6-digit OTP".tr,
          position: EasyLoadingToastPosition.center);
      return;
    }

    if (orderModel.otp.toString().trim() == inputOtp.trim()) {
      Get.back(); // Close the dialog
      ShowToastDialog.showLoader("Please wait...".tr);
      orderModel.status = Constant.rideInProgress;

      await FireStoreUtils.setOrder(orderModel);

      UserModel? customer =
          await FireStoreUtils.getCustomer(orderModel.userId.toString());
      if (customer?.fcmToken != null) {
        await SendNotification.sendOneNotification(
          token: customer!.fcmToken!,
          title: 'Ride Started'.tr,
          body: 'Your ride has started. Enjoy your trip!'.tr,
          payload: {},
        );
      }
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Customer pickup successful".tr);

      if (Constant.mapType == "inappmap") {
        Get.to(() => const LiveTrackingScreen(),
            arguments: {"orderModel": orderModel, "type": "orderModel"});
      }
    } else {
      ShowToastDialog.showToast("Invalid OTP".tr,
          position: EasyLoadingToastPosition.center);
    }
  }
}
