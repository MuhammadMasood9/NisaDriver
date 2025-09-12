import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'language_utils.dart';

/// Utility class for testing RTL layout and functionality
class RTLTestUtils {
  /// Test RTL layout for various UI components
  static void testRTLLayouts() {
    if (!kDebugMode) return;
    
    debugPrint('\n🔄 RTL Layout Testing Started');
    debugPrint('=' * 50);
    
    // Test current language RTL status
    final currentLang = LanguageUtils.getCurrentLanguage();
    final isRTL = LanguageUtils.isRTL(currentLang);
    final textDirection = LanguageUtils.getTextDirection(currentLang);
    
    debugPrint('Current Language: $currentLang');
    debugPrint('Is RTL: $isRTL');
    debugPrint('Text Direction: $textDirection');
    debugPrint('Text Align: ${LanguageUtils.getTextAlign()}');
    debugPrint('Main Axis Alignment: ${LanguageUtils.getMainAxisAlignment()}');
    debugPrint('Cross Axis Alignment: ${LanguageUtils.getCrossAxisAlignment()}');
    
    // Test Urdu-specific features
    if (LanguageUtils.isCurrentLanguageUrdu()) {
      debugPrint('\n📝 Urdu-specific features:');
      debugPrint('Font Family: ${LanguageUtils.getUrduFontFamily() ?? "System Default"}');
      debugPrint('Is Current Language Urdu: ${LanguageUtils.isCurrentLanguageUrdu()}');
      
      // Test text formatting
      const testText = 'یہ ایک ٹیسٹ ہے';
      final formattedText = LanguageUtils.formatRTLText(testText);
      debugPrint('Original Text: $testText');
      debugPrint('Formatted Text: $formattedText');
    }
    
    debugPrint('=' * 50);
    debugPrint('🔄 RTL Layout Testing Completed\n');
  }

  /// Test input field RTL behavior
  static void testInputFieldRTL(TextEditingController controller) {
    if (!kDebugMode) return;
    
    debugPrint('\n⌨️ Input Field RTL Testing');
    debugPrint('Current text: "${controller.text}"');
    debugPrint('Text length: ${controller.text.length}');
    debugPrint('Selection: ${controller.selection}');
    
    if (LanguageUtils.isCurrentLanguageUrdu()) {
      final formattedText = LanguageUtils.formatRTLText(controller.text);
      debugPrint('Formatted for RTL: "$formattedText"');
    }
  }

  /// Test layout measurements for RTL
  static void testLayoutMeasurements(BuildContext context) {
    if (!kDebugMode) return;
    
    debugPrint('\n📐 Layout Measurements for RTL');
    final mediaQuery = MediaQuery.of(context);
    final textDirection = Directionality.of(context);
    
    debugPrint('Screen width: ${mediaQuery.size.width}');
    debugPrint('Screen height: ${mediaQuery.size.height}');
    debugPrint('Text direction from context: $textDirection');
    debugPrint('Text scale factor: ${mediaQuery.textScaler.scale(1.0)}');
    debugPrint('Device pixel ratio: ${mediaQuery.devicePixelRatio}');
    
    // Test padding adjustments
    const testPadding = EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 12);
    debugPrint('Original padding: $testPadding');
    
