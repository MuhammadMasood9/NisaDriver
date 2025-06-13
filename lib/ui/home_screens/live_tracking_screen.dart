import 'dart:math';
import 'dart:developer' as dev;

import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/live_tracking_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    try {
      final String style = await DefaultAssetBundle.of(context)
          .loadString('assets/map_style.json');
      setState(() {
        _mapStyle = style;
      });
    } catch (e) {
      print('Error loading map style: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final double controlButtonsBottom = screenHeight * 0.45;

    return GetBuilder<LiveTrackingController>(
      init: LiveTrackingController(),
      builder: (controller) {
        return Scaffold(
          body: Stack(
            children: [
              Obx(() => GoogleMap(
                    compassEnabled: true,
                    rotateGesturesEnabled: false, // Disabled rotation
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    mapType: controller.isNightMode.value
                        ? MapType.hybrid
                        : MapType.normal,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    polylines: Set.of(controller.polyLines.values),
                    markers: Set.of(controller.markers.values),
                    padding: EdgeInsets.only(
                      bottom: isSmallScreen ? 300 : 340,
                      top: isSmallScreen ? 140 : 160,
                    ),
                    onMapCreated: (GoogleMapController mapController) async {
                      controller.mapController = mapController;
                      try {
                        await mapController.setMapStyle(_mapStyle);
                      } catch (e) {
                        print('Error applying map style: $e');
                      }
                      ShowToastDialog.closeLoader();
                      if (controller.isFollowingDriver.value) {
                        controller.updateNavigationView();
                      }
                    },
                    initialCameraPosition: CameraPosition(
                      zoom: controller.navigationZoom.value,
                      target: LatLng(
                        controller.currentPosition.value?.latitude ??
                            Constant.currentLocation?.latitude ??
                            45.521563,
                        controller.currentPosition.value?.longitude ??
                            Constant.currentLocation?.longitude ??
                            -122.677433,
                      ),
                      tilt: 0.0,
                      bearing: 0.0, // Fixed bearing
                    ),
                    onCameraMove: (CameraPosition position) {
                      controller.navigationZoom.value = position.zoom;
                      dev.log('Zoom: ${controller.navigationZoom.value}');
                    },
                    onTap: (LatLng position) {
                      controller.onMapTap(position);
                    },
                  )),
              _buildStatusBar(context, controller),
              _buildOffRouteWarning(context, controller),
              _buildControlButtons(controller, controlButtonsBottom),
              _buildBottomPanel(context, controller),
              _buildTrafficReportTrigger(controller, controlButtonsBottom),
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
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    )),
                Obx(() => _buildInfoChip(
                      icon: Icons.speed,
                      text:
                          "${controller.currentSpeed.value.toStringAsFixed(0)} km/h",
                      color: controller.currentSpeed.value >
                              (double.tryParse(controller.speedLimit.value) ??
                                  50)
                          ? Colors.red.withOpacity(0.9)
                          : Colors.white.withOpacity(0.9),
                    )),
                Row(
                  children: [
                    const SizedBox(width: 8),
                    Obx(() => _buildInfoChip(
                          icon: Icons.traffic,
                          text: controller.getTrafficLevelText(),
                          color: controller.getTrafficLevelColor(),
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
                            "Off route! Follow the red path to return.",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => controller.recalculateRoute(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Reroute",
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shadowColor: Colors.black.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
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
              Row(
                children: [
                  Obx(() => Container(
                        padding: const EdgeInsets.all(8),
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
                          size: 24,
                        ),
                      )),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() => Text(
                              controller.navigationInstruction.value,
                              style: AppTypography.smBoldLabel(context),
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
              Obx(() => controller.nextTurnInstruction.value.isNotEmpty
                  ? Column(
                      children: [
                        const SizedBox(height: 10),
                      ],
                    )
                  : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons(
      LiveTrackingController controller, double bottom) {
    return Positioned(
      bottom: bottom,
      right: 16,
      child: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              _buildControlButton(
                icon: Icons.volume_up_rounded,
                iconOff: Icons.volume_off_rounded,
                isActive: controller.isVoiceEnabled.value,
                onPressed: () => controller.toggleVoiceGuidance(),
              ),
              _buildControlButton(
                icon: Icons.wb_sunny_rounded,
                iconOff: Icons.nights_stay_rounded,
                isActive: controller.isNightMode.value,
                onPressed: () => controller.toggleNightMode(),
              ),
              _buildControlButton(
                icon: Icons.add_rounded,
                onPressed: () {
                  controller.navigationZoom.value += 0.5;
                  controller.mapController
                      ?.animateCamera(CameraUpdate.zoomIn());
                },
              ),
              _buildControlButton(
                icon: Icons.remove_rounded,
                onPressed: () {
                  controller.navigationZoom.value -= 0.5;
                  controller.mapController
                      ?.animateCamera(CameraUpdate.zoomOut());
                },
              ),
              _buildControlButton(
                icon: Icons.my_location_rounded,
                iconOff: Icons.location_searching_rounded,
                isActive: controller.isFollowingDriver.value,
                onPressed: () => controller.toggleMapView(),
                isPrimary: true,
              ),
            ],
          )),
    );
  }

  Widget _buildBottomPanel(
      BuildContext context, LiveTrackingController controller) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.16,
      maxChildSize: 0.45,
      builder: (BuildContext context, ScrollController scrollController) {
        return AnimatedContainer(
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
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _buildNavigationCard(context, controller),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Obx(() => Text(
                                controller.currentStep.value,
                                style: AppTypography.boldLabel(context),
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
                      const SizedBox(height: 8),
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
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(10),
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
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Obx(() => Text(
                                      controller
                                              .driverUserModel.value.fullName ??
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
                          InkWell(
                            onTap: () => controller.shareLocation(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.share_location_rounded,
                                color: Colors.grey.shade700,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Obx(() => _buildStatItem(
                                  icon: Icons.pin_drop_rounded,
                                  value: controller.formatDistance(
                                      controller.distance.value),
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
                      Row(
                        children: [
                          Expanded(
                            child: Obx(() {
                              final isRideInProgress =
                                  controller.status.value ==
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
                                  OrderModel orderModel =
                                      controller.orderModel.value;
                                  InterCityOrderModel interOrderModel =
                                      controller.intercityOrderModel.value;

                                  if (isRideInProgress) {
                                    ShowToastDialog.showLoader(
                                        "Completing ride...".tr);
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
                                          body: 'Please complete your payment.'
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
                                            "Ride completed successfully".tr);
                                        Get.back();
                                      }
                                    });
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) =>
                                          _otpDialog(context, controller,
                                              orderModel, interOrderModel),
                                    );
                                  }
                                },
                              );
                            }),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              InkWell(
                                onTap: () async {
                                  UserModel? customer =
                                      await FireStoreUtils.getCustomer(
                                          controller.orderModel.value.userId
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
                                    color: AppColors.darkBackground,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Icon(
                                    Icons.chat,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () async {
                                  UserModel? customer =
                                      await FireStoreUtils.getCustomer(
                                          controller.orderModel.value.userId
                                              .toString());
                                  Constant.makePhoneCall(
                                      "${customer!.countryCode}${customer.phoneNumber}");
                                },
                                child: Container(
                                  height: 34,
                                  width: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.darkBackground,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Icon(
                                    Icons.call,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                                    onPressed: () =>
                                        Navigator.pop(context, true),
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
                                Map<String, dynamic> playLoad =
                                    <String, dynamic>{
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
                                Get.back();
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
          ),
        );
      },
    );
  }

  Widget _buildTrafficReportTrigger(
      LiveTrackingController controller, double bottom) {
    return Positioned(
      bottom: bottom,
      left: 16,
      child: Obx(() => _buildControlButton(
            icon: Icons.traffic_rounded,
            isActive: controller.trafficLevel.value > 0,
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: AppColors.background,
                    title: Text("Report Traffic".tr),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text("Light Traffic".tr),
                          onTap: () {
                            controller.reportTraffic(0);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: Text("Moderate Traffic".tr),
                          onTap: () {
                            controller.reportTraffic(1);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: Text("Heavy Traffic".tr),
                          onTap: () {
                            controller.reportTraffic(2);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancel".tr),
                      ),
                    ],
                  );
                },
              );
            },
          )),
    );
  }

  Dialog _otpDialog(BuildContext context, LiveTrackingController controller,
      OrderModel orderModel, InterCityOrderModel interOrderModel) {
    String currentOtp = ""; // Add this variable to store the current OTP
    bool isOtpComplete = false; // Track if OTP is complete

    return Dialog(
      backgroundColor: AppColors.background,
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
                  activeColor: AppColors.textFieldBorder,
                  selectedColor: AppColors.textFieldBorder,
                  inactiveColor: AppColors.textFieldBorder,
                  activeFillColor: AppColors.textField,
                  inactiveFillColor: AppColors.textField,
                  selectedFillColor: AppColors.textField,
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(5),
                ),
                enableActiveFill: true,
                cursorColor: AppColors.primary,
                controller: controller.otpController.value,
                onCompleted: (v) {
                  currentOtp = v; // Store the completed OTP

                  isOtpComplete = true;
                  print("OTP Completed: $currentOtp");
                  // Add a small delay to ensure the value is properly set
                  // Future.delayed(Duration(milliseconds: 100), () {
                  //   currentOtp = v;
                  // });
                },
                // onChanged: (value) {
                //   currentOtp = value; // Update currentOtp on every change
                //   isOtpComplete = value.length == 6; // Check if OTP is complete
                //   otpController.text = value;
                //   print("OTP Changed: $value");
                //   print("OTP Changed22: ${otpController.text}");
                // },
              ),
            ),
            const SizedBox(height: 10),
            ButtonThem.buildButton(
              context,
              title: "OTP verify".tr,
              onPress: () async {
                try {
                  // Add a small delay to ensure the OTP value is captured
                  // await Future.delayed(Duration(milliseconds: 50));
                  print("OTP in button ${currentOtp.trim()}");
                  // Use currentOtp, but also check controller.text as fallback
                  final inputOtp = controller.otpController.value.text;

                  // // If both are empty or incomplete, show error
                  // if (inputOtp.isEmpty || inputOtp.length != 5) {
                  //   ShowToastDialog.showToast("Please enter complete OTP".tr,
                  //       position: EasyLoadingToastPosition.center);
                  //   return;
                  // }
                  print(
                      "OTP after button ${controller.otpController.value.text}");

                  String modelOtp = controller.type.value == "orderModel"
                      ? orderModel.otp ?? ''
                      : interOrderModel.otp ?? '';

                  print(
                      "OTP Verification - Model OTP: '$modelOtp', Input OTP: '$inputOtp'");

                  if (modelOtp == inputOtp) {
                    Get.back();
                    ShowToastDialog.showLoader("Starting ride...".tr);
                    OrderModel orderModel = controller.orderModel.value;
                    orderModel.status = Constant.rideInProgress;

                    await FireStoreUtils.getCustomer(
                            orderModel.userId.toString())
                        .then((value) async {
                      if (value != null && value.fcmToken != null) {
                        await SendNotification.sendOneNotification(
                          token: value.fcmToken.toString(),
                          title: 'Ride Started'.tr,
                          body:
                              'The ride has officially started. Please follow the designated route to the destination.'
                                  .tr,
                          payload: {"type": "city_order_started"},
                        );
                      }
                    });

                    await FireStoreUtils.setOrder(orderModel).then((value) {
                      if (value == true) {
                        ShowToastDialog.closeLoader();
                        ShowToastDialog.showToast(
                            "Customer pickup successful".tr);
                        controller.status.value = Constant.rideInProgress;
                        controller.updateRouteVisibility();
                      }
                    });
                  } else {
                    ShowToastDialog.showToast("Invalid OTP".tr,
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
          Icon(icon, size: 12, color: Colors.black87),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
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
                style: AppTypography.boldLabel(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.smBoldLabel(context)
              .copyWith(color: AppColors.grey500),
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
      case 'roundabout':
        return Icons.roundabout_right_rounded;
      default:
        return Icons.arrow_upward_rounded;
    }
  }
}
