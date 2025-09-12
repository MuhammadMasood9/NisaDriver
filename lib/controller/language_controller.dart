import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/language_model.dart';
import '../services/localization_service.dart';

class LanguageController extends GetxController {
  static const String _languageKey = 'selected_language';
  static const String _firstLaunchKey = 'first_launch_language_set';
  
  // Observable current language
  final Rx<SupportedLanguageModel> _currentLanguage = SupportedLanguageModel.defaultLanguage.obs;
  
  // Observable loading state for language switching
  final RxBool _isChangingLanguage = false.obs;
  
  // Observable for language initialization status
  final RxBool _isLanguageInitialized = false.obs;
  
  // Cache for SharedPreferences instance
  SharedPreferences? _prefs;
  
  // Performance tracking
  final Stopwatch _switchingStopwatch = Stopwatch();
  
  // Getters
  SupportedLanguageModel get currentLanguage => _currentLanguage.value;
  bool get isChangingLanguage => _isChangingLanguage.value;
  bool get isLanguageInitialized => _isLanguageInitialized.value;
  String get currentLanguageCode => _currentLanguage.value.code;
  bool get isCurrentLanguageRTL => _currentLanguage.value.isRTL;
  
  @override
  void onInit() {
    super.onInit();
    _initializeSharedPreferences();
  }

