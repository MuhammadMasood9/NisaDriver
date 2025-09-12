import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/controller/language_controller.dart';
import 'package:driver/services/localization_service.dart';

void main() {
  group('LanguageController Tests', () {
    late LanguageController languageController;

    setUp(() async {
      // Initialize GetX
      Get.testMode = true;
      
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Initialize LocalizationService
      Get.put(LocalizationService());
      
      // Initialize LanguageController
      languageController = Get.put(LanguageController());
    });

    tearDown(() {
      Get.reset();
    });

    test('should initialize with default language', () {
      expect(languageController.currentLanguageCode, 'en');
      expect(languageController.isLanguageInitialized, false);
    });

    test('should change language successfully', () async {
      // Test changing to Urdu
      final result = await languageController.changeLanguage('ur');
      
      expect(result, true);
      expect(languageController.currentLanguageCode, 'ur');
      expect(languageController.isCurrentLanguageRTL, true);
    });

    test('should not change to invalid language', () async {
      final result = await languageController.changeLanguage('invalid');
      
      expect(result, false);
      expect(languageController.currentLanguageCode, 'en'); // Should remain unchanged
    });

    test('should return correct text direction', () {
      // English (LTR)
      languageController.changeLanguage('en');
      expect(languageController.getTextDirection(), TextDirection.ltr);
      
      // Urdu (RTL)
      languageController.changeLanguage('ur');
      expect(languageController.getTextDirection(), TextDirection.rtl);
    });

    test('should return primary languages only', () {
      final primaryLanguages = languageController.getPrimaryLanguages();
      
      expect(primaryLanguages.length, 2);
      expect(primaryLanguages.any((lang) => lang.code == 'en'), true);
      expect(primaryLanguages.any((lang) => lang.code == 'ur'), true);
    });

    test('should track performance metrics', () {
      final metrics = languageController.getPerformanceMetrics();
      
      expect(metrics.containsKey('current_language'), true);
      expect(metrics.containsKey('is_rtl'), true);
      expect(metrics.containsKey('is_initialized'), true);
    });

    test('should handle language switching state', () async {
      expect(languageController.isChangingLanguage, false);
      
      // Start language change (this will be async)
      final future = languageController.changeLanguage('ur');
      
      // During the change, isChangingLanguage should be true briefly
      // But since this is a test, it might complete too quickly
      
      await future;
      
      // After completion, should be false
      expect(languageController.isChangingLanguage, false);
    });
  });
}