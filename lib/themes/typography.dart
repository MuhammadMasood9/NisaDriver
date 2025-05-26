
import 'package:driver/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static double _responsiveFontSize(BuildContext context, double baseSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) {
      return baseSize * 0.85; // Smaller screens
    } else if (screenWidth < 720) {
      return baseSize; // Medium screens
    } else {
      return baseSize * 1.15; // Larger screens
    }
  }

  // Headings
  static TextStyle h1(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 24),
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      );

  static TextStyle h2(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 20),
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      );

  static TextStyle h3(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 18),
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      );

  // Body text
  static TextStyle bodyLarge(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 16),
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      );

  static TextStyle bodyMedium(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 14),
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      );

  static TextStyle bodySmall(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 12),
        fontWeight: FontWeight.w400,
        color: Colors.black87,
      );

  // Special text styles
  static TextStyle caption(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 12),
        fontWeight: FontWeight.w400,
        color: Colors.black54,
      );

  static TextStyle button(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 12),
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle appTitle(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 14),
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextFieldBorder,
      );

  static TextStyle homeTabs(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 10),
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle input(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 11.5),
        fontWeight: FontWeight.w400,
        color: const Color.fromARGB(221, 46, 46, 46),
      );
  static TextStyle priceTypo(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 14),
        fontWeight: FontWeight.w500,
        color: AppColors.darkTextFieldBorder,
      );

  static TextStyle label(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 12),
        fontWeight: FontWeight.w400,
        color: AppColors.darkTextFieldBorder,
      );
  static TextStyle boldLabel(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 12),
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextFieldBorder,
      );
  static TextStyle headers(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 16),
        fontWeight: FontWeight.w500,
        color: AppColors.darkTextFieldBorder,
      );

  static TextStyle appBar(BuildContext context) => GoogleFonts.poppins(
        fontSize: _responsiveFontSize(context, 12),
        fontWeight: FontWeight.w600,
        color: AppColors.background,
      );
}
