import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'widgets/app_background.dart';

class DanceStudyTrackerApp extends StatelessWidget {
  const DanceStudyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Folk's Study Progress Tracker",
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: tp.themeMode,

      // OPTIMIZATION: Smoothly animate the transitions between themes
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,

      // One gradient behind the whole Navigator. Because scaffolds and app
      // bars are transparent (see AppTheme), it shows through every screen,
      // dialog backdrop, and tab without wrapping each one individually.
      builder: (context, child) => AppBackground(child: child ?? const SizedBox.shrink()),

      home: const SplashScreen(),
    );
  }
}