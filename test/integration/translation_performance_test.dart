import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/main.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/controller/language_controller.dart';
import 'package:driver/models/language_model.dart';

void main() {
  group('Translation Performance Tests', () {
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

    group('Language Switching Performance Tests', () {
      testWidgets('should switch language within 2 seconds (Requirement 4.1)', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Test English to Urdu switch
        final stopwatch1 = Stopwatch()..start();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        stopwatch1.stop();
        
        expect(stopwatch1.elapsedMilliseconds, lessThan(2000),
          reason: 'English to Urdu switch took ${stopwatch1.elapsedMilliseconds}ms, should be under 2000ms');
        
        // Test Urdu to English switch
        final stopwatch2 = Stopwatch()..start();
        await languageController.changeLanguage('en');
        await tester.pumpAndSettle();
        stopwatch2.stop();
        
        expect(stopwatch2.elapsedMilliseconds, lessThan(2000),
          reason: 'Urdu to English switch took ${stopwatch2.elapsedMilliseconds}ms, should be under 2000ms');
        
        // Log performance metrics
        final metrics = languageController.getPerformanceMetrics();
        print('Language switching performance metrics: $metrics');
      });

      testWidgets('should maintain consistent performance across multiple switches', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        final List<int> switchTimes = [];
        
        // Perform 10 language switches and measure each
        for (int i = 0; i < 10; i++) {
          final targetLang = i % 2 == 0 ? 'ur' : 'en';
          
          final stopwatch = Stopwatch()..start();
          await languageController.changeLanguage(targetLang);
          await tester.pumpAndSettle();
          stopwatch.stop();
          
          switchTimes.add(stopwatch.elapsedMilliseconds);
        }
        
        // Calculate statistics
        final averageTime = switchTimes.reduce((a, b) => a + b) / switchTimes.length;
        final maxTime = switchTimes.reduce((a, b) => a > b ? a : b);
        final minTime = switchTimes.reduce((a, b) => a < b ? a : b);
        
        print('Switch times: $switchTimes');
        print('Average: ${averageTime.toStringAsFixed(1)}ms, Max: ${maxTime}ms, Min: ${minTime}ms');
        
        // All switches should be under 2 seconds
        expect(maxTime, lessThan(2000),
          reason: 'Maximum switch time was ${maxTime}ms, should be under 2000ms');
        
        // Average should be much better
        expect(averageTime, lessThan(1000),
          reason: 'Average switch time was ${averageTime.toStringAsFixed(1)}ms, should be under 1000ms');
      });
    });

    group('Language Persistence Performance Tests', () {
      testWidgets('should persist language preference quickly (Requirement 4.2)', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Measure time to save language preference
        final stopwatch = Stopwatch()..start();
        await languageController.changeLanguage('ur');
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'Language preference saving took ${stopwatch.elapsedMilliseconds}ms, should be under 1000ms');
        
        // Simulate app restart by creating new controller
        Get.delete<LanguageController>();
        final newLanguageController = Get.put(LanguageController());
        
        // Measure time to load language preference
        final loadStopwatch = Stopwatch()..start();
        await newLanguageController.initializeLanguage();
        loadStopwatch.stop();
        
        expect(loadStopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Language preference loading took ${loadStopwatch.elapsedMilliseconds}ms, should be under 500ms');
        
        // Verify language was persisted correctly
        expect(newLanguageController.currentLanguageCode, equals('ur'));
      });

      testWidgets('should remember language across multiple app restarts', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Set language to Urdu
        await languageController.changeLanguage('ur');
        
        // Simulate multiple app restarts
        for (int i = 0; i < 5; i++) {
          Get.delete<LanguageController>();
          final newController = Get.put(LanguageController());
          
          final stopwatch = Stopwatch()..start();
          await newController.initializeLanguage();
          stopwatch.stop();
          
          expect(stopwatch.elapsedMilliseconds, lessThan(500),
            reason: 'Language initialization ${i + 1} took ${stopwatch.elapsedMilliseconds}ms');
          
          expect(newController.currentLanguageCode, equals('ur'),
            reason: 'Language not persisted correctly after restart ${i + 1}');
        }
      });
    });

    group('Translation Loading Performance Tests', () {
      testWidgets('should load translations efficiently (Requirement 4.3)', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Measure translation preloading performance
        final stopwatch = Stopwatch()..start();
        await languageController.preloadTranslations();
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'Translation preloading took ${stopwatch.elapsedMilliseconds}ms, should be under 1000ms');
        
        // Test individual translation lookup performance
        final lookupStopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          LocalizationService.getTranslationWithFallback('app_name');
        }
        lookupStopwatch.stop();
        
        final averageLookupTime = lookupStopwatch.elapsedMicroseconds / 100;
        expect(averageLookupTime, lessThan(1000),
          reason: 'Average translation lookup took ${averageLookupTime.toStringAsFixed(1)}μs, should be under 1000μs');
      });

      testWidgets('should handle large number of translation lookups efficiently', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        // Test performance with many translation lookups
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 1000; i++) {
          LocalizationService.getTranslationWithFallback('app_name');
          LocalizationService.getTranslationWithFallback('loading');
          LocalizationService.getTranslationWithFallback('error');
          LocalizationService.getTranslationWithFallback('success');
          LocalizationService.getTranslationWithFallback('cancel');
        }
        
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: '5000 translation lookups took ${stopwatch.elapsedMilliseconds}ms, should be under 1000ms');
      });
    });

    group('UI Responsiveness Tests', () {
      testWidgets('should maintain UI responsiveness during language switching (Requirement 4.4)', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Test UI responsiveness during language switch
        final Future<void> languageSwitch = languageController.changeLanguage('ur');
        
        // Pump frames during language switch to ensure UI remains responsive
        int frameCount = 0;
        while (!languageSwitch.isCompleted && frameCount < 120) { // Max 2 seconds at 60fps
          await tester.pump(const Duration(milliseconds: 16));
          frameCount++;
        }
        
        await languageSwitch;
        await tester.pumpAndSettle();
        
        expect(frameCount, lessThan(120),
          reason: 'Language switch took more than 2 seconds (${frameCount} frames)');
        
        // Verify UI is still responsive after switch
        expect(languageController.currentLanguageCode, equals('ur'));
      });

      testWidgets('should not block UI during translation system validation', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        // Run translation system validation
        final stopwatch = Stopwatch()..start();
        final systemHealth = LocalizationService.validateTranslationSystem();
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Translation system validation took ${stopwatch.elapsedMilliseconds}ms, should be under 500ms');
        
        expect(systemHealth['status'], isNotNull);
        
        // Run coverage analysis
        final coverageStopwatch = Stopwatch()..start();
        final coverage = LocalizationService.getTranslationCoverage();
        coverageStopwatch.stop();
        
        expect(coverageStopwatch.elapsedMilliseconds, lessThan(300),
          reason: 'Translation coverage analysis took ${coverageStopwatch.elapsedMilliseconds}ms, should be under 300ms');
        
        expect(coverage['total_keys'], greaterThan(0));
      });
    });

    group('Memory Performance Tests', () {
      testWidgets('should not cause memory leaks during extensive usage', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Perform extensive operations that could cause memory leaks
        for (int cycle = 0; cycle < 10; cycle++) {
          // Language switching
          await languageController.changeLanguage('ur');
          await tester.pumpAndSettle();
          await languageController.changeLanguage('en');
          await tester.pumpAndSettle();
          
          // Translation lookups
          for (int i = 0; i < 100; i++) {
            LocalizationService.getTranslationWithFallback('test_key_$i');
          }
          
          // System validation
          LocalizationService.validateTranslationSystem();
          LocalizationService.getTranslationCoverage();
          
          // Clear logs periodically
          if (cycle % 3 == 0) {
            LocalizationService.clearAllTranslationLogs();
          }
          
          // Force garbage collection
          await tester.binding.delayed(const Duration(milliseconds: 10));
        }
        
        // Verify system is still functional
        expect(languageController.currentLanguageCode, equals('en'));
        
        final finalSystemHealth = LocalizationService.validateTranslationSystem();
        expect(finalSystemHealth['status'], isIn(['healthy', 'warning']));
      });

      testWidgets('should efficiently manage translation cache', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Test cache efficiency with repeated lookups
        final stopwatch = Stopwatch()..start();
        
        // First round of lookups (cache miss)
        for (int i = 0; i < 100; i++) {
          LocalizationService.getTranslationWithFallback('app_name');
        }
        
        final firstRoundTime = stopwatch.elapsedMicroseconds;
        stopwatch.reset();
        
        // Second round of lookups (cache hit)
        for (int i = 0; i < 100; i++) {
          LocalizationService.getTranslationWithFallback('app_name');
        }
        
        final secondRoundTime = stopwatch.elapsedMicroseconds;
        stopwatch.stop();
        
        // Second round should be faster or similar (cache efficiency)
        expect(secondRoundTime, lessThanOrEqualTo(firstRoundTime * 1.5),
          reason: 'Cache efficiency issue: first=${firstRoundTime}μs, second=${secondRoundTime}μs');
      });
    });

    group('Stress Testing', () {
      testWidgets('should handle rapid language switching without issues', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        
        // Rapid language switching stress test
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 50; i++) {
          final targetLang = i % 2 == 0 ? 'ur' : 'en';
          await languageController.changeLanguage(targetLang);
          
          // Minimal settling to stress test
          await tester.pump();
        }
        
        await tester.pumpAndSettle();
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(30000),
          reason: '50 rapid language switches took ${stopwatch.elapsedMilliseconds}ms, should be under 30s');
        
        // Verify system is still functional
        expect(languageController.currentLanguageCode, isIn(['en', 'ur']));
        
        final systemHealth = LocalizationService.validateTranslationSystem();
        expect(systemHealth['status'], isIn(['healthy', 'warning']));
      });

      testWidgets('should handle concurrent translation operations', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        // Simulate concurrent translation operations
        final futures = <Future>[];
        
        // Start multiple concurrent operations
        for (int i = 0; i < 10; i++) {
          futures.add(Future(() {
            for (int j = 0; j < 100; j++) {
              LocalizationService.getTranslationWithFallback('test_key_${i}_$j');
            }
          }));
        }
        
        final stopwatch = Stopwatch()..start();
        await Future.wait(futures);
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: 'Concurrent translation operations took ${stopwatch.elapsedMilliseconds}ms, should be under 2s');
        
        // Verify system integrity
        final systemHealth = LocalizationService.validateTranslationSystem();
        expect(systemHealth['status'], isIn(['healthy', 'warning']));
      });
    });
  });
}