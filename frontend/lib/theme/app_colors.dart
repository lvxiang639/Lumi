import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Light Mode ──
  static const lightBg = Color(0xFFF5F5F5);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBubbleUser = Color(0xFFDCF8C6);
  static const lightBubbleAi = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE5E5EA);

  // ── Dark Mode ──
  static const darkBg = Color(0xFF0D1117);
  static const darkCard = Color(0xFF161B22);
  static const darkBubbleUser = Color(0xFF056B42);
  static const darkBubbleAi = Color(0xFF1C2129);
  static const darkBorder = Color(0xFF21262D);

  // ── Shared Accent ──
  static const accent = Color(0xFF10B981);
  static const accentBlue = Color(0xFF3B82F6);
  static const online = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);

  // ── Text ──
  static const textLight = Color(0xFF1A1A1A);
  static const textLightSecondary = Color(0xFF8E8E93);
  static const textDark = Color(0xFFE6E6E6);
  static const textDarkSecondary = Color(0xFF8B949E);

  // ── Brightness-dependent accessors ──
  static Color bg(Brightness b) =>
      b == Brightness.light ? lightBg : darkBg;
  static Color card(Brightness b) =>
      b == Brightness.light ? lightCard : darkCard;
  static Color bubbleUser(Brightness b) =>
      b == Brightness.light ? lightBubbleUser : darkBubbleUser;
  static Color bubbleAi(Brightness b) =>
      b == Brightness.light ? lightBubbleAi : darkBubbleAi;
  static Color border(Brightness b) =>
      b == Brightness.light ? lightBorder : darkBorder;
  static Color text(Brightness b) =>
      b == Brightness.light ? textLight : textDark;
  static Color textSecondary(Brightness b) =>
      b == Brightness.light ? textLightSecondary : textDarkSecondary;
}
