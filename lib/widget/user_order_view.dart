import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserDriverView extends StatelessWidget {
  final String? userId;
  final String? amount;

  const UserDriverView({super.key, this.userId, this.amount});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
        future: FireStoreUtils.getCustomer(userId.toString()),
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return const SizedBox();
            case ConnectionState.done:
              if (snapshot.hasError) {
                return Text(snapshot.error.toString());
              } else {
                if(snapshot.data == null){
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                            child: CachedNetworkImage(
                              height: 40,
                              width: 40,
                              imageUrl: Constant.userPlaceHolder,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Constant.loader(context),
                              errorWidget: (context, url, error) => Image.network(
                                  'https://firebasestorage.googleapis.com/v0/b/goride-1a752.appspot.com/o/placeholderImages%2Fuser-placeholder.jpeg?alt=media&token=34a73d67-ba1d-4fe4-a29f-271d3e3ca115'),
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Asynchronous user", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 22,
                                            color: AppColors.ratingColour,
                                          ),
                                          const SizedBox(
                                            width: 5,
                                          ),
                                          Text(Constant.calculateReview(reviewCount: "0.0", reviewSum: "0.0"),
                                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      Constant.amountShow(amount: amount),
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }else{
                  UserModel driverModel = snapshot.data!;
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                            child: CachedNetworkImage(
                              height: 40,
                              width: 40,
                              imageUrl: driverModel.profilePic.toString(),
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Constant.loader(context),
                              errorWidget: (context, url, error) => Image.network(
                                  'https://firebasestorage.googleapis.com/v0/b/goride-1a752.appspot.com/o/placeholderImages%2Fuser-placeholder.jpeg?alt=media&token=34a73d67-ba1d-4fe4-a29f-271d3e3ca115'),
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driverModel.fullName.toString(), style: AppTypography.boldLabel(context)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 16,
                                            color: AppColors.ratingColour,
                                          ),
                                          const SizedBox(
                                            width: 5,
                                          ),
                                          Text(Constant.calculateReview(reviewCount: driverModel.reviewsCount.toString(), reviewSum: driverModel.reviewsSum.toString()),
                                              style: AppTypography.smBoldLabel(context)),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      Constant.amountShow(amount: amount),
                                      style: AppTypography.boldLabel(context),
                                    ),

                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              }
            default:
              return const Text('Error');
          }
        });
  }
}
