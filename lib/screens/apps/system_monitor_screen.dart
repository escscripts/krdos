import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/platform/system_bridge.dart';
import '../../core/settings_state.dart';
import '../../theme/app_theme.dart';

/// Task Manager + Performance monitor for the KrdOS shell.
///
/// This is wired by `HomeScreen` so it can list and manage live windows.
class SystemMonitorScreen extends StatefulWidget {
  const SystemMonitorScreen({
    super.key,
    required this.getWindows,
    required this.onFocusWindow,
    required this.onToggleMinimize,
    required this.onToggleMaximize,
    required this.onCloseWindow,
  });

  final List<dynamic> Function() getWindows;
  final void Function(String windowId) onFocusWindow;
  final void Function(String windowId) onToggleMinimize;
  final void Function(String windowId) onToggleMaximize;
  final void Function(String windowId) onCloseWindow;

  @override
  State<SystemMonitorScreen> createState() => _SystemMonitorScreenState();
}

class _SystemMonitorScreenState extends State<SystemMonitorScreen> {
  late int _tab = 0;
  Timer? _ticker;

  final _cpu = _RollingSeries(120);
  final _mem = _RollingSeries(120);
  final _disk = _RollingSeries(120);
  final _net = _RollingSeries(120);

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _seed();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 900), (_) async {
      await _tick();
    });
  }

  // Live stats from the last poll
  double _cpuPct = 0, _memPct = 0;
  double _uptime = 0, _load1 = 0, _load5 = 0;
  int _rxBytes = 0, _txBytes = 0;

  void _seed() {
  // Pre-fill with zeros so charts render immediately before first poll
    for (var i = 0; i < 60; i++) {
      _cpu.push(0.0); _mem.push(0.0); _disk.push(0.0); _net.push(0.0);
    }
  }

  bool _polling = false; // guard: prevents concurrent /proc reads from stacking up

  Future<void> _tick() async {
    if (_polling) return; // previous poll still in flight ? skip this tick
    _polling = true;
    if (!kIsWeb) {
      try {
        final stats = await SystemBridge.systemStats();
        final netStats = await SystemBridge.networkStats();
        final cpu  = ((stats['cpu_percent'] as num?)?.toDouble() ?? 0) / 100.0;
        final memT = (stats['mem_total_kb'] as num?)?.toDouble() ?? 1;
        final memU = (stats['mem_used_kb']  as num?)?.toDouble() ?? 0;
        final mem  = (memT > 0) ? (memU / memT).clamp(0.0, 1.0) : 0.0;
        final rxNow = (netStats['rx_bytes'] as num?)?.toInt() ?? 0;
        final txNow = (netStats['tx_bytes'] as num?)?.toInt() ?? 0;
        final rxDelta = (rxNow - _rxBytes).abs();
        final txDelta = (txNow - _txBytes).abs();
        _rxBytes = rxNow; _txBytes = txNow;
        final netLoad = ((rxDelta + txDelta) / 1000000.0).clamp(0.0, 1.0);
        if (mounted) {
          setState(() {
            _cpuPct = cpu * 100;
            _memPct = mem * 100;
            _uptime = (stats['uptime_seconds'] as num?)?.toDouble() ?? 0;
            _load1  = (stats['load_avg_1']  as num?)?.toDouble() ?? 0;
            _load5  = (stats['load_avg_5']  as num?)?.toDouble() ?? 0;
            _cpu.push(cpu);
            _mem.push(mem);
            _disk.push(0.0); // disk I/O polling added separately
            _net.push(netLoad);
          });
        }
        return;
      } catch (_) { /* fall through to demo data */ }
      finally { _polling = false; }
    }
    _polling = false;
  // Demo mode (Windows dev machine ? simulated data so UI is previewable)
    final r = _rng();
    if (mounted) {
      setState(() {
        _cpu.push(_nextFrom(_cpu.last, r, floor: 0.05, ceil: 0.97, step: 0.10));
        _mem.push(_nextFrom(_mem.last, r, floor: 0.18, ceil: 0.88, step: 0.06));
        _disk.push(_nextFrom(_disk.last, r, floor: 0.02, ceil: 0.95, step: 0.12));
        _net.push(_nextFrom(_net.last, r, floor: 0.01, ceil: 0.99, step: 0.18));
        _cpuPct = _cpu.last * 100;
        _memPct = _mem.last * 100;
      });
    }
  }

  math.Random _rng() {
    final t = DateTime.now().millisecondsSinceEpoch ~/ 900;
    return math.Random(t);
  }

  double _nextFrom(double prev, math.Random r,
      {required double floor, required double ceil, required double step}) {
    final p0 = prev.isFinite ? prev : (floor + ceil) / 2;
    final d = (r.nextDouble() - 0.5) * 2 * step;
    final x = (p0 + d).clamp(floor, ceil);
    final toward = (floor + ceil) / 2;
    return (x * 0.88 + toward * 0.12).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    return Container(
      color: const Color(0xFF050A0E),
      child: Column(
        children: [
          _Header(
            tab: _tab,
            onPickTab: (i) => setState(() => _tab = i),
            searchCtrl: _searchCtrl,
            accent: settings.accentColor,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_tab) {
                0 => KeyedSubtree(key: const ValueKey('tm_overview'), child: _overview(settings)),
                1 => KeyedSubtree(key: const ValueKey('tm_perf'), child: _performance(settings)),
                _ => KeyedSubtree(key: const ValueKey('tm_proc'), child: _processes(settings)),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _overview(SettingsState settings) {
    final acc = settings.accentColor;
    final windows = widget.getWindows();
    final running = windows.length;
    final minimized = windows.where((w) => (w.minimized as bool?) == true).length;

    return ListView(
      key: const ValueKey('overview'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _hero(
          title: 'System Monitor',
          subtitle:
              'Real window control + simulated metrics tuned for the KrdOS shell.',
          accent: acc,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = w > 980 ? 4 : w > 720 ? 2 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cols == 4 ? 1.55 : 1.85,
              children: [
                _metricCard(
                  title: 'CPU load',
                  value: _pct(_cpu.last),
                  tone: acc,
                  icon: Icons.memory_rounded,
                  series: _cpu.values,
                ),
                _metricCard(
                  title: 'Memory pressure',
                  value: _pct(_mem.last),
                  tone: AppTheme.warning,
                  icon: Icons.sd_storage_rounded,
                  series: _mem.values,
                ),
                _metricCard(
                  title: 'Disk activity',
                  value: _pct(_disk.last),
                  tone: const Color(0xFF8B5CF6),
                  icon: Icons.storage_rounded,
                  series: _disk.values,
                ),
                _metricCard(
                  title: 'Network',
                  value: _pct(_net.last),
                  tone: const Color(0xFF00D4FF),
                  icon: Icons.wifi_rounded,
                  series: _net.values,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: acc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.window_rounded, color: acc, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session windows',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$running running · $minimized minimized',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _tab = 2),
                child: Text('View processes', style: TextStyle(color: acc, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _performance(SettingsState settings) {
    final acc = settings.accentColor;
    return ListView(
      key: const ValueKey('performance'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _sectionTitle('Performance', 'Rolling charts (last ~2 minutes).', acc),
        const SizedBox(height: 14),
        _bigChart(
          label: 'CPU',
          value: _pct(_cpu.last),
          tone: acc,
          series: _cpu.values,
        ),
        const SizedBox(height: 12),
        _bigChart(
          label: 'Memory pressure',
          value: _pct(_mem.last),
          tone: AppTheme.warning,
          series: _mem.values,
        ),
        const SizedBox(height: 12),
        _bigChart(
          label: 'Disk activity',
          value: _pct(_disk.last),
          tone: const Color(0xFF8B5CF6),
          series: _disk.values,
        ),
        const SizedBox(height: 12),
        _bigChart(
          label: 'Network',
          value: _pct(_net.last),
          tone: const Color(0xFF00D4FF),
          series: _net.values,
        ),
      ],
    );
  }

  Widget _processes(SettingsState settings) {
    final acc = settings.accentColor;
    final windows = widget.getWindows();
    final rows = windows
        .map((w) => _ProcRow(
              id: w.id as String,
              title: w.title as String,
              icon: w.icon as IconData,
              color: w.color as Color,
              minimized: w.minimized as bool,
              maximized: w.maximized as bool,
              cpu: _pseudoUsage(w.id as String, salt: 13, base: 0.08, amp: 0.42),
              mem: _pseudoUsage(w.id as String, salt: 77, base: 0.12, amp: 0.55),
            ))
        .where((p) {
          if (_query.isEmpty) return true;
          return p.title.toLowerCase().contains(_query) || p.id.toLowerCase().contains(_query);
        })
        .toList()
      ..sort((a, b) => b.cpu.compareTo(a.cpu));

    return ListView(
      key: const ValueKey('processes'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        _sectionTitle('Processes', 'Live windows + per-task controls.', acc),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              windows.isEmpty ? 'No windows are running.' : 'No matches.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _procHeader(),
                for (final p in rows) _procTile(p, acc),
              ],
            ),
          ),
      ],
    );
  }

  double _pseudoUsage(String id, {required int salt, required double base, required double amp}) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c + salt) & 0x7fffffff;
    }
    final r = math.Random(h);
  // Make it react slightly to global CPU to feel "alive"
    final global = _cpu.last;
    final v = base + r.nextDouble() * amp + global * 0.15;
    return v.clamp(0.0, 1.0);
  }

  Widget _procHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt.withValues(alpha: 0.65),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.7))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(
            child: Text('App', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.9)),
          ),
          SizedBox(
            width: 76,
            child: Text('CPU', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.9)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 86,
            child: Text('Memory', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.9)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 190,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Actions', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _procTile(_ProcRow p, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.55))),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: p.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.color.withValues(alpha: 0.35)),
            ),
            child: Icon(p.icon, color: p.color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                    ),
                    if (p.minimized)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _pill('MIN', AppTheme.textSecondary),
                      ),
                    if (p.maximized)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _pill('MAX', accent),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  p.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.88), fontSize: 10.5),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(_pct(p.cpu), textAlign: TextAlign.right, style: TextStyle(color: accent.withValues(alpha: 0.95), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 86,
            child: Text(_pct(p.mem), textAlign: TextAlign.right, style: TextStyle(color: AppTheme.warning.withValues(alpha: 0.95), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 190,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _miniBtn(
                  icon: Icons.visibility_rounded,
                  label: 'Focus',
                  tone: accent,
                  onTap: () => widget.onFocusWindow(p.id),
                ),
                const SizedBox(width: 6),
                _miniBtn(
                  icon: p.minimized ? Icons.open_in_full_rounded : Icons.minimize_rounded,
                  label: p.minimized ? 'Restore' : 'Minimize',
                  tone: AppTheme.textSecondary,
                  onTap: () => widget.onToggleMinimize(p.id),
                ),
                const SizedBox(width: 6),
                _miniBtn(
                  icon: Icons.crop_square_rounded,
                  label: p.maximized ? 'Unmax' : 'Max',
                  tone: const Color(0xFF8B5CF6),
                  onTap: () => widget.onToggleMaximize(p.id),
                ),
                const SizedBox(width: 6),
                _miniBtn(
                  icon: Icons.close_rounded,
                  label: 'End',
                  tone: AppTheme.danger,
                  onTap: () => widget.onCloseWindow(p.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn({
    required IconData icon,
    required String label,
    required Color tone,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tone.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, size: 16, color: tone),
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color tone,
    required IconData icon,
    required List<double> series,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tone, size: 20),
              const Spacer(),
              Text(value, style: TextStyle(color: tone, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: CustomPaint(
              painter: _SparkPainter(series: series, tone: tone),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Rolling', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _bigChart({
    required String label,
    required String value,
    required Color tone,
    required List<double> series,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              Text(value, style: TextStyle(color: tone, fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _SparkPainter(series: series, tone: tone, fill: true),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero({
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surface,
            AppTheme.surfaceAlt.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.55)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: const Icon(Icons.monitor_heart_rounded, color: Colors.black, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.2)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle, Color accent) {
    return Row(
      children: [
        Container(width: 3, height: 28, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.25)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  static String _pct(double v) {
    if (!v.isFinite) return '0%';
    return '${(v.clamp(0.0, 1.0) * 100).round()}%';
  }

  static Widget _pill(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.28)),
      ),
      child: Text(
        t,
        style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.7),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tab,
    required this.onPickTab,
    required this.searchCtrl,
    required this.accent,
  });

  final int tab;
  final ValueChanged<int> onPickTab;
  final TextEditingController searchCtrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F14),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 720;
          final titleBlock = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.65)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.monitor_heart_rounded, color: Colors.black, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SYSTEM MONITOR', style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 2),
                    Text('Task Manager', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  ],
                ),
              ),
            ],
          );

          final tabs = Row(
            children: [
              _tabBtn(0, 'Overview'),
              const SizedBox(width: 8),
              _tabBtn(1, 'Performance'),
              const SizedBox(width: 8),
              _tabBtn(2, 'Processes'),
            ],
          );

          final search = TextField(
            controller: searchCtrl,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'search windows?',
              hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.75), fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
              suffixIcon: searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: searchCtrl.clear,
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                    ),
              filled: true,
              fillColor: AppTheme.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: accent, width: 1.2),
              ),
            ),
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleBlock,
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      tabs,
                      const SizedBox(width: 12),
                      SizedBox(width: (c.maxWidth - 28).clamp(160.0, 320.0), child: search),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              ...titleBlock.children,
              tabs,
              const SizedBox(width: 12),
              SizedBox(width: 240, child: search),
            ],
          );
        },
      ),
    );
  }

  Widget _tabBtn(int i, String label) {
    final on = tab == i;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onPickTab(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: on ? accent.withValues(alpha: 0.12) : AppTheme.surfaceAlt.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? accent.withValues(alpha: 0.6) : AppTheme.border.withValues(alpha: 0.55)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? accent : AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _RollingSeries {
  _RollingSeries(this.capacity);
  final int capacity;
  final List<double> _vals = [];
  List<double> get values => List.unmodifiable(_vals);
  double get last => _vals.isEmpty ? 0.0 : _vals.last;
  void push(double v) {
    final x = v.isFinite ? v.clamp(0.0, 1.0) : 0.0;
    _vals.add(x);
    if (_vals.length > capacity) _vals.removeAt(0);
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.series, required this.tone, this.fill = false});
  final List<double> series;
  final Color tone;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (!size.isFinite || size.width <= 0 || size.height <= 0) return;
    if (series.length < 2) return;

    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final grid = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    canvas.drawPath(grid, bg);

    final w = size.width;
    final h = size.height;
    final span = math.max(1, series.length - 1);
    final dx = w / span;

    final p = Path();
    for (var i = 0; i < series.length; i++) {
      final x = i * dx;
      final t = series[i];
      final ty = (t.isFinite ? t.clamp(0.0, 1.0) : 0.0) * h;
      final y = h - ty;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }

    if (fill) {
      final fp = Path.from(p)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            tone.withValues(alpha: 0.22),
            tone.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fp, fillPaint);
    }

    final stroke = Paint()
      ..color = tone.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(p, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.tone != tone || oldDelegate.fill != fill;
  }
}

class _ProcRow {
  _ProcRow({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.minimized,
    required this.maximized,
    required this.cpu,
    required this.mem,
  });
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final bool minimized;
  final bool maximized;
  final double cpu;
  final double mem;
}
