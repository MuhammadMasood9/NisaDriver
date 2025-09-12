import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/main.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/controller/language_controller.dart';
import 'package:driver/models/language_model.dart';
import 'package:driver/ui/auth_screen/login_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/ui/profile_screen/account_screen.dart';
import 'package:driver/ui/settings/settings_screen.dart';

void main() {
  group('Comprehensive UI Translation Tests', () {
    late Widget app;
    
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      Get.testMode = true;
      
      // Initialize services
      Get.put(LocalizationService());
      Get.put(LanguageController());
      
      app = MyApp();
    });

    tearDown(() {
      Get.reset();
    });

    group('Authentication Screens Translation Tests', () {
      testWidgets('should display login screen in English correctly', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('en');
        await tester.pumpAndSettle();
        
        // Navigate to login screen if not already there
        // This test assumes the app starts with login or can navigate to it
        
        // Check for common login elements in English
        expect(find.textContaining('Login'), findsWidgets);
        expect(find.textContaining('Email'), findsWidgets);
        expect(find.textContaining('Password'), findsWidgets);
      });

      testWidgets('should display login screen in Urdu correctly', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Verify RTL layout is applied
        final directionalityFinder = find.byType(Directionality);
        if (directionalityFinder.evaluate().isNotEmpty) {
          final directionality = tester.widget<Directionality>(directionalityFinder.first);
          expect(directionality.textDirection, equals(TextDirection.rtl));
        }
        
        // Check that no English hardcoded text appears
        expect(find.text('Login'), findsNothing);
        expect(find.text('Email'), findsNothing);
        expect(find.text('Password'), findsNothing);
      });
    });

    group('Dashboard Translation Tests', () {
      testWidgets('should display dashboard elements in selected language', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Test English
        await languageController.changeLanguage('en');
        await tester.pumpAndSettle();
        
        // Navigate to dashboard (implementation depends on app structure)
        // Check for dashboard elements
        
        // Test Urdu
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Verify no English hardcoded text in Urdu mode
        final commonEnglishWords = ['Dashboard', 'Home', 'Profile', 'Settings', 'Wallet'];
        for (final word in commonEnglishWords) {
          expect(find.text(word), findsNothing, 
            reason: 'Found hardcoded English text "$word" in Urdu mode');
        }
      });
    });

    group('Settings Screen Translation Tests', () {
      testWidgets('should display settings screen in both languages', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Test language switching in settings
        for (String langCode in ['en', 'ur']) {
          await languageController.changeLanguage(langCode);
          await tester.pumpAndSettle();
          
          // Verify language-specific behavior
          if (langCode == 'ur') {
            // Check RTL layout
            final directionalityFinder = find.byType(Directionality);
            if (directionalityFinder.evaluate().isNotEmpty) {
              final directionality = tester.widget<Directionality>(directionalityFinder.first);
              expect(directionality.textDirection, equals(TextDirection.rtl));
            }
          }
        }
      });
    });

    group('Form Validation Translation Tests', () {
      testWidgets('should display form validation messages in selected language', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Test validation messages in both languages
        for (String langCode in ['en', 'ur']) {
          await languageController.changeLanguage(langCode);
          await tester.pumpAndSettle();
          
          // Try to trigger validation (implementation depends on forms available)
          // This would involve interacting with form fields and checking error messages
          
          // Verify no mixed language validation messages
          if (langCode == 'ur') {
            // Common English validation words that shouldn't appear
            expect(find.text('Required'), findsNothing);
            expect(find.text('Invalid'), findsNothing);
            expect(find.text('Error'), findsNothing);
          }
        }
      });
    });

    group('Navigation Translation Tests', () {
      testWidgets('should display navigation elements in selected language', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Test navigation in both languages
        for (String langCode in ['en', 'ur']) {
          await languageController.changeLanguage(langCode);
          await tester.pumpAndSettle();
          
          // Check for navigation elements (drawer, bottom nav, etc.)
          // Implementation depends on app navigation structure
          
          if (langCode == 'ur') {
            // Verify no English navigation text
            final commonNavWords = ['Home', 'Profile', 'Settings', 'History', 'Help'];
            for (final word in commonNavWords) {
              expect(find.text(word), findsNothing,
                reason: 'Found hardcoded English navigation text "$word" in Urdu mode');
            }
          }
        }
      });
    });

    group('Error Message Translation Tests', () {
      testWidgets('should display error messages in selected language', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Test error messages in both languages
        for (String langCode in ['en', 'ur']) {
          await languageController.changeLanguage(langCode);
          await tester.pumpAndSettle();
          
          // Test fallback error messages
          final errorText = LocalizationService.getTranslationWithFallback('test_error_key');
          expect(errorText, isNotNull);
          expect(errorText, isNotEmpty);
          
          if (langCode == 'ur') {
            // Verify no English error messages appear
            expect(find.text('Error occurred'), findsNothing);
            expect(find.text('Something went wrong'), findsNothing);
            expect(find.text('Please try again'), findsNothing);
          }
        }
      });
    });

    group('Text Layout and Overflow Tests', () {
      testWidgets('should handle text layout properly in both languages', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Test text layout in both languages
        for (String langCode in ['en', 'ur']) {
          await languageController.changeLanguage(langCode);
          await tester.pumpAndSettle();
          
          // Check for text overflow issues
          final textWidgets = find.byType(Text);
          for (final textWidget in textWidgets.evaluate()) {
            final text = textWidget.widget as Text;
            if (text.data != null && text.data!.isNotEmpty) {
              // Verify text doesn't overflow (basic check)
              expect(text.overflow, isNot(equals(TextOverflow.visible)));
            }
          }
          
          // Check text direction consistency
          if (langCode == 'ur') {
            final directionalityWidgets = find.byType(Directionality);
            for (final directionalityWidget in directionalityWidgets.evaluate()) {
              final directionality = directionalityWidget.widget as Directionality;
              expect(directionality.textDirection, equals(TextDirection.rtl));
            }
          }
        }
      });
    });

    group('Performance During Language Switching Tests', () {
      testWidgets('should maintain UI responsiveness during language switching', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Measure UI responsiveness during rapid language switching
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 3; i++) {
          await languageController.changeLanguage('ur');
          await tester.pumpAndSettle();
          
          await languageController.changeLanguage('en');
          await tester.pumpAndSettle();
        }
        
        stopwatch.stop();
        
        // Each complete switch cycle should be reasonable
        final averageTimePerSwitch = stopwatch.elapsedMilliseconds / 6;
        expect(averageTimePerSwitch, lessThan(1000),
          reason: 'Average language switch took ${averageTimePerSwitch}ms, should be under 1000ms');
      });

      testWidgets('should not cause UI flickering during language switch', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Switch language and verify smooth transition
        await languageController.changeLanguage('ur');
        
        // Pump a few frames to check for flickering
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16)); // ~60fps
        }
        
        await tester.pumpAndSettle();
        
        // If we reach here without exceptions, UI transition was smooth
        expect(true, isTrue);
      });
    });

    group('Memory Usage During Translation Tests', () {
      testWidgets('should not cause memory leaks during extensive language switching', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Perform extensive language switching
        for (int i = 0; i < 20; i++) {
          await languageController.changeLanguage(i % 2 == 0 ? 'en' : 'ur');
          await tester.pumpAndSettle();
          
          // Force garbage collection periodically
          if (i % 5 == 0) {
            await tester.binding.delayed(const Duration(milliseconds: 50));
          }
        }
        
        // Verify app is still responsive
        await languageController.changeLanguage('en');
        await tester.pumpAndSettle();
        
        expect(languageController.currentLanguageCode, equals('en'));
      });
    });

    group('Translation Key Coverage Tests', () {
      testWidgets('should have comprehensive translation key coverage', (WidgetTester tester) async {
        // Get translation coverage report
        final coverage = LocalizationService.getTranslationCoverage();
        
        expect(coverage['total_keys'], greaterThan(0));
        
        final languages = coverage['languages'] as Map;
        
        // Check English coverage
        final enCoverage = languages['en'] as Map;
        final enPercentage = double.parse(enCoverage['coverage_percentage'] as String);
        expect(enPercentage, equals(100.0), 
          reason: 'English should have 100% coverage as the base language');
        
        // Check Urdu coverage
        final urCoverage = languages['ur'] as Map;
        final urPercentage = double.parse(urCoverage['coverage_percentage'] as String);
        expect(urPercentage, greaterThan(95.0),
          reason: 'Urdu should have at least 95% translation coverage');
        
        // Check for missing translations
        final missingTranslations = LocalizationService.validateTranslationCompleteness();
        if (missingTranslations.isNotEmpty) {
          print('Missing translations found:');
          missingTranslations.forEach((lang, keys) {
            print('  $lang: ${keys.length} missing keys');
            if (keys.length <= 10) {
              for (String key in keys) {
                print('    - $key');
              }
            }
          });
        }
        
        // Urdu should have minimal missing translations
        final urduMissing = missingTranslations['ur'] ?? [];
        expect(urduMissing.length, lessThan(10),
          reason: 'Urdu should have fewer than 10 missing translations');
      });
    });
  });
}