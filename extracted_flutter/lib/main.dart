import 'package:flutter/material.dart';

import 'screens/splash/splash_screen.dart';

import 'app_startup.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await AppStartup.init();

  runApp(const AlFashnApp());
}

class AlFashnApp extends StatelessWidget {
  const AlFashnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'برنامج إدارة المخالفات',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6B55),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F2EA),
        dialogBackgroundColor: Colors.white,
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF05352D),
          ),
          contentTextStyle: TextStyle(
            fontSize: 14,
            color: Color(0xFF2D2D2D),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 4,
          textStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF2D2D2D),
          ),
        ),
        dropdownMenuTheme: const DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.white),
            surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
            elevation: WidgetStatePropertyAll(4),
          ),
        ),
        cardColor: Colors.white,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}