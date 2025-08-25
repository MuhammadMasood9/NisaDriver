import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TextFieldThem {
  const TextFieldThem({Key? key});

  static buildTextFiled(
    BuildContext context, {
    required String hintText,
    required TextEditingController controller,
    TextInputType keyBoardType = TextInputType.text,
    bool enable = true,
    int maxLine = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {

    return TextFormField(
        controller: controller,
        textAlign: TextAlign.start,
        enabled: enable,
        
        keyboardType: keyBoardType,
        maxLines: maxLine,
        inputFormatters: inputFormatters,
        style: AppTypography.input(context),
        decoration: InputDecoration(
            filled: true,
            
            fillColor: AppColors.background,
            contentPadding: EdgeInsets.only(left: 10, right: 10, top: maxLine == 1 ? 0 : 10),
            disabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            hintText: hintText));
  }

  static buildTextFiledWithPrefixIcon(BuildContext context,
      {required String hintText,
      required TextEditingController controller,
      required Widget prefix,
      TextInputType keyBoardType = TextInputType.text,
      bool enable = true,
      ValueChanged<String>? onChanged}) {

    return TextFormField(
        controller: controller,
        textAlign: TextAlign.start,
        enabled: enable,
        keyboardType: keyBoardType,
        style: GoogleFonts.poppins(color:  Colors.black),
        onChanged: onChanged,
        decoration: InputDecoration(
            prefix: prefix,
            filled: true,
            fillColor: AppColors.textField,
            contentPadding: const EdgeInsets.only(left: 10, right: 10),
            disabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color: AppColors.textFieldBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            hintText: hintText));
  }

  static buildTextFiledWithSuffixIcon(
    BuildContext context, {
    required String hintText,
    required TextEditingController controller,
    required Widget suffixIcon,
    TextInputType keyBoardType = TextInputType.text,
    bool enable = true,
  }) {

    return TextFormField(
        controller: controller,
        textAlign: TextAlign.start,
        enabled: enable,
        keyboardType: keyBoardType,
        style: GoogleFonts.poppins(color:  Colors.black),
        decoration: InputDecoration(
            suffixIcon: suffixIcon,
            filled: true,
            fillColor:  AppColors.textField,
            contentPadding: const EdgeInsets.only(left: 10, right: 10),
            disabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              borderSide: BorderSide(color:  AppColors.textFieldBorder, width: 1),
            ),
            hintText: hintText));
  }
}
