import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../utils/language_utils.dart';
import '../../themes/app_colors.dart';
import '../../themes/typography.dart';

/// A specialized input field optimized for Urdu text input
class UrduInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
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
  final bool autoCorrect;
  final bool enableSuggestions;
  final TextCapitalization textCapitalization;

  const UrduInputField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
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
    this.autoCorrect = true,
    this.enableSuggestions = true,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if we should use RTL layout
    final isUrdu = LanguageUtils.isCurrentLanguageUrdu();
    final textDirection = isUrdu ? TextDirection.rtl : TextDirection.ltr;
    final textAlign = isUrdu ? TextAlign.right : TextAlign.left;

    // Apply Urdu-specific text styling
    TextStyle finalStyle = style ?? AppTypography.input(context);
    if (isUrdu) {
      finalStyle = LanguageUtils.getUrduTextStyle(finalStyle);
    }

    // Create decoration with proper RTL support
    InputDecoration finalDecoration = decoration ?? _buildDefaultDecoration();
    
    // Swap prefix and suffix icons for RTL
    Widget? finalPrefixIcon = prefixIcon;
    Widget? finalSuffixIcon = suffixIcon;
    
    if (isUrdu && prefixIcon != null && suffixIcon != null) {
      finalPrefixIcon = suffixIcon;
      finalSuffixIcon = prefixIcon;
    }

    finalDecoration = finalDecoration.copyWith(
      labelText: labelText?.tr ?? finalDecoration.labelText,
      hintText: hintText?.tr ?? finalDecoration.hintText,
      helperText: helperText?.tr ?? finalDecoration.helperText,
      errorText: errorText,
      prefixIcon: finalPrefixIcon,
      suffixIcon: finalSuffixIcon,
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
        autocorrect: autoCorrect,
        enableSuggestions: enableSuggestions,
        textCapitalization: textCapitalization,
        // Optimize for Urdu text input
        textInputAction: TextInputAction.done,
        cursorColor: AppColors.primary,
      ),
    );
  }

  InputDecoration _buildDefaultDecoration() {
    return InputDecoration(
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
      filled: true,
      fillColor: AppColors.background,
    );
  }
}

/// A specialized form field optimized for Urdu text input
class UrduFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? Function(String?)? validator;
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
  final bool autoCorrect;
  final bool enableSuggestions;
  final TextCapitalization textCapitalization;

  const UrduFormField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.validator,
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
    this.autoCorrect = true,
    this.enableSuggestions = true,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    // Determine if we should use RTL layout
    final isUrdu = LanguageUtils.isCurrentLanguageUrdu();
    final textDirection = isUrdu ? TextDirection.rtl : TextDirection.ltr;
    final textAlign = isUrdu ? TextAlign.right : TextAlign.left;

    // Apply Urdu-specific text styling
    TextStyle finalStyle = style ?? AppTypography.input(context);
    if (isUrdu) {
      finalStyle = LanguageUtils.getUrduTextStyle(finalStyle);
    }

    // Create decoration with proper RTL support
    InputDecoration finalDecoration = decoration ?? _buildDefaultDecoration();
    
    // Swap prefix and suffix icons for RTL
    Widget? finalPrefixIcon = prefixIcon;
    Widget? finalSuffixIcon = suffixIcon;
    
    if (isUrdu && prefixIcon != null && suffixIcon != null) {
      finalPrefixIcon = suffixIcon;
      finalSuffixIcon = prefixIcon;
    }

    finalDecoration = finalDecoration.copyWith(
      labelText: labelText?.tr ?? finalDecoration.labelText,
      hintText: hintText?.tr ?? finalDecoration.hintText,
      helperText: helperText?.tr ?? finalDecoration.helperText,
      prefixIcon: finalPrefixIcon,
      suffixIcon: finalSuffixIcon,
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
        autocorrect: autoCorrect,
        enableSuggestions: enableSuggestions,
        textCapitalization: textCapitalization,
        // Optimize for Urdu text input
        textInputAction: TextInputAction.done,
        cursorColor: AppColors.primary,
      ),
    );
  }

  InputDecoration _buildDefaultDecoration() {
    return InputDecoration(
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
      filled: true,
      fillColor: AppColors.background,
    );
  }
}

/// Input formatter for Urdu text to handle special characters
class UrduTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Handle Urdu-specific text formatting if needed
    String formattedText = newValue.text;
    
    // Add RTL mark for proper text direction
    if (formattedText.isNotEmpty && LanguageUtils.isCurrentLanguageUrdu()) {
      // Ensure proper RTL formatting
      formattedText = LanguageUtils.formatRTLText(formattedText);
    }
    
    return TextEditingValue(
      text: formattedText,
      selection: newValue.selection,
    );
  }
}