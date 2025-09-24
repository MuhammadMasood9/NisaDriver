import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/controller/global_setting_conroller.dart';
import 'package:driver/controller/language_controller.dart';
import 'package:driver/firebase_options.dart';
import 'package:driver/services/app_lifecycle_service.dart';
import 'package:driver/services/dynamic_timer_service.dart';
import 'package:driver/services/translation_manager.dart';
import 'package:driver/services/translation_validator.dart';
import 'package:driver/utils/translation_demo.dart';
import 'package:driver/ui/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'services/localization_service.dart';
import 'utils/Preferences.dart';
import 'utils/language_utils.dart';
import 'themes/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    print('Firebase initialized successfully');
  }

  await Preferences.initPref();

  // Initialize LanguageController first for better performance
  final languageController = Get.put(LanguageController());

  // Initialize language from saved preference with performance optimization
  await languageController.initializeLanguage();

  // Preload translations for better performance
  await LanguageUtils.preloadTranslations();

  // Initialize enhanced localization features in debug mode
  if (kDebugMode) {
    _initializeEnhancedLocalization();
  }

  // Configure global loader appearance/behavior
  _configLoading();

  // Initialize GlobalSettingController at app startup
  Get.put(GlobalSettingController());

  // Initialize AppLifecycleService for automatic online/offline management
  Get.put(AppLifecycleService());

  // Initialize DynamicTimerService for timer management
  Get.put(DynamicTimerService());

  runApp(const MyApp());
}

void _configLoading() {
  EasyLoading.instance
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.custom
    ..maskType = EasyLoadingMaskType.black
    ..userInteractions = false
    ..dismissOnTap = false
    ..indicatorSize = 42.0
    ..radius = 10.0
    ..backgroundColor = Colors.white
    ..indicatorColor = AppColors.primary
    ..textColor = AppColors.darkBackground
    ..progressColor = AppColors.primary;
}

/// Initialize enhanced localization features for development
void _initializeEnhancedLocalization() {
  if (!kDebugMode) return;

  // Print initial translation coverage report
  LocalizationService.printTranslationCoverageReport();

  // Print validation report
  TranslationValidator.printValidationReport();

  // Print comprehensive translation report
  TranslationManager.printTranslationReport();

  // Run error handling demonstration
  TranslationDemo.runAllDemonstrations();

  print('🌐 Enhanced localization features initialized');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // This widget is the root of your application.
  // DarkThemeProvider themeChangeProvider = DarkThemeProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Handle app termination - set driver offline
    AppLifecycleService.handleAppTermination();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // The AppLifecycleService handles lifecycle changes automatically
    // through its own WidgetsBindingObserver implementation
    if (kDebugMode) {
      print('Main app lifecycle state changed to: $state');
    }
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    // Handle memory pressure if needed
    if (kDebugMode) {
      print('Memory pressure detected');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LanguageController>(
      builder: (languageController) {
        return GetMaterialApp(
          title: 'NisaRide'.tr,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            CountryLocalizations.delegate,
          ],
          supportedLocales: LocalizationService.locales,
          locale: Locale(languageController.currentLanguageCode),
          fallbackLocale: LocalizationService.locale,
          translations: LocalizationService(),
          builder: (context, child) {
            // Apply RTL support and EasyLoading initialization
            final easyLoadingChild = EasyLoading.init()(context, child);

            // Get text direction from optimized controller
            final textDirection = languageController.getTextDirection();

            return Directionality(
              textDirection: textDirection,
              child: easyLoadingChild,
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
