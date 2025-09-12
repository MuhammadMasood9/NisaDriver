import 'package:flutter/foundation.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/services/translation_validator.dart';

/// Translation management utilities for developers
class TranslationManager {
  /// Generate translation key suggestions for a list of hardcoded strings
  static Map<String, Map<String, String>> generateKeySuggestions(
    List<String> hardcodedStrings, {
    String? category,
  }) {
    final Map<String, Map<String, String>> suggestions = {};
    
    for (String text in hardcodedStrings) {
      if (text.trim().isNotEmpty) {
        final key = LocalizationService.generateTranslationKey(text, category: category);
        suggestions[key] = {
          'en': text,
          'ur': '[NEEDS_TRANSLATION]', // Placeholder for Urdu translation
          'original_text': text,
        };
      }
    }
    
    return suggestions;
  }

  /// Analyze translation coverage and generate comprehensive report
  static Map<String, dynamic> analyzeTranslationCoverage() {
    final coverage = LocalizationService.getTranslationCoverage();
    final validation = TranslationValidator.getValidationSummary();
    final missingKeys = LocalizationService.getMissingTranslationKeys();
    final translationErrors = LocalizationService.getTranslationErrors();
    final errorDetails = LocalizationService.getErrorDetails();
    final systemHealth = LocalizationService.validateTranslationSystem();
    
    return {
      'coverage': coverage,
      'validation': validation,
      'system_health': systemHealth,
      'missing_keys_count': missingKeys.length,
      'missing_keys': missingKeys.toList(),
      'error_count': translationErrors.length,
      'translation_errors': translationErrors.toList(),
      'error_details': errorDetails,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Generate a comprehensive translation report
  static String generateTranslationReport() {
    final StringBuffer report = StringBuffer();
    final analysis = analyzeTranslationCoverage();
    
    report.writeln('📋 Comprehensive Translation Report');
    report.writeln('Generated: ${DateTime.now()}');
    report.writeln('=' * 60);
    
    // Coverage section
    final coverage = analysis['coverage'] as Map<String, dynamic>;
    final totalKeys = coverage['total_keys'] as int;
    
    report.writeln('\n📊 COVERAGE STATISTICS');
    report.writeln('-' * 30);
    report.writeln('Total translation keys: $totalKeys');
    
    final languages = coverage['languages'] as Map<String, Map<String, dynamic>>;
    for (String lang in languages.keys) {
      final langData = languages[lang]!;
      final percentage = langData['coverage_percentage'];
      final missing = langData['missing_keys'];
      
      report.writeln('$lang: $percentage% complete (Missing: $missing keys)');
    }
    
    // Validation section
    final validation = analysis['validation'] as Map<String, dynamic>;
    final totalIssues = validation['total_issues'] as int;
    final isValid = validation['is_valid'] as bool;
    
    report.writeln('\n🔍 VALIDATION RESULTS');
    report.writeln('-' * 30);
    report.writeln('Status: ${isValid ? "✅ VALID" : "❌ ISSUES FOUND"}');
    report.writeln('Total issues: $totalIssues');
    
    if (totalIssues > 0) {
      final issueCounts = validation['issue_counts'] as Map<String, dynamic>;
      for (String issueType in issueCounts.keys) {
        final count = issueCounts[issueType];
        report.writeln('  • $issueType: $count');
      }
    }
    
    // System health section
    final systemHealth = analysis['system_health'] as Map<String, dynamic>;
    final systemStatus = systemHealth['status'] as String;
    
    report.writeln('\n🏥 SYSTEM HEALTH');
    report.writeln('-' * 30);
    report.writeln('Status: ${_getStatusIcon(systemStatus)} $systemStatus');
    
    final systemErrors = systemHealth['errors'] as List;
    if (systemErrors.isNotEmpty) {
      report.writeln('System Errors:');
      for (String error in systemErrors.take(3)) {
        report.writeln('  • $error');
      }
      if (systemErrors.length > 3) {
        report.writeln('  ... and ${systemErrors.length - 3} more');
      }
    }
    
    // Translation errors section
    final errorCount = analysis['error_count'] as int;
    if (errorCount > 0) {
      report.writeln('\n🚨 TRANSLATION ERRORS');
      report.writeln('-' * 30);
      report.writeln('Total errors logged: $errorCount');
      
      final errorDetails = analysis['error_details'] as Map<String, Map<String, dynamic>>;
      final recentErrors = errorDetails.entries.take(5);
      for (MapEntry<String, Map<String, dynamic>> entry in recentErrors) {
        final error = entry.value;
        report.writeln('  • ${error['message']} (${error['key']})');
      }
      if (errorDetails.length > 5) {
        report.writeln('  ... and ${errorDetails.length - 5} more errors');
      }
    }

    // Missing keys section
    final missingKeysCount = analysis['missing_keys_count'] as int;
    if (missingKeysCount > 0) {
      report.writeln('\n🔍 MISSING TRANSLATIONS');
      report.writeln('-' * 30);
      report.writeln('Total missing: $missingKeysCount');
      final missingKeys = analysis['missing_keys'] as List<String>;
      for (String key in missingKeys.take(10)) {
        report.writeln('  • $key');
      }
      if (missingKeys.length > 10) {
        report.writeln('  ... and ${missingKeys.length - 10} more');
      }
    }
    
    // Recommendations section
    report.writeln('\n💡 RECOMMENDATIONS');
    report.writeln('-' * 30);
    
    if (totalIssues == 0 && missingKeysCount == 0 && errorCount == 0 && systemStatus == 'healthy') {
      report.writeln('✅ All translations are complete and valid!');
    } else {
      // System health recommendations
      if (systemStatus != 'healthy') {
        report.writeln('🚨 URGENT: Fix system health issues first');
      }
      
      // Error recommendations
      if (errorCount > 0) {
        report.writeln('• Fix $errorCount translation loading/runtime errors');
      }
      
      if (missingKeysCount > 0) {
        report.writeln('• Add missing translations for $missingKeysCount logged keys');
      }
      
      final criticalIssues = validation['critical_issues'] as int;
      if (criticalIssues > 0) {
        report.writeln('• Fix $criticalIssues critical translation issues');
      }
      
      final enCoverage = languages['en']?['coverage_percentage'];
      final urCoverage = languages['ur']?['coverage_percentage'];
      
      if (enCoverage != null && double.parse(enCoverage.toString().replaceAll('%', '')) < 100) {
        report.writeln('• Complete English translations');
      }
      
      if (urCoverage != null && double.parse(urCoverage.toString().replaceAll('%', '')) < 100) {
        report.writeln('• Complete Urdu translations');
      }
      
      // Performance recommendations
      if (errorCount > 10) {
        report.writeln('• Consider clearing error logs: LocalizationService.clearTranslationErrors()');
      }
    }
    
    report.writeln('\n${'=' * 60}');
    return report.toString();
  }

  /// Print translation report to debug console
  static void printTranslationReport() {
    if (!kDebugMode) return;
    
    final report = generateTranslationReport();
    debugPrint(report);
  }

  /// Validate translation key naming convention
  static bool isValidTranslationKey(String key) {
    // Check if key follows naming convention
    final keyPattern = RegExp(r'^[a-z][a-z0-9_]*[a-z0-9]$');
    
    if (key.length < 2) return false;
    if (!keyPattern.hasMatch(key)) return false;
    if (key.contains('__')) return false; // No double underscores
    if (key.startsWith('_') || key.endsWith('_')) return false;
    
    return true;
  }

  /// Suggest improvements for translation keys
  static List<String> suggestKeyImprovements(String key) {
    final List<String> suggestions = [];
    
    if (!isValidTranslationKey(key)) {
      if (key.length < 2) {
        suggestions.add('Key is too short (minimum 2 characters)');
      }
      
      if (key.contains(RegExp(r'[A-Z]'))) {
        suggestions.add('Use lowercase letters only');
      }
      
      if (key.contains(RegExp(r'[^a-z0-9_]'))) {
        suggestions.add('Use only letters, numbers, and underscores');
      }
      
      if (key.contains('__')) {
        suggestions.add('Avoid double underscores');
      }
      
      if (key.startsWith('_') || key.endsWith('_')) {
        suggestions.add('Do not start or end with underscore');
      }
      
      if (RegExp(r'^\d').hasMatch(key)) {
        suggestions.add('Do not start with a number');
      }
    }
    
    return suggestions;
  }

  /// Get translation statistics for development
  static Map<String, dynamic> getTranslationStatistics() {
    final LocalizationService service = LocalizationService();
    final Map<String, dynamic> stats = {};
    
    // Count keys per language
    for (String lang in LocalizationService.primaryLanguages) {
      final translations = service.keys[lang] ?? {};
      stats['${lang}_key_count'] = translations.length;
      
      // Calculate average translation length
      if (translations.isNotEmpty) {
        final totalLength = translations.values
            .where((value) => value.isNotEmpty)
            .map((value) => value.length)
            .fold(0, (sum, length) => sum + length);
        
        stats['${lang}_avg_length'] = totalLength / translations.length;
      }
    }
    
    // Get validation stats
    final validationSummary = TranslationValidator.getValidationSummary();
    stats.addAll(validationSummary);
    
    // Get missing keys count
    stats['runtime_missing_keys'] = LocalizationService.getMissingTranslationKeys().length;
    
    return stats;
  }

  /// Export translation keys for external tools (development only)
  static Map<String, dynamic> exportTranslationData() {
    if (!kDebugMode) return {};
    
    final LocalizationService service = LocalizationService();
    final Map<String, dynamic> exportData = {
      'metadata': {
        'export_date': DateTime.now().toIso8601String(),
        'primary_languages': LocalizationService.primaryLanguages,
        'total_languages': service.keys.keys.length,
      },
      'translations': {},
      'analysis': analyzeTranslationCoverage(),
    };
    
    // Export translations for primary languages only
    for (String lang in LocalizationService.primaryLanguages) {
      exportData['translations'][lang] = service.keys[lang] ?? {};
    }
    
    return exportData;
  }

  /// Clear all development logs and caches
  static void clearDevelopmentData() {
    LocalizationService.clearAllTranslationLogs();
    if (kDebugMode) {
      debugPrint('🧹 Cleared translation development data');
    }
  }

  /// Get status icon for system health
  static String _getStatusIcon(String status) {
    switch (status) {
      case 'healthy':
        return '✅';
      case 'warning':
        return '⚠️';
      case 'error':
        return '❌';
      case 'critical_error':
        return '🚨';
      default:
        return '❓';
    }
  }
}