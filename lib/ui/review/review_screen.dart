import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/rating_controller.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/text_field_them.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:driver/themes/typography.dart'; // Added for AppTypography

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<RatingController>(
        init: RatingController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            body: controller.isLoading.value == true
                ? Constant.loader(context)
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 200, // Adjust height based on design needs
                          child: Stack(
                            children: [
                              // Background Image
                              Image.asset(
                                "assets/Background.png",
                                fit: BoxFit.fill,
                                width: double.infinity,
                                height: 156,
                              ),
                              // Bike Image
                              Positioned(
                                top: 80, // Padding from the top
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Image.asset(
                                    "assets/bike.png",
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 50, // Padding from the top
                                left: 0,
                                right: 0,
                                child: Center(
                                    child: Text(
                                        "Rate Your Passenger"
                                            .tr, // Updated for driver context
                                        style:
                                            AppTypography.boldHeaders(context)
                                                .copyWith(
                                                    color: Colors.white,
                                                    letterSpacing: 0.8))),
                              ),
                              Positioned(
                                top: 40, // Padding from the top
                                left: 10,
                                child: FloatingActionButton(
                                  onPressed: () => Get.back(),
                                  mini: true,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 0, right: 0, top: 5, bottom: 0),
                          child: Container(
                            decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 255, 255, 255),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 5,
                                    offset: Offset(6, 0),
                                  ),
                                ],
                                borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(60),
                                                color: Colors.white,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                            alpha: 0.10),
                                                    blurRadius: 5,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(60),
                                                child: CachedNetworkImage(
                                                  imageUrl: controller.userModel
                                                      .value.profilePic
                                                      .toString(),
                                                  height: 50,
                                                  width: 50,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      Constant.loader(context),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Image.network(Constant
                                                              .userPlaceHolder),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${controller.userModel.value.fullName}',
                                                  textAlign: TextAlign.center,
                                                  style: AppTypography.headers(
                                                          context)
                                                      .copyWith(
                                                          letterSpacing: 0.8,
                                                          fontWeight:
                                                              FontWeight.w800),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 20,
                                              color: AppColors.ratingColour,
                                            ),
                                            const SizedBox(
                                              width: 5,
                                            ),
                                            Text(
                                                Constant.calculateReview(
                                                    reviewCount: controller
                                                        .userModel
                                                        .value
                                                        .reviewsCount
                                                        .toString(),
                                                    reviewSum: controller
                                                        .userModel
                                                        .value
                                                        .reviewsSum
                                                        .toString()),
                                                style: AppTypography.boldLabel(
                                                    context)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  const MySeparator(
                                      color:
                                          Color.fromARGB(255, 227, 227, 227)),
                                  SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Text(
                                      'How Was Your Passenger Experience'
                                          .tr, // Updated for driver context
                                      textAlign: TextAlign.center,
                                      style: AppTypography.boldHeaders(context)
                                          .copyWith(
                                        letterSpacing: 1.9,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'Your Overall Rating'.tr,
                                    textAlign: TextAlign.center,
                                    style:
                                        AppTypography.headers(context).copyWith(
                                      letterSpacing: 0.9,
                                      color:
                                          const Color.fromARGB(255, 92, 92, 92),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: RatingBar.builder(
                                      glowRadius: 0,
                                      unratedColor: const Color.fromARGB(
                                          255, 236, 236, 236),
                                      initialRating: controller.rating.value,
                                      minRating: 1,
                                      direction: Axis.horizontal,
                                      allowHalfRating: true,
                                      itemCount: 5,
                                      itemPadding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      itemBuilder: (context, _) => const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                      ),
                                      onRatingUpdate: (rating) {
                                        controller.rating(rating);
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 30),
                                    child: TextFieldThem.buildTextFiled(context,
                                        hintText: 'Comment..'.tr,
                                        controller:
                                            controller.commentController.value,
                                        maxLine: 5),
                                  ),
                                  const SizedBox(height: 10),
                                  ButtonThem.buildButton(
                                    context,
                                    title: "Submit".tr,
                                    onPress: () async {
                                      if (controller.rating.value > 0) {
                                        ShowToastDialog.showLoader(
                                            "Please wait".tr);

                                        await FireStoreUtils.getCustomer(
                                                controller.type.value ==
                                                        "orderModel"
                                                    ? controller
                                                        .orderModel.value.userId
                                                        .toString()
                                                    : controller
                                                        .intercityOrderModel
                                                        .value
                                                        .userId
                                                        .toString())
                                            .then((value) async {
                                          if (value != null) {
                                            UserModel userModel = value;

                                            if (controller
                                                    .reviewModel.value.id !=
                                                null) {
                                              userModel.reviewsSum =
                                                  (double.parse(userModel
                                                              .reviewsSum
                                                              .toString()) -
                                                          double.parse(
                                                              controller
                                                                  .reviewModel
                                                                  .value
                                                                  .rating
                                                                  .toString()))
                                                      .toString();
                                              userModel.reviewsCount =
                                                  (double.parse(userModel
                                                              .reviewsCount
                                                              .toString()) -
                                                          1)
                                                      .toString();
                                            }
                                            userModel.reviewsSum =
                                                (double.parse(userModel
                                                            .reviewsSum
                                                            .toString()) +
                                                        double.parse(controller
                                                            .rating.value
                                                            .toString()))
                                                    .toString();
                                            userModel.reviewsCount =
                                                (double.parse(userModel
                                                            .reviewsCount
                                                            .toString()) +
                                                        1)
                                                    .toString();
                                            await FireStoreUtils.updateUser(
                                                userModel);
                                          }
                                        });

                                        controller.reviewModel.value.id =
                                            controller.type.value ==
                                                    "orderModel"
                                                ? controller.orderModel.value.id
                                                : controller.intercityOrderModel
                                                    .value.id;
                                        controller.reviewModel.value.comment =
                                            controller
                                                .commentController.value.text;
                                        controller.reviewModel.value.rating =
                                            controller.rating.value.toString();
                                        controller
                                                .reviewModel.value.customerId =
                                            FireStoreUtils.getCurrentUid();
                                        controller.reviewModel.value.driverId =
                                            controller.type.value ==
                                                    "orderModel"
                                                ? controller
                                                    .orderModel.value.driverId
                                                : controller.intercityOrderModel
                                                    .value.driverId;
                                        controller.reviewModel.value.date =
                                            Timestamp.now();
                                        controller.reviewModel.value.type =
                                            controller.type.value ==
                                                    "orderModel"
                                                ? "city"
                                                : "intercity";

                                        await FireStoreUtils.setReview(
                                                controller.reviewModel.value)
                                            .then((value) {
                                          if (value != null && value == true) {
                                            ShowToastDialog.closeLoader();
                                            ShowToastDialog.showToast(
                                                "Review submit successfully"
                                                    .tr);
                                            Get.back();
                                          }
                                        });
                                      } else {
                                        ShowToastDialog.showToast(
                                            "Please give rate in star and add feedback comment."
                                                .tr);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        });
  }
}
