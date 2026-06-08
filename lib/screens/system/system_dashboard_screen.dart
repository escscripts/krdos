import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

class SystemDashboardScreen extends StatefulWidget {
  const SystemDashboardScreen({super.key});
  @override
  State<SystemDashboardScreen> createState() => _SystemDashboardScreenState();
}

class _SystemDashboardScreenState extends State<SystemDashboardScreen> {
  Map<String, dynamic> _info    = {};
  Map<String, dynamic> _stats   = {};
  Map<String, dynamic> _cpu     = {};
  Map<String, dynamic> _battery = {};
  List<Map<String, dynamic>> _disks = [];
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _refresh() async {
    final results = await Future.wait([
      SystemBridge.systemInfo(),
      SystemBridge.systemStats(),
      SystemBridge.cpuDetail(),
      SystemBridge.batteryStatus(),
      SystemBridge.diskUsage(),
    ]);
    if (!mounted) return;
    setState(() {
      _info    = results[0] as Map<String, dynamic>;
      _stats   = results[1] as Map<String, dynamic>;
      _cpu     = results[2] as Map<String, dynamic>;
      _battery = results[3] as Map<String, dynamic>;
      _disks   = results[4] as List<Map<String, dynamic>>;
      _loading = false;
    });
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
                  _buildIdentityCard(),
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(children: [
                      _buildCpuCard(),
                      const SizedBox(height: 16),
                      _buildMemoryCard(),
                    ])),
                    const SizedBox(width: 16),
                    Expanded(child: Column(children: [
                      _buildUptimeCard(),
                      const SizedBox(height: 16),
                      if ((_battery['has_battery'] as bool?) == true) _buildBatteryCard(),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  _buildDisksCard(),
                  const SizedBox(height: 16),
                  _buildLoadCard(),
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
        child: Icon(Icons.monitor_heart_rounded, color: AppTheme.accent, size: 16),
      ),
      const SizedBox(width: 12),
      Text('System Dashboard',
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
      const Spacer(),
      GestureDetector(
        onTap: _refresh,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.accentDim, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.refresh_rounded, color: AppTheme.accent, size: 16),
        ),
      ),
    ]),
  );

  Widget _buildIdentityCard() {
    final hostname   = _info['hostname']  ?? 'krdos';
    final kernel     = _info['kernel']    ?? 'â€”';
    final arch       = _info['arch']      ?? 'â€”';
    final cpuModel   = _info['cpu_model'] ?? 'â€”';
    final cpuCores   = _info['cpu_cores'] ?? 'â€”';
    final ramDisplay = _info['ram']       ?? 'â€”';
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.computer_rounded, 'Identity'),
        const SizedBox(height: 12),
        _infoRow('Hostname',  hostname),
        _infoRow('Kernel',    kernel),
        _infoRow('Arch',      arch),
        _infoRow('CPU',       cpuModel),
        _infoRow('Cores',     '$cpuCores'),
        _infoRow('RAM',       ramDisplay),
      ]),
    );
  }

  Widget _buildCpuCard() {
    final cpuPct = (_stats['cpu_percent'] as num?)?.toDouble() ?? 0.0;
    final cores  = (_cpu['cores'] as List?)?.cast<num>() ?? [];
    final temp   = (_cpu['temp_c'] as num?)?.toDouble();
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _sectionTitle(Icons.developer_board_rounded, 'CPU'),
          const Spacer(),
          if (temp != null)
            _Chip(text: '${temp.toStringAsFixed(0)}Â°C',
              color: temp > 80 ? AppTheme.danger : temp > 60 ? AppTheme.warning : AppTheme.success),
        ]),
        const SizedBox(height: 12),
        _BarRow(label: 'Total', value: cpuPct / 100, color: AppTheme.accent),
        const SizedBox(height: 8),
        if (cores.isNotEmpty) ...[
          Text('Per core', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          ...cores.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _BarRow(
              label: 'Core ${e.key}',
              value: (e.value.toDouble() / 100).clamp(0, 1),
              color: AppTheme.accent.withValues(alpha: 0.7),
            ),
          )),
        ],
      ]),
    );
  }

  Widget _buildMemoryCard() {
    final totalKb = (_stats['mem_total_kb'] as num?)?.toDouble() ?? 1;
    final usedKb  = (_stats['mem_used_kb']  as num?)?.toDouble() ?? 0;
    final pct     = (usedKb / totalKb).clamp(0.0, 1.0);
    final usedGb  = (usedKb / 1024 / 1024).toStringAsFixed(1);
    final totalGb = (totalKb / 1024 / 1024).toStringAsFixed(1);
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.memory_rounded, 'Memory'),
        const SizedBox(height: 12),
        _BarRow(label: '$usedGb / $totalGb GB', value: pct,
          color: pct > 0.85 ? AppTheme.danger : pct > 0.65 ? AppTheme.warning : AppTheme.success),
        const SizedBox(height: 8),
        Row(children: [
          _LegendDot(color: AppTheme.success),
          const SizedBox(width: 4),
          Text('Free: ${((totalKb - usedKb) / 1024 / 1024).toStringAsFixed(1)} GB',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildUptimeCard() {
    final secs = (_stats['uptime_seconds'] as num?)?.toDouble() ?? 0;
    final d = (secs ~/ 86400);
    final h = ((secs % 86400) ~/ 3600);
    final m = ((secs % 3600) ~/ 60);
    final uptime = d > 0 ? '${d}d ${h}h ${m}m' : '${h}h ${m}m';
    final load1  = (_stats['load_avg_1']  as num?)?.toStringAsFixed(2) ?? '0.00';
    final load5  = (_stats['load_avg_5']  as num?)?.toStringAsFixed(2) ?? '0.00';
    final load15 = (_stats['load_avg_15'] as num?)?.toStringAsFixed(2) ?? '0.00';
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.access_time_rounded, 'Uptime & Load'),
        const SizedBox(height: 12),
        Center(
          child: Text(uptime,
            style: TextStyle(color: AppTheme.accent, fontSize: 28, fontWeight: FontWeight.bold,
              fontFamily: 'monospace')),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _LoadBadge(label: '1m',  value: load1),
          _LoadBadge(label: '5m',  value: load5),
          _LoadBadge(label: '15m', value: load15),
        ]),
      ]),
    );
  }

  Widget _buildBatteryCard() {
    final lvl      = (_battery['level'] as num?)?.toInt() ?? 0;
    final charging = _battery['charging'] == true;
    final status   = _battery['status'] as String? ?? '';
    final color    = lvl <= 15 ? AppTheme.danger : lvl <= 30 ? AppTheme.warning : AppTheme.success;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(
          charging ? Icons.battery_charging_full_rounded : Icons.battery_full_rounded,
          'Battery'),
        const SizedBox(height: 12),
        _BarRow(label: '$lvl%', value: lvl / 100, color: color),
        const SizedBox(height: 8),
        Row(children: [
          _Chip(text: charging ? 'Charging' : status, color: charging ? AppTheme.success : AppTheme.textSecondary),
        ]),
      ]),
    );
  }

  Widget _buildDisksCard() {
    if (_disks.isEmpty) return const SizedBox.shrink();
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.storage_rounded, 'Disk Usage'),
        const SizedBox(height: 12),
        ..._disks.map((d) {
          final mount  = d['mountpoint'] as String? ?? '';
          final size   = d['size']       as String? ?? '';
          final used   = d['used']       as String? ?? '';
          final pctStr = (d['use_pct']   as String? ?? '0%').replaceAll('%', '');
          final pct    = (double.tryParse(pctStr) ?? 0) / 100;
          final color  = pct > 0.9 ? AppTheme.danger : pct > 0.75 ? AppTheme.warning : AppTheme.success;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(mount, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12,
                  fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('$used / $size', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ]),
              const SizedBox(height: 4),
              _BarRow(label: '', value: pct, color: color, showLabel: false),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildLoadCard() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(Icons.speed_rounded, 'Quick Actions'),
        const SizedBox(height: 12),
        Row(children: [
          _ActionBtn(label: 'Reboot', icon: Icons.restart_alt_rounded, color: AppTheme.warning,
            onTap: () => _confirmPower(context, 'Reboot', SystemBridge.reboot)),
          const SizedBox(width: 10),
          _ActionBtn(label: 'Shutdown', icon: Icons.power_settings_new_rounded, color: AppTheme.danger,
            onTap: () => _confirmPower(context, 'Shutdown', SystemBridge.shutdown)),
          const SizedBox(width: 10),
          _ActionBtn(label: 'Sleep', icon: Icons.bedtime_rounded, color: AppTheme.accent,
            onTap: SystemBridge.sleep),
        ]),
      ]),
    );
  }

  Future<void> _confirmPower(BuildContext ctx, String action, Future<void> Function() fn) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        title: Text(action, style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Confirm $action?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok == true) fn();
  }

  Widget _sectionTitle(IconData icon, String label) => Row(children: [
    Icon(icon, color: AppTheme.accent, size: 16),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
  ]);

  Widget _infoRow(String key, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 70, child: Text(key,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
      Expanded(child: Text(val,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 11,
          fontWeight: FontWeight.w500, fontFamily: 'monospace'),
        overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
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

class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool showLabel;
  const _BarRow({required this.label, required this.value, required this.color,
    this.showLabel = true});
  @override
  Widget build(BuildContext context) => Row(children: [
    if (showLabel && label.isNotEmpty) ...[
      SizedBox(width: 80,
        child: Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10))),
    ],
    Expanded(child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: AppTheme.border,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    )),
    const SizedBox(width: 6),
    Text('${(value * 100).round()}%',
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  ]);
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

class _LoadBadge extends StatelessWidget {
  final String label, value;
  const _LoadBadge({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18,
      fontWeight: FontWeight.bold, fontFamily: 'monospace')),
    Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
  ]);
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 8, height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color,
    required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    ),
  ));
}
