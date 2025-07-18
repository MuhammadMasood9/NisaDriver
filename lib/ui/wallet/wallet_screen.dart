import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/wallet_controller.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/wallet_transaction_model.dart';
import 'package:driver/model/withdraw_model.dart';
import 'package:driver/payment/createRazorPayOrderModel.dart';
import 'package:driver/payment/rozorpayConroller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_them.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/order_intercity_screen/complete_intecity_order_screen.dart';
import 'package:driver/ui/order_screen/complete_order_screen.dart';
import 'package:driver/ui/withdraw_history/withdraw_history_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scroll_date_picker/scroll_date_picker.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<WalletController>(
      init: WalletController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.containerBackground,
          body: controller.isLoading.value
              ? Constant.loader(context)
              : Column(
                  children: [
                    _buildHeader(context, controller),
                    _buildModernDateFilter(context, controller),
                    // Divider(
                    //   color: AppColors.grey200,
                    //   indent: 10,
                    //   endIndent: 10,
                    //   height: 1,
                    // ),
                    Expanded(
                      child: _buildTransactionList(context, controller),
                    ),
                  ],
                ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: ButtonThem.buildBorderButton(
                    context,
                    title: "withdraw".tr,
                    onPress: () async {
                      if (double.parse(controller
                              .driverUserModel.value.walletAmount
                              .toString()) <=
                          0) {
                        ShowToastDialog.showToast("Insufficient balance".tr);
                      } else {
                        ShowToastDialog.showLoader("Please wait".tr);
                        await FireStoreUtils.bankDetailsIsAvailable()
                            .then((value) {
                          ShowToastDialog.closeLoader();
                          if (value == true) {
                            withdrawAmountBottomSheet(context, controller);
                          } else {
                            ShowToastDialog.showToast(
                                "Your bank details is not available.Please add bank details"
                                    .tr);
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ButtonThem.buildButton(
                    context,
                    title: "History".tr,
                    onPress: () {
                      Get.to(const WithDrawHistoryScreen());
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernDateFilter(
      BuildContext context, WalletController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(

          // borderRadius: BorderRadius.circular(20),
          ),
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Obx(() => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: controller.startDate.value != null
                                ? AppColors.primary.withOpacity(0.4)
                                : AppColors.textFieldBorder.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await showModalBottomSheet(
                              context: context,
                              builder: (context) => Container(
                                color: AppColors.background,
                                height: Responsive.width(85, context),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Start Date",
                                          style: AppTypography.headers(context),
                                        ),
                                        TextButton(
                                            onPressed: () {
                                              controller.clearStartDateFilter();
                                              _showFilterFeedback(
                                                  context, controller);
                                            },
                                            child: Text(
                                              "Clear",
                                              style: AppTypography.caption(
                                                  context),
                                            ))
                                      ],
                                    ),
                                    Expanded(
                                      child: ScrollDatePicker(
                                        selectedDate:
                                            controller.startDate.value ??
                                                DateTime.now(),
                                        locale: Locale('en'),
                                        minimumDate: DateTime(2000),
                                        maximumDate: controller.endDate.value ??
                                            DateTime.now(),
                                        onDateTimeChanged: (DateTime value) {
                                          controller.setStartDate(value);
                                          _showFilterFeedback(
                                              context, controller);
                                        },
                                        options: DatePickerOptions(
                                          backgroundColor: Colors.white,
                                          itemExtent: 40,
                                          diameterRatio: 1.5,
                                        ),
                                        indicator: Container(
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: controller.startDate.value != null
                                      ? AppColors.primary.withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.calendar_today_rounded,
                                  color: controller.startDate.value != null
                                      ? AppColors.primary
                                      : AppColors.darkBackground
                                          .withOpacity(0.5),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Start Date".tr,
                                      style: AppTypography.smBoldLabel(context)
                                          .copyWith(
                                        color:
                                            controller.startDate.value != null
                                                ? AppColors.primary
                                                : AppColors.darkBackground
                                                    .withOpacity(0.5),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      controller.startDate.value == null
                                          ? "Select".tr
                                          : DateFormat('dd MMM yyyy').format(
                                              controller.startDate.value!),
                                      style: AppTypography.caption(context)
                                          .copyWith(
                                        letterSpacing: -0.3,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Obx(() => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: controller.endDate.value != null
                                ? AppColors.primary.withOpacity(0.4)
                                : AppColors.textFieldBorder.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await showModalBottomSheet(
                              context: context,
                              builder: (context) => Container(
                                color: AppColors.background,
                                height: Responsive.width(85, context),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "End Date",
                                          style: AppTypography.headers(context),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            controller.clearEndDateFilter();
                                            _showFilterFeedback(
                                                context, controller);
                                          },
                                          child: Text(
                                            "Clear",
                                            style:
                                                AppTypography.caption(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: ScrollDatePicker(
                                        selectedDate:
                                            controller.endDate.value ??
                                                DateTime.now(),
                                        locale: Locale('en'),
                                        minimumDate:
                                            controller.startDate.value ??
                                                DateTime(2000),
                                        maximumDate: DateTime.now(),
                                        onDateTimeChanged: (DateTime value) {
                                          controller.setEndDate(value);
                                          _showFilterFeedback(
                                              context, controller);
                                        },
                                        options: DatePickerOptions(
                                          backgroundColor: Colors.white,
                                          itemExtent: 40,
                                          diameterRatio: 1.5,
                                        ),
                                        indicator: Container(
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: controller.endDate.value != null
                                      ? AppColors.primary.withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.calendar_today_rounded,
                                  color: controller.endDate.value != null
                                      ? AppColors.primary
                                      : AppColors.darkBackground
                                          .withOpacity(0.5),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "End Date".tr,
                                      style: AppTypography.smBoldLabel(context)
                                          .copyWith(
                                        color: controller.endDate.value != null
                                            ? AppColors.primary
                                            : AppColors.darkBackground
                                                .withOpacity(0.5),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      controller.endDate.value == null
                                          ? "Select".tr
                                          : DateFormat('dd MMM yyyy').format(
                                              controller.endDate.value!),
                                      style: AppTypography.caption(context)
                                          .copyWith(
                                        letterSpacing: -0.3,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ), // const SizedBox(width: 8),
                // Obx(() => AnimatedScale(
                //       scale: (controller.startDate.value != null ||
                //               controller.endDate.value != null)
                //           ? 0.9
                //           : 0.9,
                //       duration: const Duration(milliseconds: 300),
                //       curve: Curves.easeInOut,
                //       child: AnimatedOpacity(
                //         opacity: (controller.startDate.value != null ||
                //                 controller.endDate.value != null)
                //             ? 1.0
                //             : 0.5,
                //         duration: const Duration(milliseconds: 300),
                //         child: InkWell(
                //           onTap: (controller.startDate.value != null ||
                //                   controller.endDate.value != null)
                //               ? () {
                //                   HapticFeedback.lightImpact();
                //                   controller.clearDateFilter();
                //                   ScaffoldMessenger.of(context).showSnackBar(
                //                     SnackBar(
                //                       content: Text(
                //                         "Filter cleared".tr,
                //                         style: GoogleFonts.poppins(
                //                             fontWeight: FontWeight.w500),
                //                       ),
                //                       behavior: SnackBarBehavior.floating,
                //                       shape: RoundedRectangleBorder(
                //                           borderRadius:
                //                               BorderRadius.circular(8)),
                //                       duration: const Duration(seconds: 1),
                //                     ),
                //                   );
                //                 }
                //               : null,
                //           borderRadius: BorderRadius.circular(0),
                //           child: AnimatedContainer(
                //             duration: const Duration(milliseconds: 300),
                //             padding: const EdgeInsets.all(12),
                //             decoration: BoxDecoration(
                //               borderRadius: BorderRadius.circular(16),
                //               border: Border.all(
                //                 color: (controller.startDate.value != null ||
                //                         controller.endDate.value != null)
                //                     ? AppColors.primary.withOpacity(0.3)
                //                     : Colors.grey.withOpacity(0.5),
                //                 width: (controller.startDate.value != null ||
                //                         controller.endDate.value != null)
                //                     ? 1.5
                //                     : 1,
                //               ),
                //             ),
                //             child: Icon(
                //               Icons.close_rounded,
                //               color: (controller.startDate.value != null ||
                //                       controller.endDate.value != null)
                //                   ? AppColors.primary.withOpacity(0.9)
                //                   : Colors.grey.shade500,
                //               size: 22,
                //             ),
                //           ),
                //         ),
                //       ),
                //     )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to show filter feedback
  void _showFilterFeedback(BuildContext context, WalletController controller) {
    // Get filtered results count
    int filteredCount = controller.filteredTransactionList.length;
    int totalCount = controller.transactionList.length;

    // Show snackbar with filter results
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(
    //       "Showing $filteredCount of $totalCount transactions".tr,
    //       style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
    //     ),
    //     backgroundColor: AppColors.primary,
    //     behavior: SnackBarBehavior.floating,
    //     shape: RoundedRectangleBorder(
    //       borderRadius: BorderRadius.circular(12),
    //     ),
    //     duration: const Duration(seconds: 2),
    //     action: filteredCount < totalCount
    //         ? SnackBarAction(
    //             label: "Clear".tr,
    //             textColor: Colors.white,
    //             onPressed: () {
    //               controller.clearDateFilter();
    //             },
    //           )
    //         : null,
    //   ),
    // );
  }

  Widget _buildHeader(BuildContext context, WalletController controller) {
    return Container(
      height: Responsive.width(50, context),
      width: Responsive.width(65, context),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.all(Radius.circular(10))),
              margin: EdgeInsets.only(right: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.download,
                    size: 10,
                  ),
                  Text(
                    "Export",
                    style: AppTypography.smBoldLabel(context),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            "Wallet Balance".tr,
            style: AppTypography.boldHeaders(context)
                .copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            Constant.amountShow(
                amount:
                    controller.driverUserModel.value.walletAmount.toString()),
            style: AppTypography.boldHeaders(context)
                .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ButtonThem.roundButton(
              context,
              title: "Topup Wallet".tr,
              btnWidthRatio: 0.5,
              btnHeight: 50,
              onPress: () async {
                paymentMethodDialog(context, controller);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(
      BuildContext context, WalletController controller) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: controller.filteredTransactionList.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: AppColors.darkBackground.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No transactions found".tr,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkBackground.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.selectedDateRange.value != null
                          ? "Try selecting a different date range".tr
                          : "Your transactions will appear here".tr,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.darkBackground.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: controller.filteredTransactionList.length,
                itemBuilder: (context, index) {
                  WalletTransactionModel walletTransactionModel =
                      controller.filteredTransactionList[index];
                  return AnimatedOpacity(
                    opacity: 1.0,
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _buildTransactionCard(
                            context, walletTransactionModel),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildTransactionCard(
      BuildContext context, WalletTransactionModel walletTransactionModel) {
    return InkWell(
      onTap: () async {
        if (walletTransactionModel.orderType == "city") {
          await FireStoreUtils.getOrder(
                  walletTransactionModel.transactionId.toString())
              .then((value) {
            if (value != null) {
              OrderModel orderModel = value;
              Get.to(const CompleteOrderScreen(),
                  arguments: {"orderModel": orderModel});
            }
          });
        } else if (walletTransactionModel.orderType == "intercity") {
          await FireStoreUtils.getInterCityOrder(
                  walletTransactionModel.transactionId.toString())
              .then((value) {
            if (value != null) {
              InterCityOrderModel orderModel = value;
              Get.to(const CompleteIntercityOrderScreen(),
                  arguments: {"orderModel": orderModel});
            }
          });
        } else {
          showTransactionDetails(
              context: context, walletTransactionModel: walletTransactionModel);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Badge positioned at top-left
            if (walletTransactionModel.orderType == "city" ||
                walletTransactionModel.orderType == "intercity")
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: walletTransactionModel.orderType == "city"
                          ? [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8)
                            ]
                          : [Colors.orange, Colors.orange.withOpacity(0.8)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomRight: Radius.circular(12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (walletTransactionModel.orderType == "city"
                                ? AppColors.primary
                                : Colors.orange)
                            .withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    walletTransactionModel.orderType == "city"
                        ? "Ride"
                        : "Parcel",
                    style: AppTypography.smBoldLabel(context).copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // Main content with proper padding to avoid badge overlap
            Padding(
              padding: EdgeInsets.fromLTRB(
                8,
                (walletTransactionModel.orderType == "city" ||
                        walletTransactionModel.orderType == "intercity")
                    ? 20
                    : 20,
                8,
                8,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.darkBackground.withOpacity(0.1),
                          AppColors.darkBackground.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/ic_wallet.svg',
                      width: 22,
                      color: AppColors.darkBackground,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              Constant.dateFormatTimestamp(
                                  walletTransactionModel.createdDate),
                              style: AppTypography.boldLabel(context),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${Constant.IsNegative(double.parse(walletTransactionModel.amount.toString())) ? "-" : "+"}${Constant.amountShow(amount: walletTransactionModel.amount.toString().replaceAll("-", ""))}",
                                style:
                                    AppTypography.boldLabel(context).copyWith(
                                  color: Constant.IsNegative(double.parse(
                                          walletTransactionModel.amount
                                              .toString()))
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                walletTransactionModel.note.toString(),
                                style: AppTypography.caption(context),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                walletTransactionModel.paymentType
                                    .toString()
                                    .toUpperCase(),
                                style:
                                    AppTypography.smBoldLabel(context).copyWith(
                                  color: AppColors.primary,
                                ),
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
          ],
        ),
      ),
    );
  }

  void paymentMethodDialog(
    BuildContext context,
    WalletController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context1) {
        return SafeArea(
          top: true,
          child: FractionallySizedBox(
            heightFactor: 0.65,
            child: StatefulBuilder(
              builder: (context1, setState) {
                return Obx(
                  () => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios,
                                  color: AppColors.darkBackground),
                              onPressed: () => Get.back(),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  "Topup Wallet".tr,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                    color: AppColors.darkBackground,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Add Topup Amount".tr,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: AppColors.darkBackground,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFieldThem.buildTextFiled(
                                  context,
                                  hintText: 'Enter Amount'.tr,
                                  controller: controller.amountController.value,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9]')),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  "Select Payment Option".tr,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: AppColors.darkBackground,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Visibility(
                                  visible: controller
                                          .paymentModel.value.strip?.enable ==
                                      true,
                                  child: _buildPaymentOption(
                                    context,
                                    controller,
                                    controller.paymentModel.value.strip!.name
                                        .toString(),
                                    'assets/images/stripe.png',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ButtonThem.buildButton(
                          context,
                          title: "Topup".tr,
                          onPress: () {
                            if (controller
                                .amountController.value.text.isNotEmpty) {
                              Get.back();
                              if (controller.selectedPaymentMethod.value ==
                                  controller.paymentModel.value.strip!.name) {
                                controller.stripeMakePayment(
                                    amount:
                                        controller.amountController.value.text);
                              } else {
                                ShowToastDialog.showToast(
                                    "Please select payment method".tr);
                              }
                            } else {
                              ShowToastDialog.showToast(
                                  "Please enter amount".tr);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption(
    BuildContext context,
    WalletController controller,
    String paymentMethod,
    String imagePath,
  ) {
    return InkWell(
      onTap: () {
        controller.selectedPaymentMethod.value = paymentMethod;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: controller.selectedPaymentMethod.value == paymentMethod
                ? AppColors.primary
                : AppColors.textFieldBorder,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 80,
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(imagePath),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                paymentMethod,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.darkBackground,
                ),
              ),
            ),
            Radio(
              value: paymentMethod,
              groupValue: controller.selectedPaymentMethod.value,
              activeColor: AppColors.primary,
              onChanged: (value) {
                controller.selectedPaymentMethod.value = paymentMethod;
              },
            ),
          ],
        ),
      ),
    );
  }

  void showTransactionDetails({
    required BuildContext context,
    required WalletTransactionModel walletTransactionModel,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Transaction Details".tr,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: AppColors.darkBackground,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  title: "Transaction ID".tr,
                  value:
                      "#${walletTransactionModel.transactionId!.toUpperCase()}",
                ),
                const SizedBox(height: 12),
                _buildDetailCard(
                  title: "Payment Details".tr,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Pay Via".tr,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.darkBackground.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          walletTransactionModel.paymentType ?? "Unknown",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.darkBackground,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      "Date in UTC Format".tr,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.darkBackground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('KK:mm:ss a, dd MMM yyyy')
                          .format(walletTransactionModel.createdDate!.toDate())
                          .toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.darkBackground.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCard({
    required String title,
    String? value,
    List<Widget>? children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.darkBackground,
            ),
          ),
          if (value != null) ...[
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: AppColors.darkBackground.withOpacity(0.7),
              ),
            ),
          ],
          if (children != null) ...children,
        ],
      ),
    );
  }

  void withdrawAmountBottomSheet(
      BuildContext context, WalletController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25), topRight: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Container(
            color: AppColors.background,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Withdraw".tr,
                      style: AppTypography.headers(context),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  controller.bankDetailsModel.value.bankName
                                      .toString(),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                    color: AppColors.darkBackground,
                                  ),
                                ),
                                const Icon(
                                  Icons.account_balance,
                                  size: 40,
                                  color: AppColors.darkBackground,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.bankDetailsModel.value.accountNumber
                                  .toString(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color:
                                    AppColors.darkBackground.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.bankDetailsModel.value.holderName
                                  .toString(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color: AppColors.darkBackground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.bankDetailsModel.value.branchName
                                  .toString(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color:
                                    AppColors.darkBackground.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              controller.bankDetailsModel.value.otherInformation
                                  .toString(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color:
                                    AppColors.darkBackground.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Amount to Withdraw".tr,
                      style: AppTypography.headers(context),
                    ),
                    const SizedBox(height: 10),
                    TextFieldThem.buildTextFiled(
                      context,
                      hintText: 'Enter Amount'.tr,
                      controller: controller.withdrawalAmountController.value,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFieldThem.buildTextFiled(
                      context,
                      hintText: 'Notes'.tr,
                      maxLine: 3,
                      controller: controller.noteController.value,
                    ),
                    const SizedBox(height: 20),
                    ButtonThem.buildButton(
                      context,
                      title: "Withdrawal".tr,
                      onPress: () async {
                        if (double.parse(controller
                                .driverUserModel.value.walletAmount
                                .toString()) <
                            double.parse(controller
                                .withdrawalAmountController.value.text)) {
                          ShowToastDialog.showToast("Insufficient balance".tr);
                        } else if (double.parse(
                                Constant.minimumAmountToWithdrawal) >
                            double.parse(controller
                                .withdrawalAmountController.value.text)) {
                          ShowToastDialog.showToast(
                              "Withdraw amount must be greater or equal to ${Constant.amountShow(amount: Constant.minimumAmountToWithdrawal.toString())}"
                                  .tr);
                        } else {
                          ShowToastDialog.showLoader("Please wait".tr);
                          WithdrawModel withdrawModel = WithdrawModel();
                          withdrawModel.id = Constant.getUuid();
                          withdrawModel.userId = FireStoreUtils.getCurrentUid();
                          withdrawModel.paymentStatus = "pending";
                          withdrawModel.amount =
                              controller.withdrawalAmountController.value.text;
                          withdrawModel.note =
                              controller.noteController.value.text;
                          withdrawModel.createdDate = Timestamp.now();

                          await FireStoreUtils.updatedDriverWallet(
                              amount:
                                  "-${controller.withdrawalAmountController.value.text}");

                          await FireStoreUtils.setWithdrawRequest(withdrawModel)
                              .then((value) {
                            controller.getUser();
                            ShowToastDialog.closeLoader();
                            ShowToastDialog.showToast(
                                "Request sent to admin".tr);
                            Get.back();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
