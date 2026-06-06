import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  String _lastRun = 'Checking?';
  bool _running = false;
  final List<String> _log = [];
  List<Map<String, dynamic>> _startupServices = [];
  bool _loadingStartup = false;
  String _optimizeStatus = '';

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadStartup();
  }

  Future<void> _loadStatus() async {
    final s = await SystemBridge.maintenanceStatus();
    if (mounted) setState(() => _lastRun = s.isEmpty ? 'Never' : s);
  }

  Future<void> _loadStartup() async {
    setState(() => _loadingStartup = true);
    final list = await SystemBridge.startupList();
    if (mounted) setState(() { _startupServices = list; _loadingStartup = false; });
  }

  Future<void> _runMaintenance() async {
    setState(() { _running = true; _log.clear(); });
    _log.add('Starting maintenance?');
    final tasks = [
      ('Cleaning temp files?',      () => SystemBridge.diskClean('/tmp')),
      ('Cleaning apt cache?',       () => SystemBridge.terminalExecute('apt-get clean -y')),
      ('Removing orphan packages?', () => SystemBridge.terminalExecute('apt-get autoremove -y')),
      ('Vacuuming system logs?',    () => SystemBridge.terminalExecute('journalctl --vacuum-time=7d')),
      ('Trimming SSD?',            () => SystemBridge.terminalExecute('fstrim -av')),
      ('Freeing cached memory?',    SystemBridge.dropCaches),
    ];
    for (final (msg, fn) in tasks) {
      if (!mounted) break;
      setState(() => _log.add('  ? $msg'));
      await fn();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) {
      setState(() {
        _running = false;
        _lastRun = DateTime.now().toString().substring(0, 16);
        _log.add('? Maintenance complete ? ${_lastRun}');
      });
    }
  }

  Future<void> _optimize() async {
    setState(() => _optimizeStatus = 'Applying optimizations?');
    await SystemBridge.systemOptimize();
    await SystemBridge.setCpuGovernor('performance');
    if (mounted) setState(() => _optimizeStatus = '? Optimizations applied');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _section('System Health'),
          _infoRow(Icons.schedule_rounded, 'Last maintenance', _lastRun),
          _infoRow(Icons.update_rounded, 'Next scheduled',
              'Every Sunday 3:00 AM (auto)'),
          const SizedBox(height: 16),
          _btn('Run Maintenance Now', Icons.cleaning_services,
              _running ? null : _runMaintenance,
              loading: _running),
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: _log.map((l) => Text(l,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12,
                      fontFamily: 'monospace'))).toList()),
            ),
          ],

          const SizedBox(height: 24),
          _section('Performance Optimization'),
          Text('Apply permanent speed settings: performance CPU governor, zRAM, '
               'SSD trim, optimal I/O scheduler.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          _btn('Optimize System Speed', Icons.speed, _optimize),
          if (_optimizeStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_optimizeStatus, style: TextStyle(
              color: _optimizeStatus.startsWith('?') ? AppTheme.success : AppTheme.textSecondary,
              fontSize: 13)),
          ],

          const SizedBox(height: 24),
          _section('RAM Cleaner'),
          Text('Safely frees cached memory so apps run faster immediately.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          _btn('Free Cached RAM', Icons.memory_rounded, () async {
            await SystemBridge.dropCaches();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Cached memory freed'),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ));
            }
          }),

          const SizedBox(height: 24),
          _section('Startup Manager'),
          Text('Choose which services start automatically when the OS boots.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          if (_loadingStartup)
            const Center(child: CircularProgressIndicator())
          else
            ..._startupServices.take(15).map((svc) => _serviceRow(svc)),

          const SizedBox(height: 24),
          _section('Disk Health'),
          _btn('Check Disk Health', Icons.storage_rounded, () async {
            final h = await SystemBridge.diskHealth('/dev/sda');
            if (!mounted) return;
            showDialog(context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppTheme.surfaceAlt,
                title: Text('Disk Health', style: TextStyle(color: AppTheme.textPrimary)),
                content: Text(h, style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace')),
                actions: [TextButton(onPressed: () => Navigator.pop(context),
                    child: const Text('OK'))],
              ),
            );
          }),
        ]),
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(
      color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, color: AppTheme.textSecondary, size: 18),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      const Spacer(),
      Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
    ]),
  );

  Widget _btn(String label, IconData icon, VoidCallback? onTap, {bool loading = false}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 44,
        decoration: BoxDecoration(
          color: onTap == null ? AppTheme.surfaceAlt : AppTheme.accentDim,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.accent.withValues(alpha: onTap == null ? 0.1 : 0.4)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.accent))
          else
            Icon(icon, color: onTap == null ? AppTheme.textSecondary : AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            color: onTap == null ? AppTheme.textSecondary : AppTheme.accent,
            fontSize: 14, fontWeight: FontWeight.w500,
          )),
        ]),
      ),
    );

  Widget _serviceRow(Map<String, dynamic> svc) {
    final name    = svc['name']    as String? ?? '';
    final enabled = svc['enabled'] as bool?   ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Expanded(child: Text(name,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
        Switch(
          value: enabled,
          activeColor: AppTheme.accent,
          onChanged: (v) async {
            await SystemBridge.startupToggle(name, v);
            _loadStartup();
          },
        ),
      ]),
    );
  }
}
