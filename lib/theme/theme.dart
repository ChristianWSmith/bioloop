import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light([Color? seedColor]) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor ?? Colors.deepPurple,
        ),
      );

  static ThemeData dark([Color? seedColor]) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor ?? Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      );
}
