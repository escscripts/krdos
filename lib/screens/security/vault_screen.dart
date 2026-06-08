import 'package:flutter/material.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

enum _VaultState { unknown, setup, locked, unlocked }

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  _VaultState _vaultState = _VaultState.unknown;
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  bool _busy    = false;
  String _sessionPassphrase = '';

  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  @override
  void initState() { super.initState(); _checkStatus(); }

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    final s = await SystemBridge.vaultStatus();
    if (!mounted) return;
    setState(() {
      if (s['exists'] == true) {
        _vaultState = _sessionPassphrase.isNotEmpty ? _VaultState.unlocked : _VaultState.locked;
      } else {
        _vaultState = _VaultState.setup;
      }
      _loading = false;
    });
    if (_vaultState == _VaultState.unlocked) _loadFiles();
  }

  Future<void> _create() async {
    if (_passCtrl.text.isEmpty) { _snack('Passphrase required', error: true); return; }
    if (_passCtrl.text != _confirmCtrl.text) { _snack('Passphrases do not match', error: true); return; }
    setState(() => _busy = true);
    final ok = await SystemBridge.vaultCreate(_passCtrl.text);
    if (!mounted) return;
    if (ok) {
      _sessionPassphrase = _passCtrl.text;
      _passCtrl.clear(); _confirmCtrl.clear();
      await _checkStatus();
    } else {
      _snack('Failed to create vault', error: true);
    }
    setState(() => _busy = false);
  }

  Future<void> _unlock() async {
    if (_passCtrl.text.isEmpty) { _snack('Enter passphrase', error: true); return; }
    setState(() => _busy = true);
    final ok = await SystemBridge.vaultVerify(_passCtrl.text);
    if (!mounted) return;
    if (ok) {
      _sessionPassphrase = _passCtrl.text;
      _passCtrl.clear();
      setState(() => _vaultState = _VaultState.unlocked);
      await _loadFiles();
    } else {
      _snack('Incorrect passphrase', error: true);
    }
    setState(() => _busy = false);
  }

  void _lock() {
    _sessionPassphrase = '';
    setState(() { _vaultState = _VaultState.locked; _files = []; });
  }

  Future<void> _loadFiles() async {
    final files = await SystemBridge.vaultListFiles();
    if (!mounted) return;
    setState(() => _files = files);
  }

  Future<void> _pickAndEncrypt() async {
    // Use file picker via terminal â€” show dialog for manual path entry
    final srcCtrl  = TextEditingController();
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        title: Text('Add File to Vault',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter the full path of the file to encrypt:',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 12),
          _VaultTextField(controller: srcCtrl, hint: '/home/admin/secret.txt'),
          const SizedBox(height: 10),
          _VaultTextField(controller: nameCtrl, hint: 'Vault name (e.g. secret)'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Encrypt', style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );
    if (ok != true) return;
    final src  = srcCtrl.text.trim();
    final name = nameCtrl.text.trim();
    if (src.isEmpty || name.isEmpty) { _snack('Path and name required', error: true); return; }
    setState(() => _busy = true);
    final result = await SystemBridge.vaultAddFile(
      srcPath: src, passphrase: _sessionPassphrase, name: name);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result) { _snack('File encrypted and stored'); await _loadFiles(); }
    else        { _snack('Failed â€” check file path', error: true); }
  }

  Future<void> _removeFile(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        title: Text('Delete "$name"?',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        content: Text('The encrypted file will be permanently deleted from the vault.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await SystemBridge.vaultRemoveFile(name);
    if (mounted) { _snack('File removed'); await _loadFiles(); }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.success,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: _loading
            ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : _buildBody(),
        ),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    height: 56,
    color: AppTheme.surface,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: _vaultState == _VaultState.unlocked
            ? AppTheme.success.withValues(alpha: 0.15)
            : AppTheme.accentDim,
          borderRadius: BorderRadius.circular(8)),
        child: Icon(
          _vaultState == _VaultState.unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
          color: _vaultState == _VaultState.unlocked ? AppTheme.success : AppTheme.accent,
          size: 16),
      ),
      const SizedBox(width: 12),
      Text('Encrypted Vault',
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      const Spacer(),
      if (_vaultState == _VaultState.unlocked)
        GestureDetector(
          onTap: _lock,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Icon(Icons.lock_rounded, color: AppTheme.danger, size: 12),
              const SizedBox(width: 4),
              Text('Lock', style: TextStyle(color: AppTheme.danger,
                fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
    ]),
  );

  Widget _buildBody() {
    switch (_vaultState) {
      case _VaultState.setup:    return _buildSetupView();
      case _VaultState.locked:   return _buildLockedView();
      case _VaultState.unlocked: return _buildUnlockedView();
      case _VaultState.unknown:  return const SizedBox.shrink();
    }
  }

  Widget _buildSetupView() => SingleChildScrollView(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(height: 40),
      Icon(Icons.lock_rounded, size: 64, color: AppTheme.accent),
      const SizedBox(height: 20),
      Text('Create Your Vault',
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 20,
          fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Files stored in the vault are encrypted with AES-256-CBC.\nChoose a strong passphrase you will not forget.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        textAlign: TextAlign.center),
      const SizedBox(height: 32),
      _VaultTextField(controller: _passCtrl, hint: 'Master passphrase', obscure: true),
      const SizedBox(height: 10),
      _VaultTextField(controller: _confirmCtrl, hint: 'Confirm passphrase', obscure: true),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _busy ? null : _create,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.accentDim,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent),
          ),
          child: _busy
            ? Center(child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shield_rounded, color: AppTheme.accent, size: 16),
                const SizedBox(width: 8),
                Text('Create Vault', style: TextStyle(color: AppTheme.accent,
                  fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
        ),
      ),
    ]),
  );

  Widget _buildLockedView() => SingleChildScrollView(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const SizedBox(height: 40),
      Icon(Icons.lock_rounded, size: 64, color: AppTheme.warning),
      const SizedBox(height: 20),
      Text('Vault Locked',
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Enter your master passphrase to access the vault.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      const SizedBox(height: 32),
      _VaultTextField(controller: _passCtrl, hint: 'Master passphrase', obscure: true,
        onSubmit: (_) => _unlock()),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _busy ? null : _unlock,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.accentDim,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accent),
          ),
          child: _busy
            ? Center(child: SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_open_rounded, color: AppTheme.accent, size: 16),
                const SizedBox(width: 8),
                Text('Unlock Vault', style: TextStyle(color: AppTheme.accent,
                  fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
        ),
      ),
    ]),
  );

  Widget _buildUnlockedView() => Column(children: [
    Padding(
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Icon(Icons.lock_open_rounded, color: AppTheme.success, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vault Unlocked', style: TextStyle(color: AppTheme.success,
                fontSize: 12, fontWeight: FontWeight.bold)),
              Text('${_files.length} encrypted file${_files.length == 1 ? '' : 's'}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ])),
            GestureDetector(
              onTap: _busy ? null : _pickAndEncrypt,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent),
                ),
                child: Row(children: [
                  Icon(Icons.add_rounded, color: AppTheme.accent, size: 14),
                  const SizedBox(width: 4),
                  Text('Add File', style: TextStyle(color: AppTheme.accent,
                    fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),
        )),
      ]),
    ),
    Expanded(
      child: _files.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.folder_open_rounded, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text('Vault is empty', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Tap "Add File" to encrypt and store a file',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ]))
        : ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _files.length,
            separatorBuilder: (_, index) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final f    = _files[i];
              final name = f['name'] as String? ?? 'unknown';
              final size = f['size'] as String? ?? '0';
              final sizeKb = (int.tryParse(size.trim()) ?? 0) ~/ 1024;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.lock_outlined, color: AppTheme.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: TextStyle(color: AppTheme.textPrimary,
                      fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${sizeKb > 0 ? '$sizeKb KB' : '<1 KB'} Â· AES-256-CBC',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                  ])),
                  GestureDetector(
                    onTap: () => _removeFile(name),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18),
                    ),
                  ),
                ]),
              );
            },
          ),
    ),
  ]);
}

class _VaultTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final ValueChanged<String>? onSubmit;
  const _VaultTextField({required this.controller, required this.hint,
    this.obscure = false, this.onSubmit});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    onSubmitted: onSubmit,
    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
    cursorColor: AppTheme.accent,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      filled: true, fillColor: AppTheme.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.accent)),
    ),
  );
}
