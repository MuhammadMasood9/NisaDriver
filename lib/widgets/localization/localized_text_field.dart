import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/language_utils.dart';
import '../../themes/app_colors.dart';

class LocalizedTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final bool autoDirection;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool enabled;
  final String? fallbackLabel;
  final String? fallbackHint;
  final String? fallbackHelper;

  const LocalizedTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.autoDirection = true,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.focusNode,
    this.decoration,
    this.style,
    this.enabled = true,
    this.fallbackLabel,
    this.fallbackHint,
    this.fallbackHelper,
  });

  @override
  Widget build(BuildContext context) {
    final localizedLabel = labelText != null 
        ? LanguageUtils.getLocalizedText(labelText!, fallback: fallbackLabel)
        : null;
    final localizedHint = hintText != null 
        ? LanguageUtils.getLocalizedText(hintText!, fallback: fallbackHint)
        : null;
    final localizedHelper = helperText != null 
        ? LanguageUtils.getLocalizedText(helperText!, fallback: fallbackHelper)
        : null;

    TextStyle? finalStyle = style;
    if (LanguageUtils.isCurrentLanguageUrdu() && style != null) {
      finalStyle = LanguageUtils.getUrduTextStyle(style!);
    }

    TextDirection textDirection = autoDirection 
        ? LanguageUtils.getTextDirection(LanguageUtils.getCurrentLanguage())
        : TextDirection.ltr;

    TextAlign textAlign = autoDirection 
        ? LanguageUtils.getTextAlign()
        : TextAlign.start;

    InputDecoration finalDecoration = decoration ?? InputDecoration(
      labelText: localizedLabel,
      hintText: localizedHint,
      helperText: localizedHelper,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.grey300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.grey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

    // Override decoration texts with localized versions
    finalDecoration = finalDecoration.copyWith(
      labelText: localizedLabel ?? finalDecoration.labelText,
      hintText: localizedHint ?? finalDecoration.hintText,
      helperText: localizedHelper ?? finalDecoration.helperText,
    );

    return Directionality(
      textDirection: textDirection,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onTap: onTap,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        readOnly: readOnly,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        focusNode: focusNode,
        decoration: finalDecoration,
        style: finalStyle,
        enabled: enabled,
        textAlign: textAlign,
        textDirection: textDirection,
      ),
    );
  }
}

class LocalizedFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? Function(String?)? validator;
  final bool autoDirection;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final Function(String?)? onSaved;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool enabled;
  final String? fallbackLabel;
  final String? fallbackHint;
  final String? fallbackHelper;

  const LocalizedFormField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.validator,
    this.autoDirection = true,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.onChanged,
    this.onSaved,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.focusNode,
    this.decoration,
    this.style,
    this.enabled = true,
    this.fallbackLabel,
    this.fallbackHint,
    this.fallbackHelper,
  });

  @override
  Widget build(BuildContext context) {
    final localizedLabel = labelText != null 
        ? LanguageUtils.getLocalizedText(labelText!, fallback: fallbackLabel)
        : null;
    final localizedHint = hintText != null 
        ? LanguageUtils.getLocalizedText(hintText!, fallback: fallbackHint)
        : null;
    final localizedHelper = helperText != null 
        ? LanguageUtils.getLocalizedText(helperText!, fallback: fallbackHelper)
        : null;

    TextStyle? finalStyle = style;
    if (LanguageUtils.isCurrentLanguageUrdu() && style != null) {
      finalStyle = LanguageUtils.getUrduTextStyle(style!);
    }

    TextDirection textDirection = autoDirection 
        ? LanguageUtils.getTextDirection(LanguageUtils.getCurrentLanguage())
        : TextDirection.ltr;

    TextAlign textAlign = autoDirection 
        ? LanguageUtils.getTextAlign()
        : TextAlign.start;

    InputDecoration finalDecoration = decoration ?? InputDecoration(
      labelText: localizedLabel,
      hintText: localizedHint,
      helperText: localizedHelper,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.grey300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.grey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

    // Override decoration texts with localized versions
    finalDecoration = finalDecoration.copyWith(
      labelText: localizedLabel ?? finalDecoration.labelText,
      hintText: localizedHint ?? finalDecoration.hintText,
      helperText: localizedHelper ?? finalDecoration.helperText,
    );

    return Directionality(
      textDirection: textDirection,
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onTap: onTap,
        onChanged: onChanged,
        onSaved: onSaved,
        readOnly: readOnly,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        focusNode: focusNode,
        decoration: finalDecoration,
        style: finalStyle,
        enabled: enabled,
        textAlign: textAlign,
        textDirection: textDirection,
      ),
    );
  }
}