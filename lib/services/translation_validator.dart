import 'package:flutter/foundation.dart';
import 'package:driver/services/localization_service.dart';

/// Validation issue types
enum ValidationIssueType {
  missingTranslation,
  emptyTranslation,
  inconsistentTerminology,
  lengthMismatch,
  specialCharacterMismatch,
  rtlLayoutIssue,
  translationError,
  systemError,
  loadingFailure,
}

/// Represents a translation validation issue
class ValidationIssue {
  final String key;
  final String language;
  final ValidationIssueType type;
  final String description;
  final String? suggestion;

  const ValidationIssue({
    required this.key,
    required this.language,
    required this.type,
    required this.description,
    this.suggestion,
  });

  @override
  String toString() {
    return '[$language] $key: ${type.name} - $description${suggestion != null ? ' (Suggestion: $suggestion)' : ''}';
  }
}

/// Translation validator for ensuring quality and consistency
class TranslationValidator {
  static const int _maxLengthDifferencePercent = 50;
  static const List<String> _commonTerms = [
    'NisaRide',
    'NisaDrive',
    'Login',
    'Sign up',
    'Profile',
    'Wallet',
    'Ride',
    'Driver',
    'Customer',
    'Payment',
    'Cancel',
    'Confirm',
    'Save',
    'Delete',
    'Edit',
    'Back',
    'Next',
    'Submit',
    'OK',
    'Yes',
    'No',
  ];

  /// Validate all translations and return list of issues
  static List<ValidationIssue> validateAllTranslations() {
    final List<ValidationIssue> issues = [];
    
    try {
      final LocalizationService service = LocalizationService();
      
      // Validate system health first
      issues.addAll(_validateSystemHealth());
      
      // Get all keys from primary languages
      final Set<String> allKeys = <String>{};
      for (String lang in LocalizationService.primaryLanguages) {
        try {
          final translations = service.keys[lang];
          if (translations != null) {
            allKeys.addAll(translations.keys);
          } else {
            issues.add(ValidationIssue(
              key: 'system',
              language: lang,
              type: ValidationIssueType.loadingFailure,
              description: 'Failed to load translations for language $lang',
              suggestion: 'Check if language file exists and is properly formatted',
            ));
          }
        } catch (e) {
          issues.add(ValidationIssue(
            key: 'system',
            language: lang,
            type: ValidationIssueType.systemError,
            description: 'Error accessing translations for language $lang: $e',
            suggestion: 'Check language file integrity and app configuration',
          ));
        }
      }

      // Validate each key across languages
      for (String key in allKeys) {
        try {
          issues.addAll(_validateTranslationKey(key, service));
        } catch (e) {
          issues.add(ValidationIssue(
            key: key,
            language: 'system',
            type: ValidationIssueType.translationError,
            description: 'Error validating translation key: $e',
            suggestion: 'Check translation key format and content',
          ));
        }
      }

      // Validate terminology consistency
      try {
        issues.addAll(_validateTerminologyConsistency(service));
      } catch (e) {
        issues.add(ValidationIssue(
          key: 'terminology',
          language: 'system',
          type: ValidationIssueType.systemError,
          description: 'Error validating terminology consistency: $e',
          suggestion: 'Check translation content and system integrity',
        ));
      }

    } catch (e) {
      issues.add(ValidationIssue(
        key: 'system',
        language: 'system',
        type: ValidationIssueType.systemError,
        description: 'Critical validation system error: $e',
        suggestion: 'Contact development team for system diagnosis',
      ));
    }

    return issues;
  }

  /// Validate translation system health
  static List<ValidationIssue> _validateSystemHealth() {
    final List<ValidationIssue> issues = [];
    
    // Check for translation errors
    final translationErrors = LocalizationService.getTranslationErrors();
    if (translationErrors.isNotEmpty) {
      issues.add(ValidationIssue(
        key: 'system',
        language: 'system',
        type: ValidationIssueType.translationError,
        description: '${translationErrors.length} translation errors detected during runtime',
        suggestion: 'Review error logs and fix translation loading issues',
      ));
    }
    
    // Check system validation
    final systemHealth = LocalizationService.validateTranslationSystem();
    final status = systemHealth['status'] as String;
    
    if (status == 'error' || status == 'critical_error') {
      final errors = systemHealth['errors'] as List;
      for (String error in errors) {
        issues.add(ValidationIssue(
          key: 'system',
          language: 'system',
          type: ValidationIssueType.systemError,
          description: error,
          suggestion: 'Fix system configuration and translation loading',
        ));
      }
    }
    
    return issues;
  }

