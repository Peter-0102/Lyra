import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF1DB954);
  static const Color primaryVariant = Color(0xFF1ED760);
  static const Color onPrimary = Colors.white;

  // Secondary palette
  static const Color secondary = Color(0xFF191414);
  static const Color secondaryVariant = Color(0xFF282828);
  static const Color onSecondary = Colors.white;

  // Background
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color surfaceLight = Colors.white;
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF282828);

  // Text
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFFB3B3B3);
  static const Color textPrimaryLight = Color(0xFF191414);
  static const Color textSecondaryLight = Color(0xFF535353);

  // Player controls
  static const Color playerProgress = Color(0xFF1DB954);
  static const Color playerProgressBackground = Color(0xFF4D4D4D);
  static const Color miniPlayerBackground = Color(0xFF2A2A2A);

  // Download states
  static const Color downloadActive = Color(0xFF1DB954);
  static const Color downloadError = Color(0xFFE91E63);
  static const Color downloadQueued = Color(0xFF9E9E9E);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE91E63);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);
}
