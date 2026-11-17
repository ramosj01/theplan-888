import 'package:flutter/material.dart';

class AppColors {
  static const bgTop = Color(0xFF0A0E27);
  static const bgMid = Color(0xFF1B1446);
  static const bgBottom = Color(0xFF0B2B45);

  static const violet = Color(0xFF7F5AF0);
  static const cyan = Color(0xFF2CB1FF);
  static const pink = Color(0xFFFF6AD5);
  static const mint = Color(0xFF2EE6A6);
  static const amber = Color(0xFFFFC857);
  static const danger = Color(0xFFFF5C7A);

  static const textPrimary = Color(0xFFF4F5FF);
  static const textSecondary = Color(0xFFADB3D6);

  static const accent = LinearGradient(
    colors: [violet, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentWarm = LinearGradient(
    colors: [pink, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const background = LinearGradient(
    colors: [bgTop, bgMid, bgBottom],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: Brightness.dark,
      primary: AppColors.violet,
      secondary: AppColors.cyan,
      surface: AppColors.bgTop,
      error: AppColors.danger,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme
          .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary)
          .copyWith(
            headlineLarge: const TextStyle(
                fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: AppColors.textPrimary),
            headlineMedium: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.textPrimary),
            titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            bodyMedium: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textSecondary),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF241D55),
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
    );
  }
}
