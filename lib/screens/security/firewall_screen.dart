import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

class FirewallScreen extends StatefulWidget {
  const FirewallScreen({super.key});
  @override
  State<FirewallScreen> createState() => _FirewallScreenState();
}

class _FirewallScreenState extends State<FirewallScreen> {
  bool _enabled = false;
  bool _loading = true;
  bool _toggling = false;
  List<Map<String, dynamic>> _rules = [];

  // Add rule form
  final _portCtrl  = TextEditingController();
  String _proto     = 'tcp';
  String _action    = 'allow';
  String _direction = 'in';

  @override
  void initState() { super.initState(); _reload(); }

  @override
  void dispose() { _portCtrl.dispose(); super.dispose(); }

  Future<void> _reload() async {
    final status = await SystemBridge.firewallStatus();
    final rules  = await SystemBridge.firewallListRules();
    if (!mounted) return;
    setState(() {
      _enabled = status['enabled'] == true;
      _rules   = rules;
      _loading = false;
    });
  }

  Future<void> _toggle() async {
    setState(() => _toggling = true);
    final ok = _enabled
        ? await SystemBridge.firewallDisable()
        : await SystemBridge.firewallEnable();
    if (!mounted) return;
    if (ok) await _reload();
    setState(() => _toggling = false);
  }

  Future<void> _addRule() async {
    final port = _portCtrl.text.trim();
    if (port.isEmpty) return;
    final ok = await SystemBridge.firewallAddRule(
      port: port, proto: _proto, action: _action, direction: _direction);
    if (!mounted) return;
    if (ok) {
      _portCtrl.clear();
      await _reload();
    } else {
      _snack('Failed to add rule. Is UFW installed and running as root?', error: true);
    }
  }

  Future<void> _deleteRule(int num) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        title: Text('Delete rule #$num?',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        content: Text('This will permanently remove the firewall rule.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    await SystemBridge.firewallDeleteRule(num);
    if (mounted) await _reload();
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
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildAddRuleCard(),
                  const SizedBox(height: 16),
                  _buildRulesCard(),
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
        decoration: BoxDecoration(
          color: _enabled ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.shield_rounded,
          color: _enabled ? AppTheme.success : AppTheme.danger, size: 16),
      ),
      const SizedBox(width: 12),
      Text('Firewall (UFW)',
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

  Widget _buildStatusCard() => _FwCard(
    child: Row(children: [
      Icon(Icons.shield_rounded,
        size: 36, color: _enabled ? AppTheme.success : AppTheme.danger),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_enabled ? 'Firewall Active' : 'Firewall Disabled',
          style: TextStyle(
            color: _enabled ? AppTheme.success : AppTheme.danger,
            fontSize: 15, fontWeight: FontWeight.bold)),
        Text(_enabled
          ? 'UFW is running and enforcing rules'
          : 'System is unprotected â€” enable firewall',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ])),
      const SizedBox(width: 16),
      _toggling
        ? SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
        : GestureDetector(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _enabled
                  ? AppTheme.danger.withValues(alpha: 0.12)
                  : AppTheme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _enabled ? AppTheme.danger : AppTheme.success),
              ),
              child: Text(_enabled ? 'Disable' : 'Enable',
                style: TextStyle(
                  color: _enabled ? AppTheme.danger : AppTheme.success,
                  fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
    ]),
  );

  Widget _buildAddRuleCard() => _FwCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.add_circle_rounded, color: AppTheme.accent, size: 16),
        const SizedBox(width: 8),
        Text('Add Rule', style: TextStyle(color: AppTheme.accent, fontSize: 13,
          fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          flex: 3,
          child: _FwTextField(
            controller: _portCtrl,
            hint: 'Port (e.g. 22, 8080)',
            inputType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _FwDropdown<String>(
            value: _proto,
            items: const ['tcp', 'udp'],
            onChanged: (v) => setState(() => _proto = v!),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: _FwDropdown<String>(
            value: _action,
            items: const ['allow', 'deny', 'reject', 'limit'],
            onChanged: (v) => setState(() => _action = v!),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FwDropdown<String>(
            value: _direction,
            items: const ['in', 'out'],
            onChanged: (v) => setState(() => _direction = v!),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _addRule,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.accentDim,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accent),
            ),
            child: Text('Add', style: TextStyle(color: AppTheme.accent,
              fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    ]),
  );

  Widget _buildRulesCard() => _FwCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.list_alt_rounded, color: AppTheme.accent, size: 16),
        const SizedBox(width: 8),
        Text('Active Rules (${_rules.length})',
          style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),
      if (_rules.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('No rules configured',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
        )
      else
        ..._rules.map((r) {
          final num  = r['num'] as int? ?? 0;
          final rule = r['rule'] as String? ?? '';
          final isAllow = rule.toLowerCase().contains('allow');
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: (isAllow ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('$num',
                    style: TextStyle(
                      color: isAllow ? AppTheme.success : AppTheme.danger,
                      fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(rule,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 11,
                  fontFamily: 'monospace'))),
              GestureDetector(
                onTap: () => _deleteRule(num),
                child: Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 16),
              ),
            ]),
          );
        }),
    ]),
  );
}

// â”€â”€ Shared sub-widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FwCard extends StatelessWidget {
  final Widget child;
  const _FwCard({required this.child});
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

class _FwTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType inputType;
  const _FwTextField({required this.controller, required this.hint,
    this.inputType = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: inputType,
    inputFormatters: inputType == TextInputType.number
        ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))]
        : null,
    style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
    cursorColor: AppTheme.accent,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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

class _FwDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  const _FwDropdown({required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppTheme.surfaceAlt,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.border),
    ),
    child: DropdownButton<T>(
      value: value,
      items: items.map((i) => DropdownMenuItem<T>(
        value: i,
        child: Text('$i', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
      )).toList(),
      onChanged: onChanged,
      underline: const SizedBox(),
      dropdownColor: AppTheme.surfaceAlt,
      icon: Icon(Icons.expand_more, color: AppTheme.textSecondary, size: 16),
      isExpanded: true,
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
    ),
  );
}
