import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/language_model.dart';
import '../controller/language_controller.dart';

class LanguageUtils {
  /// Get language controller instance
  static LanguageController get _controller {
    try {
      return Get.find<LanguageController>();
    } catch (e) {
      // If controller is not found, put it and return
      return Get.put(LanguageController());
    }
  }
  
  /// Check if a language is RTL (Right-to-Left)
  static bool isRTL(String languageCode) {
    final language = SupportedLanguageModel.getLanguageByCode(languageCode);
    return language?.isRTL ?? false;
  }

  /// Get text direction for a language
  static TextDirection getTextDirection(String languageCode) {
    return isRTL(languageCode) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Get current language from controller (optimized)
  static String getCurrentLanguage() {
    try {
      return _controller.currentLanguageCode;
    } catch (e) {
      // Fallback to GetX locale if controller is not available
      return Get.locale?.languageCode ?? 'en';
    }
  }

  /// Get current language model from controller (optimized)
  static SupportedLanguageModel getCurrentLanguageModel() {
    try {
      return _controller.currentLanguage;
    } catch (e) {
      // Fallback to manual lookup if controller is not available
      final currentCode = Get.locale?.languageCode ?? 'en';
      return SupportedLanguageModel.getLanguageByCode(currentCode) ?? SupportedLanguageModel.defaultLanguage;
    }
  }

  /// Change app language using optimized controller
  static Future<bool> changeLanguage(String languageCode) async {
    try {
      return await _controller.changeLanguage(languageCode);
    } catch (e) {
      debugPrint('Error changing language: $e');
      return false;
    }
  }

  /// Initialize language using optimized controller
  static Future<void> initializeLanguage() async {
    try {
      await _controller.initializeLanguage();
    } catch (e) {
      debugPrint('Error initializing language: $e');
    }
  }

  /// Get font family for Urdu text
  static String? getUrduFontFamily() {
    // Return null to use system default fonts which handle Urdu well
    // Can be customized to return specific font families if needed
    return null;
  }

  /// Get text style for Urdu text
  static TextStyle getUrduTextStyle(TextStyle baseStyle) {
    final fontFamily = getUrduFontFamily();
    if (fontFamily != null) {
      return baseStyle.copyWith(fontFamily: fontFamily);
    }
    return baseStyle;
  }

  /// Check if current language is Urdu
  static bool isCurrentLanguageUrdu() {
    return getCurrentLanguage() == 'ur';
  }

  /// Check if current language is RTL (optimized)
  static bool isCurrentLanguageRTL() {
    try {
      return _controller.isCurrentLanguageRTL;
    } catch (e) {
      return isRTL(getCurrentLanguage());
    }
  }

  /// Get localized text with enhanced fallback
  static String getLocalizedText(String key, {String? fallback}) {
    try {
      // Use enhanced translation method with fallback
      return key.tr;
    } catch (e) {
      debugPrint('Error getting localized text for key: $key, error: $e');
      return fallback ?? key;
    }
  }

  /// Format text for RTL languages
  static String formatRTLText(String text) {
    if (isCurrentLanguageRTL()) {
      // Add RTL mark if needed
      return '\u202B$text\u202C';
    }
    return text;
  }

  /// Get appropriate text alignment for current language (optimized)
  static TextAlign getTextAlign() {
    try {
      return _controller.getTextAlign();
    } catch (e) {
      return isCurrentLanguageRTL() ? TextAlign.right : TextAlign.left;
    }
  }

  /// Get appropriate main axis alignment for current language (optimized)
  static MainAxisAlignment getMainAxisAlignment() {
    try {
      return _controller.getMainAxisAlignment();
    } catch (e) {
      return isCurrentLanguageRTL() ? MainAxisAlignment.end : MainAxisAlignment.start;
    }
  }

  /// Get appropriate cross axis alignment for current language (optimized)
  static CrossAxisAlignment getCrossAxisAlignment() {
    try {
      return _controller.getCrossAxisAlignment();
    } catch (e) {
      return isCurrentLanguageRTL() ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    }
  }

  /// Get text direction for current language (optimized)
  static TextDirection getCurrentTextDirection() {
    try {
      return _controller.getTextDirection();
    } catch (e) {
      return getTextDirection(getCurrentLanguage());
    }
  }

  /// Check if language switching is in progress
  static bool isLanguageSwitchingInProgress() {
    try {
      return _controller.isChangingLanguage;
    } catch (e) {
      return false;
    }
  }

  /// Check if language is initialized
  static bool isLanguageInitialized() {
    try {
      return _controller.isLanguageInitialized;
    } catch (e) {
      return true; // Assume initialized if controller is not available
    }
  }

  /// Get primary supported languages
  static List<SupportedLanguageModel> getPrimaryLanguages() {
    try {
      return _controller.getPrimaryLanguages();
    } catch (e) {
      return SupportedLanguageModel.supportedLanguages
          .where((lang) => ['en', 'ur'].contains(lang.code))
          .toList();
    }
  }

  /// Preload translations for better performance
  static Future<void> preloadTranslations() async {
    try {
      await _controller.preloadTranslations();
    } catch (e) {
      debugPrint('Error preloading translations: $e');
    }
  }

  /// Get language switching performance metrics
  static Map<String, dynamic> getPerformanceMetrics() {
    try {
      return _controller.getPerformanceMetrics();
    } catch (e) {
      return {
        'error': 'Controller not available',
        'current_language': getCurrentLanguage(),
      };
    }
  }
}