import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Slow-moving gradient mesh + technical grid for sign-in / setup flows.
class AuthSessionBackdrop extends StatefulWidget {
  const AuthSessionBackdrop({
    super.key,
    required this.child,
    this.overWallpaper = false,
  });

  final Widget child;

  /// When true, uses a light scrim so a user wallpaper can show through underneath.
  final bool overWallpaper;

  @override
  State<AuthSessionBackdrop> createState() => _AuthSessionBackdropState();
}

class _AuthSessionBackdropState extends State<AuthSessionBackdrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_drift.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (!widget.overWallpaper)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF020508),
                  gradient: LinearGradient(
                    begin: Alignment(-1 + t * 0.35, -1.05),
                    end: Alignment(1.05, 1 - t * 0.25),
                    stops: const [0.0, 0.45, 1.0],
                    colors: [
                      Color.lerp(
                        const Color(0xFF071018),
                        const Color(0xFF0C1624),
                        t,
                      )!,
                      const Color(0xFF03060C),
                      Color.lerp(
                        const Color(0xFF060810),
                        const Color(0xFF12081C),
                        t,
                      )!,
                    ],
                  ),
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.42 + t * 0.06),
                      Colors.black.withValues(alpha: 0.58),
                    ],
                  ),
                ),
              ),
            CustomPaint(
              painter: _AuthMeshPainter(
                opacity: 0.035 + t * 0.015,
              ),
              child: const SizedBox.expand(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.15 - t * 0.1, -0.72),
                  radius: 1.05,
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.07),
                    AppTheme.accent.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.75 + t * 0.05, 0.85),
                  radius: 0.95,
                  colors: [
                    const Color(0xFF1E1038).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _AuthMeshPainter extends CustomPainter {
  _AuthMeshPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 1;
    const step = 56.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuthMeshPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

/// Horizontal segment progress (setup wizard).
class AuthSetupProgressSegments extends StatelessWidget {
  const AuthSetupProgressSegments({
    super.key,
    required this.index,
    required this.total,
  });

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i < index;
        final active = i == index;
        return Expanded(
          child: Container(
            height: 2,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              color: done || active
                  ? AppTheme.accent.withValues(alpha: active ? 1 : 0.45)
                  : Colors.white.withValues(alpha: 0.08),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.35),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class AuthGlassPanel extends StatelessWidget {
  const AuthGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
    this.maxWidth = 440,
  });

  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0A1018).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.09),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 48,
                offset: const Offset(0, 28),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Monospace caption  protocol / status line aesthetic.
TextStyle authMonoCaption(BuildContext context, {double opacity = 0.55}) {
  return GoogleFonts.sourceCodePro(
    fontSize: 11,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w500,
    color: AppTheme.textPrimary.withValues(alpha: opacity),
  );
}

TextStyle authDisplayTime(BuildContext context) {
  return GoogleFonts.inter(
    fontSize: 112,
    fontWeight: FontWeight.w200,
    height: 0.88,
    letterSpacing: -5,
    color: Colors.white,
  );
}

/// Banking-style PIN visualization + invisible digit capture.
class AuthPinCapture extends StatelessWidget {
  const AuthPinCapture({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.hasError,
    this.onCompleted,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool hasError;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => focusNode.requestFocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final filled = controller.text.length;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(length, (i) {
                  final on = i < filled;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasError
                            ? AppTheme.danger.withValues(alpha: 0.85)
                            : on
                                ? AppTheme.accent.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.18),
                        width: on ? 0 : 1.5,
                      ),
                      color: on
                          ? AppTheme.accent.withValues(alpha: 0.92)
                          : Colors.transparent,
                      boxShadow: on
                          ? [
                              BoxShadow(
                                color:
                                    AppTheme.accent.withValues(alpha: 0.38),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 14),
  // Capture lane  minimal footprint but receives IME / paste.
          Opacity(
            opacity: 0.012,
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(length),
                ],
                decoration: const InputDecoration(border: InputBorder.none),
                onChanged: (value) {
                  if (value.length == length) {
                    onCompleted?.call(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}