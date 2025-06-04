import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/global_setting_conroller.dart';
import 'package:driver/firebase_options.dart';
import 'package:driver/ui/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'services/localization_service.dart';
import 'utils/Preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check
  try {
    await FirebaseAppCheck.instance.activate(
      // Use Play Integrity for Android in production
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      // Use DeviceCheck for iOS in production
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );

    if (kDebugMode) {
      print('Firebase App Check activated successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Firebase App Check activation failed: $e');
    }
    // Continue without App Check if activation fails
  }

  await Preferences.initPref();
  runApp(const MyApp());
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
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'NisaRide'.tr,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        CountryLocalizations.delegate,
      ],
      locale: LocalizationService.locale,
      fallbackLocale: LocalizationService.locale,
      translations: LocalizationService(),
      builder: EasyLoading.init(),
      home: GetX<GlobalSettingController>(
        init: GlobalSettingController(),
        builder: (controller) {
          return controller.isLoading.value
              ? Constant.loader(context)
              : const SplashScreen();
        },
      ),
    );
  }
}
