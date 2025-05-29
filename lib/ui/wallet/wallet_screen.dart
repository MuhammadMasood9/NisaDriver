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
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX<WalletController>(
      init: WalletController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.containerBackground,
          body: controller.isLoading.value
              ? Constant.loader(context)
              : Column(
                  children: [
                    _buildHeader(context, controller, themeChange),
                    Expanded(
                      child: _buildTransactionList(context, controller, themeChange),
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
                      if (double.parse(controller.driverUserModel.value.walletAmount.toString()) <= 0) {
                        ShowToastDialog.showToast("Insufficient balance".tr);
                      } else {
                        ShowToastDialog.showLoader("Please wait".tr);
                        await FireStoreUtils.bankDetailsIsAvailable().then((value) {
                          ShowToastDialog.closeLoader();
                          if (value == true) {
                            withdrawAmountBottomSheet(context, controller, themeChange);
                          } else {
                            ShowToastDialog.showToast("Your bank details is not available.Please add bank details".tr);
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
                    title: "Withdrawal history".tr,
                  
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

  Widget _buildHeader(BuildContext context, WalletController controller, DarkThemeProvider themeChange) {
    return Container(
      height: Responsive.width(65, context),
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
          const SizedBox(height: 40),
          Text(
            "Wallet Balance".tr,
            style: AppTypography.boldHeaders(context).copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            Constant.amountShow(amount: controller.driverUserModel.value.walletAmount.toString()),
            style: AppTypography.boldHeaders(context).copyWith(color: Colors.white,fontWeight: FontWeight.w600),
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
                paymentMethodDialog(context, controller, themeChange);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context, WalletController controller, DarkThemeProvider themeChange) {
    return Container(
      decoration: BoxDecoration(
        color: themeChange.getThem() ? AppColors.darkBackground : AppColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: controller.transactionList.isEmpty
            ? Center(
                child: Text(
                  "No transactions found".tr,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: AppColors.darkBackground.withOpacity(0.6),
                  ),
                ),
              )
            : ListView.builder(
                itemCount: controller.transactionList.length,
                itemBuilder: (context, index) {
                  WalletTransactionModel walletTransactionModel = controller.transactionList[index];
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
                        child: _buildTransactionCard(context, walletTransactionModel, themeChange),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, WalletTransactionModel walletTransactionModel, DarkThemeProvider themeChange) {
    return InkWell(
      onTap: () async {
        if (walletTransactionModel.orderType == "city") {
          await FireStoreUtils.getOrder(walletTransactionModel.transactionId.toString()).then((value) {
            if (value != null) {
              OrderModel orderModel = value;
              Get.to(const CompleteOrderScreen(), arguments: {"orderModel": orderModel});
            }
          });
        } else if (walletTransactionModel.orderType == "intercity") {
          await FireStoreUtils.getInterCityOrder(walletTransactionModel.transactionId.toString()).then((value) {
            if (value != null) {
              InterCityOrderModel orderModel = value;
              Get.to(const CompleteIntercityOrderScreen(), arguments: {"orderModel": orderModel});
            }
          });
        } else {
          showTransactionDetails(context: context, walletTransactionModel: walletTransactionModel, themeChange: themeChange);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: themeChange.getThem() ? AppColors.darkContainerBackground : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/icons/ic_wallet.svg',
                  width: 20,
                  color: AppColors.darkBackground,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Constant.dateFormatTimestamp(walletTransactionModel.createdDate),
                          style: AppTypography.boldLabel(context),
                        ),
                        
                        Text(
                          "${Constant.IsNegative(double.parse(walletTransactionModel.amount.toString())) ? "(-" : "+"}${Constant.amountShow(amount: walletTransactionModel.amount.toString().replaceAll("-", ""))}${Constant.IsNegative(double.parse(walletTransactionModel.amount.toString())) ? ")" : ""}",
                          style: AppTypography.smBoldLabel(context).copyWith(color:Constant.IsNegative(double.parse(walletTransactionModel.amount.toString())) ? Colors.red : Colors.green ),
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
                            style:AppTypography.label(context).copyWith(color: AppColors.darkBackground.withOpacity(0.6)),
                          ),
                        ),
                        Text(
                          walletTransactionModel.paymentType.toString().toUpperCase(),
                          style: AppTypography.boldLabel(context).copyWith(color: AppColors.primary.withOpacity(0.6)),
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
    );
  }

  void paymentMethodDialog(BuildContext context, WalletController controller, DarkThemeProvider themeChange) {
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
                              icon: const Icon(Icons.arrow_back_ios, color: AppColors.darkBackground),
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
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
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
                                  visible: controller.paymentModel.value.strip?.enable == true,
                                  child: _buildPaymentOption(
                                    context,
                                    controller,
                                    controller.paymentModel.value.strip!.name.toString(),
                                    'assets/images/stripe.png',
                                    themeChange,
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
                            if (controller.amountController.value.text.isNotEmpty) {
                              Get.back();
                              if (controller.selectedPaymentMethod.value == controller.paymentModel.value.strip!.name) {
                                controller.stripeMakePayment(amount: controller.amountController.value.text);
                              } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.paypal?.name) {
                                controller.paypalPaymentSheet(controller.amountController.value.text, context1);
                              } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.payStack?.name) {
                                controller.payStackPayment(controller.amountController.value.text);
                              } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.mercadoPago?.name) {
                                controller.mercadoPagoMakePayment(context: context, amount: controller.amountController.value.text);
                              } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.flutterWave?.name) {
                                controller.flutterWaveInitiatePayment(context: context, amount: controller.amountController.value.text);
                              } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.payfast?.name) {
                                controller.payFastPayment(context: context, amount: controller.amountController.value.text);
                              } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.paytm?.name) {
                                controller.getPaytmCheckSum(context, amount: double.parse(controller.amountController.value.text));
                              } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.razorpay?.name) {
                                RazorPayController()
                                    .createOrderRazorPay(
                                  amount: int.parse(controller.amountController.value.text),
                                  razorpayModel: controller.paymentModel.value.razorpay,
                                )
                                    .then((value) {
                                  if (value == null) {
                                    Get.back();
                                    ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
                                  } else {
                                    CreateRazorPayOrderModel result = value;
                                    controller.openCheckout(amount: controller.amountController.value.text, orderId: result.id);
                                  }
                                });
                              } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.midtrans?.name) {
                                controller.midtransMakePayment(context: context, amount: controller.amountController.value.text);
                              } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.orangePay?.name) {
                                controller.orangeMakePayment(context: context, amount: controller.amountController.value.text);
                              } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.xendit?.name) {
                                controller.xenditPayment(context, controller.amountController.value.text);
                              } else {
                                ShowToastDialog.showToast("Please select payment method".tr);
                              }
                            } else {
                              ShowToastDialog.showToast("Please enter amount".tr);
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
    DarkThemeProvider themeChange,
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
    required DarkThemeProvider themeChange,
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
                  value: "#${walletTransactionModel.transactionId!.toUpperCase()}",
                  themeChange: themeChange,
                ),
                const SizedBox(height: 12),
                _buildDetailCard(
                  title: "Payment Details".tr,
                  themeChange: themeChange,
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
                      DateFormat('KK:mm:ss a, dd MMM yyyy').format(walletTransactionModel.createdDate!.toDate()).toUpperCase(),
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
    required DarkThemeProvider themeChange,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeChange.getThem() ? AppColors.darkContainerBackground : Colors.white,
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

  void withdrawAmountBottomSheet(BuildContext context, WalletController controller, DarkThemeProvider themeChange) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Padding(
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
                      color: themeChange.getThem() ? AppColors.darkContainerBackground : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                                controller.bankDetailsModel.value.bankName.toString(),
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
                            controller.bankDetailsModel.value.accountNumber.toString(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: AppColors.darkBackground.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.bankDetailsModel.value.holderName.toString(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: AppColors.darkBackground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.bankDetailsModel.value.branchName.toString(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              color: AppColors.darkBackground.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            controller.bankDetailsModel.value.otherInformation.toString(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              color: AppColors.darkBackground.withOpacity(0.7),
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
                      if (double.parse(controller.driverUserModel.value.walletAmount.toString()) < double.parse(controller.withdrawalAmountController.value.text)) {
                        ShowToastDialog.showToast("Insufficient balance".tr);
                      } else if (double.parse(Constant.minimumAmountToWithdrawal) > double.parse(controller.withdrawalAmountController.value.text)) {
                        ShowToastDialog.showToast(
                            "Withdraw amount must be greater or equal to ${Constant.amountShow(amount: Constant.minimumAmountToWithdrawal.toString())}".tr);
                      } else {
                        ShowToastDialog.showLoader("Please wait".tr);
                        WithdrawModel withdrawModel = WithdrawModel();
                        withdrawModel.id = Constant.getUuid();
                        withdrawModel.userId = FireStoreUtils.getCurrentUid();
                        withdrawModel.paymentStatus = "pending";
                        withdrawModel.amount = controller.withdrawalAmountController.value.text;
                        withdrawModel.note = controller.noteController.value.text;
                        withdrawModel.createdDate = Timestamp.now();

                        await FireStoreUtils.updatedDriverWallet(amount: "-${controller.withdrawalAmountController.value.text}");

                        await FireStoreUtils.setWithdrawRequest(withdrawModel).then((value) {
                          controller.getUser();
                          ShowToastDialog.closeLoader();
                          ShowToastDialog.showToast("Request sent to admin".tr);
                          Get.back();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}