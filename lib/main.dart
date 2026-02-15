import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'Splash/splash_screen.dart';
import 'Auth/role_login.dart';
import 'Auth/auth_service.dart';
import 'Organizer/organizer_controller.dart';
import 'Organizer/Widgets/firestore_organizer_repository.dart';
import 'shared/theme/theme_controller.dart';
import 'shared/theme/app_theme.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ShooFiApp());
}

/// Controls app locale (EN/AR) without needing full l10n files.
class LocaleController extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  void setLocale(String code) {
    final next = Locale(code);
    if (next.languageCode == _locale.languageCode) return;
    _locale = next;
    notifyListeners();
  }
}

class ShooFiApp extends StatelessWidget {
  const ShooFiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => LocaleController()),

        ChangeNotifierProvider(
          create: (_) => OrganizerController(
            FirestoreOrganizerRepository(FirebaseFirestore.instance),
            AuthService.instance,
          ),
        ),
      ],
      child: Consumer2<ThemeController, LocaleController>(
        builder: (context, themeCtrl, localeCtrl, _) {
          return MaterialApp(
            title: 'ShooFi',
            debugShowCheckedModeBanner: false,

            // Global role-based theme
            theme: AppTheme.build(role: themeCtrl.role, mode: ThemeMode.light),
            darkTheme: AppTheme.build(role: themeCtrl.role, mode: ThemeMode.dark),
            themeMode: themeCtrl.mode,

            // Locale handling
            locale: localeCtrl.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('ar'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            home: const SplashScreen(
              next: RoleLoginScreen(),
            ),
          );
        },
      ),
    );
  }
}
