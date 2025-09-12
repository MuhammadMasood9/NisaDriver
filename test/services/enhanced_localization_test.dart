import 'package:flutter_test/flutter_test.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/services/translation_validator.dart';
import 'package:driver/services/translation_manager.dart';
import 'package:driver/utils/translation_extensions.dart';

void main() {
  group('Enhanced Localization Service Tests', () {
    test('should generate valid translation keys', () {
      // Test translation key generation
      final key1 = LocalizationService.generateTranslationKey('Hello World');
      expect(key1, equals('hello_world'));
      
      final key2 = LocalizationService.generateTranslationKey('Sign Up Now!', category: 'auth');
      expect(key2, equals('auth_sign_up_now'));
      
      final key3 = LocalizationService.generateTranslationKey('123 Test');
      expect(key3, equals('key_123_test'));
    });

    test('should validate translation key format', () {
      expect(TranslationManager.isValidTranslationKey('hello_world'), isTrue);
      expect(TranslationManager.isValidTranslationKey('auth_login'), isTrue);
      expect(TranslationManager.isValidTranslationKey('Hello_World'), isFalse); // uppercase
      expect(TranslationManager.isValidTranslationKey('hello__world'), isFalse); // double underscore
      expect(TranslationManager.isValidTranslationKey('_hello'), isFalse); // starts with underscore
      expect(TranslationManager.isValidTranslationKey('hello_'), isFalse); // ends with underscore
      expect(TranslationManager.isValidTranslationKey('1hello'), isFalse); // starts with number
    });

    test('should provide fallback translations', () {
      // Test fallback mechanism
      final existingKey = LocalizationService.getTranslationWithFallback('Login');
      expect(existingKey, isNotEmpty);
      
      final nonExistentKey = LocalizationService.getTranslationWithFallback('non_existent_key_12345');
      expect(nonExistentKey, contains('non_existent_key_12345'));
    });

    test('should check translation key existence', () {
      expect(LocalizationService.hasTranslationKey('Login'), isTrue);
      expect(LocalizationService.hasTranslationKey('non_existent_key_12345'), isFalse);
    });

    test('should generate translation coverage report', () {
      final coverage = LocalizationService.getTranslationCoverage();
      expect(coverage, isA<Map<String, dynamic>>());
      expect(coverage['total_keys'], isA<int>());
      expect(coverage['languages'], isA<Map<String, Map<String, dynamic>>>());
      
      // Check that primary languages are included
      final languages = coverage['languages'] as Map<String, Map<String, dynamic>>;
      expect(languages.containsKey('en'), isTrue);
      expect(languages.containsKey('ur'), isTrue);
    });

    test('should validate translations', () {
      final issues = TranslationValidator.validateAllTranslations();
      expect(issues, isA<List<ValidationIssue>>());
      
      final summary = TranslationValidator.getValidationSummary();
      expect(summary, isA<Map<String, dynamic>>());
      expect(summary['total_issues'], isA<int>());
      expect(summary['is_valid'], isA<bool>());
    });

    test('should generate key suggestions', () {
      final hardcodedStrings = ['Hello World', 'Sign Up', 'Welcome Back'];
      final suggestions = TranslationManager.generateKeySuggestions(
        hardcodedStrings,
        category: 'test',
      );
      
      expect(suggestions, isA<Map<String, Map<String, String>>>());
      expect(suggestions.length, equals(3));
      expect(suggestions.containsKey('test_hello_world'), isTrue);
      expect(suggestions.containsKey('test_sign_up'), isTrue);
      expect(suggestions.containsKey('test_welcome_back'), isTrue);
    });

    test('should provide translation statistics', () {
      final stats = TranslationManager.getTranslationStatistics();
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats['en_key_count'], isA<int>());
      expect(stats['ur_key_count'], isA<int>());
    });
  });

  group('Translation Extensions Tests', () {
    test('should provide enhanced translation methods', () {
      const testKey = 'Login';
      
      // Test fallback translation
      final translation = testKey.trWithFallback;
      expect(translation, isNotEmpty);
      
      // Test translation key existence
      expect(testKey.hasTranslation, isTrue);
      expect('non_existent_key'.hasTranslation, isFalse);
      
      // Test key generation
      const text = 'Hello World';
      final key = text.toTranslationKey(category: 'test');
      expect(key, equals('test_hello_world'));
    });

    test('should provide translation utilities', () {
      final translation = TranslationUtils.translate('Login');
      expect(translation, isNotEmpty);
      
      final batchTranslations = TranslationUtils.translateBatch(['Login', 'Sign up']);
      expect(batchTranslations, isA<Map<String, String>>());
      expect(batchTranslations.length, equals(2));
      
      final missingTranslations = TranslationUtils.getMissingTranslations();
      expect(missingTranslations, isA<Map<String, List<String>>>());
    });
  });
}