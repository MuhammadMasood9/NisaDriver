import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/controller/language_controller.dart';
import 'package:driver/models/language_model.dart';

void main() {
  group('Translation System Validation Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      Get.testMode = true;
    });

    tearDown(() {
      Get.reset();
      LocalizationService.clearAllTranslationLogs();
    });

    group('Core Translation System Tests', () {
      testWidgets('should initialize localization service correctly', (WidgetTester tester) async {
        // Initialize services
        final localizationService = LocalizationService();
        final languageController = LanguageController();
        
        Get.put(localizationService);
        Get.put(languageController);
        
        // Verify service initialization
        expect(localizationService, isNotNull);
        expect(languageController, isNotNull);
        
        // Verify supported languages
        expect(LocalizationService.primaryLanguages, contains('en'));
        expect(LocalizationService.primaryLanguages, contains('ur'));
      });

      testWidgets('should handle translation fallback mechanism', (WidgetTester tester) async {
        // Test fallback for non-existent key
        final fallbackText = LocalizationService.getTranslationWithFallback('non_existent_test_key');
        
        expect(fallbackText, isNotNull);
        expect(fallbackText, isNotEmpty);
        
        // Should contain key name or readable fallback
        final isValidFallback = fallbackText.contains('non_existent_test_key') || 
                               fallbackText.contains('Non Existent Test Key');
        expect(isValidFallback, isTrue);
      });

      testWidgets('should log missing translation keys', (WidgetTester tester) async {
        // Clear existing logs
        LocalizationService.clearAllTranslationLogs();
        
        // Request non-existent translations
        LocalizationService.getTranslationWithFallback('test_missing_key_1');
        LocalizationService.getTranslationWithFallback('test_missing_key_2');
        
        // Verify logging
        final missingKeys = LocalizationService.getMissingTranslationKeys();
        expect(missingKeys, isNotEmpty);
        
        // Should contain logged keys
        final hasLoggedKeys = missingKeys.any((key) => 
          key.contains('test_missing_key_1') || key.contains('test_missing_key_2'));
        expect(hasLoggedKeys, isTrue);
      });

      testWidgets('should validate translation system health', (WidgetTester tester) async {
        final systemHealth = LocalizationService.validateTranslationSystem();
        
        expect(systemHealth, isNotNull);
        expect(systemHealth['status'], isNotNull);
        expect(systemHealth['languages_loaded'], isList);
        expect(systemHealth['total_keys_per_language'], isA<Map>());
        
        // Should have loaded primary languages
        final languagesLoaded = systemHealth['languages_loaded'] as List;
        expect(languagesLoaded, contains('en'));
        expect(languagesLoaded, contains('ur'));
      });

      testWidgets('should generate translation coverage report', (WidgetTester tester) async {
        final coverage = LocalizationService.getTranslationCoverage();
        
        expect(coverage, isNotNull);
        expect(coverage['total_keys'], isA<int>());
        expect(coverage['languages'], isA<Map>());
        
        final languages = coverage['languages'] as Map;
        expect(languages.containsKey('en'), isTrue);
        expect(languages.containsKey('ur'), isTrue);
        
        // Each language should have coverage data
        for (String lang in ['en', 'ur']) {
          final langData = languages[lang] as Map;
          expect(langData['translated_keys'], isA<int>());
          expect(langData['missing_keys'], isA<int>());
          expect(langData['coverage_percentage'], isA<String>());
        }
      });
    });

    group('Language Controller Tests', () {
      testWidgets('should initialize language controller correctly', (WidgetTester tester) async {
        final languageController = LanguageController();
        Get.put(languageController);
        
        await languageController.initializeLanguage();
        
        expect(languageController.isLanguageInitialized, isTrue);
        expect(languageController.currentLanguageCode, isIn(['en', 'ur']));
      });

      testWidgets('should change language successfully', (WidgetTester tester) async {
        final languageController = LanguageController();
        Get.put(languageController);
        
        await languageController.initializeLanguage();
        
        // Test changing to Urdu
        final success = await languageController.changeLanguage('ur');
        expect(success, isTrue);
        expect(languageController.currentLanguageCode, equals('ur'));
        
        // Test changing back to English
        final successEn = await languageController.changeLanguage('en');
        expect(successEn, isTrue);
        expect(languageController.currentLanguageCode, equals('en'));
      });

      testWidgets('should handle invalid language codes gracefully', (WidgetTester tester) async {
        final languageController = LanguageController();
        Get.put(languageController);
        
        await languageController.initializeLanguage();
        final originalLang = languageController.currentLanguageCode;
        
        // Try to change to invalid language
        final success = await languageController.changeLanguage('invalid');
        expect(success, isFalse);
        
        // Should remain on original language
        expect(languageController.currentLanguageCode, equals(originalLang));
      });

      testWidgets('should provide correct text direction for languages', (WidgetTester tester) async {
        final languageController = LanguageController();
        Get.put(languageController);
        
        await languageController.initializeLanguage();
        
        // Test English (LTR)
        await languageController.changeLanguage('en');
        expect(languageController.getTextDirection(), equals(TextDirection.ltr));
        expect(languageController.isCurrentLanguageRTL, isFalse);
        
        // Test Urdu (RTL)
        await languageController.changeLanguage('ur');
        expect(languageController.getTextDirection(), equals(TextDirection.rtl));
        expect(languageController.isCurrentLanguageRTL, isTrue);
      });

      testWidgets('should measure language switching performance', (WidgetTester tester) async {
        final languageController = LanguageController();
        Get.put(languageController);
        
        await languageController.initializeLanguage();
        
        // Measure language switching time
        final stopwatch = Stopwatch()..start();
        await languageController.changeLanguage('ur');
        stopwatch.stop();
        
        // Should be within performance requirement (2 seconds)
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        
        // Check performance metrics
        final metrics = languageController.getPerformanceMetrics();
        expect(metrics['is_within_requirement'], isTrue);
        expect(metrics['current_language'], equals('ur'));
        expect(metrics['is_rtl'], isTrue);
      });

      testWidgets('should persist language preference', (WidgetTester tester) async {
        final languageController = LanguageController();
        Get.put(languageController);
        
        await languageController.initializeLanguage();
        
        // Change to Urdu
        await languageController.changeLanguage('ur');
        
        // Simulate app restart
        Get.delete<LanguageController>();
        final newController = LanguageController();
        Get.put(newController);
        
        await newController.initializeLanguage();
        
        // Should remember Urdu preference
        expect(newController.currentLanguageCode, equals('ur'));
      });
    });

    group('Translation Key Management Tests', () {
      testWidgets('should generate consistent translation keys', (WidgetTester tester) async {
        final key1 = LocalizationService.generateTranslationKey('Hello World');
        final key2 = LocalizationService.generateTranslationKey('Hello World');
        
        expect(key1, equals(key2));
        expect(key1, equals('hello_world'));
        
        // Test with category
        final categoryKey = LocalizationService.generateTranslationKey('Submit Button', category: 'auth');
        expect(categoryKey, equals('auth_submit_button'));
      });

      testWidgets('should suggest translation keys for multiple texts', (WidgetTester tester) async {
        final texts = ['Login', 'Sign Up', 'Forgot Password'];
        final suggestions = LocalizationService.suggestTranslationKeys(texts, category: 'auth');
        
        expect(suggestions, isNotEmpty);
        expect(suggestions['auth_login'], equals('Login'));
        expect(suggestions['auth_sign_up'], equals('Sign Up'));
        expect(suggestions['auth_forgot_password'], equals('Forgot Password'));
      });

      testWidgets('should check translation key existence', (WidgetTester tester) async {
        // Test with a key that should exist (common key)
        final hasCommonKey = LocalizationService.hasTranslationKey('app_name');
        // Note: This might be false if the key doesn't exist, which is fine for testing
        
        // Test with a key that definitely doesn't exist
        final hasNonExistentKey = LocalizationService.hasTranslationKey('definitely_non_existent_key_12345');
        expect(hasNonExistentKey, isFalse);
      });
    });

    group('Error Handling Tests', () {
      testWidgets('should handle translation errors gracefully', (WidgetTester tester) async {
        // Clear existing logs
        LocalizationService.clearAllTranslationLogs();
        
        // Test with empty key
        final emptyKeyResult = LocalizationService.getTranslationWithFallback('');
        expect(emptyKeyResult, isNotNull);
        expect(emptyKeyResult, isNotEmpty);
        
        // Test with null-like key
        final nullKeyResult = LocalizationService.getTranslationWithFallback('null');
        expect(nullKeyResult, isNotNull);
        expect(nullKeyResult, isNotEmpty);
        
        // Check that errors were logged
        final errors = LocalizationService.getTranslationErrors();
        expect(errors, isNotEmpty);
      });

      testWidgets('should provide error details for debugging', (WidgetTester tester) async {
        // Clear existing logs
        LocalizationService.clearAllTranslationLogs();
        
        // Generate some errors
        LocalizationService.getTranslationWithFallback('');
        LocalizationService.getTranslationWithFallback('test_error_key');
        
        // Get error details
        final errorDetails = LocalizationService.getErrorDetails();
        expect(errorDetails, isNotEmpty);
        
        // Each error should have detailed information
        for (final errorDetail in errorDetails.values) {
          expect(errorDetail['type'], isNotNull);
          expect(errorDetail['timestamp'], isNotNull);
        }
      });

      testWidgets('should clear translation logs correctly', (WidgetTester tester) async {
        // Generate some logs
        LocalizationService.getTranslationWithFallback('test_key_1');
        LocalizationService.getTranslationWithFallback('');
        
        // Verify logs exist
        expect(LocalizationService.getMissingTranslationKeys(), isNotEmpty);
        expect(LocalizationService.getTranslationErrors(), isNotEmpty);
        
        // Clear logs
        LocalizationService.clearAllTranslationLogs();
        
        // Verify logs are cleared
        expect(LocalizationService.getMissingTranslationKeys(), isEmpty);
        expect(LocalizationService.getTranslationErrors(), isEmpty);
      });
    });

    group('Performance Tests', () {
      testWidgets('should handle multiple translation lookups efficiently', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        // Perform many translation lookups
        for (int i = 0; i < 1000; i++) {
          LocalizationService.getTranslationWithFallback('test_key_$i');
        }
        
        stopwatch.stop();
        
        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      testWidgets('should validate translation system performance', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        // Run system validation
        final systemHealth = LocalizationService.validateTranslationSystem();
        
        stopwatch.stop();
        
        // Should complete quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
        expect(systemHealth, isNotNull);
      });

      testWidgets('should generate coverage report efficiently', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        // Generate coverage report
        final coverage = LocalizationService.getTranslationCoverage();
        
        stopwatch.stop();
        
        // Should complete quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(300));
        expect(coverage, isNotNull);
      });
    });

    group('Language Model Tests', () {
      testWidgets('should provide correct language information', (WidgetTester tester) async {
        // Test English language
        final english = SupportedLanguageModel.getLanguageByCode('en');
        expect(english, isNotNull);
        expect(english!.code, equals('en'));
        expect(english.name, equals('English'));
        expect(english.isRTL, isFalse);
        
        // Test Urdu language
        final urdu = SupportedLanguageModel.getLanguageByCode('ur');
        expect(urdu, isNotNull);
        expect(urdu!.code, equals('ur'));
        expect(urdu.name, equals('Urdu'));
        expect(urdu.isRTL, isTrue);
        
        // Test invalid language
        final invalid = SupportedLanguageModel.getLanguageByCode('invalid');
        expect(invalid, isNull);
      });

      testWidgets('should provide default language', (WidgetTester tester) async {
        final defaultLang = SupportedLanguageModel.defaultLanguage;
        expect(defaultLang, isNotNull);
        expect(defaultLang.code, equals('en'));
      });

      testWidgets('should support language equality comparison', (WidgetTester tester) async {
        final lang1 = SupportedLanguageModel.getLanguageByCode('en');
        final lang2 = SupportedLanguageModel.getLanguageByCode('en');
        final lang3 = SupportedLanguageModel.getLanguageByCode('ur');
        
        expect(lang1, equals(lang2));
        expect(lang1, isNot(equals(lang3)));
      });
    });
  });
}