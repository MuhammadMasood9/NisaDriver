import 'package:driver/constant/constant.dart';
import 'package:driver/model/withdraw_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class WithDrawHistoryScreen extends StatelessWidget {
  const WithDrawHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildSimpleAppBar(context),
      body: SafeArea(
        child: FutureBuilder<List<WithdrawModel>?>(
          future: FireStoreUtils.getWithDrawRequest(),
          builder: (context, snapshot) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(context),
                Expanded(
                  child: _buildContent(context, snapshot),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSimpleAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: InkWell(
        onTap: () => Get.back(),
        child: const Icon(Icons.arrow_back, color: Colors.black),
      ),
      centerTitle: true,
      title: Text(
        "Withdrawal History".tr,
        style: AppTypography.appTitle(context),
      ),
    );
  }

  Widget _buildHeaderSection(
      BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.darkBackground.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkBackground.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.history,
              color: AppColors.darkBackground,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Transaction History".tr,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Track your withdrawal requests".tr,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      AsyncSnapshot<List<WithdrawModel>?> snapshot,
      ) {
    switch (snapshot.connectionState) {
      case ConnectionState.waiting:
        return _buildLoadingState(context);
      case ConnectionState.done:
        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error.toString());
        } else {
          return snapshot.data!.isEmpty
              ? _buildEmptyState(context)
              : _buildTransactionList(context, snapshot.data!);
        }
      default:
        return _buildErrorState(context, 'Error'.tr);
    }
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            "Loading transactions...".tr,
            style: AppTypography.label(Get.context!),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.grey500,
          ),
          const SizedBox(height: 12),
          Text(
            "No Transactions Found".tr,
            style: AppTypography.headers(Get.context!),
          ),
          const SizedBox(height: 8),
          Text(
            "Your withdrawal history will appear here".tr,
            style: AppTypography.label(Get.context!)
                .copyWith(color: AppColors.grey500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          Text(
            error,
            style:
                AppTypography.label(Get.context!).copyWith(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context,
      List<WithdrawModel> transactions ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        return _buildTransactionCard(context, transactions[index]);
      },
    );
  }

  Widget _buildTransactionCard(BuildContext context, WithdrawModel transaction,
       ) {
    final isApproved = transaction.paymentStatus == "approved";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildSectionCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.asset(
                'assets/icons/ic_wallet.svg',
                width: 24,
                height: 24,
                color: AppColors.primary,
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
                        DateFormat('MMM dd, yyyy')
                            .format(transaction.createdDate!.toDate()),
                        style: AppTypography.boldLabel(Get.context!),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          transaction.paymentStatus.toString().toUpperCase(),
                          style: AppTypography.label(Get.context!).copyWith(
                            color: isApproved ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('hh:mm a')
                        .format(transaction.createdDate!.toDate()),
                    style: AppTypography.label(Get.context!)
                        .copyWith(color: AppColors.grey500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          transaction.note?.toString() ?? 'N/A',
                          style: AppTypography.label(Get.context!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "- ${Constant.amountShow(amount: transaction.amount.toString().replaceAll("-", ""))}",
                        style: AppTypography.boldLabel(Get.context!)
                            .copyWith(color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    // final themeChange = Provider.of<DarkThemeProvider>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkContainerBackground,
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