  /// Initialize SharedPreferences for better performance
  Future<void> _initializeSharedPreferences() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing SharedPreferences: $e');
      }
    }
  }

  /// Initialize language from saved preference with performance optimization
  Future<void> initializeLanguage() async {
    try {
      if (_isLanguageInitialized.value) return;
      
      final stopwatch = Stopwatch()..start();
      
      // Ensure SharedPreferences is initialized
      await _initializeSharedPreferences();
      
      // Load saved language preference
      final savedLanguageCode = await _loadLanguagePreference();
      
      // Validate and set language
      final language = SupportedLanguageModel.getLanguageByCode(savedLanguageCode);
      if (language != null) {
        _currentLanguage.value = language;
        
        // Apply language to GetX without triggering full rebuild
        if (Get.locale?.languageCode != savedLanguageCode) {
          await _applyLanguageChange(savedLanguageCode, skipSave: true);
        }
      }
      
      _isLanguageInitialized.value = true;
      
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('Language initialization completed in ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing language: $e');
      }
      _isLanguageInitialized.value = true; // Set to true to prevent blocking
    }
  }

  /// Change app language with performance optimization
  Future<bool> changeLanguage(String languageCode) async {
    try {
      // Validate language code
      final language = SupportedLanguageModel.getLanguageByCode(languageCode);
      if (language == null) {
        if (kDebugMode) {
          debugPrint('Invalid language code: $languageCode');
        }
        return false;
      }

      // Skip if already current language
      if (_currentLanguage.value.code == languageCode) {
        return true;
      }

      // Start performance tracking
      _switchingStopwatch.reset();
      _switchingStopwatch.start();
      _isChangingLanguage.value = true;

      // Update current language immediately for UI responsiveness
      _currentLanguage.value = language;

      // Apply language change
      final success = await _applyLanguageChange(languageCode);
      
      _switchingStopwatch.stop();
      _isChangingLanguage.value = false;

      if (success) {
        final elapsedMs = _switchingStopwatch.elapsedMilliseconds;
        if (kDebugMode) {
          debugPrint('Language changed to ${language.name} in ${elapsedMs}ms');
          
          // Log performance warning if exceeds 2 seconds
          if (elapsedMs > 2000) {
            debugPrint('⚠️ Language switching took ${elapsedMs}ms (exceeds 2s requirement)');
          }
        }
        
        // Trigger UI updates
        update();
        
        return true;
      } else {
        // Revert on failure
        final previousLanguage = SupportedLanguageModel.getLanguageByCode(Get.locale?.languageCode ?? 'en');
        if (previousLanguage != null) {
          _currentLanguage.value = previousLanguage;
        }
        return false;
      }
    } catch (e) {
      _isChangingLanguage.value = false;
      if (kDebugMode) {
        debugPrint('Error changing language: $e');
      }
      return false;
    }
  }

  /// Apply language change with optimized performance
  Future<bool> _applyLanguageChange(String languageCode, {bool skipSave = false}) async {
    try {
      // Create locale
      final locale = Locale(languageCode);
      
      // Update GetX locale efficiently
      await Get.updateLocale(locale);
      
      // Save preference if not skipping
      if (!skipSave) {
        await _saveLanguagePreference(languageCode);
      }
      
      // Force rebuild of specific widgets that need immediate update
      _forceRebuildCriticalWidgets();
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error applying language change: $e');
      }
      return false;
    }
  }

  /// Force rebuild of critical widgets for immediate language update
  void _forceRebuildCriticalWidgets() {
    // Force update of GetX controllers that handle UI text
    try {
      // Update any existing controllers that might cache translated text
      Get.find<LanguageController>().update();
    } catch (e) {
      // Controller might not be registered yet, which is fine
    }
  }

  /// Save language preference with caching
  Future<void> _saveLanguagePreference(String languageCode) async {
    try {
      await _initializeSharedPreferences();
      await _prefs?.setString(_languageKey, languageCode);
      
      // Mark that language has been set by user
      await _prefs?.setBool(_firstLaunchKey, true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving language preference: $e');
      }
    }
  }

  /// Load language preference with caching
  Future<String> _loadLanguagePreference() async {
    try {
      await _initializeSharedPreferences();
      return _prefs?.getString(_languageKey) ?? 'en';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading language preference: $e');
      }
      return 'en';
    }
  }

  /// Check if this is the first app launch (for language selection)
  Future<bool> isFirstLaunch() async {
    try {
      await _initializeSharedPreferences();
      return !(_prefs?.getBool(_firstLaunchKey) ?? false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking first launch: $e');
      }
      return false;
    }
  }

  /// Get text direction for current language
  TextDirection getTextDirection() {
    return _currentLanguage.value.isRTL ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Get text alignment for current language
  TextAlign getTextAlign() {
    return _currentLanguage.value.isRTL ? TextAlign.right : TextAlign.left;
  }

  /// Get main axis alignment for current language
  MainAxisAlignment getMainAxisAlignment() {
    return _currentLanguage.value.isRTL ? MainAxisAlignment.end : MainAxisAlignment.start;
  }

  /// Get cross axis alignment for current language
  CrossAxisAlignment getCrossAxisAlignment() {
    return _currentLanguage.value.isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start;
  }

  /// Get supported languages filtered for primary languages only
  List<SupportedLanguageModel> getPrimaryLanguages() {
    return SupportedLanguageModel.supportedLanguages
        .where((lang) => LocalizationService.primaryLanguages.contains(lang.code))
        .toList();
  }

  /// Get all supported languages
  List<SupportedLanguageModel> getAllSupportedLanguages() {
    return SupportedLanguageModel.supportedLanguages;
  }

  /// Check if language switching is available
  bool isLanguageSwitchingAvailable() {
    return getPrimaryLanguages().length > 1;
  }

  /// Get language switching performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'last_switch_duration_ms': _switchingStopwatch.elapsedMilliseconds,
      'is_within_requirement': _switchingStopwatch.elapsedMilliseconds <= 2000,
      'current_language': _currentLanguage.value.code,
      'is_rtl': _currentLanguage.value.isRTL,
      'is_initialized': _isLanguageInitialized.value,
    };
  }

  /// Preload translations for better performance
  Future<void> preloadTranslations() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Access translation keys to trigger loading
      for (String langCode in LocalizationService.primaryLanguages) {
        final locale = Locale(langCode);
        final tempLocale = Get.locale;
        
        // Temporarily switch to load translations
        Get.updateLocale(locale);
        
        // Access some common keys to trigger loading
        'app_name'.tr;
        'loading'.tr;
        'error'.tr;
        'success'.tr;
        
        // Restore original locale
        if (tempLocale != null) {
          Get.updateLocale(tempLocale);
        }
      }
      
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('Translations preloaded in ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error preloading translations: $e');
      }
    }
  }

  /// Reset language to default
  Future<bool> resetToDefaultLanguage() async {
    return await changeLanguage(SupportedLanguageModel.defaultLanguage.code);
  }

  /// Clear language preferences (for testing/debugging)
  Future<void> clearLanguagePreferences() async {
    try {
      await _initializeSharedPreferences();
      await _prefs?.remove(_languageKey);
      await _prefs?.remove(_firstLaunchKey);
      _isLanguageInitialized.value = false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing language preferences: $e');
      }
    }
  }

  @override
  void onClose() {
    _switchingStopwatch.stop();
    super.onClose();
  }
}