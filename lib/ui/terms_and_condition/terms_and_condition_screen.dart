import 'package:driver/constant/constant.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';

class TermsAndConditionScreen extends StatefulWidget {
  final String? type;

  const TermsAndConditionScreen({super.key, this.type});

  @override
  State<TermsAndConditionScreen> createState() =>
      _TermsAndConditionScreenState();
}

class _TermsAndConditionScreenState extends State<TermsAndConditionScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      setState(() {
        _scrollProgress =
            maxScroll > 0 ? (currentScroll / maxScroll).clamp(0.0, 1.0) : 0.0;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPrivacy = widget.type == "privacy";
    final primaryColor =
        isPrivacy ? AppColors.primary : AppColors.darksecondary;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (!isDarkMode)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: isDarkMode ? Colors.white : AppColors.darkBackground,
            ),
          ),
        ),
        title: Text(
          isPrivacy ? "Privacy Policy".tr : "Terms & Conditions".tr,
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppColors.darkBackground,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
            child: LinearProgressIndicator(
              value: _scrollProgress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPrivacy
                          ? Icons.shield_outlined
                          : Icons.description_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPrivacy ? "Privacy Policy" : "Terms of Service",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.white
                                : AppColors.darkBackground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Last updated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.white70
                                : AppColors.darkBackground.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Content Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Html(
                shrinkWrap: true,
                data: isPrivacy
                    ? Constant.localizationPrivacyPolicy(Constant.privacyPolicy)
                    : Constant.localizationTermsCondition(
                        Constant.termsAndConditions),
                style: {
                  "body": Style(
                    fontSize: FontSize(16),
                    lineHeight: const LineHeight(1.6),
                    color: isDarkMode ? Colors.white : AppColors.darkBackground,
                    fontWeight: FontWeight.w400,
                    margin: Margins.zero,
                  ),
                  "h1": Style(
                    fontSize: FontSize(24),
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                    margin: Margins.only(top: 24, bottom: 16),
                  ),
                  "h2": Style(
                    fontSize: FontSize(20),
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                    margin: Margins.only(top: 20, bottom: 12),
                  ),
                  "h3": Style(
                    fontSize: FontSize(18),
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                    margin: Margins.only(top: 16, bottom: 8),
                  ),
                  "p": Style(
                    fontSize: FontSize(16),
                    lineHeight: const LineHeight(1.6),
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppColors.darkBackground.withValues(alpha: 0.8),
                    margin: Margins.only(bottom: 16),
                  ),
                  "ul": Style(
                    margin: Margins.only(bottom: 16, left: 16),
                  ),
                  "li": Style(
                    fontSize: FontSize(16),
                    lineHeight: const LineHeight(1.6),
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppColors.darkBackground.withValues(alpha: 0.8),
                    margin: Margins.only(bottom: 8),
                  ),
                  "strong": Style(
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                },
              ),
            ),

            const SizedBox(height: 20),

            // Footer Note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: isDarkMode
                        ? Colors.white70
                        : AppColors.darkBackground.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Questions? Contact our support team for assistance.",
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? Colors.white70
                            : AppColors.darkBackground.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
