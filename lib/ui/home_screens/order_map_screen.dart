import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/order_map_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_them.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class OrderMapScreen extends StatelessWidget {
  const OrderMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OrderMapController>(
      init: OrderMapController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color.fromARGB(0, 255, 228, 239),
          // MODIFICATION: The AppBar and the back button have been removed.
          body: Stack(
            children: [
              GoogleMap(
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                mapType: MapType.normal,
                zoomControlsEnabled: false,
                polylines: Set<Polyline>.of(controller.polyLines.values),
                markers: Set<Marker>.of(controller.markers.values),
                padding: const EdgeInsets.only(bottom: 200.0),
                onMapCreated: (GoogleMapController mapController) async {
                  String style =
                      await rootBundle.loadString('assets/map_style.json');
                  mapController?.setMapStyle(style);
                  controller.mapController.complete(mapController);
                },
                initialCameraPosition: CameraPosition(
                  zoom: 15,
                  target: LatLng(
                    controller
                            .orderModel.value.sourceLocationLAtLng?.latitude ??
                        Constant.currentLocation?.latitude ??
                        45.521563,
                    controller
                            .orderModel.value.sourceLocationLAtLng?.longitude ??
                        Constant.currentLocation?.longitude ??
                        -122.677433,
                  ),
                ),
              ),
              Positioned(
                  bottom: 350,
                  right: 20,
                  child: Container(
                    height: 40,
                    width: 40,
                    child: FloatingActionButton(
                      backgroundColor: AppColors.primary,
                      onPressed: () async {
                        await controller.animateToSourceLocation();
                      },
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  )),
              Positioned(
                top: 30,
                left: 5,
                child: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.arrow_back_ios_new,
                        color: AppColors.primary, size: 20),
                  ),
                  onPressed: () => Get.back(),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.containerBackground,
                    borderRadius: const BorderRadius.all(Radius.circular(15)),
                    border: Border.all(
                      color: AppColors.containerBorder,
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Obx(
                      () => controller.isLoading.value
                          ? Constant.loader(context)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserView(
                                  userId: controller.orderModel.value.userId,
                                  amount: controller.orderModel.value.offerRate,
                                  distance:
                                      controller.orderModel.value.distance,
                                  distanceType:
                                      controller.orderModel.value.distanceType,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(color: AppColors.gray),
                                ),
                                LocationView(
                                  sourceLocation: controller
                                      .orderModel.value.sourceLocationName
                                      .toString(),
                                  destinationLocation: controller
                                      .orderModel.value.destinationLocationName
                                      .toString(),
                                ),
                                const SizedBox(height: 8),
                                Visibility(
                                  visible: controller.orderModel.value.service!
                                          .offerRate ==
                                      true,
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              if (double.parse(controller
                                                      .newAmount.value) >=
                                                  10) {
                                                controller.newAmount
                                                    .value = (double.parse(
                                                            controller.newAmount
                                                                .value) -
                                                        10)
                                                    .toStringAsFixed(Constant
                                                        .currencyModel!
                                                        .decimalDigits!);
                                                controller
                                                        .enterOfferRateController
                                                        .value
                                                        .text =
                                                    controller.newAmount.value;
                                              } else {
                                                controller.newAmount.value =
                                                    "0";
                                              }
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: AppColors
                                                        .textFieldBorder),
                                                borderRadius:
                                                    const BorderRadius.all(
                                                        Radius.circular(30)),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 10),
                                                child: Text(
                                                  "- 10",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            Constant.amountShow(
                                                amount:
                                                    controller.newAmount.value),
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          ButtonThem.roundButton(
                                            context,
                                            title: "+ 10",
                                            btnWidthRatio: 0.22,
                                            onPress: () {
                                              controller.newAmount.value =
                                                  (double.parse(controller
                                                              .newAmount
                                                              .value) +
                                                          10)
                                                      .toStringAsFixed(Constant
                                                          .currencyModel!
                                                          .decimalDigits!);
                                              controller
                                                      .enterOfferRateController
                                                      .value
                                                      .text =
                                                  controller.newAmount.value;
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      TextFieldThem
                                          .buildTextFiledWithPrefixIcon(
                                        context,
                                        hintText: "Enter Fare Rate".tr,
                                        controller: controller
                                            .enterOfferRateController.value,
                                        keyBoardType: const TextInputType
                                            .numberWithOptions(
                                            decimal: true, signed: false),
                                        onChanged: (value) {
                                          if (value.isEmpty) {
                                            controller.newAmount.value = "0.0";
                                          } else {
                                            controller.newAmount.value = value;
                                          }
                                        },
                                        prefix: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 10),
                                          child: Text(
                                            Constant.currencyModel?.symbol
                                                    .toString() ??
                                                '\$',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                FutureBuilder<bool>(
                                  future: FireStoreUtils.hasActiveRide(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Constant.loader(context);
                                    }
                                    if (snapshot.hasError ||
                                        !snapshot.hasData) {
                                      return ButtonThem.buildButton(
                                        context,
                                        title: "Error checking active ride".tr,
                                        btnHeight: 50,
                                        bgColors: Colors.grey,
                                        onPress: () {
                                          ShowToastDialog.showToast(
                                              "Error checking active ride".tr);
                                        },
                                      );
                                    }

                                    bool hasActiveRide = snapshot.data!;

                                    return ButtonThem.buildButton(
                                      context,
                                      title:
                                          "Accept Fare on ${Constant.amountShow(amount: controller.newAmount.value)}"
                                              .tr,
                                      btnHeight: 50,
                                      bgColors: hasActiveRide
                                          ? Colors.grey
                                          : AppColors.darkBackground,
                                      onPress: () async {
                                        if (hasActiveRide) {
                                          ShowToastDialog.showToast(
                                              "You can only have one active ride at a time."
                                                  .tr);
                                          return;
                                        }

                                        if (controller
                                                .newAmount.value.isNotEmpty &&
                                            double.parse(controller
                                                    .newAmount.value
                                                    .toString()) >
                                                0) {
                                          await controller.acceptOrder();
                                        } else {
                                          ShowToastDialog.showToast(
                                              "Please enter a valid offer rate"
                                                  .tr);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
