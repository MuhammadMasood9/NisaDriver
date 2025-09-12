import 'package:driver/services/localization_service.dart';
import 'package:get/get.dart';

/// Extension to provide enhanced translation methods for String
extension TranslationExtension on String {
  /// Enhanced translation with fallback mechanism
  /// Uses the LocalizationService fallback chain: Urdu → English → Key display
  String get trWithFallback {
    return LocalizationService.getTranslationWithFallback(this);
  }

  /// Standard GetX translation (kept for backward compatibility)
  /// Note: This uses GetX's built-in tr extension

  /// Check if this string has a translation key
  bool get hasTranslation {
    return LocalizationService.hasTranslationKey(this);
  }

  /// Generate a translation key from this text
  String toTranslationKey({String? category}) {
    return LocalizationService.generateTranslationKey(this, category: category);
  }
}

/// Helper class for translation utilities
class TranslationUtils {
  /// Get translation with fallback for any string
  static String translate(String key) {
    return LocalizationService.getTranslationWithFallback(key);
  }

  /// Batch translate multiple keys
  static Map<String, String> translateBatch(List<String> keys) {
    final Map<String, String> translations = {};
    for (String key in keys) {
      translations[key] = LocalizationService.getTranslationWithFallback(key);
    }
    return translations;
  }

  /// Get missing translations report
  static Map<String, List<String>> getMissingTranslations() {
    return LocalizationService.validateTranslationCompleteness();
  }

  /// Print coverage report (development only)
  static void printCoverageReport() {
    LocalizationService.printTranslationCoverageReport();
  }

  /// Clear missing keys log
  static void clearMissingKeysLog() {
    LocalizationService.clearMissingTranslationKeys();
  }

  /// Get all missing keys that were logged
  static Set<String> getMissingKeys() {
    return LocalizationService.getMissingTranslationKeys();
  }
}