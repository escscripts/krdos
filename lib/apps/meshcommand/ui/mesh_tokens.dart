import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Visual language aligned with the host OS (`AppTheme`) so MeshCommand feels native.
abstract final class MeshTokens {
  static Color bg() => AppTheme.background;

  static Color surface() => AppTheme.surface;

  static Color elevated() => AppTheme.surfaceAlt;

  static Color border() => AppTheme.border.withValues(alpha: 0.75);

  static Color accent() => AppTheme.accent;

  static Color accentMuted() => AppTheme.accentDim;

  static Color textPrimary() => AppTheme.textPrimary;

  static Color textSecondary() => AppTheme.textSecondary;

  static Color success() => AppTheme.success.withValues(alpha: 0.9);

  static Color warning() => AppTheme.warning.withValues(alpha: 0.95);

  static Color danger() => AppTheme.danger.withValues(alpha: 0.92);

  static BorderSide hairlineBorder() =>
      BorderSide(color: AppTheme.border.withValues(alpha: 0.65));

  static List<BoxShadow> panelShadow() => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static EdgeInsets screenPadding() => const EdgeInsets.fromLTRB(16, 12, 16, 16);
}
