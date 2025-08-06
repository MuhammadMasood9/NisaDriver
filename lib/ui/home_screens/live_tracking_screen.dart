import 'dart:math';
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
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
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

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with TickerProviderStateMixin {
  String? _mapStyle;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
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
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPanelMinHeight = screenHeight * 0.20;
    final bottomPanelMaxHeight = screenHeight * 0.45;

    return GetBuilder<LiveTrackingController>(
      init: LiveTrackingController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          body: Stack(
            children: [
              // Google Map
              Obx(() => GoogleMap(
                    compassEnabled: false,
                    rotateGesturesEnabled: true,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    mapType: MapType.normal,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    trafficEnabled: false,
                    polylines: Set.of(controller.polyLines.values),
                    markers: Set.of(controller.markers.values),
                    padding: EdgeInsets.only(
                      bottom: bottomPanelMinHeight,
                      top: 140,
                    ),
                    onMapCreated: (GoogleMapController mapController) async {
                      controller.mapController = mapController;
                      if (_mapStyle != null) {
                        try {
                          await mapController.setMapStyle(_mapStyle);
                        } catch (e) {
                          print('Error applying map style: $e');
                        }
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
                      tilt: 30,
                      bearing: controller.mapBearing.value,
                    ),
                    onCameraMove: (CameraPosition position) {
                      controller.navigationZoom.value = position.zoom;
                    },
                    onTap: (LatLng position) {
                      controller.onMapTap(position);
                    },
                  )),

              // Status Bar Background
              Container(
                height: MediaQuery.of(context).padding.top,
                color: Colors.white,
              ),

              // Top Navigation Header
              _buildTopNavigationHeader(context, controller),

              // Navigation Instruction Card
              _buildNavigationCard(context, controller),

              // Off-Route Warning
              _buildOffRouteAlert(context, controller),

              // Floating Action Buttons (Left side)
              _buildFloatingActions(context, controller),

              // Map Controls (Right side)
              _buildMapControls(controller, bottomPanelMaxHeight),

              // Bottom Panel
              _buildBottomSheet(context, controller),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopNavigationHeader(
      BuildContext context, LiveTrackingController controller) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).padding.top + 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildBackButton(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Trip in Progress',
                        style: AppTypography.appTitle(context),
                      ),
                      Obx(() => Text(
                            'ETA: ${controller.estimatedArrival.value}',
                            style: AppTypography.caption(context),
                          )),
                    ],
                  ),
                ),
                _buildLiveIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => Get.back(),
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green.shade400,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Live',
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade400),
        ),
      ],
    );
  }

  Widget _buildNavigationCard(
      BuildContext context, LiveTrackingController controller) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 16,
      right: 16,
      child: Obx(
        () => AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: controller.navigationInstruction.value.isEmpty ? 0.0 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getManeuverIcon(controller.currentManeuver.value),
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "In ${controller.distanceToNextTurn.value.toStringAsFixed(0)}m",
                        style: AppTypography.caption(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.navigationInstruction.value,
                        style: AppTypography.appTitle(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.speed, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        "${controller.currentSpeed.value.toStringAsFixed(0)} km/h",
                        style: AppTypography.smBoldLabel(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOffRouteAlert(
      BuildContext context, LiveTrackingController controller) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 180,
      left: 16,
      right: 16,
      child: Obx(
        () => AnimatedSlide(
          offset:
              controller.isOffRoute.value ? Offset.zero : const Offset(0, -2),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          child: AnimatedOpacity(
            opacity: controller.isOffRoute.value ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: controller.isOffRoute.value
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_rounded,
                            color: Colors.orange.shade600, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Off-Route! Recalculating...",
                            style: AppTypography.boldLabel(context).copyWith(
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => controller.recalculateRoute(),
                          child: Text(
                            "Reroute",
                            style: AppTypography.label(context).copyWith(
                              color: Colors.orange.shade700,
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

  Widget _buildFloatingActions(
      BuildContext context, LiveTrackingController controller) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.35,
      left: 16,
      child: Column(
        children: [
          _buildFloatingActionButton(
            icon: Icons.chat_bubble_outline,
            tooltip: 'Chat',
            onPressed: () async {
              UserModel? customer = await FireStoreUtils.getCustomer(
                  controller.orderModel.value.userId.toString());
              DriverUserModel? driver = await FireStoreUtils.getDriverProfile(
                  controller.orderModel.value.driverId.toString());
              if (customer != null && driver != null) {
                Get.to(() => ChatScreens(
                      driverId: driver.id,
                      customerId: customer.id,
                      customerName: customer.fullName,
                      customerProfileImage: customer.profilePic,
                      driverName: driver.fullName,
                      driverProfileImage: driver.profilePic,
                      orderId: controller.orderModel.value.id,
                      token: customer.fcmToken,
                    ));
              }
            },
          ),
          const SizedBox(height: 10),
          _buildFloatingActionButton(
            icon: Icons.phone_outlined,
            tooltip: 'Call',
            onPressed: () async {
              UserModel? customer = await FireStoreUtils.getCustomer(
                  controller.orderModel.value.userId.toString());
              if (customer != null) {
                Constant.makePhoneCall(
                    "${customer.countryCode}${customer.phoneNumber}");
              }
            },
          ),
          const SizedBox(height: 10),
          _buildFloatingActionButton(
            icon: Icons.share_location_outlined,
            tooltip: 'Share Location',
            onPressed: () => controller.shareLocation(),
          ),
          const SizedBox(height: 10),
          _buildFloatingActionButton(
            icon: Icons.traffic_outlined,
            tooltip: 'Report Traffic',
            onPressed: () => _showTrafficReportDialog(context, controller),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls(
      LiveTrackingController controller, double bottomPanelMaxHeight) {
    return Positioned(
      bottom: bottomPanelMaxHeight - 60,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapControlButton(
            icon: Icons.my_location_outlined,
            isActive: controller.isFollowingDriver.value,
            tooltip: 'Recenter',
            onPressed: () => controller.toggleMapView(),
          ),
          const SizedBox(height: 8),
          _buildMapControlButton(
            icon: Icons.volume_up_outlined,
            iconOff: Icons.volume_off_outlined,
            isActive: controller.isVoiceEnabled.value,
            tooltip: 'Toggle Voice',
            onPressed: () => controller.toggleVoiceGuidance(),
          ),
          const SizedBox(height: 8),
          _buildMapControlButton(
            icon: Icons.add,
            tooltip: 'Zoom In',
            onPressed: () =>
                controller.mapController?.animateCamera(CameraUpdate.zoomIn()),
          ),
          const SizedBox(height: 8),
          _buildMapControlButton(
            icon: Icons.remove,
            tooltip: 'Zoom Out',
            onPressed: () =>
                controller.mapController?.animateCamera(CameraUpdate.zoomOut()),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(
      BuildContext context, LiveTrackingController controller) {
    return DraggableScrollableSheet(
      initialChildSize: 0.22,
      minChildSize: 0.22,
      maxChildSize: 0.30,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Obx(() => _buildStatCard(
                                  icon: Icons.access_time_outlined,
                                  value: controller.estimatedTime.value,
                                  label: "Time Left",
                                  color: AppColors.primary,
                                )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Obx(() => _buildStatCard(
                                  icon: Icons.straighten_outlined,
                                  value: controller.formatDistance(
                                      controller.distance.value),
                                  label: "Distance",
                                  color: AppColors.darkBackground,
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Obx(() => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trip Progress',
                                style: AppTypography.boldHeaders(context),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 8,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.grey200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor:
                                      controller.tripProgressValue.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.darkBackground
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )),
                      const SizedBox(height: 24),
                      Obx(() {
                        final isRideInProgress =
                            controller.status.value == Constant.rideInProgress;
                        return Row(
                          spacing: 5,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (isRideInProgress) {
                                    _handleCompleteRide(controller);
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) =>
                                          _otpDialog(
                                        context,
                                        controller,
                                        controller.orderModel.value,
                                        controller.intercityOrderModel.value,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.darkBackground,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  isRideInProgress
                                      ? "Complete ".tr
                                      : "Pickup ".tr,
                                  style: AppTypography.buttonlight(context),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _handleCancelRide(context, controller),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade600,
                                  side: BorderSide(color: Colors.red.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  "Cancel Ride".tr,
                                  style: AppTypography.button(context)
                                      .copyWith(color: AppColors.primary),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingActionButton(
      {required IconData icon,
      required String tooltip,
      required VoidCallback onPressed}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildMapControlButton(
      {required IconData icon,
      IconData? iconOff,
      bool isActive = false,
      required String tooltip,
      required VoidCallback onPressed}) {
    final effectiveIcon = (isActive && iconOff != null) ? iconOff : icon;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBackground.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Icon(
              effectiveIcon,
              color: isActive ? AppColors.primary : Colors.grey.shade700,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      {required IconData icon,
      required String value,
      required String label,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        // crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.boldLabel(context),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.caption(context),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _handleCompleteRide(LiveTrackingController controller) async {
    ShowToastDialog.showLoader("Completing ride...".tr);
    OrderModel orderModel = controller.orderModel.value;
    orderModel.status = Constant.rideComplete;

    UserModel? customer =
        await FireStoreUtils.getCustomer(orderModel.userId.toString());
    if (customer?.fcmToken != null) {
      Map<String, dynamic> playLoad = {
        "type": "city_order_complete",
        "orderId": orderModel.id
      };
      await SendNotification.sendOneNotification(
        token: customer!.fcmToken.toString(),
        title: 'Ride complete!'.tr,
        body: 'Please complete your payment.'.tr,
        payload: playLoad,
      );
    }

    await FireStoreUtils.setOrder(orderModel);
    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Ride completed successfully".tr);
    Get.back();
  }

  Future<void> _handleCancelRide(
      BuildContext context, LiveTrackingController controller) async {
    bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Cancel Ride?".tr,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w600, color: Colors.grey.shade900),
        ),
        content: Text(
          "Are you sure you want to cancel this ride?".tr,
          style: GoogleFonts.inter(color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "No".tr,
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              "Yes, Cancel".tr,
              style: GoogleFonts.inter(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmCancel == true) {
      ShowToastDialog.showLoader("Cancelling ride...".tr);
      OrderModel orderModel = controller.orderModel.value;
      orderModel.status = Constant.rideCanceled;

      UserModel? customer =
          await FireStoreUtils.getCustomer(orderModel.userId.toString());
      if (customer?.fcmToken != null) {
        Map<String, dynamic> playLoad = {
          "type": "city_order_cancelled",
          "orderId": orderModel.id
        };
        await SendNotification.sendOneNotification(
          token: customer!.fcmToken.toString(),
          title: 'Ride Cancelled'.tr,
          body: 'Your ride has been cancelled by the driver.'.tr,
          payload: playLoad,
        );
      }

      await FireStoreUtils.setOrder(orderModel);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Ride cancelled successfully".tr);
      Get.back();
    }
  }

  Dialog _otpDialog(BuildContext context, LiveTrackingController controller,
      OrderModel orderModel, InterCityOrderModel interOrderModel) {
    String currentOtp = "";
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Verify OTP".tr,
              style: AppTypography.boldHeaders(context),
            ),
            const SizedBox(height: 8),
            Text(
              "Enter the 6-digit code from the customer's app.".tr,
              style: AppTypography.caption(context),
            ),
            const SizedBox(height: 12),
            PinCodeTextField(
              length: 6,
              appContext: context,
              keyboardType: TextInputType.number,
              pinTheme: PinTheme(
                fieldHeight: 35,
                fieldWidth: 35,
                borderWidth: 1,
                activeColor: AppColors.primary,
                selectedColor: AppColors.primary,
                inactiveColor: Colors.grey.shade300,
                activeFillColor: AppColors.primary.withOpacity(0.1),
                inactiveFillColor: Colors.grey.shade50,
                selectedFillColor: AppColors.primary.withOpacity(0.1),
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: AppTypography.button(context),
              enableActiveFill: true,
              cursorColor: AppColors.primary,
              controller: controller.otpController.value,
              onCompleted: (v) => currentOtp = v,
              onChanged: (value) => currentOtp = value,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () async {
                  await _verifyOtp(
                      currentOtp, controller, orderModel, interOrderModel);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  "Verify & Start Ride".tr,
                  style: AppTypography.buttonlight(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyOtp(String currentOtp, LiveTrackingController controller,
      OrderModel orderModel, InterCityOrderModel interOrderModel) async {
    try {
      final inputOtp = currentOtp.trim();
      if (inputOtp.length < 6) {
        ShowToastDialog.showToast("Please enter complete OTP".tr,
            position: EasyLoadingToastPosition.center);
        return;
      }

      String modelOtp = controller.type.value == "orderModel"
          ? orderModel.otp ?? ''
          : interOrderModel.otp ?? '';
      if (modelOtp == inputOtp) {
        Get.back();
        ShowToastDialog.showLoader("Starting ride...".tr);
        OrderModel currentOrderModel = controller.orderModel.value;
        currentOrderModel.status = Constant.rideInProgress;

        UserModel? customer = await FireStoreUtils.getCustomer(
            currentOrderModel.userId.toString());
        if (customer?.fcmToken != null) {
          await SendNotification.sendOneNotification(
            token: customer!.fcmToken.toString(),
            title: 'Ride Started'.tr,
            body:
                'The ride has officially started. Please follow the designated route to the destination.'
                    .tr,
            payload: {"type": "city_order_started"},
          );
        }

        await FireStoreUtils.setOrder(currentOrderModel);
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Customer pickup successful".tr);
        controller.status.value = Constant.rideInProgress;
        controller.updateRouteVisibility();
      } else {
        ShowToastDialog.showToast("Invalid OTP".tr,
            position: EasyLoadingToastPosition.center);
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error: ${e.toString()}".tr,
          position: EasyLoadingToastPosition.center);
    }
  }

  void _showTrafficReportDialog(
      BuildContext context, LiveTrackingController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Report Traffic".tr,
            style: AppTypography.appTitle(context),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  "Light Traffic".tr,
                  style: AppTypography.caption(Get.context!),
                ),
                onTap: () {
                  controller.reportTraffic(0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(
                  "Moderate Traffic".tr,
                  style: AppTypography.caption(Get.context!),
                ),
                onTap: () {
                  controller.reportTraffic(1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(
                  "Heavy Traffic".tr,
                  style: AppTypography.caption(Get.context!),
                ),
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
              child: Text("Cancel".tr,
                  style: AppTypography.boldLabel(Get.context!)
                      .copyWith(color: AppColors.grey600)),
            ),
          ],
        );
      },
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
      case 'turn-slight-left':
        return Icons.turn_slight_left_rounded;
      case 'slight-right':
      case 'turn-slight-right':
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
      case 'roundabout-left':
        return Icons.roundabout_left_rounded;
      default:
        return Icons.navigation_rounded;
    }
  }
}
