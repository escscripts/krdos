import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Log-paper style horizontal rules ? stays in the background.
class AuthDeskGrid extends StatelessWidget {
  const AuthDeskGrid({super.key, this.lineStep = 44});

  final double lineStep;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DeskRulePainter(lineStep: lineStep),
      child: const SizedBox.expand(),
    );
  }
}

class _DeskRulePainter extends CustomPainter {
  _DeskRulePainter({required this.lineStep});

  final double lineStep;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += lineStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DeskRulePainter old) => old.lineStep != lineStep;
}

/// Flat panel: looks like a focused window on the desktop, not a game modal.
class AuthFramePanel extends StatelessWidget {
  const AuthFramePanel({
    super.key,
    required this.child,
    this.title,
    this.maxWidth = 520,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 22),
  });

  final Widget child;
  final String? title;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceAlt,
                border: Border(
                  bottom: BorderSide(color: AppTheme.border),
                ),
              ),
              child: Text(
                title!,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}