    if (LanguageUtils.isCurrentLanguageRTL()) {
      final flippedPadding = EdgeInsets.only(
        left: testPadding.right,
        right: testPadding.left,
        top: testPadding.top,
        bottom: testPadding.bottom,
      );
      debugPrint('RTL flipped padding: $flippedPadding');
    }
  }

  /// Test text rendering for Urdu
  static void testUrduTextRendering(String text) {
    if (!kDebugMode) return;
    
    debugPrint('\n🔤 Urdu Text Rendering Test');
    debugPrint('Input text: "$text"');
    debugPrint('Text length: ${text.length}');
    debugPrint('Contains Arabic/Urdu characters: ${_containsUrduCharacters(text)}');
    
    if (LanguageUtils.isCurrentLanguageUrdu()) {
      final styledText = LanguageUtils.formatRTLText(text);
      debugPrint('RTL formatted text: "$styledText"');
    }
    
    // Test character analysis
    final runes = text.runes.toList();
    debugPrint('Character count (runes): ${runes.length}');
    debugPrint('First 5 character codes: ${runes.take(5).toList()}');
  }

  /// Check if text contains Urdu/Arabic characters
  static bool _containsUrduCharacters(String text) {
    // Unicode ranges for Arabic/Urdu characters
    final urduRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return urduRegex.hasMatch(text);
  }

  /// Test form validation with RTL text
  static String? testFormValidation(String? value, String fieldName) {
    if (!kDebugMode) return null;
    
    debugPrint('\n✅ Form Validation Test for RTL');
    debugPrint('Field: $fieldName');
    debugPrint('Value: "$value"');
    debugPrint('Is empty: ${value?.isEmpty ?? true}');
    
    if (value != null && LanguageUtils.isCurrentLanguageUrdu()) {
      debugPrint('Contains Urdu characters: ${_containsUrduCharacters(value)}');
      debugPrint('Formatted value: "${LanguageUtils.formatRTLText(value)}"');
    }
    
    return null; // Return null for testing purposes
  }

  /// Test navigation and routing with RTL
  static void testNavigationRTL(BuildContext context, String routeName) {
    if (!kDebugMode) return;
    
    debugPrint('\n🧭 Navigation RTL Test');
    debugPrint('Current route: $routeName');
    debugPrint('Text direction: ${Directionality.of(context)}');
    debugPrint('Locale: ${Localizations.localeOf(context)}');
    
    final navigator = Navigator.of(context);
    debugPrint('Can pop: ${navigator.canPop()}');
  }

  /// Generate RTL test report
  static Map<String, dynamic> generateRTLTestReport() {
    final report = <String, dynamic>{};
    
    report['timestamp'] = DateTime.now().toIso8601String();
    report['current_language'] = LanguageUtils.getCurrentLanguage();
    report['is_rtl'] = LanguageUtils.isCurrentLanguageRTL();
    report['is_urdu'] = LanguageUtils.isCurrentLanguageUrdu();
    report['text_direction'] = LanguageUtils.getTextDirection(LanguageUtils.getCurrentLanguage()).toString();
    report['text_align'] = LanguageUtils.getTextAlign().toString();
    
    // Test various text samples
    final testTexts = [
      'Hello World',
      'سلام دنیا',
      'مرحبا بالعالم',
      '123 ABC اردو',
      'Mixed نص Text',
    ];
    
    report['text_tests'] = testTexts.map((text) => {
      'original': text,
      'contains_urdu': _containsUrduCharacters(text),
      'formatted': LanguageUtils.formatRTLText(text),
      'length': text.length,
      'runes_count': text.runes.length,
    }).toList();
    
    if (kDebugMode) {
      debugPrint('\n📊 RTL Test Report Generated');
      debugPrint('Report: $report');
    }
    
    return report;
  }

  /// Print comprehensive RTL status
  static void printRTLStatus() {
    if (!kDebugMode) return;
    
    debugPrint('\n🌐 Comprehensive RTL Status');
    debugPrint('=' * 60);
    
    final currentLang = LanguageUtils.getCurrentLanguage();
    final languageModel = LanguageUtils.getCurrentLanguageModel();
    
    debugPrint('Language Code: $currentLang');
    debugPrint('Language Name: ${languageModel.name}');
    debugPrint('Native Name: ${languageModel.nativeName}');
    debugPrint('Is RTL: ${languageModel.isRTL}');
    debugPrint('Flag: ${languageModel.flag}');
    
    debugPrint('\nLayout Properties:');
    debugPrint('  Text Direction: ${LanguageUtils.getTextDirection(currentLang)}');
    debugPrint('  Text Align: ${LanguageUtils.getTextAlign()}');
    debugPrint('  Main Axis Alignment: ${LanguageUtils.getMainAxisAlignment()}');
    debugPrint('  Cross Axis Alignment: ${LanguageUtils.getCrossAxisAlignment()}');
    
    if (LanguageUtils.isCurrentLanguageUrdu()) {
      debugPrint('\nUrdu-specific Properties:');
      debugPrint('  Font Family: ${LanguageUtils.getUrduFontFamily() ?? "System Default"}');
      debugPrint('  Is Current Language Urdu: true');
    }
    
    debugPrint('=' * 60);
  }
}