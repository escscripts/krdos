import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_manager.dart';
import '../../theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _busyCredential = false;
  bool _busyPwless = false;
  String? _credError;
  String? _pwlessError;

  /// `custom`  `pin4`  `pin6`  mirrored from [AuthManager] account model.
  String _nextKind = 'custom';
  bool _wantPasswordless = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromAuth());
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _hydrateFromAuth() {
    if (!mounted) return;
    final u = context.read<AuthManager>().currentUser;
    if (u == null) return;
    final t = u.passwordType;
    setState(() {
      _nextKind = (t == 'pin4' || t == 'pin6' || t == 'custom') ? t : 'custom';
      _wantPasswordless = u.allowPasswordlessLogin;
    });
  }

  int _strengthScore(String p) {
    var s = 0;
    if (p.length >= 8) s++;
    if (p.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s.clamp(0, 6);
  }

  String _strengthLabel(int score) {
    if (score <= 1) return 'Weak';
    if (score <= 3) return 'Fair';
    if (score <= 4) return 'Good';
    return 'Excellent';
  }

  Color _strengthColor(int score) {
    if (score <= 1) return AppTheme.danger;
    if (score <= 3) return AppTheme.warning;
    if (score <= 4) return AppTheme.accent;
    return AppTheme.success;
  }

  bool get _isPin => _nextKind == 'pin4' || _nextKind == 'pin6';
  int get _pinLen => _nextKind == 'pin4' ? 4 : 6;

  String _secretLabel() {
    switch (_nextKind) {
      case 'pin4':
        return 'New 4‚¬-digit PIN';
      case 'pin6':
        return 'New 6‚¬-digit PIN';
      default:
        return 'New passphrase';
    }
  }

  Future<void> _submitCredentialChange() async {
    final auth = context.read<AuthManager>();
    setState(() {
      _credError = null;
      _busyCredential = true;
    });

    final n = _newCtrl.text.trim();
    final c = _confirmCtrl.text.trim();
    if (n != c) {
      setState(() {
        _busyCredential = false;
        _credError = 'Confirmation does not match the new secret.';
      });
      return;
    }

    if (n.isEmpty) {
      setState(() {
        _busyCredential = false;
        _credError = 'Enter your new passphrase or PIN.';
      });
      return;
    }

    final err = await auth.updateSignInSecret(
      currentPassword: _currentCtrl.text,
      nextSecret: n,
      nextPasswordType: _nextKind,
    );

    if (!mounted) return;
    setState(() => _busyCredential = false);

    if (err != null) {
      setState(() => _credError = err);
      return;
    }

    _newCtrl.clear();
    _confirmCtrl.clear();
    _hydrateFromAuth();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sign‚¬-in credential updated.'),
        backgroundColor: AppTheme.surfaceAlt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _applyPasswordless() async {
    final auth = context.read<AuthManager>();
    final u = auth.currentUser;
    if (u == null) return;

    setState(() {
      _pwlessError = null;
      _busyPwless = true;
    });

    if (_wantPasswordless && _currentCtrl.text.trim().isEmpty) {
      setState(() {
        _busyPwless = false;
        _pwlessError =
            'Enter your current passphrase or PIN above before enabling password‚¬-less unlock.';
      });
      return;
    }

    if (_wantPasswordless == u.allowPasswordlessLogin) {
      setState(() => _busyPwless = false);
      return;
    }

    final err = await auth.setAllowPasswordlessLogin(
      allow: _wantPasswordless,
      currentPassword: _currentCtrl.text,
    );

    if (!mounted) return;
    setState(() => _busyPwless = false);

    if (err != null) {
      setState(() => _pwlessError = err);
      return;
    }

    _hydrateFromAuth();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _wantPasswordless ? 'Password‚¬-less unlock enabled.' : 'Password‚¬-less unlock turned off.',
        ),
        backgroundColor: AppTheme.surfaceAlt,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthManager>();
    final user = auth.currentUser;

    final score = _strengthScore(_newCtrl.text);
    final strengthW = score / 6;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.35),
                    AppTheme.accent.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.key_rounded, color: AppTheme.accent, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign‚¬-in & password',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user != null
                        ? 'Signed in as ${user.username} ‚¬ rotate your passphrase/PIN type and configure password‚¬-less unlock.'
                        : 'Sign in from the lock screen to edit these options.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (user == null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.warning),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No active session. Unlock from the clock screen first.',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Text(
            'Sign‚¬-in credential type',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('Passphrase'),
                selected: _nextKind == 'custom',
                onSelected: (_) {
                  setState(() {
                    _nextKind = 'custom';
                    _newCtrl.clear();
                    _confirmCtrl.clear();
                  });
                },
              ),
              ChoiceChip(
                label: Text('PIN (4)'),
                selected: _nextKind == 'pin4',
                onSelected: (_) {
                  setState(() {
                    _nextKind = 'pin4';
                    _newCtrl.clear();
                    _confirmCtrl.clear();
                  });
                },
              ),
              ChoiceChip(
                label: Text('PIN (6)'),
                selected: _nextKind == 'pin6',
                onSelected: (_) {
                  setState(() {
                    _nextKind = 'pin6';
                    _newCtrl.clear();
                    _confirmCtrl.clear();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          _field(
            label: _isPin ? 'Current passphrase or PIN' : 'Current passphrase',
            controller: _currentCtrl,
            obscure: _obscureCurrent,
            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
            enabled: !_busyCredential && !_busyPwless,
            keyboardType: _isPin ? TextInputType.number : TextInputType.text,
          ),
          const SizedBox(height: 14),
          _field(
            label: _secretLabel(),
            controller: _newCtrl,
            obscure: !_isPin ? _obscureNew : false,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
            enabled: !_busyCredential,
            obscureEnabled: !_isPin,
            onChanged: (_) => setState(() {}),
            keyboardType: _isPin ? TextInputType.number : TextInputType.visiblePassword,
            inputFormatters: _isPin
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_pinLen),
                  ]
                : null,
          ),
          if (!_isPin) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _newCtrl.text.isEmpty ? 0 : strengthW,
                      minHeight: 6,
                      backgroundColor: AppTheme.surfaceAlt,
                      color: _strengthColor(score),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _newCtrl.text.isEmpty ? 'Strength' : _strengthLabel(score),
                  style: TextStyle(
                    color: _newCtrl.text.isEmpty ? AppTheme.textSecondary : _strengthColor(score),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _field(
            label: _isPin ? 'Confirm PIN' : 'Confirm passphrase',
            controller: _confirmCtrl,
            obscure: !_isPin ? _obscureConfirm : false,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
            enabled: !_busyCredential,
            obscureEnabled: !_isPin,
            keyboardType: _isPin ? TextInputType.number : TextInputType.visiblePassword,
            inputFormatters: _isPin
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_pinLen),
                  ]
                : null,
          ),
          if (_credError != null) ...[
            const SizedBox(height: 14),
            Text(_credError!, style: TextStyle(color: AppTheme.danger, fontSize: 13)),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busyCredential ? null : _submitCredentialChange,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _busyCredential
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.vpn_key_rounded),
              label: Text(_busyCredential ? 'Saving‚¬¦' : 'Update passphrase / PIN'),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lock screen shortcut',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'When enabled, the lock screen shows ‚¬Å“sign in without password‚¬ after you pick your avatar. Anyone with physical access could open the desktop.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Allow unlocking without typing a passphrase/PIN',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  ),
                  value: _wantPasswordless,
                  activeThumbColor: AppTheme.accent,
                  onChanged: _busyPwless
                      ? null
                      : (v) => setState(() => _wantPasswordless = v),
                ),
                if (_pwlessError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_pwlessError!, style: TextStyle(color: AppTheme.danger, fontSize: 12)),
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busyPwless ? null : _applyPasswordless,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: Text(_busyPwless ? 'Saving‚¬¦' : 'Apply password‚¬-less preference'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required bool enabled,
    void Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
    TextInputType keyboardType = TextInputType.text,
    bool obscureEnabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.accent, width: 1.5),
            ),
            suffixIcon: obscureEnabled
                ? IconButton(
                    onPressed: enabled ? onToggle : null,
                    icon: Icon(
                      obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
