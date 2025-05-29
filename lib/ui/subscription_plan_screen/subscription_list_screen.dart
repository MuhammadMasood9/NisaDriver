import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/subscription_controller.dart';
import 'package:driver/model/subscription_plan_model.dart';
import 'package:driver/payment/createRazorPayOrderModel.dart';
import 'package:driver/payment/rozorpayConroller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
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
      builder: (controller) => Scaffold(
        backgroundColor: AppColors.background,
        body: _buildBody(context, controller),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SubscriptionController controller) {
    if (controller.isLoading.value) {
      return _buildLoadingState();
    }

    if (controller.subscriptionPlanList.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 0),
          _buildHeader(),
          const SizedBox(height: 32),
          _buildPlansList(controller),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.grey600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.subscriptions_outlined,
              size: 60,
              color: AppColors.grey600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No Subscription Plans Available",
            style: GoogleFonts.poppins(
              color: AppColors.grey200,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Check back later for available plans",
            style: GoogleFonts.poppins(
              color: AppColors.grey400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Choose Your Plan",
          style: AppTypography.boldHeaders(Get.context!),
        ),
        const SizedBox(height: 8),
        Text(
          "Select the perfect subscription plan for your needs",
          style: AppTypography.label(Get.context!)
              .copyWith(color: AppColors.grey400),
        ),
      ],
    );
  }

  Widget _buildPlansList(SubscriptionController controller) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controller.subscriptionPlanList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final plan = controller.subscriptionPlanList[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOutCubic,
          child: ModernSubscriptionPlanWidget(
            onContainClick: () => _selectPlan(controller, plan),
            onClick: () => _handlePlanAction(controller, plan),
            subscriptionPlanModel: plan,
            index: index,
          ),
        );
      },
    );
  }

  void _selectPlan(
      SubscriptionController controller, SubscriptionPlanModel plan) {
    controller.selectedSubscriptionPlan.value = plan;
    controller.totalAmount.value = double.parse(plan.price ?? '0.0');
    controller.update();
  }

  void _handlePlanAction(
      SubscriptionController controller, SubscriptionPlanModel plan) {
    if (controller.selectedSubscriptionPlan.value.id != plan.id) return;

    if (plan.type == 'free' || plan.id == Constant.commissionSubscriptionID) {
      controller.selectedPaymentMethod.value = 'free';
      controller.placeOrder();
    } else {
      _showPaymentMethodDialog(Get.context!, controller);
    }
  }

  void _showPaymentMethodDialog(
      BuildContext context, SubscriptionController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentMethodDialog(controller: controller),
    );
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
      builder: (controller) {
        final isSelected = controller.selectedSubscriptionPlan.value.id ==
            subscriptionPlanModel.id;
        final isActive = controller.driverUserModel.value.subscriptionPlanId ==
            subscriptionPlanModel.id;
        final isFree = subscriptionPlanModel.type == "free";

        return GestureDetector(
          onTap: onContainClick,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected ? _buildSelectedGradient() : null,
              color: isSelected ? null : AppColors.background,
              borderRadius: BorderRadius.circular(8),
              boxShadow:
                  isSelected ? _buildSelectedShadow() : _buildDefaultShadow(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isSelected, isActive),
                  const SizedBox(height: 15),
                  _buildPricing(isSelected, isFree),
                  const SizedBox(height: 15),
                  if (subscriptionPlanModel.id ==
                      Constant.commissionSubscriptionID)
                    _buildCommissionInfo(isSelected),
                  if (subscriptionPlanModel.planPoints?.isNotEmpty == true) ...[
                    _buildFeaturesList(isSelected),
                    const SizedBox(height: 15),
                  ],
                  _buildBookingLimit(isSelected),
                  const SizedBox(height: 15),
                  _buildActionButton(isSelected, isActive),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isSelected, bool isActive) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : AppColors.grey100.withOpacity(0.1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: NetworkImageWidget(
              imageUrl: subscriptionPlanModel.image ?? '',
              fit: BoxFit.cover,
              width: 46,
              height: 46,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subscriptionPlanModel.name ?? '',
                      style: AppTypography.boldHeaders(Get.context!).copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.darkBackground,
                      ),
                    ),
                  ),
                  if (isActive) _buildActiveBadge(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subscriptionPlanModel.description ?? '',
                style: AppTypography.label(Get.context!).copyWith(
                  color: isSelected
                      ? Colors.white.withOpacity(0.8)
                      : AppColors.grey500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ratingColour,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "Active",
        style: AppTypography.smBoldLabel(Get.context!)
            .copyWith(color: Colors.white),
      ),
    );
  }

  Widget _buildPricing(bool isSelected, bool isFree) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          isFree
              ? "Free"
              : Constant.amountShow(
                  amount: double.parse(subscriptionPlanModel.price ?? '0.0')
                      .toString()),
          style: AppTypography.boldHeaders(Get.context!).copyWith(
            color: isSelected ? Colors.white : AppColors.darkTextFieldBorder,
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            subscriptionPlanModel.expiryDay == "-1"
                ? "/ Lifetime"
                : "/ ${subscriptionPlanModel.expiryDay} Days",
            style: AppTypography.boldLabel(Get.context!).copyWith(
              color: isSelected ? AppColors.grey200 : AppColors.grey500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommissionInfo(bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withOpacity(0.1)
            : AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : AppColors.primary.withOpacity(0.09),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isSelected ? Colors.white : AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Commission: ${Constant.adminCommission?.type == 'percentage' ? "${Constant.adminCommission?.amount}%" : "${Constant.amountShow(amount: Constant.adminCommission?.amount)} Flat"} per order',
              style: AppTypography.label(Get.context!).copyWith(
                color: isSelected ? Colors.white : AppColors.grey500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(bool isSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's included:",
          style: AppTypography.boldLabel(Get.context!).copyWith(
            color: isSelected ? Colors.white : AppColors.darkTextFieldBorder,
          ),
        ),
        const SizedBox(height: 8),
        ...subscriptionPlanModel.planPoints!.map(
          (point) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.ratingColour,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point,
                    style: AppTypography.label(Get.context!).copyWith(
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : AppColors.grey600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingLimit(bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color:
            isSelected ? Colors.white.withOpacity(0.1) : AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : AppColors.darkBackground,
          width: 0.95,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bookmark_border,
            color: isSelected ? Colors.white : AppColors.darkBackground,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Booking Limit: ${subscriptionPlanModel.bookingLimit == '-1' ? 'Unlimited' : subscriptionPlanModel.bookingLimit ?? '0'}',
            style: AppTypography.boldLabel(Get.context!).copyWith(
              color: isSelected ? Colors.white : AppColors.darkTextFieldBorder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(bool isSelected, bool isActive) {
    return SizedBox(
      width: double.infinity,
      height: 35,
      child: ElevatedButton(
        onPressed: onClick,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.white : AppColors.darkBackground,
          foregroundColor: isSelected ? AppColors.darkBackground : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          isActive
              ? "Renew Plan"
              : isSelected
                  ? "Continue with Plan"
                  : "Select Plan",
          style: AppTypography.button(Get.context!).copyWith(
              color: isSelected ? AppColors.primary : AppColors.background),
        ),
      ),
    );
  }

  LinearGradient _buildSelectedGradient() {
    return const LinearGradient(
      colors: [AppColors.primary, AppColors.darkModePrimary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  List<BoxShadow> _buildSelectedShadow() {
    return [
      BoxShadow(
        color: AppColors.primary.withOpacity(0.5),
        blurRadius: 10,
        offset: const Offset(0, 8),
      ),
    ];
  }

  List<BoxShadow> _buildDefaultShadow() {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.09),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

class PaymentMethodDialog extends StatelessWidget {
  final SubscriptionController controller;

  const PaymentMethodDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildContent()),
          _buildPayButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_ios,
                color: AppColors.darkTextFieldBorder),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
          Text(
            "Choose Payment Method".tr,
            style: GoogleFonts.poppins(
              color: AppColors.grey600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Obx(() => Column(
                children: [
                  if (controller.paymentModel.value.wallet?.enable == true)
                    ModernPaymentOption(
                      title:
                          controller.paymentModel.value.wallet!.name.toString(),
                      icon: 'assets/icons/ic_wallet.svg',
                      isSelected: controller.selectedPaymentMethod.value ==
                          controller.paymentModel.value.wallet!.name.toString(),
                      onTap: () {
                        controller.selectedPaymentMethod.value = controller
                            .paymentModel.value.wallet!.name
                            .toString();
                      },
                    ),
                  if (controller.paymentModel.value.strip?.enable == true)
                    ModernPaymentOption(
                      title:
                          controller.paymentModel.value.strip!.name.toString(),
                      iconImage: 'assets/images/stripe.png',
                      isSelected: controller.selectedPaymentMethod.value ==
                          controller.paymentModel.value.strip!.name.toString(),
                      onTap: () {
                        controller.selectedPaymentMethod.value = controller
                            .paymentModel.value.strip!.name
                            .toString();
                      },
                    ),
                ],
              )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPayButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () => _handlePayment(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkBackground,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            "Pay Now".tr,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _handlePayment(BuildContext context) {
    if (controller.selectedPaymentMethod.value.isEmpty) {
      ShowToastDialog.showToast("Please Select Payment Method.");
      return;
    }

    if (controller.selectedPaymentMethod.value ==
        controller.paymentModel.value.wallet?.name) {
      _handleWalletPayment();
    } else if (controller.selectedPaymentMethod.value ==
        controller.paymentModel.value.strip?.name) {
      _handleStripePayment();
    } else {
      ShowToastDialog.showToast("Please select payment method".tr);
    }
  }

  void _handleWalletPayment() {
    final walletAmount =
        double.parse(controller.driverUserModel.value.walletAmount.toString());
    if (walletAmount >= controller.totalAmount.value) {
      Get.back();
      controller.placeOrder();
    } else {
      ShowToastDialog.showToast("Wallet Amount Insufficient".tr);
    }
  }

  void _handleStripePayment() {
    Get.back();
    controller.stripeMakePayment(
        amount: controller.totalAmount.value.toString());
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.grey200,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: AppColors.darkTextFieldBorder,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildSelectionIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.darkBackground.withOpacity(0.04)
            : AppColors.grey100.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: icon != null
            ? SvgPicture.asset(
                icon!,
                color: AppColors.primary,
                width: 24,
                height: 24,
              )
            : iconImage != null
                ? Image.asset(iconImage!, width: 24, height: 24)
                : Icon(
                    Icons.payment,
                    color: isSelected ? AppColors.primary : Colors.white,
                    size: 24,
                  ),
      ),
    );
  }

  Widget _buildSelectionIndicator() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.grey600,
          width: 2,
        ),
        color: isSelected ? AppColors.primary : Colors.transparent,
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }
}
