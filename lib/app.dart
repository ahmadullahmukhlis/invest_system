import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/app_shell.dart';

class InvestSystemApp extends StatelessWidget {
  const InvestSystemApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.spaceGroteskTextTheme();
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Bulk Sales & Accounting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.canvas,
        textTheme: baseTextTheme.apply(
          bodyColor: const Color(0xFF1F2A44),
          displayColor: const Color(0xFF1F2A44),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.canvas,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: AppColors.indigo),
          titleTextStyle: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.indigo,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.card,
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          dense: false,
          minVerticalPadding: 10,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE5E7EB),
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.indigo,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.indigo,
          contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
            color: Colors.white,
          ),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titleTextStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.indigo,
          ),
        ),
      ),
      home: home,
    );
  }
}
