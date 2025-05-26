import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/subscription_controller.dart';
import 'package:driver/model/subscription_plan_model.dart';
import 'package:driver/payment/createRazorPayOrderModel.dart';
import 'package:driver/payment/rozorpayConroller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/network_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SubscriptionListScreen extends StatelessWidget {
  const SubscriptionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<SubscriptionController>(
        init: SubscriptionController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: AppColors.primary, // Updated to darkBackground
            body: CustomScrollView(
              slivers: [
                // Modern App Bar with gradient using primary and darkModePrimary
                SliverAppBar(
                  expandedHeight: 120,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary, // Pink
                          AppColors.darkModePrimary, // Deep Pink/Purple
                        ],
                      ),
                    ),
                    child: FlexibleSpaceBar(
                      centerTitle: true,
                      title: Text(
                        "Choose Your Plan",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.darkModePrimary,
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: -50,
                              right: -50,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -30,
                              left: -30,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Content
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background, // Updated to darkBackground
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? Container(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary), // Updated to primary
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(20),
                            child: controller.subscriptionPlanList.isEmpty
                                ? Container(
                                    height: MediaQuery.of(context).size.height * 0.7,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.subscriptions_outlined,
                                            size: 80,
                                            color: AppColors.grey600, // Updated for visibility on dark background
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            "No Subscription Plans Available",
                                            style: GoogleFonts.poppins(
                                              color: AppColors.grey200, // Lighter grey for contrast
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),
                                      Text(
                                        "Select the perfect plan for you",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      ...controller.subscriptionPlanList.asMap().entries.map(
                                        (entry) {
                                          int index = entry.key;
                                          SubscriptionPlanModel plan = entry.value;
                                          return AnimatedContainer(
                                            duration: Duration(milliseconds: 300 + (index * 100)),
                                            curve: Curves.easeOutCubic,
                                            child: ModernSubscriptionPlanWidget(
                                              onContainClick: () {
                                                controller.selectedSubscriptionPlan.value = plan;
                                                controller.totalAmount.value = double.parse(plan.price ?? '0.0');
                                                controller.update();
                                              },
                                              onClick: () {
                                                if (controller.selectedSubscriptionPlan.value.id == plan.id) {
                                                  if (controller.selectedSubscriptionPlan.value.type == 'free' ||
                                                      controller.selectedSubscriptionPlan.value.id == Constant.commissionSubscriptionID) {
                                                    controller.selectedPaymentMethod.value = 'free';
                                                    controller.placeOrder();
                                                  } else {
                                                    paymentMethodDialog(context, controller);
                                                  }
                                                }
                                              },
                                              subscriptionPlanModel: plan,
                                              index: index,
                                            ),
                                          );
                                        },
                                      ).toList(),
                                      const SizedBox(height: 40),
                                    ],
                                  ),
                          ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  paymentMethodDialog(BuildContext context, SubscriptionController controller) {
    return showModalBottomSheet(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topRight: Radius.circular(24), topLeft: Radius.circular(24)),
        ),
        backgroundColor: AppColors.background, // Updated to darkBackground
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        builder: (context1) {
          final themeChange = Provider.of<DarkThemeProvider>(context1);

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: AppColors.background, // Updated to darkBackground
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: StatefulBuilder(builder: (context1, setState) {
              return Obx(
                () => Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.grey600, // Updated to grey600
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: const Icon(Icons.arrow_back_ios, color: AppColors.darkTextFieldBorder),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                "Payment Method".tr,
                                style: GoogleFonts.poppins(
                                  color: AppColors.darkTextFieldBorder,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // Balance the back button
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Choose Payment Method".tr,
                              style: GoogleFonts.poppins(
                                color: AppColors.grey600,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Wallet Payment Option
                            if (controller.paymentModel.value.wallet?.enable == true)
                              ModernPaymentOption(
                                title: controller.paymentModel.value.wallet!.name.toString(),
                                icon: 'assets/icons/ic_wallet.svg',
                                isSelected: controller.selectedPaymentMethod.value == controller.paymentModel.value.wallet!.name.toString(),
                                onTap: () {
                                  controller.selectedPaymentMethod.value = controller.paymentModel.value.wallet!.name.toString();
                                },
                              ),
                            // Stripe Payment Option
                            if (controller.paymentModel.value.strip?.enable == true)
                              ModernPaymentOption(
                                title: controller.paymentModel.value.strip!.name.toString(),
                                iconImage: 'assets/images/stripe.png',
                                isSelected: controller.selectedPaymentMethod.value == controller.paymentModel.value.strip!.name.toString(),
                                onTap: () {
                                  controller.selectedPaymentMethod.value = controller.paymentModel.value.strip!.name.toString();
                                },
                              ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                    // Pay Now Button
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            if (controller.selectedPaymentMethod.value == '') {
                              ShowToastDialog.showToast("Please Select Payment Method.");
                            } else {
                              _handlePayment(controller, context1);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary, // Updated to primary
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            "Pay Now".tr,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        });
  }

  void _handlePayment(SubscriptionController controller, BuildContext context) {
    // Payment logic remains unchanged as it doesn't involve UI colors
    if (controller.selectedPaymentMethod.value == controller.paymentModel.value.wallet?.name) {
      if (double.parse(controller.driverUserModel.value.walletAmount.toString()) >= controller.totalAmount.value) {
        Get.back();
        controller.placeOrder();
      } else {
        ShowToastDialog.showToast("Wallet Amount Insufficient".tr);
      }
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.strip?.name) {
      Get.back();
      controller.stripeMakePayment(amount: controller.totalAmount.value.toString());
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.paypal?.name) {
      Get.back();
      controller.paypalPaymentSheet(controller.totalAmount.value.toString(), context);
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.payStack?.name) {
      Get.back();
      controller.payStackPayment(controller.totalAmount.value.toString());
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.mercadoPago?.name) {
      Get.back();
      controller.mercadoPagoMakePayment(context: context, amount: controller.totalAmount.value.toString());
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.flutterWave?.name) {
      Get.back();
      controller.flutterWaveInitiatePayment(context: context, amount: controller.totalAmount.value.toString());
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.payfast?.name) {
      Get.back();
      controller.payFastPayment(context: context, amount: controller.totalAmount.value.toString());
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.paytm?.name) {
      Get.back();
      controller.getPaytmCheckSum(context, amount: double.parse(controller.totalAmount.value.toString()));
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.razorpay?.name) {
      RazorPayController()
          .createOrderRazorPay(amount: int.parse(controller.totalAmount.value.toString()), razorpayModel: controller.paymentModel.value.razorpay)
          .then((value) {
        if (value == null) {
          Get.back();
          ShowToastDialog.showToast("Something went wrong, please contact admin.".tr);
        } else {
          CreateRazorPayOrderModel result = value;
          controller.openCheckout(amount: controller.totalAmount.value.toString(), orderId: result.id);
        }
      });
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.midtrans?.name) {
      Get.back();
      controller.midtransMakePayment(context: context, amount: controller.totalAmount.value.toString());
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.orangePay?.name) {
      Get.back();
      controller.orangeMakePayment(context: context, amount: controller.totalAmount.value.toString());
    } else if (controller.selectedPaymentMethod.value == controller.paymentModel.value.xendit?.name) {
      Get.back();
      controller.xenditPayment(context, controller.totalAmount.value.toString());
    } else {
      ShowToastDialog.showToast("Please select payment method".tr);
    }
  }
}

class ModernSubscriptionPlanWidget extends StatelessWidget {
  final VoidCallback onClick;
  final VoidCallback onContainClick;
  final SubscriptionPlanModel subscriptionPlanModel;
  final int index;

  const ModernSubscriptionPlanWidget({
    super.key,
    required this.onClick,
    required this.subscriptionPlanModel,
    required this.onContainClick,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GetX<SubscriptionController>(
      init: SubscriptionController(),
      builder: (controller) {
        bool isSelected = controller.selectedSubscriptionPlan.value.id == subscriptionPlanModel.id;
        bool isActive = controller.driverUserModel.value.subscriptionPlanId == subscriptionPlanModel.id;
        bool isFree = subscriptionPlanModel.type == "free";

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 20),
          child: GestureDetector(
            onTap: onContainClick,
            child: Container(
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.darkModePrimary], // Updated gradient
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : AppColors.background, // Updated to darkContainerBackground
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : AppColors.grey300, // Updated border
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3), // Updated shadow with primary
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  // Decorative elements for selected plan
                  if (isSelected) ...[
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : AppColors.darkBackground.withOpacity(0.05), // Updated with primary
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: NetworkImageWidget(
                                  imageUrl: subscriptionPlanModel.image ?? '',
                                  fit: BoxFit.cover,
                                  width: 60,
                                  height: 60,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          subscriptionPlanModel.name ?? '',
                                          style: GoogleFonts.poppins(
                                            color:isSelected
                                    ? Colors.white
                                    : AppColors.darkBackground,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.ratingColour, // Updated to ratingColour
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            "Active",
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subscriptionPlanModel.description ?? '',
                                    style: GoogleFonts.poppins(
                                      color: isSelected ? Colors.white.withOpacity(0.8) : const Color.fromARGB(255, 55, 56, 58),
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Price Section
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isFree
                                  ? "Free"
                                  : Constant.amountShow(amount: double.parse(subscriptionPlanModel.price ?? '0.0').toString()),
                              style: GoogleFonts.poppins(
                                color:  isSelected ? Colors.white : AppColors.darkTextFieldBorder,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                subscriptionPlanModel.expiryDay == "-1"
                                    ? "/ Lifetime"
                                    : "/ ${subscriptionPlanModel.expiryDay} Days",
                                style: GoogleFonts.poppins(
                                  color: isSelected ? Colors.white.withOpacity(0.7) : AppColors.grey500,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Features
                        if (subscriptionPlanModel.id == Constant.commissionSubscriptionID)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.1) : AppColors.primary.withOpacity(0.1), // Updated with primary
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: isSelected ? Colors.white : AppColors.primary, // Updated with primary
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Commission: ${Constant.adminCommission?.type == 'percentage' ? "${Constant.adminCommission?.amount}%" : "${Constant.amountShow(amount: Constant.adminCommission?.amount)} Flat"} per order',
                                    style: GoogleFonts.poppins(
                                      color: isSelected ? Colors.white : AppColors.grey400,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Plan Features
                        if (subscriptionPlanModel.planPoints?.isNotEmpty == true)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "What's included:",
                                style: GoogleFonts.poppins(
                                  color: isSelected ? Colors.white : AppColors.darkTextFieldBorder,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...subscriptionPlanModel.planPoints!.map(
                                (point) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: AppColors.ratingColour, // Updated to ratingColour
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          point,
                                          style: GoogleFonts.poppins(
                                            color: isSelected ? Colors.white.withOpacity(0.9) : AppColors.grey600,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ).toList(),
                            ],
                          ),
                        const SizedBox(height: 20),
                        // Booking Limit
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withOpacity(0.1) : AppColors.background, // Updated to darkBackground
                            borderRadius: BorderRadius.circular(12),
                            border: Border.symmetric(
                              horizontal:  BorderSide(
                              color: isSelected ? Colors.white.withOpacity(0.2) : AppColors.primary, // Updated with primary
                              width: 1.5,
                             
                            ), vertical:  BorderSide(
                              color: isSelected ? Colors.white.withOpacity(0.2) : AppColors.primary, // Updated with primary
                              width: 1.5,
                             
                            )),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.bookmark_border,
                                color: isSelected ? Colors.white : AppColors.primary, // Updated with primary
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Booking Limit: ${subscriptionPlanModel.bookingLimit == '-1' ? 'Unlimited' : subscriptionPlanModel.bookingLimit ?? '0'}',
                                style: GoogleFonts.poppins(
                                  color: isSelected ? Colors.white : AppColors.darkTextFieldBorder,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Action Button
                        Container(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: onClick,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected ? Colors.white : AppColors.primary, // Updated with primary
                              foregroundColor: isSelected ? AppColors.primary : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              isActive
                                  ? "Renew Plan"
                                  : isSelected
                                      ? "Continue with Plan"
                                      : "Select Plan",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ModernPaymentOption extends StatelessWidget {
  final String title;
  final String? icon;
  final String? iconImage;
  final bool isSelected;
  final VoidCallback onTap;

  const ModernPaymentOption({
    super.key,
    required this.title,
    this.icon,
    this.iconImage,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.background : AppColors.background, // Updated colors
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.grey400, // Updated with primary
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.2) : AppColors.grey100.withOpacity(0.1), // Updated with primary
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: icon != null
                      ? SvgPicture.asset(
                          icon!,
                          color: isSelected ? AppColors.primary : Colors.white, // Updated with primary
                          width: 24,
                          height: 24,
                        )
                      : iconImage != null
                          ? Image.asset(
                              iconImage!,
                              width: 24,
                              height: 24,
                            )
                          : Icon(
                              Icons.payment,
                              color: isSelected ? AppColors.primary : Colors.white, // Updated with primary
                              size: 24,
                            ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: AppColors.darkTextFieldBorder, // Updated to darkTextFieldBorder
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.grey600, // Updated with primary
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent, // Updated with primary
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureItem extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool selectedPlan;

  const FeatureItem({
    super.key,
    required this.title,
    required this.isActive,
    required this.selectedPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isActive ? AppColors.ratingColour : AppColors.danger200.withOpacity(0.2), // Updated colors
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isActive ? Icons.check : Icons.close,
              color: isActive ? Colors.white : AppColors.danger200, // Updated with danger200
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getFeatureTitle(title),
              style: GoogleFonts.poppins(
                color: selectedPlan ? Colors.white : AppColors.grey300,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFeatureTitle(String title) {
    switch (title) {
      case 'chat':
        return 'Chat Support';
      case 'dineIn':
        return 'Dine-In Service';
      case 'qrCodeGenerate':
        return 'QR Code Generation';
      case 'restaurantMobileApp':
        return 'Restaurant Mobile App';
      default:
        return title;
    }
  }
}