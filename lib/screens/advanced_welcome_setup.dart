import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_manager.dart';
import '../core/auth/user_account.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_experience_layers.dart';
import '../widgets/auth_session_shell.dart';
import 'advanced_lock_screen.dart';

class AdvancedWelcomeSetup extends StatefulWidget {
  const AdvancedWelcomeSetup({super.key});

  @override
  State<AdvancedWelcomeSetup> createState() => _AdvancedWelcomeSetupState();
}

class _AdvancedWelcomeSetupState extends State<AdvancedWelcomeSetup> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _hostnameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _pinPrimaryFocus = FocusNode();
  final _pinConfirmFocus = FocusNode();

  String _errorMessage = '';
  bool _isCreating = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String _passwordType = 'custom';

  String _usageProfile = 'development';
  String _editorBinding = 'vscode';
  bool _telemetryDisabled = true;
  bool _strictDns = false;
  bool _bootstrapFirewall = true;

  static const int _totalPages = 10;

  static const List<_StepMeta> _steps = [
    _StepMeta('00', 'manifest'),
    _StepMeta('01', 'profile'),
    _StepMeta('02', 'account'),
    _StepMeta('03', 'machine'),
    _StepMeta('04', 'auth'),
    _StepMeta('05', 'secret'),
    _StepMeta('06', 'tooling'),
    _StepMeta('07', 'baseline'),
    _StepMeta('08', 'review'),
    _StepMeta('09', 'commit'),
  ];

  @override
  void initState() {
    super.initState();
    _hostnameController.text = 'KrdOS-host';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _hostnameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pinPrimaryFocus.dispose();
    _pinConfirmFocus.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (_currentPage < _totalPages - 1) {
        _pageController.animateToPage(
          _currentPage + 1,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _errorMessage = '');
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _validateCurrentPage() {
    setState(() => _errorMessage = '');

    if (_currentPage == 1) {
      final name = _fullNameController.text.trim();
      if (name.length < 2) {
        setState(() => _errorMessage = 'name: too short (min 2 chars)');
        return false;
      }
    }
    if (_currentPage == 2) {
      final username = _usernameController.text.trim();
      if (username.length < 3) {
        setState(() => _errorMessage = 'username: min 3 characters');
        return false;
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        setState(() => _errorMessage = 'username: [a-zA-Z0-9_] only');
        return false;
      }
      final mail = _emailController.text.trim();
      if (mail.isNotEmpty &&
          !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(mail)) {
        setState(() => _errorMessage = 'email: invalid format');
        return false;
      }
    }
    if (_currentPage == 3) {
      final h = _hostnameController.text.trim().toLowerCase();
      if (h.length < 2 || h.length > 63) {
        setState(() => _errorMessage = 'hostname: 2 to 63 chars');
        return false;
      }
      if (!RegExp(r'^[a-z0-9]([a-z0-9\-]*[a-z0-9])?$').hasMatch(h)) {
        setState(() => _errorMessage = 'hostname: lowercase DNS labels only');
        return false;
      }
    }
    if (_currentPage == 5) {
      final password = _passwordController.text;
      final confirm = _confirmPasswordController.text;
      if (password.isEmpty) {
        setState(() => _errorMessage = 'credential required');
        return false;
      }
      if (_passwordType == 'pin4' && password.length != 4) {
        setState(() => _errorMessage = 'PIN must be 4 digits');
        return false;
      }
      if (_passwordType == 'pin6' && password.length != 6) {
        setState(() => _errorMessage = 'PIN must be 6 digits');
        return false;
      }
      if (_passwordType == 'custom') {
        if (password.length < 8) {
          setState(() => _errorMessage = 'passphrase: min 8 chars');
          return false;
        }
        if (!RegExp(r'[A-Z]').hasMatch(password)) {
          setState(() => _errorMessage = 'passphrase: need uppercase');
          return false;
        }
        if (!RegExp(r'[a-z]').hasMatch(password)) {
          setState(() => _errorMessage = 'passphrase: need lowercase');
          return false;
        }
        if (!RegExp(r'[0-9]').hasMatch(password)) {
          setState(() => _errorMessage = 'passphrase: need digit');
          return false;
        }
      }
      if (password != confirm) {
        setState(() => _errorMessage = 'confirmation mismatch');
        return false;
      }
    }
    return true;
  }

  Future<void> _completeSetup() async {
    if (!_validateCurrentPage()) return;

    setState(() {
      _errorMessage = '';
      _isCreating = true;
    });

    final authManager = context.read<AuthManager>();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim().isEmpty
        ? '$username@KrdOS.local'
        : _emailController.text.trim();

    final success = await authManager.createAccount(
      username: username,
      fullName: _fullNameController.text.trim(),
      email: email,
      password: _passwordController.text,
      accountType: UserAccountType.administrator,
      passwordType: _passwordType,
    );

    if (success && mounted) {
      final created =
          authManager.accounts.firstWhere((a) => a.username == username);
      final prefs = {
        ...created.preferences,
        'hostname': _hostnameController.text.trim().toLowerCase(),
        'usage_profile': _usageProfile,
        'editor_binding': _editorBinding,
        'telemetry_disabled': _telemetryDisabled,
        'strict_dns': _strictDns,
        'bootstrap_firewall': _bootstrapFirewall,
        'provisioned_at': DateTime.now().toIso8601String(),
      };
      await authManager.updateAccount(created.copyWith(preferences: prefs));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AdvancedLockScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 480),
        ),
      );
    } else if (mounted) {
      setState(() {
        _errorMessage = 'account exists: username or email';
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AuthSessionBackdrop(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: AuthDeskGrid(lineStep: 48)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) _buildStepRail(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(wide),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (i) => setState(() => _currentPage = i),
                          children: [
                            _pageManifest(),
                            _pageProfile(),
                            _pageAccount(),
                            _pageMachine(),
                            _pageAuthType(),
                            _pageSecret(),
                            _pageTooling(),
                            _pageBaseline(),
                            _pageReview(),
                            _pageCommit(),
                          ],
                        ),
                      ),
                      _buildFooter(wide),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRail() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.border),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
        children: [
          Text(
            'provision',
            style: GoogleFonts.sourceCodePro(
              fontSize: 10,
              letterSpacing: 1.2,
              color: AppTheme.accent.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'first boot',
            style: GoogleFonts.sourceCodePro(
              fontSize: 10,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _totalPages; i++)
            _railLine(i, _steps[i]),
        ],
      ),
    );
  }

  Widget _railLine(int i, _StepMeta m) {
    final done = i < _currentPage;
    final on = i == _currentPage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppTheme.surfaceAlt : null,
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(
              width: 2,
              color: on
                  ? AppTheme.accent
                  : done
                      ? AppTheme.textSecondary.withValues(alpha: 0.35)
                      : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                m.idx,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 10,
                  color: on
                      ? AppTheme.accent
                      : AppTheme.textSecondary.withValues(alpha: 0.65),
                ),
              ),
            ),
            Expanded(
              child: Text(
                m.label,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 11,
                  color: on || done
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary.withValues(alpha: 0.55),
                ),
              ),
            ),
            if (done)
              Icon(Icons.check, size: 14, color: AppTheme.accent.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool wide) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
        color: AppTheme.surface,
      ),
      child: Row(
        children: [
          if (!wide)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'provision',
                style: GoogleFonts.sourceCodePro(
                  fontSize: 10,
                  color: AppTheme.accent.withValues(alpha: 0.85),
                ),
              ),
            ),
          Text(
            '${_steps[_currentPage].idx}  ${_steps[_currentPage].label}',
            style: GoogleFonts.sourceCodePro(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            '${_currentPage + 1}/$_totalPages',
            style: GoogleFonts.sourceCodePro(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool wide) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Color(0xE60D1117),
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: _previousPage,
                  child: Text(
                    'back',
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              else
                const SizedBox(width: 64),
              if (!wide)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: AuthSetupProgressSegments(
                      index: _currentPage,
                      total: _totalPages,
                    ),
                  ),
                )
              else
                const Spacer(),
              OutlinedButton(
                onPressed: _isCreating
                    ? null
                    : (_currentPage == _totalPages - 1
                        ? _completeSetup
                        : _nextPage),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.border),
                  backgroundColor: AppTheme.surfaceAlt,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                child: _isCreating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent.withValues(alpha: 0.85),
                        ),
                      )
                    : Text(
                        _currentPage == _totalPages - 1 ? 'write & reboot' : 'next',
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageWrap(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(child: child),
    );
  }

  Widget _pageManifest() {
    return _pageWrap(
      AuthFramePanel(
        title: '/etc/KrdOS/first-boot.d/README',
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Initial provisioning',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This flow creates the primary administrator, stamps machine metadata, '
              'and stores a few defaults the shell and settings apps read later. '
              'Nothing here is wizard copy it is configuration you can reason about.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppTheme.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 20),
            _monoBlock('''
Ã‚ |  local account (offline-first)
Ã‚ |  password hashed (sha256) demo tier
Ã‚ |  hostname + policy flags user preferences JSON
Ã‚ |  10 steps skip nothing; each screen is one concern
'''),
            const SizedBox(height: 20),
            if (MediaQuery.of(context).size.width < 1024)
              AuthSetupProgressSegments(
                index: _currentPage,
                total: _totalPages,
              ),
          ],
        ),
      ),
    );
  }

  Widget _monoBlock(String s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        s.trim(),
        style: GoogleFonts.sourceCodePro(
          fontSize: 11,
          height: 1.45,
          color: AppTheme.textSecondary.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _pageProfile() {
    return _pageWrap(
      AuthFramePanel(
        title: 'user.full_name',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _fieldLabel('How you want it printed in UI / prompts'),
            const SizedBox(height: 8),
            _textField(_fullNameController, 'Ada Lovelace', autofocus: true),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              _err(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pageAccount() {
    return _pageWrap(
      AuthFramePanel(
        title: 'passwd  new entry',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _fieldLabel('username (login)'),
            const SizedBox(height: 8),
            _textField(_usernameController, 'alovelace', autofocus: true),
            const SizedBox(height: 16),
            _fieldLabel('email (optional, for display)'),
            const SizedBox(height: 8),
            _textField(_emailController, 'ada@local'),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              _err(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pageMachine() {
    return _pageWrap(
      AuthFramePanel(
        title: '/etc/hostname',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _fieldLabel('hostname (DNS label, lowercase)'),
            const SizedBox(height: 8),
            _textField(_hostnameController, 'machine', autofocus: true),
            const SizedBox(height: 18),
            _fieldLabel('usage profile (stored; informs defaults later)'),
            const SizedBox(height: 8),
            _segmented(
              value: _usageProfile,
              options: const [
                _Seg('development', 'dev'),
                _Seg('daily', 'daily'),
                _Seg('offline', 'offline'),
              ],
              onChanged: (v) => setState(() => _usageProfile = v),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              _err(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pageAuthType() {
    return _pageWrap(
      AuthFramePanel(
        title: 'pam ‚¬ credential class',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _radioRow(
              'pin4',
              'PIN 4',
              'fast unlock, low entropy',
            ),
            _radioRow(
              'pin6',
              'PIN 6',
              'better than 4; still numeric',
            ),
            _radioRow(
              'custom',
              'passphrase',
              'recommended for this OS demo',
            ),
          ],
        ),
      ),
    );
  }

  Widget _radioRow(String id, String title, String sub) {
    final on = _passwordType == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() {
          _passwordType = id;
          _passwordController.clear();
          _confirmPasswordController.clear();
        }),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: on ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.border,
            ),
            color: on ? AppTheme.surfaceAlt : AppTheme.background,
          ),
          child: Row(
            children: [
              Icon(
                on ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: on ? AppTheme.accent : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageSecret() {
    final isPin = _passwordType == 'pin4' || _passwordType == 'pin6';
    final n = _passwordType == 'pin4' ? 4 : 6;

    return _pageWrap(
      AuthFramePanel(
        title: 'set secret',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isPin) ...[
              Text('primary', style: authMonoCaption(context, opacity: 0.55)),
              const SizedBox(height: 8),
              AuthPinCapture(
                controller: _passwordController,
                focusNode: _pinPrimaryFocus,
                length: n,
                hasError: _errorMessage.isNotEmpty,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Text('again', style: authMonoCaption(context, opacity: 0.55)),
              const SizedBox(height: 8),
              AuthPinCapture(
                controller: _confirmPasswordController,
                focusNode: _pinConfirmFocus,
                length: n,
                hasError: _errorMessage.isNotEmpty,
                autofocus: false,
              ),
            ] else ...[
              _fieldLabel('passphrase'),
              const SizedBox(height: 8),
              _passField(_passwordController, _showPassword,
                  () => setState(() => _showPassword = !_showPassword),
                  autofocus: true),
              const SizedBox(height: 14),
              _fieldLabel('confirm'),
              const SizedBox(height: 8),
              _passField(
                  _confirmPasswordController,
                  _showConfirmPassword,
                  () => setState(
                      () => _showConfirmPassword = !_showConfirmPassword)),
            ],
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              _err(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pageTooling() {
    return _pageWrap(
      AuthFramePanel(
        title: '~/.config/editor ‚¬ binding hint',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stored as preference; apps may ignore in this demo.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            _fieldLabel('keybinding profile'),
            const SizedBox(height: 8),
            _segmented(
              value: _editorBinding,
              options: const [
                _Seg('vscode', 'vscode'),
                _Seg('emacs', 'emacs'),
                _Seg('vim', 'vim'),
              ],
              onChanged: (v) => setState(() => _editorBinding = v),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'disable outbound telemetry stubs',
                style: GoogleFonts.sourceCodePro(fontSize: 12),
              ),
              subtitle: Text(
                'no network calls in this build; flag is for realism',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary.withValues(alpha: 0.75),
                ),
              ),
              value: _telemetryDisabled,
              activeThumbColor: AppTheme.accent,
              onChanged: (v) => setState(() => _telemetryDisabled = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageBaseline() {
    return _pageWrap(
      AuthFramePanel(
        title: 'policy ‚¬ bootstrap defaults',
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'firewall flag on (matches control center default)',
                style: GoogleFonts.sourceCodePro(fontSize: 12),
              ),
              value: _bootstrapFirewall,
              activeThumbColor: AppTheme.accent,
              onChanged: (v) => setState(() => _bootstrapFirewall = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'strict DNS resolver list (preference only)',
                style: GoogleFonts.sourceCodePro(fontSize: 12),
              ),
              value: _strictDns,
              activeThumbColor: AppTheme.accent,
              onChanged: (v) => setState(() => _strictDns = v),
            ),
          ],
        ),
      ),
    );
  }

  String _manifestText() {
    final mail = _emailController.text.trim().isEmpty
        ? '${_usernameController.text.trim()}@KrdOS.local'
        : _emailController.text.trim();
    return '''
USER=${_usernameController.text.trim()}
NAME=${_fullNameController.text.trim()}
EMAIL=$mail
HOST=${_hostnameController.text.trim().toLowerCase()}
PROFILE=$_usageProfile
AUTH=$_passwordType
EDITOR=$_editorBinding
TELEMETRY=${_telemetryDisabled ? 'off' : 'on'}
DNS_STRICT=${_strictDns ? 'yes' : 'no'}
FIREWALL=${_bootstrapFirewall ? 'on' : 'off'}
'''.trim();
  }

  Widget _pageReview() {
    return _pageWrap(
      AuthFramePanel(
        title: 'review ‚¬ /var/lib/KrdOS/stamp',
        maxWidth: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              _manifestText(),
              style: GoogleFonts.sourceCodePro(
                fontSize: 11,
                height: 1.45,
                color: AppTheme.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'If this looks wrong, go back. Commit writes SQLite prefs + account.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageCommit() {
    return _pageWrap(
      AuthFramePanel(
        title: 'finalize',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Creates the account, saves bootstrap flags to your profile JSON, '
              'then drops you on the lock screen (same as a real session manager).',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppTheme.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 16),
            _monoBlock('[*] ready to commit\n[ ] post-login: customize dock / wallpaper in settings'),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String s) {
    return Text(
      s,
      style: GoogleFonts.sourceCodePro(
        fontSize: 10,
        letterSpacing: 0.4,
        color: AppTheme.textSecondary.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _textField(
    TextEditingController c,
    String hint, {
    bool autofocus = false,
  }) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      style: GoogleFonts.sourceCodePro(
        fontSize: 13,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppTheme.textSecondary.withValues(alpha: 0.45),
        ),
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide:
              BorderSide(color: AppTheme.accent.withValues(alpha: 0.65)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _passField(
    TextEditingController c,
    bool visible,
    VoidCallback toggle, {
    bool autofocus = false,
  }) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      obscureText: !visible,
      style: GoogleFonts.sourceCodePro(
        fontSize: 13,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: AppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide:
              BorderSide(color: AppTheme.accent.withValues(alpha: 0.65)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _err() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
      ),
      child: Text(
        _errorMessage,
        style: GoogleFonts.sourceCodePro(
          fontSize: 11,
          color: AppTheme.danger.withValues(alpha: 0.95),
        ),
      ),
    );
  }

  Widget _segmented({
    required String value,
    required List<_Seg> options,
    required ValueChanged<String> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final on = value == o.id;
        return ChoiceChip(
          label: Text(
            o.label,
            style: GoogleFonts.sourceCodePro(
              fontSize: 11,
              color: on ? AppTheme.background : AppTheme.textPrimary,
            ),
          ),
          selected: on,
          selectedColor: AppTheme.accent,
          backgroundColor: AppTheme.surfaceAlt,
          side: const BorderSide(color: AppTheme.border),
          onSelected: (_) => onChanged(o.id),
        );
      }).toList(),
    );
  }
}

class _StepMeta {
  const _StepMeta(this.idx, this.label);
  final String idx;
  final String label;
}

class _Seg {
  const _Seg(this.id, this.label);
  final String id;
  final String label;
}