  /// Validate a specific translation key across languages
  static List<ValidationIssue> _validateTranslationKey(String key, LocalizationService service) {
    final List<ValidationIssue> issues = [];
    final Map<String, String?> translations = {};

    // Collect translations for this key
    for (String lang in LocalizationService.primaryLanguages) {
      final langTranslations = service.keys[lang];
      translations[lang] = langTranslations?[key];
    }

    // Check for missing or empty translations
    for (String lang in LocalizationService.primaryLanguages) {
      final translation = translations[lang];
      
      if (translation == null) {
        issues.add(ValidationIssue(
          key: key,
          language: lang,
          type: ValidationIssueType.missingTranslation,
          description: 'Translation key is missing',
          suggestion: 'Add translation for this key',
        ));
      } else if (translation.trim().isEmpty) {
        issues.add(ValidationIssue(
          key: key,
          language: lang,
          type: ValidationIssueType.emptyTranslation,
          description: 'Translation is empty',
          suggestion: 'Provide a meaningful translation',
        ));
      }
    }

    // Check length consistency between English and Urdu
    final enTranslation = translations['en'];
    final urTranslation = translations['ur'];
    
    if (enTranslation != null && urTranslation != null && 
        enTranslation.isNotEmpty && urTranslation.isNotEmpty) {
      
      final lengthDiff = (enTranslation.length - urTranslation.length).abs();
      final maxLength = enTranslation.length > urTranslation.length 
          ? enTranslation.length 
          : urTranslation.length;
      
      if (maxLength > 0) {
        final percentDiff = (lengthDiff / maxLength) * 100;
        
        if (percentDiff > _maxLengthDifferencePercent) {
          issues.add(ValidationIssue(
            key: key,
            language: 'ur',
            type: ValidationIssueType.lengthMismatch,
            description: 'Significant length difference between English and Urdu translations (${percentDiff.toStringAsFixed(1)}%)',
            suggestion: 'Review translation for completeness',
          ));
        }
      }
    }

    // Check for RTL-specific issues in Urdu
    if (urTranslation != null && urTranslation.isNotEmpty) {
      issues.addAll(_validateRTLTranslation(key, urTranslation));
    }

    return issues;
  }

  /// Validate RTL-specific issues
  static List<ValidationIssue> _validateRTLTranslation(String key, String translation) {
    final List<ValidationIssue> issues = [];

    // Check for mixed LTR/RTL characters that might cause layout issues
    final hasLTR = RegExp(r'[a-zA-Z]').hasMatch(translation);
    final hasRTL = RegExp(r'[\u0600-\u06FF]').hasMatch(translation);
    
    if (hasLTR && hasRTL) {
      // This is common and often acceptable, but flag for review
      if (translation.split(RegExp(r'[a-zA-Z]+')).length > 3) {
        issues.add(ValidationIssue(
          key: key,
          language: 'ur',
          type: ValidationIssueType.rtlLayoutIssue,
          description: 'Multiple LTR segments in RTL text may cause layout issues',
          suggestion: 'Consider restructuring or using proper text direction markers',
        ));
      }
    }

    return issues;
  }

