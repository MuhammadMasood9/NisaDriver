import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/active_intercity_order_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/ui/home_screens/live_tracking_screen.dart';
import 'package:driver/ui/intercity_screen/pacel_details_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class ActiveIntercityOrderScreen extends StatelessWidget {
  const ActiveIntercityOrderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Controller is initialized here but state is managed by StreamBuilder
    Get.put(ActiveInterCityOrderController());

    return Scaffold(
      backgroundColor: AppColors.grey75,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(CollectionName.ordersIntercity)
            .where('driverId', isEqualTo: FireStoreUtils.getCurrentUid())
            .where('status', whereIn: [
          Constant.rideInProgress,
          Constant.rideActive
        ]).snapshots(),
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
              final orderModel = InterCityOrderModel.fromJson(
                  snapshot.data!.docs[index].data() as Map<String, dynamic>);
              return _buildActiveOrderCard(context, orderModel);
            },
          );
        },
      ),
    );
  }

  /// Builds the card for an active order, styled with a ride type tag.
  Widget _buildActiveOrderCard(
      BuildContext context, InterCityOrderModel orderModel) {
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
          _buildRideTypeTag(context), // New tag header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              children: [
                _buildLocationAndPriceSection(context, orderModel),
                const SizedBox(height: 10),
                _buildMainActionAndContactRow(context, orderModel),
                const SizedBox(height: 5),
                _buildSecondaryActionRow(context, orderModel),
                const Divider(height: 20, color: AppColors.grey200),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trip on: ${orderModel.whenDates.toString()} at ${orderModel.whenTime.toString()}',
                      style: AppTypography.caption(context)
                          .copyWith(color: Colors.grey.shade600),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 50,
                            child: _buildCircleIconButton(
                              context: context,
                              icon: Icons.chat_bubble_outline,
                              onTap: () => _openChat(orderModel),
                            ),
                          ),
                          const SizedBox(width: 5),
                          SizedBox(
                            width: 50,
                            child: _buildCircleIconButton(
                              context: context,
                              icon: Icons.call_outlined,
                              onTap: () => _makePhoneCall(orderModel),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top tag indicating the ride type.
  Widget _buildRideTypeTag(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade700.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Inter-City Ride".tr,
            style: AppTypography.boldLabel(context)
                .copyWith(color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }

  /// Builds the location/price/distance section.
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
                        amount: orderModel.offerRate.toString()),
                    style: AppTypography.boldLabel(context)
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ],
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
                  '${orderModel.distance} ${orderModel.distanceType}',
                  style: AppTypography.boldLabel(context),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Main action (Pickup/Complete) and track button.
  Widget _buildMainActionAndContactRow(
      BuildContext context, InterCityOrderModel orderModel) {
    bool isRideInProgress = orderModel.status == Constant.rideInProgress;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 35,
            child: ElevatedButton(
              onPressed: () => isRideInProgress
                  ? _completeRide(orderModel)
                  : _showOtpDialog(context, orderModel),
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
            child: SizedBox(
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

  /// Secondary actions (Cancel/View Details).
  Widget _buildSecondaryActionRow(
      BuildContext context, InterCityOrderModel orderModel) {
    bool isParcelService = orderModel.intercityServiceId == "647f350983ba2";

    return Row(
      children: [
        Expanded(
          child: SizedBox(
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
          ),
        ),
        if (isParcelService) ...[
          const SizedBox(width: 5),
          Expanded(
            child: SizedBox(
              height: 35,
              child: OutlinedButton(
                onPressed: () => Get.to(() => const ParcelDetailsScreen(),
                    arguments: {"orderModel": orderModel}),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side:
                      BorderSide(color: Colors.blue.shade700.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3)),
                ),
                child: Text("View Details".tr,
                    style: AppTypography.button(context)
                        .copyWith(color: Colors.blue.shade700)),
              ),
            ),
          ),
        ]
      ],
    );
  }

  /// A circular icon button for chat and call.
  Widget _buildCircleIconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
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
            Icon(Icons.explore_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text("No Active Inter-City Rides".tr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            Text("Your current inter-city trips will appear here.".tr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 15, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  /// Shows the OTP dialog for customer pickup.
  void _showOtpDialog(BuildContext context, InterCityOrderModel orderModel) {
    showDialog(
      context: context,
      builder: (BuildContext context) => otpDialog(context, orderModel),
    );
  }

  // --- Action Handlers ---

  Future<void> _completeRide(InterCityOrderModel orderModel) async {
    ShowToastDialog.showLoader("Completing Ride...".tr);
    orderModel.status = Constant.rideComplete;
    orderModel.updateDate = Timestamp.now();

    UserModel? customer =
        await FireStoreUtils.getCustomer(orderModel.userId.toString());
    if (customer?.fcmToken != null) {
      await SendNotification.sendOneNotification(
        token: customer!.fcmToken!,
        title: 'Ride complete!'.tr,
        body: 'Please complete your payment for the inter-city ride.'.tr,
        payload: {"type": "intercity_order_complete", "orderId": orderModel.id},
      );
    }

    if (await FireStoreUtils.setInterCityOrder(orderModel) ?? false) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Ride completed successfully".tr);
      // Optional: Navigate to a review screen if available for intercity
    } else {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to complete ride".tr);
    }
  }

  Future<void> _cancelRide(
      BuildContext context, InterCityOrderModel orderModel) async {
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
          body: 'Your inter-city ride has been cancelled by the driver.'.tr,
          payload: {
            "type": "intercity_order_cancelled",
            "orderId": orderModel.id
          },
        );
      }
      await FireStoreUtils.setInterCityOrder(orderModel);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Ride cancelled successfully".tr);
    }
  }

  void _trackRide(InterCityOrderModel orderModel) {
    if (Constant.mapType == "inappmap") {
      Get.to(() => const LiveTrackingScreen(), arguments: {
        "interCityOrderModel": orderModel,
        "type": "interCityOrderModel"
      });
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

  Future<void> _openChat(InterCityOrderModel orderModel) async {
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

  Future<void> _makePhoneCall(InterCityOrderModel orderModel) async {
    UserModel? customer =
        await FireStoreUtils.getCustomer(orderModel.userId.toString());
    if (customer?.phoneNumber != null) {
      Constant.makePhoneCall("${customer!.countryCode}${customer.phoneNumber}");
    }
  }

  /// OTP verification dialog.
  Dialog otpDialog(BuildContext context, InterCityOrderModel orderModel) {
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

  Future<void> _verifyOtp(
      String inputOtp, InterCityOrderModel orderModel) async {
    if (inputOtp.length < 6) {
      ShowToastDialog.showToast("Please enter the full 6-digit OTP".tr,
          position: EasyLoadingToastPosition.center);
      return;
    }

    if (orderModel.otp.toString().trim() == inputOtp.trim()) {
      Get.back(); // Close the dialog
      ShowToastDialog.showLoader("Please wait...".tr);
      orderModel.status = Constant.rideInProgress;

      await FireStoreUtils.setInterCityOrder(orderModel);

      UserModel? customer =
          await FireStoreUtils.getCustomer(orderModel.userId.toString());
      if (customer?.fcmToken != null) {
        await SendNotification.sendOneNotification(
          token: customer!.fcmToken!,
          title: 'Ride Started'.tr,
          body: 'Your inter-city ride has started. Enjoy your trip!'.tr,
          payload: {},
        );
      }
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Customer pickup successful".tr);

      _trackRide(orderModel); // Automatically open map after successful pickup
    } else {
      ShowToastDialog.showToast("Invalid OTP".tr,
          position: EasyLoadingToastPosition.center);
    }
  }
}
