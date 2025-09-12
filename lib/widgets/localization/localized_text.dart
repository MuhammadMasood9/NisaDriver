import 'package:flutter/material.dart';
import '../../utils/language_utils.dart';

class LocalizedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? fallback;
  final bool autoDirection;

  const LocalizedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
    this.fallback,
    this.autoDirection = true,
  });

  @override
  Widget build(BuildContext context) {
    final localizedText = LanguageUtils.getLocalizedText(text, fallback: fallback);
    
    TextStyle? finalStyle = style;
    if (LanguageUtils.isCurrentLanguageUrdu() && style != null) {
      finalStyle = LanguageUtils.getUrduTextStyle(style!);
    }

    TextAlign finalTextAlign = textAlign ?? 
        (autoDirection ? LanguageUtils.getTextAlign() : TextAlign.start);

    TextDirection finalTextDirection = textDirection ?? 
        (autoDirection ? LanguageUtils.getTextDirection(LanguageUtils.getCurrentLanguage()) : TextDirection.ltr);

    return Directionality(
      textDirection: finalTextDirection,
      child: Text(
        localizedText,
        style: finalStyle,
        textAlign: finalTextAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

class LocalizedRichText extends StatelessWidget {
  final List<TextSpan> textSpans;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool autoDirection;

  const LocalizedRichText({
    super.key,
    required this.textSpans,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
    this.autoDirection = true,
  });

  @override
  Widget build(BuildContext context) {
    TextAlign finalTextAlign = textAlign ?? 
        (autoDirection ? LanguageUtils.getTextAlign() : TextAlign.start);

    TextDirection finalTextDirection = textDirection ?? 
        (autoDirection ? LanguageUtils.getTextDirection(LanguageUtils.getCurrentLanguage()) : TextDirection.ltr);

    // Process text spans for Urdu font if needed
    List<TextSpan> processedSpans = textSpans;
    if (LanguageUtils.isCurrentLanguageUrdu()) {
      processedSpans = textSpans.map((span) {
        if (span.style != null) {
          return TextSpan(
            text: span.text,
            style: LanguageUtils.getUrduTextStyle(span.style!),
            children: span.children,
            recognizer: span.recognizer,
          );
        }
        return span;
      }).toList();
    }

    return Directionality(
      textDirection: finalTextDirection,
      child: RichText(
        text: TextSpan(children: processedSpans),
        textAlign: finalTextAlign,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.clip,
      ),
    );
  }
}