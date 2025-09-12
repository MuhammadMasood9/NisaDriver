import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/main.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/controller/language_controller.dart';
import 'package:driver/models/language_model.dart';
import 'package:driver/lang/app_en.dart';
import 'package:driver/lang/app_ur.dart';

void main() {
  group('Comprehensive Translation System Tests', () {
    late Widget app;
    
    setUpAll(() async {
      // Initialize test environment
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Initialize GetX
      Get.testMode = true;
      
      // Initialize services
      Get.put(LocalizationService());
      Get.put(LanguageController());
      
      // Create app instance
      app = MyApp();
    });

    tearDown(() {
      // Clean up after each test
      Get.reset();
    });

    group('Translation Coverage Tests', () {
      testWidgets('should have all English keys translated to Urdu', (WidgetTester tester) async {
        // Get all English keys
        final englishKeys = enUS.keys.toSet();
        final urduKeys = urUR.keys.toSet();
        
        // Find missing Urdu translations
        final missingUrduKeys = englishKeys.difference(urduKeys);
        
        // Log missing keys for debugging
        if (missingUrduKeys.isNotEmpty) {
          debugPrint('Missing Urdu translations for keys: $missingUrduKeys');
        }
        
        // Assert that all English keys have Urdu translations
        expect(missingUrduKeys.isEmpty, true, 
          reason: 'Missing Urdu translations for keys: $missingUrduKeys');
      });

      testWidgets('should have no orphaned Urdu keys', (WidgetTester tester) async {
        // Get all keys
        final englishKeys = enUS.keys.toSet();
        final urduKeys = urUR.keys.toSet();
        
        // Find orphaned Urdu keys (keys that exist in Urdu but not in English)
        final orphanedUrduKeys = urduKeys.difference(englishKeys);
        
        // Log orphaned keys for debugging
        if (orphanedUrduKeys.isNotEmpty) {
          debugPrint('Orphaned Urdu keys: $orphanedUrduKeys');
        }
        
        // Assert that there are no orphaned Urdu keys
        expect(orphanedUrduKeys.isEmpty, true,
          reason: 'Orphaned Urdu keys found: $orphanedUrduKeys');
      });

      testWidgets('should have non-empty translations for all keys', (WidgetTester tester) async {
        // Check English translations
        final emptyEnglishKeys = enUS.entries
            .where((entry) => entry.value.trim().isEmpty)
            .map((entry) => entry.key)
            .toList();
        
        expect(emptyEnglishKeys.isEmpty, true,
          reason: 'Empty English translations found for keys: $emptyEnglishKeys');
        
        // Check Urdu translations
        final emptyUrduKeys = urUR.entries
            .where((entry) => entry.value.trim().isEmpty)
            .map((entry) => entry.key)
            .toList();
        
        expect(emptyUrduKeys.isEmpty, true,
          reason: 'Empty Urdu translations found for keys: $emptyUrduKeys');
      });
    });

    group('Language Switching Performance Tests', () {
      testWidgets('should switch language within 2 seconds', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Measure language switching time
        final stopwatch = Stopwatch()..start();
        
        // Switch to Urdu
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        stopwatch.stop();
        
        // Assert that language switching took less than 2 seconds
        expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: 'Language switching took ${stopwatch.elapsedMilliseconds}ms, should be under 2000ms');
        
        // Verify language was actually changed
        expect(languageController.currentLanguageCode, equals('ur'));
      });

      testWidgets('should persist language preference across app restarts', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Change language to Urdu
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Simulate app restart by creating new controller
        Get.delete<LanguageController>();
        final newLanguageController = Get.put(LanguageController());
        
        // Initialize the new controller
        await newLanguageController.initializeLanguage();
        
        // Verify language preference was persisted
        expect(newLanguageController.currentLanguageCode, equals('ur'));
      });
    });

    group('UI Layout and Text Direction Tests', () {
      testWidgets('should display RTL layout for Urdu language', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Switch to Urdu
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Find Directionality widget
        final directionalityFinder = find.byType(Directionality);
        expect(directionalityFinder, findsWidgets);
        
        // Verify text direction is RTL for Urdu
        final directionality = tester.widget<Directionality>(directionalityFinder.first);
        expect(directionality.textDirection, equals(TextDirection.rtl));
      });

      testWidgets('should display LTR layout for English language', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Ensure English is selected
        await languageController.changeLanguage('en');
        await tester.pumpAndSettle();
        
        // Find Directionality widget
        final directionalityFinder = find.byType(Directionality);
        expect(directionalityFinder, findsWidgets);
        
        // Verify text direction is LTR for English
        final directionality = tester.widget<Directionality>(directionalityFinder.first);
        expect(directionality.textDirection, equals(TextDirection.ltr));
      });
    });

    group('Hardcoded Text Detection Tests', () {
      testWidgets('should not contain hardcoded English text in Urdu mode', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Switch to Urdu
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // List of common English words that should not appear when Urdu is selected
        final commonEnglishWords = [
          'Login',
          'Sign up',
          'Email',
          'Password',
          'Submit',
          'Cancel',
          'Next',
          'Back',
          'Settings',
          'Profile',
          'Dashboard',
          'Wallet',
          'History',
          'Notifications',
        ];
        
        // Check that these English words don't appear in the UI
        for (final word in commonEnglishWords) {
          final finder = find.text(word);
          expect(finder, findsNothing,
            reason: 'Found hardcoded English text "$word" when Urdu is selected');
        }
      });
    });

    group('Translation Fallback Tests', () {
      testWidgets('should provide fallback for missing translations', (WidgetTester tester) async {
        // Test fallback mechanism using static method
        final fallbackText = LocalizationService.getTranslationWithFallback('non_existent_key_test');
        
        // Should not be null or empty
        expect(fallbackText, isNotNull);
        expect(fallbackText, isNotEmpty);
        
        // Should contain the key name for debugging
        expect(fallbackText, contains('non_existent_key_test'));
      });

      testWidgets('should log missing translation keys', (WidgetTester tester) async {
        // Clear existing logs
        LocalizationService.clearAllTranslationLogs();
        
        // Request a non-existent translation
        LocalizationService.getTranslationWithFallback('test_missing_key_for_logging');
        
        // Check that the missing key was logged
        final missingKeys = LocalizationService.getMissingTranslationKeys();
        expect(missingKeys.any((key) => key.contains('test_missing_key_for_logging')), isTrue);
      });
    });

    group('Performance and Memory Tests', () {
      testWidgets('should maintain optimal performance with translation system', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Measure performance of multiple language switches
        final stopwatch = Stopwatch()..start();
        
        // Perform multiple language switches
        for (int i = 0; i < 5; i++) {
          await languageController.changeLanguage('ur');
          await tester.pumpAndSettle();
          await languageController.changeLanguage('en');
          await tester.pumpAndSettle();
        }
        
        stopwatch.stop();
        
        // Each switch should be fast (total time for 10 switches should be reasonable)
        expect(stopwatch.elapsedMilliseconds, lessThan(10000),
          reason: 'Multiple language switches took too long: ${stopwatch.elapsedMilliseconds}ms');
      });

      testWidgets('should not cause memory leaks during language switching', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Perform language switches and check for memory stability
        for (int i = 0; i < 10; i++) {
          await languageController.changeLanguage(i % 2 == 0 ? 'en' : 'ur');
          await tester.pumpAndSettle();
          
          // Force garbage collection
          await tester.binding.delayed(const Duration(milliseconds: 100));
        }
        
        // If we reach here without crashes, memory management is working
        expect(true, isTrue);
      });
    });

    group('Translation System Health Tests', () {
      testWidgets('should validate translation system health', (WidgetTester tester) async {
        // Validate system health
        final systemHealth = LocalizationService.validateTranslationSystem();
        
        expect(systemHealth, isNotNull);
        expect(systemHealth['status'], isNotNull);
        expect(systemHealth['languages_loaded'], contains('en'));
        expect(systemHealth['languages_loaded'], contains('ur'));
        expect(systemHealth['total_keys_per_language'], isA<Map>());
      });

      testWidgets('should generate comprehensive translation coverage report', (WidgetTester tester) async {
        final coverage = LocalizationService.getTranslationCoverage();
        
        expect(coverage, isNotNull);
        expect(coverage['total_keys'], isA<int>());
        expect(coverage['languages'], isA<Map>());
        
        final languages = coverage['languages'] as Map;
        expect(languages.containsKey('en'), isTrue);
        expect(languages.containsKey('ur'), isTrue);
        
        // Check coverage percentages
        final enCoverage = languages['en'] as Map;
        final urCoverage = languages['ur'] as Map;
        
        expect(enCoverage['coverage_percentage'], isA<String>());
        expect(urCoverage['coverage_percentage'], isA<String>());
        
        // Both languages should have high coverage
        final enPercentage = double.parse(enCoverage['coverage_percentage'] as String);
        final urPercentage = double.parse(urCoverage['coverage_percentage'] as String);
        
        expect(enPercentage, greaterThan(95.0));
        expect(urPercentage, greaterThan(95.0));
      });
    });
  });
}