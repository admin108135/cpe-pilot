import 'package:flutter/material.dart';

/// 色板取自 CPE Ultra 的界面常量（dex 中提取的真实值）。
/// 主视觉：浅底 + 蓝紫渐变，状态色区分良好/警告/异常。
class AppColors {
  // 品牌主色（蓝）
  static const primary = Color(0xFF3B82F6);
  static const primaryBright = Color(0xFF5B9CFF);
  static const primaryDeep = Color(0xFF2D5399);

  // 辅色（紫）
  static const secondary = Color(0xFF8B7CF6);
  static const secondaryBright = Color(0xFFA294FF);

  // 状态色
  static const success = Color(0xFF28C76F);
  static const successBright = Color(0xFF3EDC86);
  static const warning = Color(0xFFF5A623);
  static const warningBright = Color(0xFFFFB84D);
  static const danger = Color(0xFFF2545B);
  static const dangerBright = Color(0xFFFF6B72);

  // 中性
  static const bg = Color(0xFFF4F7FC);
  static const bgAlt = Color(0xFFEDF1F9);
  static const card = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE8EEF7);
  static const border = Color(0xFFB9C8DC);

  // 文字层级
  static const textPrimary = Color(0xFF161C28);
  static const textSecondary = Color(0xFF2B3446);
  static const textBody = Color(0xFF49576F);
  static const textMuted = Color(0xFF5D708E);

  static const gradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      Color(0xFF3EDC86),
      Color(0xFF22B5C8),
      Color(0xFF3B82F6),
      Color(0xFF8B7CF6),
    ],
  );

  static const gradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEEF3FF), Color(0xFFF3EFFF)],
  );
}

class AppRadius {
  static const card = 20.0;
  static const chip = 12.0;
  static const sheet = 28.0;
}

/// 柔和投影：浅色卡片在浅底上更轻盈
List<BoxShadow> softShadow({double y = 6, double blur = 20}) => [
      BoxShadow(
        color: const Color(0xFF2D5399).withOpacity(0.07),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    tertiary: AppColors.success,
    error: AppColors.danger,
    surface: AppColors.card,
    onSurface: AppColors.textPrimary,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
  );

  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      iconTheme: const IconThemeData(color: AppColors.textBody),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textSecondary,
      displayColor: AppColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgAlt,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
