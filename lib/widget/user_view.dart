import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UserView extends StatelessWidget {
  final String? userId;
  final String? amount;
  final String? distance;
  final String? distanceType;

  const UserView({
    super.key,
    this.userId,
    this.amount,
    this.distance,
    this.distanceType,
  });

  String _formatDistance(String? rawDistance, String? unit) {
    final int decimals = Constant.currencyModel?.decimalDigits ?? 2;
    final double? parsed = double.tryParse((rawDistance ?? '').toString());
    final String value = parsed != null ? parsed.toStringAsFixed(decimals) : '--';
    final String suffix = unit ?? '';
    return suffix.isNotEmpty ? '$value $suffix' : value;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: FireStoreUtils.getCustomer(userId.toString()),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            // You can return a shimmer or a simple loader here while waiting
            return const Center(child: CircularProgressIndicator());
          case ConnectionState.done:
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error.toString()}');
            }

            // --- Case for when the user is not found (snapshot.data is null) ---
            if (snapshot.data == null) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    child: CachedNetworkImage(
                      height: 50,
                      width: 50,
                      imageUrl: Constant.userPlaceHolder,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Constant.loader(context),
                      errorWidget: (context, url, error) => Image.network(
                          'https://firebasestorage.googleapis.com/v0/b/goride-1a752.appspot.com/o/placeholderImages%2Fuser-placeholder.jpeg?alt=media&token=34a73d67-ba1d-4fe4-a29f-271d3e3ca115'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Asynchronous user".tr,
                                style: AppTypography.headers(context)),
                            Text(Constant.amountShow(amount: amount.toString()),
                                style: AppTypography.appTitle(context)),
                          ],
                        ),
                        const SizedBox(height: 6), // Added for spacing
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // --- UPDATED RATING AND REVIEW COUNT ROW ---
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 15, color: AppColors.ratingColour),
                                const SizedBox(width: 5),
                                Text(
                                  Constant.calculateReview(
                                      reviewCount: "0.0", reviewSum: "0.0"),
                                  style: AppTypography.boldLabel(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "(0 Reviews)",
                                  style: AppTypography.caption(context)
                                      .copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  _formatDistance(distance, distanceType),
                                  style: AppTypography.boldLabel(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // --- Case for when the user is successfully loaded ---
            UserModel userModel = snapshot.data!;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  child: CachedNetworkImage(
                    height: 50,
                    width: 50,
                    imageUrl: userModel.profilePic.toString(),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Constant.loader(context),
                    errorWidget: (context, url, error) => Image.network(
                        'https://firebasestorage.googleapis.com/v0/b/goride-1a752.appspot.com/o/placeholderImages%2Fuser-placeholder.jpeg?alt=media&token=34a73d67-ba1d-4fe4-a29f-271d3e3ca115'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(userModel.fullName.toString(),
                              style: AppTypography.headers(context)),
                          Text(Constant.amountShow(amount: amount.toString()),
                              style: AppTypography.appTitle(context)),
                        ],
                      ),
                      const SizedBox(
                          height: 6), // Replaced invalid 'spacing' property
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // --- UPDATED RATING AND REVIEW COUNT ROW ---
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.star,
                                size: 15,
                                color: AppColors.ratingColour,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                Constant.calculateReview(
                                    reviewCount: userModel.reviewsCount,
                                    reviewSum: userModel.reviewsSum),
                                style: AppTypography.boldLabel(context),
                              ),
                              const SizedBox(width: 4),
                              // This displays the total number of reviews
                              Text(
                                "(${userModel.reviewsCount} Reviews)",
                                style: AppTypography.caption(context)
                                    .copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 10),
                              const SizedBox(width: 3),
                              Text(
                                _formatDistance(distance, distanceType),
                                style: AppTypography.boldLabel(context),
                              ),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            );
          default:
            return const Text('Something went wrong.');
        }
      },
    );
  }
}
