import 'package:flutter/cupertino.dart';

class AppColors {
  static const accent = Color(0xFF50E3C2);
  static const accentDark = Color(0xFF2AB3A6);
  static const backgroundLight = Color(0xFFF5F7FB);
  static const backgroundDark = Color(0xFF0E1116);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF161B22);
}

CupertinoThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: AppColors.accent,
    barBackgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
    scaffoldBackgroundColor:
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
    textTheme: CupertinoTextThemeData(
      navTitleTextStyle: TextStyle(
        color: isDark ? CupertinoColors.white : CupertinoColors.black,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      textStyle: TextStyle(
        color: isDark ? CupertinoColors.white : CupertinoColors.black,
        fontSize: 16,
      ),
    ),
  );
}
