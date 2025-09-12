import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/services/translation_validator.dart';
import 'package:driver/services/translation_manager.dart';

void main() {
  group('Translation Error Handling Tests', () {
    setUp(() {
      // Initialize GetX for testing
      Get.testMode = true;
      
      // Clear any existing logs
      LocalizationService.clearAllTranslationLogs();
    });

    tearDown(() {
      // Clean up after each test
      LocalizationService.clearAllTranslationLogs();
    });

    test('should handle missing translation keys gracefully', () {
      // Test missing translation key
      final result = LocalizationService.getTranslationWithFallback('non_existent_key');
      
      // Should return fallback text, not throw error
      expect(result, isNotNull);
      expect(result, isNotEmpty);
      
      // Should log the missing key
      final missingKeys = LocalizationService.getMissingTranslationKeys();
      expect(missingKeys, isNotEmpty);
    });

    test('should handle empty translation keys', () {
      // Test empty key
      final result = LocalizationService.getTranslationWithFallback('');
      
      // Should return fallback text for empty key
      expect(result, isNotNull);
      expect(result, isNotEmpty);
      
      // Should log the error
      final errors = LocalizationService.getTranslationErrors();
      expect(errors, isNotEmpty);
    });

    test('should validate translation system health', () {
      // Test system validation
      final systemHealth = LocalizationService.validateTranslationSystem();
      
      expect(systemHealth, isNotNull);
      expect(systemHealth['status'], isNotNull);
      expect(systemHealth['languages_loaded'], isList);
      expect(systemHealth['total_keys_per_language'], isMap);
    });

    test('should generate comprehensive validation report', () {
      // Generate some test data by calling missing translations
      LocalizationService.getTranslationWithFallback('test_missing_key_1');
      LocalizationService.getTranslationWithFallback('test_missing_key_2');
      
      // Test validation
      final issues = TranslationValidator.validateAllTranslations();
      expect(issues, isList);
      
      // Test validation summary
      final summary = TranslationValidator.getValidationSummary();
      expect(summary['total_issues'], isA<int>());
      expect(summary['is_valid'], isA<bool>());
    });

    test('should generate comprehensive translation report', () {
      // Generate some test data
      LocalizationService.getTranslationWithFallback('test_key_for_report');
      
      // Test analysis
      final analysis = TranslationManager.analyzeTranslationCoverage();
      
      expect(analysis['coverage'], isNotNull);
      expect(analysis['validation'], isNotNull);
      expect(analysis['system_health'], isNotNull);
      expect(analysis['timestamp'], isNotNull);
      
      // Test report generation
      final report = TranslationManager.generateTranslationReport();
      expect(report, isNotNull);
      expect(report, contains('Translation Report'));
    });

    test('should clear translation logs properly', () {
      // Generate some test data
      LocalizationService.getTranslationWithFallback('test_clear_key');
      
      // Verify data exists
      expect(LocalizationService.getMissingTranslationKeys(), isNotEmpty);
      
      // Clear logs
      LocalizationService.clearAllTranslationLogs();
      
      // Verify data is cleared
      expect(LocalizationService.getMissingTranslationKeys(), isEmpty);
      expect(LocalizationService.getTranslationErrors(), isEmpty);
    });

    test('should handle translation key validation', () {
      // Test valid keys
      expect(TranslationManager.isValidTranslationKey('valid_key'), isTrue);
      expect(TranslationManager.isValidTranslationKey('another_valid_key_123'), isTrue);
      
      // Test invalid keys
      expect(TranslationManager.isValidTranslationKey(''), isFalse);
      expect(TranslationManager.isValidTranslationKey('Invalid-Key'), isFalse);
      expect(TranslationManager.isValidTranslationKey('_invalid'), isFalse);
      expect(TranslationManager.isValidTranslationKey('invalid_'), isFalse);
      expect(TranslationManager.isValidTranslationKey('123invalid'), isFalse);
      
      // Test suggestions
      final suggestions = TranslationManager.suggestKeyImprovements('Invalid-Key');
      expect(suggestions, isNotEmpty);
    });

    test('should export translation data for debugging', () {
      final exportData = TranslationManager.exportTranslationData();
      
      if (kDebugMode) {
        expect(exportData, isNotEmpty);
        expect(exportData['metadata'], isNotNull);
        expect(exportData['translations'], isNotNull);
        expect(exportData['analysis'], isNotNull);
      } else {
        expect(exportData, isEmpty);
      }
    });
  });
}