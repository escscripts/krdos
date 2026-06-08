import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

class SshKeysScreen extends StatefulWidget {
  const SshKeysScreen({super.key});
  @override
  State<SshKeysScreen> createState() => _SshKeysScreenState();
}

class _SshKeysScreenState extends State<SshKeysScreen> {
  List<Map<String, dynamic>> _keys = [];
  bool _loading = true;

  // Generate form state
  String _genType    = 'ed25519';
  final _commentCtrl    = TextEditingController(text: 'krdos-key');
  final _passphraseCtrl = TextEditingController();
  bool _generating = false;
  String _genOutput = '';

  // Expanded key for detail view
  String? _expandedPath;
  String  _pubKeyContent = '';

  @override
  void initState() { super.initState(); _reload(); }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _passphraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final keys = await SystemBridge.keysList();
    if (!mounted) return;
    setState(() { _keys = keys; _loading = false; });
  }

  Future<void> _generate() async {
    setState(() { _generating = true; _genOutput = ''; });
    final result = await SystemBridge.keysGenerate(
      type:       _genType,
      comment:    _commentCtrl.text.trim().isEmpty ? 'krdos' : _commentCtrl.text.trim(),
      passphrase: _passphraseCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _generating = false;
      _genOutput  = result['output'] as String? ?? '';
    });
    if (result['ok'] == true) {
      await _reload();
      _snack('Key generated successfully');
    } else {
      _snack('Generation failed â€” see output below', error: true);
    }
  }

  Future<void> _expandKey(String pubPath) async {
    if (_expandedPath == pubPath) {
      setState(() { _expandedPath = null; _pubKeyContent = ''; });
      return;
    }
    final content = await SystemBridge.keysGetPublic(pubPath);
    setState(() { _expandedPath = pubPath; _pubKeyContent = content; });
  }

  Future<void> _deleteKey(Map<String, dynamic> key) async {
    final name = key['name'] as String? ?? 'key';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        title: Text('Delete "$name"?',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        content: Text('Both the private and public key files will be permanently deleted.',
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
    await SystemBridge.keysDelete(key['pub_path'] as String);
    if (mounted) { _snack('Key deleted'); await _reload(); }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _snack('Public key copied to clipboard');
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
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  _buildGenerateCard(),
                  const SizedBox(height: 16),
                  _buildKeysList(),
                ]),
              ),
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
        decoration: BoxDecoration(color: AppTheme.accentDim, borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.key_rounded, color: AppTheme.accent, size: 16),
      ),
      const SizedBox(width: 12),
      Text('SSH Key Manager',
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      const Spacer(),
      GestureDetector(
        onTap: _reload,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.accentDim, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.refresh_rounded, color: AppTheme.accent, size: 16),
        ),
      ),
    ]),
  );

  Widget _buildGenerateCard() => _KeyCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.add_rounded, color: AppTheme.accent, size: 16),
        const SizedBox(width: 8),
        Text('Generate New Key', style: TextStyle(color: AppTheme.accent, fontSize: 13,
          fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 14),
      // Key type selector
      Row(children: [
        Text('Type:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(width: 12),
        ...['ed25519', 'rsa', 'ecdsa'].map((t) => GestureDetector(
          onTap: () => setState(() => _genType = t),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _genType == t ? AppTheme.accentDim : AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _genType == t ? AppTheme.accent : AppTheme.border),
            ),
            child: Text(t, style: TextStyle(
              color: _genType == t ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _KTextField(controller: _commentCtrl, hint: 'Comment (e.g. work-server)')),
        const SizedBox(width: 10),
        Expanded(child: _KTextField(
          controller: _passphraseCtrl, hint: 'Passphrase (leave empty = none)',
          obscure: true)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _generating
          ? Row(children: [
              SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
              const SizedBox(width: 8),
              Text('Generating...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ])
          : GestureDetector(
              onTap: _generate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.vpn_key_rounded, color: AppTheme.accent, size: 14),
                  const SizedBox(width: 8),
                  Text('Generate Key', style: TextStyle(color: AppTheme.accent,
                    fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            )),
      ]),
      if (_genOutput.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(_genOutput,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10,
              fontFamily: 'monospace')),
        ),
      ],
    ]),
  );

  Widget _buildKeysList() => _KeyCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.list_alt_rounded, color: AppTheme.accent, size: 16),
        const SizedBox(width: 8),
        Text('Keys (${_keys.length})',
          style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),
      if (_keys.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Column(children: [
            Icon(Icons.key_off_rounded, color: AppTheme.textSecondary, size: 32),
            const SizedBox(height: 8),
            Text('No SSH keys found in ~/.ssh/',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ])),
        )
      else
        ..._keys.map((k) {
          final name    = k['name']        as String? ?? 'key';
          final pubPath = k['pub_path']    as String? ?? '';
          final fp      = k['fingerprint'] as String? ?? '';
          final expanded = _expandedPath == pubPath;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => _expandKey(pubPath),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: expanded ? AppTheme.accentDim : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: expanded ? AppTheme.accent : AppTheme.border),
                ),
                child: Row(children: [
                  Icon(Icons.key_rounded,
                    color: expanded ? AppTheme.accent : AppTheme.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: TextStyle(
                      color: expanded ? AppTheme.accent : AppTheme.textPrimary,
                      fontSize: 12, fontWeight: FontWeight.w600)),
                    if (fp.isNotEmpty)
                      Text(fp.length > 60 ? '${fp.substring(0, 60)}â€¦' : fp,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 9,
                          fontFamily: 'monospace')),
                  ])),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary, size: 16),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _deleteKey(k),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 16),
                    ),
                  ),
                ]),
              ),
            ),
            if (expanded) ...[
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Public key:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _copyToClipboard(_pubKeyContent),
                      child: Row(children: [
                        Icon(Icons.copy_rounded, color: AppTheme.accent, size: 12),
                        const SizedBox(width: 4),
                        Text('Copy', style: TextStyle(color: AppTheme.accent,
                          fontSize: 10, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(_pubKeyContent.isEmpty ? 'Loading...' : _pubKeyContent,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 9,
                      fontFamily: 'monospace'),
                    softWrap: true),
                ]),
              ),
            ],
            const SizedBox(height: 8),
          ]);
        }),
    ]),
  );
}

class _KeyCard extends StatelessWidget {
  final Widget child;
  const _KeyCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border),
    ),
    child: child,
  );
}

class _KTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  const _KTextField({required this.controller, required this.hint, this.obscure = false});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
    cursorColor: AppTheme.accent,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
      filled: true, fillColor: AppTheme.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.accent)),
    ),
  );
}
