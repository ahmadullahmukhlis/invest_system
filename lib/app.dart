import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/app_shell.dart';
import 'core/widgets/app_scroll_behavior.dart';

class InvestSystemApp extends StatelessWidget {
  const InvestSystemApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = Theme.of(context).textTheme;
    final colorScheme = const ColorScheme.light(
      primary: AppColors.indigo,
      secondary: AppColors.accent,
      surface: AppColors.card,
      background: AppColors.canvas,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF1F2A44),
      onBackground: Color(0xFF1F2A44),
      onError: Colors.white,
    );

    return MaterialApp(
      title: 'Bulk Sales & Accounting',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.canvas,
        fontFamily: _desktopFontFamily(),
        textTheme: baseTextTheme.copyWith(
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          titleSmall: baseTextTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ).apply(
          bodyColor: const Color(0xFF1F2A44),
          displayColor: const Color(0xFF1F2A44),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
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
          elevation: 0.5,
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

String? _desktopFontFamily() {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
      return 'Segoe UI';
    case TargetPlatform.macOS:
      return 'SF Pro Text';
    default:
      return null;
  }
}
