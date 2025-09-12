class SupportedLanguageModel {
  final String code;
  final String name;
  final String nativeName;
  final bool isRTL;
  final String flag;

  const SupportedLanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.isRTL,
    required this.flag,
  });

  static const List<SupportedLanguageModel> supportedLanguages = [
    SupportedLanguageModel(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      isRTL: false,
      flag: '🇺🇸',
    ),
    SupportedLanguageModel(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      isRTL: true,
      flag: '🇸🇦',
    ),
    SupportedLanguageModel(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      isRTL: false,
      flag: '🇫🇷',
    ),
    SupportedLanguageModel(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      isRTL: true,
      flag: '🇵🇰',
    ),
  ];

  static SupportedLanguageModel? getLanguageByCode(String code) {
    try {
      return supportedLanguages.firstWhere((lang) => lang.code == code);
    } catch (e) {
      return null;
    }
  }

  static SupportedLanguageModel get defaultLanguage => supportedLanguages.first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupportedLanguageModel &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'SupportedLanguageModel(code: $code, name: $name, nativeName: $nativeName)';
}