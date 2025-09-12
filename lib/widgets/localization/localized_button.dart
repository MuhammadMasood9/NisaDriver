import 'package:flutter/material.dart';
import '../../utils/language_utils.dart';
import '../../themes/app_colors.dart';
import '../../themes/typography.dart';

class LocalizedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final TextStyle? textStyle;
  final bool autoDirection;
  final Widget? icon;
  final bool isLoading;
  final String? fallback;

  const LocalizedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.style,
    this.textStyle,
    this.autoDirection = true,
    this.icon,
    this.isLoading = false,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final localizedText = LanguageUtils.getLocalizedText(text, fallback: fallback);
    
    TextStyle? finalTextStyle = textStyle ?? AppTypography.button(context);
    if (LanguageUtils.isCurrentLanguageUrdu() && finalTextStyle != null) {
      finalTextStyle = LanguageUtils.getUrduTextStyle(finalTextStyle);
    }

    Widget buttonChild;
    if (isLoading) {
      buttonChild = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else if (icon != null) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: LanguageUtils.isCurrentLanguageRTL()
            ? [
                Text(localizedText, style: finalTextStyle),
                const SizedBox(width: 8),
                icon!,
              ]
            : [
                icon!,
                const SizedBox(width: 8),
                Text(localizedText, style: finalTextStyle),
              ],
      );
    } else {
      buttonChild = Text(localizedText, style: finalTextStyle);
    }

    return Directionality(
      textDirection: autoDirection 
          ? LanguageUtils.getTextDirection(LanguageUtils.getCurrentLanguage())
          : TextDirection.ltr,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: buttonChild,
      ),
    );
  }
}

class LocalizedOutlinedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final TextStyle? textStyle;
  final bool autoDirection;
  final Widget? icon;
  final bool isLoading;
  final String? fallback;

  const LocalizedOutlinedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.style,
    this.textStyle,
    this.autoDirection = true,
    this.icon,
    this.isLoading = false,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final localizedText = LanguageUtils.getLocalizedText(text, fallback: fallback);
    
    TextStyle? finalTextStyle = textStyle ?? AppTypography.button(context).copyWith(color: AppColors.primary);
    if (LanguageUtils.isCurrentLanguageUrdu() && finalTextStyle != null) {
      finalTextStyle = LanguageUtils.getUrduTextStyle(finalTextStyle);
    }

    Widget buttonChild;
    if (isLoading) {
      buttonChild = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    } else if (icon != null) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: LanguageUtils.isCurrentLanguageRTL()
            ? [
                Text(localizedText, style: finalTextStyle),
                const SizedBox(width: 8),
                icon!,
              ]
            : [
                icon!,
                const SizedBox(width: 8),
                Text(localizedText, style: finalTextStyle),
              ],
      );
    } else {
      buttonChild = Text(localizedText, style: finalTextStyle);
    }

    return Directionality(
      textDirection: autoDirection 
          ? LanguageUtils.getTextDirection(LanguageUtils.getCurrentLanguage())
          : TextDirection.ltr,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: buttonChild,
      ),
    );
  }
}

class LocalizedTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final TextStyle? textStyle;
  final bool autoDirection;
  final Widget? icon;
  final String? fallback;

  const LocalizedTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.style,
    this.textStyle,
    this.autoDirection = true,
    this.icon,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final localizedText = LanguageUtils.getLocalizedText(text, fallback: fallback);
    
    TextStyle? finalTextStyle = textStyle ?? AppTypography.button(context).copyWith(color: AppColors.primary);
    if (LanguageUtils.isCurrentLanguageUrdu() && finalTextStyle != null) {
      finalTextStyle = LanguageUtils.getUrduTextStyle(finalTextStyle);
    }

    Widget buttonChild;
    if (icon != null) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: LanguageUtils.isCurrentLanguageRTL()
            ? [
                Text(localizedText, style: finalTextStyle),
                const SizedBox(width: 8),
                icon!,
              ]
            : [
                icon!,
                const SizedBox(width: 8),
                Text(localizedText, style: finalTextStyle),
              ],
      );
    } else {
      buttonChild = Text(localizedText, style: finalTextStyle);
    }

    return Directionality(
      textDirection: autoDirection 
          ? LanguageUtils.getTextDirection(LanguageUtils.getCurrentLanguage())
          : TextDirection.ltr,
      child: TextButton(
        onPressed: onPressed,
        style: style,
        child: buttonChild,
      ),
    );
  }
}