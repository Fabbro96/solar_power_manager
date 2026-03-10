import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color background = Colors.black;
  static const Color primary = Color.fromRGBO(100, 200, 255, 1);
  static const Color accent = Color.fromRGBO(0, 255, 255, 1);
  static const Color accentFaded = Color.fromRGBO(0, 255, 255, 0.2);
  static const Color label = Color.fromRGBO(150, 180, 255, 1);
  static const Color subtitle = Color.fromRGBO(180, 180, 255, 1);
  static const Color gridLine = Color.fromRGBO(100, 150, 200, 0.5);
  static const Color muted = Colors.white24;
  static const Color axisTick = Colors.white60;
}

abstract final class AppTextStyles {
  static const TextStyle appBarTitle = TextStyle(
    color: AppColors.primary,
    fontSize: 20,
    fontWeight: FontWeight.w300,
  );

  static const TextStyle label = TextStyle(
    color: AppColors.label,
    fontSize: 14,
  );

  static const TextStyle value = TextStyle(
    color: AppColors.primary,
    fontSize: 28,
    fontWeight: FontWeight.w200,
  );

  static const TextStyle subtitle = TextStyle(
    color: AppColors.subtitle,
    fontSize: 14,
    fontWeight: FontWeight.w300,
  );

  static const TextStyle muted = TextStyle(
    color: AppColors.muted,
    fontSize: 12,
  );

  static const TextStyle axisTick = TextStyle(
    color: AppColors.axisTick,
    fontSize: 10,
  );

  static const TextStyle axisLabel = TextStyle(
    color: AppColors.axisTick,
    fontSize: 13,
  );
}

ThemeData buildAppTheme() {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleTextStyle: AppTextStyles.appBarTitle,
    ),
  );
}