  /// Validate terminology consistency across translations
  static List<ValidationIssue> _validateTerminologyConsistency(LocalizationService service) {
    final List<ValidationIssue> issues = [];
    
    // Check if common terms are translated consistently
    for (String term in _commonTerms) {
      final Map<String, List<String>> termUsage = {};
      
      // Find all keys that contain this term
      for (String lang in LocalizationService.primaryLanguages) {
        final translations = service.keys[lang] ?? {};
        termUsage[lang] = [];
        
        for (String key in translations.keys) {
          final translation = translations[key];
          if (translation != null && translation.toLowerCase().contains(term.toLowerCase())) {
            termUsage[lang]!.add('$key: $translation');
          }
        }
      }
      
      // Check for inconsistent usage (this is a basic check)
      if (termUsage['en']!.isNotEmpty && termUsage['ur']!.isEmpty) {
        issues.add(ValidationIssue(
          key: 'terminology_$term',
          language: 'ur',
          type: ValidationIssueType.inconsistentTerminology,
          description: 'Term "$term" appears in English but not in Urdu translations',
          suggestion: 'Ensure consistent terminology across languages',
        ));
      }
    }

    return issues;
  }

  /// Generate a validation report
  static String generateValidationReport(List<ValidationIssue> issues) {
    if (issues.isEmpty) {
      return '✅ All translations are valid!';
    }

    final StringBuffer report = StringBuffer();
    report.writeln('🔍 Translation Validation Report');
    report.writeln('=' * 50);
    report.writeln('Total issues found: ${issues.length}');
    report.writeln('');

    // Group issues by type
    final Map<ValidationIssueType, List<ValidationIssue>> groupedIssues = {};
    for (ValidationIssue issue in issues) {
      groupedIssues.putIfAbsent(issue.type, () => []).add(issue);
    }

    // Report each type
    for (ValidationIssueType type in ValidationIssueType.values) {
      final typeIssues = groupedIssues[type] ?? [];
      if (typeIssues.isNotEmpty) {
        report.writeln('${_getTypeIcon(type)} ${type.name.toUpperCase()} (${typeIssues.length} issues):');
        for (ValidationIssue issue in typeIssues.take(5)) {
          report.writeln('  • ${issue.toString()}');
        }
        if (typeIssues.length > 5) {
          report.writeln('  ... and ${typeIssues.length - 5} more');
        }
        report.writeln('');
      }
    }

    return report.toString();
  }

  /// Get icon for validation issue type
  static String _getTypeIcon(ValidationIssueType type) {
    switch (type) {
      case ValidationIssueType.missingTranslation:
        return '❌';
      case ValidationIssueType.emptyTranslation:
        return '⚠️';
      case ValidationIssueType.inconsistentTerminology:
        return '🔄';
      case ValidationIssueType.lengthMismatch:
        return '📏';
      case ValidationIssueType.specialCharacterMismatch:
        return '🔤';
      case ValidationIssueType.rtlLayoutIssue:
        return '↔️';
      case ValidationIssueType.translationError:
        return '🚨';
      case ValidationIssueType.systemError:
        return '💥';
      case ValidationIssueType.loadingFailure:
        return '📂';
    }
  }

  /// Print validation report to debug console
  static void printValidationReport() {
    if (!kDebugMode) return;
    
    final issues = validateAllTranslations();
    final report = generateValidationReport(issues);
    debugPrint(report);
  }

  /// Quick validation check - returns true if no critical issues
  static bool isTranslationValid() {
    final issues = validateAllTranslations();
    return !issues.any((issue) => 
        issue.type == ValidationIssueType.missingTranslation ||
        issue.type == ValidationIssueType.emptyTranslation ||
        issue.type == ValidationIssueType.systemError ||
        issue.type == ValidationIssueType.loadingFailure);
  }

  /// Get validation summary
  static Map<String, dynamic> getValidationSummary() {
    final issues = validateAllTranslations();
    final Map<ValidationIssueType, int> typeCounts = {};
    
    for (ValidationIssue issue in issues) {
      typeCounts[issue.type] = (typeCounts[issue.type] ?? 0) + 1;
    }

    return {
      'total_issues': issues.length,
      'is_valid': isTranslationValid(),
      'issue_counts': typeCounts.map((key, value) => MapEntry(key.name, value)),
      'critical_issues': (typeCounts[ValidationIssueType.missingTranslation] ?? 0) +
                        (typeCounts[ValidationIssueType.emptyTranslation] ?? 0) +
                        (typeCounts[ValidationIssueType.systemError] ?? 0) +
                        (typeCounts[ValidationIssueType.loadingFailure] ?? 0),
    };
  }
}