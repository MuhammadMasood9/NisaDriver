import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/live_tracking_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetBuilder<LiveTrackingController>(
      init: LiveTrackingController(),
      builder: (controller) {
        return Scaffold(
          body: Stack(
            children: [
              // Enhanced Google Map
              Obx(
                () => GoogleMap(
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  mapType: controller.isNightMode.value
                      ? MapType.hybrid
                      : MapType.normal,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  polylines: Set<Polyline>.of(controller.polyLines.values),
                  markers: Set<Marker>.of(controller.markers.values),
                  padding: EdgeInsets.only(
                    bottom: controller.isNavigationView.value
                        ? (isSmallScreen ? 280 : 320)
                        : (isSmallScreen ? 320 : 360),
                    top: controller.isNavigationView.value
                        ? (isSmallScreen ? 120 : 140)
                        : (isSmallScreen ? 140 : 160),
                  ),
                  onMapCreated: (GoogleMapController mapController) {
                    controller.mapController = mapController;
                    ShowToastDialog.closeLoader();
                    if (controller.isFollowingDriver.value) {
                      controller.updateNavigationView();
                    }
                  },
                  initialCameraPosition: CameraPosition(
                    zoom: controller.navigationZoom.value,
                    target: LatLng(
                      Constant.currentLocation?.latitude ?? 45.521563,
                      Constant.currentLocation?.longitude ?? -122.677433,
                    ),
                    tilt: controller.isNavigationView.value
                        ? controller.navigationTilt.value
                        : 0.0,
                    bearing: controller.navigationBearing.value,
                  ),
                  onCameraMove: (CameraPosition position) {
                    controller.navigationZoom.value = position.zoom;
                  },
                  onTap: (LatLng position) {
                    if (controller.isFollowingDriver.value) {
                      controller.toggleMapView();
                    }
                  },
                ),
              ),

              // Modern Status Bar
              _buildStatusBar(context, controller),

              // Off-route warning with modern design
              _buildOffRouteWarning(context, controller),

              // Modern Navigation Instruction Card
              _buildNavigationCard(context, controller),

              // Modern Control Buttons
              _buildControlButtons(controller),

              // Modern Bottom Panel
              _buildBottomPanel(context, controller, themeChange),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(
      BuildContext context, LiveTrackingController controller) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).padding.top + 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.black.withOpacity(0.4),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status chip
                Obx(() => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            controller.status.value == Constant.rideInProgress
                                ? Colors.green.withOpacity(0.9)
                                : Colors.blue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            controller.status.value == Constant.rideInProgress
                                ? Icons.directions_car
                                : Icons.navigation,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            controller.status.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )),
                // Speed and traffic info
                Row(
                  children: [
                    Obx(() => _buildInfoChip(
                          icon: Icons.speed,
                          text:
                              "${controller.currentSpeed.value.toStringAsFixed(0)} km/h",
                          color: Colors.white.withOpacity(0.9),
                        )),
                    const SizedBox(width: 8),
                    Obx(() => _buildInfoChip(
                          icon: Icons.traffic,
                          text: controller.trafficLevel.value == 0
                              ? "Light"
                              : controller.trafficLevel.value == 1
                                  ? "Moderate"
                                  : "Heavy",
                          color: controller.trafficLevel.value == 0
                              ? Colors.green.withOpacity(0.9)
                              : controller.trafficLevel.value == 1
                                  ? Colors.orange.withOpacity(0.9)
                                  : Colors.red.withOpacity(0.9),
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOffRouteWarning(
      BuildContext context, LiveTrackingController controller) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      right: 16,
      child: Obx(
        () => AnimatedSlide(
          offset:
              controller.isOffRoute.value ? Offset.zero : const Offset(0, -1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          child: AnimatedOpacity(
            opacity: controller.isOffRoute.value ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: controller.isOffRoute.value
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.shade500,
                          Colors.red.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Off route! Recalculating...",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
      BuildContext context, LiveTrackingController controller) {
    return Positioned(
      top: controller.isOffRoute.value
          ? MediaQuery.of(context).padding.top + 60
          : MediaQuery.of(context).padding.top + 50,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: Card(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main instruction
                Row(
                  children: [
                    Obx(() => Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getManeuverIcon(controller.currentManeuver.value),
                            color: Colors.white,
                            size: 22,
                          ),
                        )),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Obx(() => Text(
                                controller.navigationInstruction.value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.2,
                                ),
                              )),
                          Obx(() => controller.distanceToNextTurn.value > 0
                              ? Column(
                                  children: [
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "in ${controller.distanceToNextTurn.value.toStringAsFixed(0)}m",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink()),
                        ],
                      ),
                    ),
                  ],
                ),

                // Next turn instruction
                Obx(() => controller.nextTurnInstruction.value.isNotEmpty
                    ? Column(
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Then ${controller.nextTurnInstruction.value}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons(LiveTrackingController controller) {
    return Positioned(
      bottom: 360,
      right: 16,
      child: Obx(() => Column(
            spacing: 10,
            children: [
              _buildControlButton(
                icon: Icons.volume_up_rounded,
                iconOff: Icons.volume_off_rounded,
                isActive: controller.isVoiceEnabled.value,
                onPressed: () {
                  controller.isVoiceEnabled.value =
                      !controller.isVoiceEnabled.value;
                },
              ),
              // const SizedBox(height: 12),
              _buildControlButton(
                icon: Icons.wb_sunny_rounded,
                iconOff: Icons.nights_stay_rounded,
                isActive: controller.isNightMode.value,
                onPressed: () {
                  controller.isNightMode.value = !controller.isNightMode.value;
                },
              ),
              // const SizedBox(height: 12),
              _buildControlButton(
                icon: Icons.add_rounded,
                onPressed: () {
                  controller.navigationZoom.value += 0.5;
                  controller.mapController
                      ?.animateCamera(CameraUpdate.zoomIn());
                },
              ),
              // const SizedBox(height: 12),
              _buildControlButton(
                icon: Icons.remove_rounded,
                onPressed: () {
                  controller.navigationZoom.value -= 0.5;
                  controller.mapController
                      ?.animateCamera(CameraUpdate.zoomOut());
                },
              ),
              // const SizedBox(height: 12),
              _buildControlButton(
                icon: Icons.my_location_rounded,
                iconOff: Icons.location_searching_rounded,
                isActive: controller.isNavigationView.value,
                onPressed: () {
                  controller.toggleMapView();
                },
                isPrimary: true,
              ),
            ],
          )),
    );
  }

  Widget _buildBottomPanel(BuildContext context,
      LiveTrackingController controller, DarkThemeProvider themeChange) {
    return Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Trip Progress Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Obx(() => Text(
                              controller.status.value == Constant.rideInProgress
                                  ? "Trip Progress"
                                  : "Approaching Pickup",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            )),
                        Obx(() => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                controller.tripProgress.value,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Obx(() => LinearProgressIndicator(
                              value: controller.tripProgressValue.value,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                controller.status.value ==
                                        Constant.rideInProgress
                                    ? Colors.green.shade500
                                    : AppColors.primary,
                              ),
                            )),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Driver and Trip Info Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey.shade50,
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Driver Info
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.8),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Obx(() => Text(
                                    controller.driverUserModel.value.fullName ??
                                        "Driver",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  )),
                              const SizedBox(height: 2),
                              Obx(() => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      controller.type.value == "orderModel"
                                          ? "Order #${controller.orderModel.value.id?.substring(0, 8) ?? 'N/A'}"
                                          : "Intercity #${controller.intercityOrderModel.value.id?.substring(0, 8) ?? 'N/A'}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Trip Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      spacing: 4,
                      children: [
                        Expanded(
                          child: Obx(() => _buildStatItem(
                                icon: Icons.pin_drop_rounded,
                                value: controller
                                    .formatDistance(controller.distance.value),
                                label: "Distance",
                                color: AppColors.primary,
                              )),
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        Expanded(
                          child: Obx(() => _buildStatItem(
                                icon: Icons.access_time_rounded,
                                value: controller.estimatedTime.value,
                                label: "Time Left",
                                color: Colors.orange.shade600,
                              )),
                        ),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        Expanded(
                          child: Obx(() => _buildStatItem(
                                icon: Icons.schedule_rounded,
                                value: controller.estimatedArrival.value,
                                label: "ETA",
                                color: Colors.green.shade600,
                              )),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        // Only the button depends on status, so wrap it with Obx
                        Expanded(
                          child: Obx(() {
                            final isRideInProgress = controller.status.value ==
                                Constant.rideInProgress;
                            return ButtonThem.buildBorderButton(
                              context,
                              title: isRideInProgress
                                  ? "Complete Ride".tr
                                  : "Pickup Customer".tr,
                              btnHeight: 34,
                              txtSize: 12,
                              borderRadius: 5,
                              iconVisibility: false,
                              onPress: () async {
                                if (isRideInProgress) {
                                  ShowToastDialog.showLoader(
                                      "Completing ride...".tr);
                                  OrderModel orderModel =
                                      controller.orderModel.value;
                                  orderModel.status = Constant.rideComplete;

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
                                            'Please complete your payment.'.tr,
                                        payload: playLoad,
                                      );
                                    }
                                  });

                                  await FireStoreUtils.setOrder(orderModel)
                                      .then((value) {
                                    if (value == true) {
                                      ShowToastDialog.closeLoader();
                                      ShowToastDialog.showToast(
                                          "Ride completed successfully".tr);
                                      Get.back(); // Navigate back to previous screen
                                    }
                                  });
                                } else {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) =>
                                        _otpDialog(context, controller),
                                  );
                                }
                              },
                            );
                          }),
                        ),
                        const SizedBox(width: 10),
                        // Chat and Call buttons are static
                        Row(
                          children: [
                            InkWell(
                              onTap: () async {
                                UserModel? customer =
                                    await FireStoreUtils.getCustomer(controller
                                        .orderModel.value.userId
                                        .toString());
                                DriverUserModel? driver =
                                    await FireStoreUtils.getDriverProfile(
                                        controller.orderModel.value.driverId
                                            .toString());
                                Get.to(ChatScreens(
                                  driverId: driver!.id,
                                  customerId: customer!.id,
                                  customerName: customer.fullName,
                                  customerProfileImage: customer.profilePic,
                                  driverName: driver.fullName,
                                  driverProfileImage: driver.profilePic,
                                  orderId: controller.orderModel.value.id,
                                  token: customer.fcmToken,
                                ));
                              },
                              child: Container(
                                height: 34,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: themeChange.getThem()
                                      ? AppColors.darkModePrimary
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Icon(
                                  Icons.chat,
                                  color: themeChange.getThem()
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () async {
                                UserModel? customer =
                                    await FireStoreUtils.getCustomer(controller
                                        .orderModel.value.userId
                                        .toString());
                                Constant.makePhoneCall(
                                    "${customer!.countryCode}${customer.phoneNumber}");
                              },
                              child: Container(
                                height: 34,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: themeChange.getThem()
                                      ? AppColors.darkModePrimary
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Icon(
                                  Icons.call,
                                  color: themeChange.getThem()
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Cancel Ride Button (no need for Obx if appearance doesn't change)
                    ButtonThem.buildBorderButton(
                      context,
                      title: "Cancel Ride".tr,
                      btnHeight: 34,
                      borderRadius: 5,
                      txtSize: 12,
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
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text("Yes".tr),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmCancel == true) {
                          ShowToastDialog.showLoader("Cancelling ride...".tr);
                          OrderModel orderModel = controller.orderModel.value;
                          orderModel.status = Constant.rideCanceled;

                          await FireStoreUtils.getCustomer(
                                  orderModel.userId.toString())
                              .then((value) async {
                            if (value != null && value.fcmToken != null) {
                              Map<String, dynamic> playLoad = <String, dynamic>{
                                "type": "city_order_cancelled",
                                "orderId": orderModel.id,
                              };
                              await SendNotification.sendOneNotification(
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
                              Get.back(); // Navigate back to previous screen
                            }
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ));
  }

  Dialog _otpDialog(BuildContext context, LiveTrackingController controller) {
    final themeChange = Provider.of<DarkThemeProvider>(context, listen: false);
    final TextEditingController otpController = TextEditingController();
    String otpValue = "";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
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
                  activeColor: themeChange.getThem()
                      ? AppColors.darkTextFieldBorder
                      : AppColors.textFieldBorder,
                  selectedColor: themeChange.getThem()
                      ? AppColors.darkTextFieldBorder
                      : AppColors.textFieldBorder,
                  inactiveColor: themeChange.getThem()
                      ? AppColors.darkTextFieldBorder
                      : AppColors.textFieldBorder,
                  activeFillColor: themeChange.getThem()
                      ? AppColors.darkTextField
                      : AppColors.textField,
                  inactiveFillColor: themeChange.getThem()
                      ? AppColors.darkTextField
                      : AppColors.textField,
                  selectedFillColor: themeChange.getThem()
                      ? AppColors.darkTextField
                      : AppColors.textField,
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(5),
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

                  String modelOtp =
                      controller.orderModel.value.otp.toString().trim();

                  print(
                      "OTP Verification - Model OTP: '$modelOtp', Input OTP: '$inputOtp', Controller Text: '${otpController.text}'");

                  if (modelOtp == inputOtp) {
                    Get.back();
                    ShowToastDialog.showLoader("Please wait...".tr);
                    OrderModel orderModel = controller.orderModel.value;
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
                        controller.status.value = Constant.rideInProgress;
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

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    IconData? iconOff,
    bool? isActive,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color:
            isActive ?? false || isPrimary ? AppColors.primary : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPressed,
          child: Icon(
            (isActive ?? false) && iconOff != null ? iconOff : icon,
            color: (isActive ?? false) || isPrimary
                ? Colors.white
                : Colors.grey.shade700,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  IconData _getManeuverIcon(String maneuver) {
    switch (maneuver.toLowerCase()) {
      case 'left':
      case 'turn-left':
        return Icons.turn_left_rounded;
      case 'right':
      case 'turn-right':
        return Icons.turn_right_rounded;
      case 'slight-left':
        return Icons.turn_slight_left_rounded;
      case 'slight-right':
        return Icons.turn_slight_right_rounded;
      case 'sharp-left':
        return Icons.turn_sharp_left_rounded;
      case 'sharp-right':
        return Icons.turn_sharp_right_rounded;
      case 'u-turn':
        return Icons.u_turn_left_rounded;
      case 'continue':
      case 'straight':
        return Icons.straight_rounded;
      case 'merge':
        return Icons.merge_rounded;
      case 'roundabout':
        return Icons.roundabout_left_rounded;
      default:
        return Icons.navigation_rounded;
    }
  }

  IconData _getLaneIcon(String lane) {
    switch (lane.toLowerCase()) {
      case 'left':
        return Icons.arrow_back_rounded;
      case 'right':
        return Icons.arrow_forward_rounded;
      case 'straight':
        return Icons.arrow_upward_rounded;
      default:
        return Icons.arrow_upward_rounded;
    }
  }
}
