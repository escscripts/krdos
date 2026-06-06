import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  // stage: 0 = ambient, 1 = PIN
  int _stage = 0;
  String _pin = '';
  String _status = '';
  bool _denied = false;
  int _attempts = 0;
  late String _time, _date, _weekday;
  late Timer _timer;
  late AnimationController _shakeCtrl;
  late AnimationController _pinSlideCtrl;
  late Animation<double> _shakeAnim;
  double _dragStartY = 0;
  double _dragDelta  = 0;
  late FocusNode _focusNode;

  static const _correctPin = '123456';
  static const _maxPin = 6;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _shakeCtrl    = AnimationController(vsync: this, duration: 500.ms);
    _pinSlideCtrl = AnimationController(vsync: this, duration: 380.ms);
    _shakeAnim    = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _time    = DateFormat('HH:mm').format(now);
      _date    = DateFormat('MMMM d').format(now);
      _weekday = DateFormat('EEEE').format(now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _shakeCtrl.dispose();
    _pinSlideCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goToPIN() {
    if (_stage == 1) return;
    setState(() => _stage = 1);
    _pinSlideCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_stage == 0) { _goToPIN(); return; }
    final logical = event.logicalKey;
    if (logical == LogicalKeyboardKey.backspace) { _backspace(); return; }
    if (logical == LogicalKeyboardKey.escape) { _backToAmbient(); return; }
    if (logical == LogicalKeyboardKey.enter) {
      if (_pin.length == _maxPin) _verify();
      return;
    }
    final char = event.character;
    if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) _onKey(char);
  }

  void _backToAmbient() {
    _pinSlideCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() { _stage = 0; _pin = ''; _status = ''; _denied = false; });
    });
  }

  void _onKey(String key) {
    if (_pin.length >= _maxPin || _denied) return;
    setState(() => _pin += key);
    if (_pin.length == _maxPin) _verify();
  }

  void _backspace() {
    if (_denied || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    if (_pin == _correctPin) {
      setState(() => _status = 'ACCESS GRANTED');
      await Future.delayed(500.ms);
      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: 600.ms,
      ));
    } else {
      _attempts++;
      setState(() {
        _denied = true;
        _status = _attempts >= 3 ? 'Too many attempts' : 'Incorrect passcode';
      });
      _shakeCtrl.forward(from: 0);
      await Future.delayed(Duration(milliseconds: _attempts >= 3 ? 3000 : 900));
      if (!mounted) return;
      setState(() { _denied = false; _pin = ''; _status = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: LayoutBuilder(builder: (context, constraints) {
        final w        = constraints.maxWidth;
        final isLaptop = w >= 900;
        final isTablet = w >= 600 && !isLaptop;
        return GestureDetector(
        onVerticalDragStart: (d) {
          _dragStartY = d.globalPosition.dy;
          _dragDelta  = 0;
        },
        onVerticalDragUpdate: (d) {
          _dragDelta = _dragStartY - d.globalPosition.dy;
        },
        onVerticalDragEnd: (_) {
          if (_dragDelta > 60 && _stage == 0) _goToPIN();
          if (_dragDelta < -60 && _stage == 1) _backToAmbient();
        },
        onTap: () { if (_stage == 0) _goToPIN(); },
        child: Stack(
          children: [
  //  Background  
            _LockBackground(isLaptop: isLaptop),

  //  Ambient screen  
            AnimatedOpacity(
              opacity: _stage == 0 ? 1.0 : 0.0,
              duration: 300.ms,
              child: _buildAmbient(isLaptop, isTablet),
            ),

  //  PIN screen slides up from bottom  
            if (_stage == 1)
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _pinSlideCtrl,
                  curve: Curves.easeOutCubic,
                )),
                child: _buildPINScreen(isLaptop, isTablet),
              ),
          ],
        ),
        );
      }),
      ),
    );
  }

  //  AMBIENT  
  Widget _buildAmbient(bool isLaptop, bool isTablet) {
    final clockSize = isLaptop ? 110.0 : isTablet ? 90.0 : 76.0;
    return Stack(
      children: [
  // Clock + date centered
        Positioned(
          top: isLaptop ? 80 : isTablet ? 70 : 60,
          left: 0, right: 0,
          child: Column(
            children: [
              Text(_weekday,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: isLaptop ? 18 : 14,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(duration: 800.ms),
              const SizedBox(height: 4),
              Text(_time,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: clockSize,
                  fontWeight: FontWeight.w200,
                  letterSpacing: isLaptop ? 8 : 4,
                ),
              ).animate().fadeIn(duration: 600.ms),
              Text(_date,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: isLaptop ? 18 : 15,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),

  // Notification cards
        Positioned(
          top: isLaptop ? 320 : isTablet ? 280 : 240,
          left: isLaptop ? 80 : 24,
          right: isLaptop ? 80 : 24,
          child: _buildNotifCards(),
        ),

  // Bottom hint  swipe up
        Positioned(
          bottom: isLaptop ? 40 : 28,
          left: 0, right: 0,
          child: Column(
            children: [
              Icon(Icons.keyboard_arrow_up,
                color: Colors.white.withOpacity(0.5), size: 22)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 5, end: -5, duration: 1400.ms, curve: Curves.easeInOut),
              const SizedBox(height: 4),
              Text(
                isLaptop ? 'Click or swipe up to unlock' : 'Swipe up to unlock',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotifCards() {
    final notifs = [
      {'icon': Icons.shield,        'app': 'Security',  'body': 'Firewall active ‚¬ 0 threats detected'},
      {'icon': Icons.wifi,          'app': 'Network',   'body': 'Connected to HomeNetwork_5G'},
      {'icon': Icons.devices_other, 'app': 'Devices',   'body': 'Drone Alpha online ‚¬ signal 87%'},
    ];
    return Column(
      children: notifs.asMap().entries.map((e) =>
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(e.value['icon'] as IconData, color: AppTheme.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value['app'] as String,
                          style: TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(e.value['body'] as String,
                          style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate(delay: Duration(milliseconds: 300 + e.key * 80))
          .fadeIn(duration: 500.ms)
          .slideY(begin: 0.1, end: 0),
      ).toList(),
    );
  }

  //  PIN SCREEN  
  Widget _buildPINScreen(bool isLaptop, bool isTablet) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: Stack(
            children: [
  // Back swipe hint
              Positioned(
                top: isLaptop ? 24 : 16,
                left: 0, right: 0,
                child: GestureDetector(
                  onTap: _backToAmbient,
                  child: Column(
                    children: [
                      Icon(Icons.keyboard_arrow_down,
                        color: Colors.white.withOpacity(0.4), size: 22)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(begin: -4, end: 4, duration: 1400.ms),
                    ],
                  ),
                ),
              ),

  // Main PIN content
              Center(
                child: AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(sin(_shakeAnim.value * pi * 7) * 12, 0),
                    child: child,
                  ),
                  child: isLaptop
                    ? _buildLaptopPINLayout()
                    : _buildMobilePINLayout(isTablet),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePINLayout(bool isTablet) {
    final keySize = isTablet ? 76.0 : 68.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
  // Mini time
        Text(_time, style: TextStyle(
          color: Colors.white, fontSize: 32,
          fontWeight: FontWeight.w200, letterSpacing: 4)),
        const SizedBox(height: 2),
        Text(_date, style: TextStyle(
          color: Colors.white.withOpacity(0.6), fontSize: 13)),
        const SizedBox(height: 48),
  // User avatar
        _buildAvatar(),
        const SizedBox(height: 16),
        Text('Enter Passcode', style: TextStyle(
          color: Colors.white.withOpacity(0.8), fontSize: 14, letterSpacing: 1)),
        const SizedBox(height: 6),
  // Status
        AnimatedOpacity(
          opacity: _status.isNotEmpty ? 1 : 0,
          duration: 200.ms,
          child: Text(_status, style: TextStyle(
            color: _denied ? AppTheme.danger : AppTheme.accent,
            fontSize: 12, letterSpacing: 1)),
        ),
        const SizedBox(height: 20),
        _buildDots(),
        const SizedBox(height: 36),
        _buildKeypad(keySize),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLaptopPINLayout() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
  // Left: clock + info
        SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_time, style: TextStyle(
                color: Colors.white, fontSize: 72,
                fontWeight: FontWeight.w100, letterSpacing: 6)),
              Text(_weekday, style: TextStyle(
                color: Colors.white.withOpacity(0.6), fontSize: 16, letterSpacing: 2)),
              Text(_date, style: TextStyle(
                color: Colors.white.withOpacity(0.5), fontSize: 14)),
              const SizedBox(height: 32),
              _buildNotifCards(),
            ],
          ),
        ),
        const SizedBox(width: 80),
  // Right: PIN pad
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(),
            const SizedBox(height: 16),
            Text('Enter Passcode', style: TextStyle(
              color: Colors.white.withOpacity(0.8), fontSize: 14, letterSpacing: 1)),
            const SizedBox(height: 6),
            AnimatedOpacity(
              opacity: _status.isNotEmpty ? 1 : 0,
              duration: 200.ms,
              child: Text(_status, style: TextStyle(
                color: _denied ? AppTheme.danger : AppTheme.accent,
                fontSize: 12, letterSpacing: 1)),
            ),
            const SizedBox(height: 20),
            _buildDots(),
            const SizedBox(height: 32),
            _buildKeypad(72),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar() => Container(
    width: 64, height: 64,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(0.1),
      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
    ),
    child: Icon(
      _denied ? Icons.lock : Icons.person,
      color: _denied ? AppTheme.danger : Colors.white,
      size: 30,
    ),
  );

  Widget _buildDots() => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(_maxPin, (i) {
      final filled = i < _pin.length;
      return AnimatedContainer(
        duration: 100.ms,
        margin: const EdgeInsets.symmetric(horizontal: 7),
        width: filled ? 14 : 10,
        height: filled ? 14 : 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
            ? (_denied ? AppTheme.danger : Colors.white)
            : Colors.transparent,
          border: Border.all(
            color: _denied
              ? AppTheme.danger
              : Colors.white.withOpacity(0.7),
            width: 1.5,
          ),
        ),
      );
    }),
  );

  Widget _buildKeypad(double size) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'Å’«'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) => Row(
        mainAxisSize: MainAxisSize.min,
        children: row.map((k) => _PinKey(
          label: k,
          size: size,
          onTap: k == 'Å’«' ? _backspace : k.isEmpty ? null : () => _onKey(k),
        )).toList(),
      )).toList(),
    );
  }
}

//  PIN Key  
class _PinKey extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double size;
  const _PinKey({required this.label, this.onTap, this.size = 68});
  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.label.isEmpty) {
      return SizedBox(width: widget.size + 16, height: widget.size + 16);
    }
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: 80.ms,
        margin: const EdgeInsets.all(8),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed
            ? Colors.white.withOpacity(0.35)
            : Colors.white.withOpacity(0.15),
          border: Border.all(
            color: Colors.white.withOpacity(_pressed ? 0.6 : 0.25),
            width: 1,
          ),
        ),
        child: Center(
          child: widget.label == 'Å’«'
            ? Icon(Icons.backspace_outlined,
                color: Colors.white.withOpacity(0.85), size: 22)
            : Text(widget.label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 26,
                  fontWeight: FontWeight.w300,
                )),
        ),
      ),
    );
  }
}

//  Background  
class _LockBackground extends StatelessWidget {
  final bool isLaptop;
  const _LockBackground({required this.isLaptop});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF050A0E),
            Color(0xFF0A1628),
            Color(0xFF050E1A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _LockBgPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LockBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
  // Radial glow top-center
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.4),
        radius: 0.7,
        colors: [
          AppTheme.accent.withOpacity(0.07),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

  // Second glow bottom
    final glow2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.6, 0.8),
        radius: 0.5,
        colors: [
          const Color(0xFF58A6FF).withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glow2);

  // Subtle grid
    final gp = Paint()
      ..color = AppTheme.accent.withOpacity(0.018)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    }
    for (double y = 0; y < size.height; y += 60) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}