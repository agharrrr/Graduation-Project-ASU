import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'Admin/Screens/admin_login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Standalone admin theme (no AppTheme.build -> avoids "mode" parameter mismatch)
    final ThemeData adminTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B5FFF),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Color(0xFFF5F5F7),
        surfaceTintColor: Colors.transparent,
      ),
    );

    return MaterialApp(
      title: 'ShooFi Admin',
      debugShowCheckedModeBanner: false,
      theme: adminTheme,
      home: const AdminLoginScreen(),
    );
  }
}
