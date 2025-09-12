import 'package:driver/lang/app_ar.dart';
import 'package:driver/lang/app_en.dart';
import 'package:driver/lang/app_fr.dart';
import 'package:driver/lang/app_ur.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LocalizationService extends Translations {
  // Default locale
  static const locale = Locale('en', 'US');

  static final locales = [
    const Locale('en'),
    const Locale('ar'),
    const Locale('fr'),
    const Locale('ur'),
  ];

  // Primary supported languages for this implementation
  static final primaryLanguages = ['en', 'ur'];
  
  // Set to track missing translation keys for development
  static final Set<String> _missingKeys = <String>{};
  
  // Set to track translation errors for development
  static final Set<String> _translationErrors = <String>{};
  
  // Map to track error details for debugging
  static final Map<String, Map<String, dynamic>> _errorDetails = <String, Map<String, dynamic>>{};
  
  // Keys and their translations
  // Translations are separated maps in `lang` file
  @override
  Map<String, Map<String, String>> get keys => {
        'en': enUS,
        'ar': arAR,
        'fr': trFr,
        'ur': urUR,
      };

  // Gets locale from language, and updates the locale with performance optimization
  void changeLocale(String lang) {
    final locale = Locale(lang);
    
    // Update locale immediately for better performance
    Get.updateLocale(locale);
    
    // Also schedule a post-frame callback as backup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.locale?.languageCode != lang) {
        Get.updateLocale(locale);
      }
    });
  }

  /// Optimized method for immediate locale change
  static Future<void> changeLocaleImmediate(String lang) async {
    final locale = Locale(lang);
    await Get.updateLocale(locale);
  }

  /// Enhanced translation method with fallback mechanism and error handling
  /// Fallback chain: Urdu → English → Key display with warning
  static String getTranslationWithFallback(String key) {
    try {
      final currentLocale = Get.locale?.languageCode ?? 'en';
      
      // Validate key format
      if (key.isEmpty) {
        _logTranslationError('Empty translation key provided', key);
        return kDebugMode ? '[EMPTY_KEY]' : 'Text';
      }
      
      // Try current language first
      String? translation = _getTranslationForLanguage(key, currentLocale);
      if (translation != null && translation.isNotEmpty) {
        return translation;
      }
      
      // Fallback chain for primary languages
      if (currentLocale == 'ur') {
        // Urdu → English fallback
        translation = _getTranslationForLanguage(key, 'en');
        if (translation != null && translation.isNotEmpty) {
          _logMissingTranslation(key, 'ur');
          return translation;
        }
      } else if (currentLocale == 'en') {
        // English → Urdu fallback (less common but possible)
        translation = _getTranslationForLanguage(key, 'ur');
        if (translation != null && translation.isNotEmpty) {
          _logMissingTranslation(key, 'en');
          return translation;
        }
      }
      
      // Try other primary languages as last resort
      for (String lang in primaryLanguages) {
        if (lang != currentLocale) {
          translation = _getTranslationForLanguage(key, lang);
          if (translation != null && translation.isNotEmpty) {
            _logMissingTranslation(key, currentLocale);
            return translation;
          }
        }
      }
      
      // Final fallback: display key with warning
      _logMissingTranslation(key, currentLocale);
      return kDebugMode ? '[MISSING: $key]' : _generateFallbackText(key);
      
    } catch (e) {
      _logTranslationError('Error getting translation for key: $key', key, error: e);
      return kDebugMode ? '[ERROR: $key]' : _generateFallbackText(key);
    }
  }

  /// Get translation for specific language with error handling
  static String? _getTranslationForLanguage(String key, String languageCode) {
    try {
      final LocalizationService service = LocalizationService();
      final translations = service.keys[languageCode];
      
      if (translations == null) {
        _logTranslationError('Language not found: $languageCode', key);
        return null;
      }
      
      return translations[key];
    } catch (e) {
      _logTranslationError('Error accessing translation for language: $languageCode', key, error: e);
      return null;
    }
  }

  /// Generate fallback text from translation key
  static String _generateFallbackText(String key) {
    // Convert snake_case to readable text
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');
  }

  /// Log missing translation keys for development
  static void _logMissingTranslation(String key, String languageCode) {
    final missingKey = '$languageCode:$key';
    if (!_missingKeys.contains(missingKey)) {
      _missingKeys.add(missingKey);
      
      // Store detailed information about missing translation
      _errorDetails[missingKey] = {
        'type': 'missing_translation',
        'key': key,
        'language': languageCode,
        'timestamp': DateTime.now().toIso8601String(),
        'current_locale': Get.locale?.languageCode ?? 'unknown',
      };
      
      if (kDebugMode) {
        debugPrint('🔍 Missing translation: [$languageCode] "$key"');
      }
    }
  }

  /// Log translation errors for development and debugging
  static void _logTranslationError(String message, String key, {Object? error}) {
    final errorKey = 'error:$key:${DateTime.now().millisecondsSinceEpoch}';
    _translationErrors.add(errorKey);
    
    // Store detailed error information
    _errorDetails[errorKey] = {
      'type': 'translation_error',
      'message': message,
      'key': key,
      'error': error?.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'current_locale': Get.locale?.languageCode ?? 'unknown',
    };
    
    if (kDebugMode) {
      debugPrint('❌ Translation Error: $message (Key: $key)');
      if (error != null) {
        debugPrint('   Error details: $error');
      }
    }
  }

  /// Get all missing translation keys (for development/debugging)
  static Set<String> getMissingTranslationKeys() {
    return Set.from(_missingKeys);
  }

  /// Get all translation errors (for development/debugging)
  static Set<String> getTranslationErrors() {
    return Set.from(_translationErrors);
  }

  /// Get detailed error information for debugging
  static Map<String, Map<String, dynamic>> getErrorDetails() {
    return Map.from(_errorDetails);
  }

  /// Clear missing translation keys log
  static void clearMissingTranslationKeys() {
    _missingKeys.clear();
  }

  /// Clear translation errors log
  static void clearTranslationErrors() {
    _translationErrors.clear();
    _errorDetails.clear();
  }

  /// Clear all translation logs
  static void clearAllTranslationLogs() {
    clearMissingTranslationKeys();
    clearTranslationErrors();
  }

  /// Validate translation completeness for primary languages with error handling
  static Map<String, List<String>> validateTranslationCompleteness() {
    try {
      final LocalizationService service = LocalizationService();
      final Map<String, List<String>> missingTranslations = {};
      
      // Get all unique keys from all primary languages
      final Set<String> allKeys = <String>{};
      for (String lang in primaryLanguages) {
        try {
          final translations = service.keys[lang];
          if (translations != null) {
            allKeys.addAll(translations.keys);
          }
        } catch (e) {
          _logTranslationError('Error accessing translations for language: $lang', 'validation', error: e);
        }
      }
      
      // Check each language for missing keys
      for (String lang in primaryLanguages) {
        try {
          final translations = service.keys[lang] ?? {};
          final List<String> missing = [];
          
          for (String key in allKeys) {
            if (!translations.containsKey(key) || 
                translations[key] == null || 
                translations[key]!.trim().isEmpty) {
              missing.add(key);
            }
          }
          
          if (missing.isNotEmpty) {
            missingTranslations[lang] = missing;
          }
        } catch (e) {
          _logTranslationError('Error validating translations for language: $lang', 'validation', error: e);
        }
      }
      
      return missingTranslations;
    } catch (e) {
      _logTranslationError('Critical error during translation validation', 'validation', error: e);
      return {};
    }
  }

  /// Validate translation loading and system health
  static Map<String, dynamic> validateTranslationSystem() {
    final Map<String, dynamic> systemHealth = {
      'status': 'healthy',
      'errors': [],
      'warnings': [],
      'languages_loaded': [],
      'total_keys_per_language': {},
      'missing_translations': {},
      'error_count': _translationErrors.length,
      'missing_key_count': _missingKeys.length,
    };

    try {
      final LocalizationService service = LocalizationService();
      
      // Check if languages are properly loaded
      for (String lang in primaryLanguages) {
        try {
          final translations = service.keys[lang];
          if (translations != null) {
            systemHealth['languages_loaded'].add(lang);
            systemHealth['total_keys_per_language'][lang] = translations.length;
          } else {
            systemHealth['errors'].add('Language $lang failed to load');
            systemHealth['status'] = 'error';
          }
        } catch (e) {
          systemHealth['errors'].add('Error loading language $lang: $e');
          systemHealth['status'] = 'error';
        }
      }
      
      // Check for missing translations
      final missingTranslations = validateTranslationCompleteness();
      systemHealth['missing_translations'] = missingTranslations;
      
      if (missingTranslations.isNotEmpty) {
        systemHealth['warnings'].add('Missing translations detected');
        if (systemHealth['status'] == 'healthy') {
          systemHealth['status'] = 'warning';
        }
      }
      
      // Check for recent errors
      if (_translationErrors.isNotEmpty) {
        systemHealth['warnings'].add('${_translationErrors.length} translation errors logged');
        if (systemHealth['status'] == 'healthy') {
          systemHealth['status'] = 'warning';
        }
      }
      
    } catch (e) {
      systemHealth['status'] = 'critical_error';
      systemHealth['errors'].add('Critical system validation error: $e');
    }
    
    return systemHealth;
  }

  /// Generate a consistent translation key from text
  static String generateTranslationKey(String text, {String? category}) {
    // Remove special characters and convert to lowercase
    String key = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    
    // Add category prefix if provided
    if (category != null && category.isNotEmpty) {
      key = '${category.toLowerCase()}_$key';
    }
    
    // Ensure key doesn't start with number
    if (key.isNotEmpty && RegExp(r'^\d').hasMatch(key)) {
      key = 'key_$key';
    }
    
    return key;
  }

  /// Helper method to create translation key suggestions
  static Map<String, String> suggestTranslationKeys(List<String> texts, {String? category}) {
    final Map<String, String> suggestions = {};
    
    for (String text in texts) {
      if (text.isNotEmpty) {
        final key = generateTranslationKey(text, category: category);
        suggestions[key] = text;
      }
    }
    
    return suggestions;
  }

  /// Check if a translation key exists in primary languages
  static bool hasTranslationKey(String key) {
    final LocalizationService service = LocalizationService();
    
    for (String lang in primaryLanguages) {
      final translations = service.keys[lang];
      if (translations != null && translations.containsKey(key)) {
        return true;
      }
    }
    
    return false;
  }

  /// Get translation coverage statistics
  static Map<String, dynamic> getTranslationCoverage() {
    final LocalizationService service = LocalizationService();
    final Map<String, dynamic> coverage = {};
    
    // Get all unique keys
    final Set<String> allKeys = <String>{};
    for (String lang in primaryLanguages) {
      final translations = service.keys[lang];
      if (translations != null) {
        allKeys.addAll(translations.keys);
      }
    }
    
    final int totalKeys = allKeys.length;
    coverage['total_keys'] = totalKeys;
    coverage['languages'] = <String, Map<String, dynamic>>{};
    
    for (String lang in primaryLanguages) {
      final translations = service.keys[lang] ?? {};
      final int translatedKeys = translations.length;
      final double percentage = totalKeys > 0 ? (translatedKeys / totalKeys) * 100 : 0;
      
      coverage['languages'][lang] = {
        'translated_keys': translatedKeys,
        'missing_keys': totalKeys - translatedKeys,
        'coverage_percentage': percentage.toStringAsFixed(1),
      };
    }
    
    return coverage;
  }

  /// Print comprehensive translation report (for development)
  static void printTranslationCoverageReport() {
    if (!kDebugMode) return;
    
    final coverage = getTranslationCoverage();
    final systemHealth = validateTranslationSystem();
    final totalKeys = coverage['total_keys'] as int;
    
    debugPrint('\n📊 Comprehensive Translation Report');
    debugPrint('=' * 50);
    debugPrint('Generated: ${DateTime.now()}');
    debugPrint('System Status: ${systemHealth['status']}');
    debugPrint('Total unique keys: $totalKeys');
    debugPrint('');
    
    // Coverage information
    debugPrint('📈 COVERAGE BY LANGUAGE:');
    final languages = coverage['languages'] as Map<String, Map<String, dynamic>>;
    for (String lang in languages.keys) {
      final langData = languages[lang]!;
      final translated = langData['translated_keys'];
      final missing = langData['missing_keys'];
      final percentage = langData['coverage_percentage'];
      
      debugPrint('  $lang: $translated/$totalKeys ($percentage%) - Missing: $missing');
    }
    
    // Error information
    if (_translationErrors.isNotEmpty) {
      debugPrint('\n❌ TRANSLATION ERRORS (${_translationErrors.length}):');
      final recentErrors = _translationErrors.take(5);
      for (String errorKey in recentErrors) {
        final errorDetail = _errorDetails[errorKey];
        if (errorDetail != null) {
          debugPrint('  - ${errorDetail['message']} (${errorDetail['key']})');
        }
      }
      if (_translationErrors.length > 5) {
        debugPrint('  ... and ${_translationErrors.length - 5} more errors');
      }
    }
    
    // Missing keys information
    if (_missingKeys.isNotEmpty) {
      debugPrint('\n🔍 MISSING TRANSLATIONS (${_missingKeys.length}):');
      for (String missingKey in _missingKeys.take(10)) {
        debugPrint('  - $missingKey');
      }
      if (_missingKeys.length > 10) {
        debugPrint('  ... and ${_missingKeys.length - 10} more');
      }
    }
    
    // System health warnings
    final warnings = systemHealth['warnings'] as List;
    if (warnings.isNotEmpty) {
      debugPrint('\n⚠️ WARNINGS:');
      for (String warning in warnings) {
        debugPrint('  - $warning');
      }
    }
    
    // System health errors
    final errors = systemHealth['errors'] as List;
    if (errors.isNotEmpty) {
      debugPrint('\n🚨 ERRORS:');
      for (String error in errors) {
        debugPrint('  - $error');
      }
    }
    
    debugPrint('=' * 50);
  }
}
