import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'shell_accent.dart';

class AppTheme {
  static const Color background   = Color(0xFF050A0E);
  static const Color surface      = Color(0xFF0D1117);
  static const Color surfaceAlt   = Color(0xFF161B22);
  static const Color textPrimary  = Color(0xFFE6EDF3);
  static const Color textSecondary= Color(0xFF8B949E);
  static const Color border       = Color(0xFF30363D);
  static const Color danger       = Color(0xFFFF4444);
  static const Color warning      = Color(0xFFFFAA00);
  static const Color success      = Color(0xFF00FF88);

  static Color _accent = kShellDefaultAccent;
  /// Current shell accent; kept in sync with [SettingsState.accentColor] from [KrdOSApp.build].
  static Color get accent => _accent;
  static Color get accentDim => _accent.withValues(alpha: 0.22);

  static void syncAccentFrom(Color c) {
    _accent = c;
  }

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      surface: surface,
      primary: kShellDefaultAccent,
      secondary: surfaceAlt,
    ),
    textTheme: GoogleFonts.sourceCodeProTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    ),
    iconTheme: const IconThemeData(color: kShellDefaultAccent),
  );
}
