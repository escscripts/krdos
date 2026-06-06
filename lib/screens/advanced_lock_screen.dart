import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_manager.dart';
import '../core/settings_state.dart';
import '../core/auth/user_account.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_experience_layers.dart';
import '../widgets/auth_session_shell.dart';
import '../widgets/desktop_wallpaper_layer.dart';
import 'home_screen.dart';

class AdvancedLockScreen extends StatefulWidget {
  const AdvancedLockScreen({super.key});

  @override
  State<AdvancedLockScreen> createState() => _AdvancedLockScreenState();
}

class _AdvancedLockScreenState extends State<AdvancedLockScreen>
    with TickerProviderStateMixin {
  int _stage = 0;
  UserAccount? _selectedUser;
  final _passwordController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _obscurePassword = true;
  String _errorMessage = '';
  late String _time;
  late String _dateLine;
  late Timer _timer;
  late AnimationController _errorShakeController;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _errorShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _passwordController.addListener(() => setState(() {}));
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _time = DateFormat('HH:mm:ss').format(now);
      _dateLine =
          '${DateFormat('yyyy-MM-dd').format(now)}  ${DateFormat('EEEE').format(now)}';
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _passwordController.dispose();
    _pinFocusNode.dispose();
    _errorShakeController.dispose();
    super.dispose();
  }

  String _initial(UserAccount u) {
    final n = u.fullName.trim();
    if (n.isEmpty) {
      return u.username.isNotEmpty ? u.username[0].toUpperCase() : '?';
    }
    return n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: DesktopWallpaperLayer(forLockScreen: true)),
          AuthSessionBackdrop(
            overWallpaper: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(child: AuthDeskGrid()),
                Focus(
                  autofocus: _stage == 0,
                  skipTraversal: _stage != 0,
                  onKeyEvent: (node, event) {
                    if (_stage != 0) return KeyEventResult.ignored;
                    if (event is KeyDownEvent) {
                      setState(() => _stage = 1);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _stage == 0
                        ? KeyedSubtree(
                            key: const ValueKey('idle'),
                            child: _buildIdleLayer(),
                          )
                        : _stage == 1
                            ? KeyedSubtree(
                                key: const ValueKey('users'),
                                child: _buildUserSelectionLayer(),
                              )
                            : KeyedSubtree(
                                key: const ValueKey('auth'),
                                child: _buildPasswordLayer(),
                              ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Text(
            'lock',
            style: GoogleFonts.sourceCodePro(
              fontSize: 11,
              color: AppTheme.accent.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Local Session',
            style: GoogleFonts.sourceCodePro(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.85),
            ),
          ),
          const Spacer(),
          Text(
            'krdos_ui',
            style: GoogleFonts.sourceCodePro(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleLayer() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _stage = 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusStrip(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _time,
                    style: GoogleFonts.inter(
                      fontSize: 96,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -3,
                      color: AppTheme.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _dateLine,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      'Press any key to unlock',
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 11,
                        color: AppTheme.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Text(
              r'[locked]',
              style: GoogleFonts.sourceCodePro(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSelectionLayer() {
    return Consumer<AuthManager>(
      builder: (context, authManager, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _stage = 0),
                child: Container(color: Colors.black.withValues(alpha: 0.5)),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                child: AuthFramePanel(
                  title: 'select user session',
                  maxWidth: 480,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Accounts on this machine',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _stage = 0),
                            child: Text(
                              'cancel',
                              style: GoogleFonts.sourceCodePro(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose who is signing in. Esc returns to clock.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppTheme.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (final user in authManager.accounts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _userRow(user),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _userRow(UserAccount user) {
    final roleColor = _roleAccent(user.accountType);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _passwordController.clear();
          _errorMessage = '';
          setState(() {
            _selectedUser = user;
            _stage = 2;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (user.passwordType == 'pin4' ||
                user.passwordType == 'pin6') {
              _pinFocusNode.requestFocus();
            }
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.border),
            color: AppTheme.surfaceAlt,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: Text(
                    _initial(user),
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${user.username} , ${user.accountType.name}',
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 10,
                        color: roleColor.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleAccent(UserAccountType type) {
    switch (type) {
      case UserAccountType.administrator:
        return AppTheme.warning;
      case UserAccountType.standard:
        return AppTheme.accent;
      case UserAccountType.guest:
        return AppTheme.textSecondary;
    }
  }

  Widget _buildPasswordLayer() {
    final user = _selectedUser;
    if (user == null) return const SizedBox.shrink();

    final isPin =
        user.passwordType == 'pin4' || user.passwordType == 'pin6';
    final pinLen = user.passwordType == 'pin4' ? 4 : 6;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _stage = 1;
                _selectedUser = null;
                _passwordController.clear();
                _errorMessage = '';
              });
            },
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: AnimatedBuilder(
              animation: _errorShakeController,
              builder: (context, child) {
                final t = _errorShakeController.value;
                final active =
                    _errorMessage.isNotEmpty && t > 0 && t < 1;
                final dx =
                    active ? math.sin(t * math.pi * 6) * 8 * (1 - t) : 0.0;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: child,
                );
              },
              child: AuthFramePanel(
                title: 'authenticate ${user.username}',
                maxWidth: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: () {
                            setState(() {
                              _stage = 1;
                              _selectedUser = null;
                              _passwordController.clear();
                              _errorMessage = '';
                            });
                          },
                          icon: Icon(
                            Icons.arrow_back,
                            size: 20,
                            color: AppTheme.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          user.email,
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 10,
                            color: AppTheme.textSecondary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isPin) ...[
                      Text(
                        'PIN',
                        style: authMonoCaption(context, opacity: 0.55),
                      ),
                      const SizedBox(height: 10),
                      AuthPinCapture(
                        controller: _passwordController,
                        focusNode: _pinFocusNode,
                        length: pinLen,
                        hasError: _errorMessage.isNotEmpty,
                        onCompleted: (_) => _handleLogin(),
                      ),
                    ] else ...[
                      Text(
                        'password',
                        style: authMonoCaption(context, opacity: 0.55),
                      ),
                      const SizedBox(height: 8),
                      _passphraseField(),
                    ],
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.danger.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          _errorMessage,
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 11,
                            color: AppTheme.danger.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: _handleLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        side: const BorderSide(color: AppTheme.border),
                        backgroundColor: AppTheme.surfaceAlt,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'login',
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (user.allowPasswordlessLogin) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _signInWithoutPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary.withValues(alpha: 0.95),
                        ),
                        child: Text(
                          'sign in without password',
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _passphraseField() {
    final borderColor = _errorMessage.isNotEmpty
        ? AppTheme.danger.withValues(alpha: 0.5)
        : AppTheme.border;

    return TextField(
      controller: _passwordController,
      autofocus: true,
      obscureText: _obscurePassword,
      style: GoogleFonts.sourceCodePro(
        fontSize: 14,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.background,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: _errorMessage.isNotEmpty
                ? AppTheme.danger.withValues(alpha: 0.6)
                : AppTheme.accent.withValues(alpha: 0.65),
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onSubmitted: (_) => _handleLogin(),
    );
  }

  void _goDesktop() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _signInWithoutPassword() async {
    final user = _selectedUser;
    if (user == null || !user.allowPasswordlessLogin) return;
    setState(() => _errorMessage = '');
    final authManager = context.read<AuthManager>();
    try {
      await authManager.login(user.username, '');
      if (!mounted) return;
      _goDesktop();
    } catch (_) {
      setState(() => _errorMessage = 'passwordless sign in unavailable');
      _errorShakeController.forward(from: 0);
    }
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = '');

    final authManager = context.read<AuthManager>();
    final user = _selectedUser!;
    try {
      if (_passwordController.text.trim().isEmpty && user.allowPasswordlessLogin) {
        await authManager.login(user.username, '');
      } else {
        await authManager.login(user.username, _passwordController.text);
      }
      if (!mounted) return;
      _goDesktop();
    } catch (_) {
      setState(() {
        _errorMessage = 'auth failed: bad password';
        _passwordController.clear();
      });
      _errorShakeController.forward(from: 0);
    }
  }
}
