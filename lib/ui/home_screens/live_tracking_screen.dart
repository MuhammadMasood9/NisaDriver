import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/live_tracking_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';

class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LiveTrackingController>(
      init: LiveTrackingController(),
      builder: (controller) {
        return Scaffold(
          body: Stack(
            children: [
              // Map
              Obx(
                () => GoogleMap(
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapType: MapType.normal,
                  zoomControlsEnabled: false,
                  polylines: Set<Polyline>.of(controller.polyLines.values),
                  markers: Set<Marker>.of(controller.markers.values),
                  padding: EdgeInsets.only(
                    bottom: controller.isNavigationView.value ? 180.0 : 220.0,
                    top: controller.isNavigationView.value ? 100.0 : 120.0,
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
                    bearing: controller.isNavigationView.value
                        ? controller.navigationBearing.value
                        : 0.0,
                  ),
                  onCameraMove: (CameraPosition position) {
                    // Update zoom in controller to keep in sync
                    controller.navigationZoom.value = position.zoom;
                  },
                  onTap: (LatLng position) {
                    if (controller.isFollowingDriver.value) {
                      controller.toggleMapView();
                    }
                  },
                ),
              ),

              // Navigation instruction overlay
              Positioned(
                top: 80,
                left: 15,
                right: 15,
                child: Obx(
                  () => AnimatedOpacity(
                    opacity: controller.isNavigationView.value ? 1.0 : 0.8,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        controller.navigationInstruction.value,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: controller.isNavigationView.value ? 18 : 16, // Larger font for navigation
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),

              // Top status indicator
              Positioned(
                top: 20,
                left: 15,
                right: 15,
                child: Obx(
                  () => Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.95),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              controller.status.value == Constant.rideInProgress
                                  ? Icons.local_taxi
                                  : Icons.directions_car,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              controller.currentStep.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14, // Slightly larger for clarity
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            controller.status.value,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom panel with ride info
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Obx(
                  () => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle for dragging
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),

                        // Trip progress
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    controller.status.value ==
                                            Constant.rideInProgress
                                        ? "Ride Progress"
                                        : "Approaching Pickup",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16, // Larger for readability
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    controller.tripProgress.value,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: controller.tripProgressValue.value,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  controller.status.value ==
                                          Constant.rideInProgress
                                      ? Colors.green
                                      : AppColors.primary,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                minHeight: 10, // Thicker progress bar
                              ),
                            ],
                          ),
                        ),

                        // ETA, Distance, and other trip details
                        Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              // Driver info
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.primary.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          controller.driverUserModel.value
                                                  .fullName ??
                                              "Driver",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 20, // Larger for emphasis
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          controller.type.value == "orderModel"
                                              ? "Order #${controller.orderModel.value.id?.substring(0, 8) ?? 'N/A'}"
                                              : "Intercity #${controller.intercityOrderModel.value.id?.substring(0, 8) ?? 'N/A'}",
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const Divider(height: 24, thickness: 1),

                              // Distance, Time, and ETA
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Distance
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.pin_drop,
                                              color: AppColors.primary,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              controller.formatDistance(
                                                  controller.distance.value),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14, // Larger for readability
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "Distance",
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Divider
                                  Container(
                                    height: 48,
                                    width: 1,
                                    color: Colors.grey.shade300,
                                  ),

                                  // Time
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              color: Colors.orange.shade700,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              controller.estimatedTime.value,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "Time Left",
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Divider
                                  Container(
                                    height: 48,
                                    width: 1,
                                    color: Colors.grey.shade300,
                                  ),

                                  // ETA
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.directions_car,
                                              color: Colors.green.shade700,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              controller.estimatedArrival.value,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "ETA",
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Map control buttons
              Positioned(
                bottom: controller.isNavigationView.value ? 220 : 280,
                right: 16,
                child: Column(
                  children: [
                    // Zoom in
                    FloatingActionButton(
                      mini: true,
                      heroTag: "zoom_in",
                      backgroundColor: Colors.white,
                      elevation: 4,
                      onPressed: () {
                        controller.navigationZoom.value += 0.5; // Smoother zoom increment
                        controller.mapController
                            ?.animateCamera(CameraUpdate.zoomIn());
                      },
                      child: Icon(
                        Icons.add,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Zoom out
                    FloatingActionButton(
                      mini: true,
                      heroTag: "zoom_out",
                      backgroundColor: Colors.white,
                      elevation: 4,
                      onPressed: () {
                        controller.navigationZoom.value -= 0.5; // Smoother zoom decrement
                        controller.mapController
                            ?.animateCamera(CameraUpdate.zoomOut());
                      },
                      child: Icon(
                        Icons.remove,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Toggle navigation view
                    Obx(
                      () => FloatingActionButton(
                        mini: true,
                        heroTag: "track_driver",
                        backgroundColor: controller.isNavigationView.value
                            ? AppColors.primary
                            : Colors.white,
                        elevation: 4,
                        onPressed: () {
                          controller.toggleMapView();
                        },
                        child: Icon(
                          controller.isNavigationView.value
                              ? Icons.my_location
                              : Icons.location_searching,
                          color: controller.isNavigationView.value
                              ? Colors.white
                              : AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}