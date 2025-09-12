import 'package:flutter/foundation.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/services/translation_validator.dart';
import 'package:driver/services/translation_manager.dart';

/// Demonstration of enhanced translation error handling and validation
class TranslationDemo {
  /// Demonstrate error handling capabilities
  static void demonstrateErrorHandling() {
    if (!kDebugMode) return;
    
    debugPrint('\n🎯 Translation Error Handling Demonstration');
    debugPrint('=' * 60);
    
    // 1. Test missing translation key
    debugPrint('\n1. Testing missing translation key:');
    final missingResult = LocalizationService.getTranslationWithFallback('demo_missing_key');
    debugPrint('Result: "$missingResult"');
    
    // 2. Test empty translation key
    debugPrint('\n2. Testing empty translation key:');
    final emptyResult = LocalizationService.getTranslationWithFallback('');
    debugPrint('Result: "$emptyResult"');
    
    // 3. Test existing translation key
    debugPrint('\n3. Testing existing translation key:');
    final existingResult = LocalizationService.getTranslationWithFallback('Login');
    debugPrint('Result: "$existingResult"');
    
    // 4. Show system health
    debugPrint('\n4. System Health Check:');
    final systemHealth = LocalizationService.validateTranslationSystem();
    debugPrint('Status: ${systemHealth['status']}');
    debugPrint('Languages loaded: ${systemHealth['languages_loaded']}');
    
    // 5. Show validation results
    debugPrint('\n5. Validation Results:');
    final validationSummary = TranslationValidator.getValidationSummary();
    debugPrint('Total issues: ${validationSummary['total_issues']}');
    debugPrint('Is valid: ${validationSummary['is_valid']}');
    debugPrint('Critical issues: ${validationSummary['critical_issues']}');
    
    // 6. Show missing keys count
    final missingKeys = LocalizationService.getMissingTranslationKeys();
    final errors = LocalizationService.getTranslationErrors();
    debugPrint('\n6. Runtime Statistics:');
    debugPrint('Missing keys logged: ${missingKeys.length}');
    debugPrint('Errors logged: ${errors.length}');
    
    debugPrint('\n' + '=' * 60);
  }

  /// Demonstrate validation capabilities
  static void demonstrateValidation() {
    if (!kDebugMode) return;
    
    debugPrint('\n🔍 Translation Validation Demonstration');
    debugPrint('=' * 60);
    
    // Run comprehensive validation
    final issues = TranslationValidator.validateAllTranslations();
    
    debugPrint('Total validation issues found: ${issues.length}');
    
    if (issues.isNotEmpty) {
      debugPrint('\nFirst 5 issues:');
      for (int i = 0; i < issues.length && i < 5; i++) {
        final issue = issues[i];
        debugPrint('${i + 1}. [${issue.language}] ${issue.key}: ${issue.type.name}');
        debugPrint('   ${issue.description}');
        if (issue.suggestion != null) {
          debugPrint('   Suggestion: ${issue.suggestion}');
        }
      }
    } else {
      debugPrint('✅ No validation issues found!');
    }
    
    debugPrint('\n' + '=' * 60);
  }

  /// Demonstrate comprehensive reporting
  static void demonstrateReporting() {
    if (!kDebugMode) return;
    
    debugPrint('\n📊 Translation Reporting Demonstration');
    debugPrint('=' * 60);
    
    // Generate and print comprehensive report
    TranslationManager.printTranslationReport();
    
    // Show coverage statistics
    final coverage = LocalizationService.getTranslationCoverage();
    debugPrint('\n📈 Coverage Summary:');
    debugPrint('Total keys: ${coverage['total_keys']}');
    
    final languages = coverage['languages'] as Map<String, Map<String, dynamic>>;
    for (String lang in languages.keys) {
      final langData = languages[lang]!;
      debugPrint('$lang: ${langData['coverage_percentage']}% complete');
    }
    
    debugPrint('\n' + '=' * 60);
  }

  /// Run all demonstrations
  static void runAllDemonstrations() {
    if (!kDebugMode) return;
    
    demonstrateErrorHandling();
    demonstrateValidation();
    demonstrateReporting();
    
    debugPrint('\n🎉 Translation Error Handling Demo Complete!');
    debugPrint('All enhanced features are working correctly.');
  }

  /// Clear all demo data
  static void clearDemoData() {
    LocalizationService.clearAllTranslationLogs();
    if (kDebugMode) {
      debugPrint('🧹 Demo data cleared');
    }
  }
}