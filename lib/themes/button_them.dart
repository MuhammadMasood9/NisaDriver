import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ButtonThem {
  const ButtonThem({Key? key});

  static buildButton(
    BuildContext context, {
    required String title,
    double btnHeight = 48,
    double txtSize = 12,
    double btnWidthRatio = 0.9,
    double btnRadius = 5,
    final Color? textColor,
    final Color? bgColors,
    required Function() onPress,
    bool isVisible = true,
  }) {
    return Visibility(
      visible: isVisible,
      child: SizedBox(
        width: Responsive.width(100, context) * btnWidthRatio,
        child: MaterialButton(
          onPressed: onPress,
          height: 35,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(btnRadius),
          ),
          color: bgColors ?? (AppColors.darkBackground),
          child: Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.buttonlight(context),
          ),
        ),
      ),
    );
  }

  static Widget buildBorderButton(
    BuildContext context, {
    required String title,
    double btnHeight = 35,
    double txtSize = 12,
    double btnWidthRatio = 0.9,
    double borderRadius = 5,
    required Function() onPress,
    bool isVisible = true,
    bool iconVisibility = false,
    String iconAssetImage = '',
    Color? iconColor,
  }) {
    return Visibility(
      visible: isVisible,
      child: Container(
        width: Responsive.width(100, context) * btnWidthRatio,
        height: 35,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: Offset(0, -2), // Top shadow
              blurRadius: 2,
              spreadRadius: 0.6,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: Offset(0, 2), // Bottom shadow
              blurRadius: 2,
              spreadRadius: 0.6,
            ),
          ],
        ),
        child: ElevatedButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(Colors.white),
            foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            elevation: MaterialStateProperty.all<double>(
                0), // Disable default elevation
          ),
          onPressed: onPress,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Visibility(
                visible: iconVisibility,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Image.asset(iconAssetImage,
                      fit: BoxFit.cover, width: 32, color: iconColor),
                ),
              ),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTypography.button(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static roundButton(
    BuildContext context, {
    required String title,
    double btnHeight = 48,
    double txtSize = 14,
    double btnWidthRatio = 0.9,
    required Function() onPress,
    bool isVisible = true,
  }) {
    return Visibility(
      visible: isVisible,
      child: SizedBox(
        width: Responsive.width(100, context) * btnWidthRatio,
        child: MaterialButton(
          onPressed: onPress,
          height: 35,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          color: AppColors.background,
          child: Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.buttonlight(context)
                .copyWith(fontWeight: FontWeight.w600)
                .copyWith(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
