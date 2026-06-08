import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

class MonitorsSettingsScreen extends StatefulWidget {
  const MonitorsSettingsScreen({super.key});
  @override
  State<MonitorsSettingsScreen> createState() => _MonitorsSettingsScreenState();
}

class _Monitor {
  final String output;
  bool connected;
  bool primary;
  bool enabled;
  String resolution;
  int refreshRate;
  double x, y;
  List<String> availableResolutions;

  _Monitor({
    required this.output,
    required this.connected,
    required this.primary,
    required this.enabled,
    required this.resolution,
    required this.refreshRate,
    required this.x,
    required this.y,
    required this.availableResolutions,
  });

  factory _Monitor.fromMap(Map<String, dynamic> m) => _Monitor(
    output:     m['output'] as String? ?? '',
    connected:  m['connected'] as bool? ?? false,
    primary:    m['primary'] as bool? ?? false,
    enabled:    (m['enabled'] as bool?) ?? true,
    resolution: m['resolution'] as String? ?? '1920x1080',
    refreshRate: (m['refresh_rate'] as num?)?.toInt() ?? 60,
    x:  (m['x'] as num?)?.toDouble() ?? 0,
    y:  (m['y'] as num?)?.toDouble() ?? 0,
    availableResolutions: (m['available_resolutions'] as List?)
        ?.map((e) => e.toString()).toList()
        ?? const ['3840x2160', '2560x1440', '1920x1080', '1280x720', '1024x768'],
  );

  Size get physicalSize {
    final parts = resolution.split('x');
    if (parts.length == 2) {
      return Size(double.tryParse(parts[0]) ?? 1920, double.tryParse(parts[1]) ?? 1080);
    }
    return const Size(1920, 1080);
  }
}

class _MonitorsSettingsScreenState extends State<MonitorsSettingsScreen> {
  List<_Monitor> _monitors = [];
  bool _loading = true;
  int? _dragging;
  bool _applying = false;
  String? _statusMsg;
  Timer? _hotplugTimer;
  Set<String> _knownOutputs = {};

  @override
  void initState() {
    super.initState();
    _detect();
    // Poll every 8 seconds for newly connected/disconnected monitors
    _hotplugTimer = Timer.periodic(const Duration(seconds: 8), (_) => _checkHotplug());
  }

  @override
  void dispose() {
    _hotplugTimer?.cancel();
    super.dispose();
  }

  /// Silent hotplug check — only reloads if connected outputs changed
  Future<void> _checkHotplug() async {
    if (_loading || _applying) return;
    final raw = await SystemBridge.detectMonitors();
    final newOutputs = raw
        .where((m) => m['connected'] == true)
        .map((m) => m['output']?.toString() ?? '')
        .toSet();
    if (!mounted) return;
    if (!_setEquals(newOutputs, _knownOutputs)) {
      // New monitor plugged in (or one removed) — reload full UI
      _knownOutputs = newOutputs;
      setState(() {
        _monitors = raw.map(_Monitor.fromMap).toList();
        _statusMsg = 'New display detected — review settings and apply.';
      });
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.every(b.contains);

  Future<void> _detect() async {
    setState(() { _loading = true; _statusMsg = null; });
    final raw = await SystemBridge.detectMonitors();
    setState(() {
      _monitors = raw.map(_Monitor.fromMap).toList();
      _knownOutputs = _monitors
          .where((m) => m.connected)
          .map((m) => m.output)
          .toSet();
      _loading = false;
    });
  }

  Future<void> _apply() async {
    setState(() { _applying = true; _statusMsg = null; });

    // Determine the primary output name (first connected primary, or first connected)
    final primary = _monitors.firstWhere(
      (m) => m.connected && m.primary,
      orElse: () => _monitors.firstWhere(
        (m) => m.connected,
        orElse: () => _monitors.first,
      ),
    ).output;

    // Build outputs map for set_arrangement
    final Map<String, Map<String, dynamic>> outputs = {};
    for (final m in _monitors) {
      if (!m.connected) continue;
      outputs[m.output] = {
        'enabled': m.enabled,
        'mode':   m.resolution,
        'rate':   m.refreshRate.toDouble(),
        'x':      m.x.toInt(),
        'y':      m.y.toInt(),
      };
    }

    // Use set_arrangement which handles primary, positions, resolutions all in one xrandr call
    final ok = await SystemBridge.setMonitorArrangement(
      primary: primary,
      outputs: outputs,
    );

    setState(() {
      _applying = false;
      _statusMsg = ok ? 'Settings applied.' : 'Some settings could not be applied.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(children: [
        _buildToolbar(),
        if (_loading)
          Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.accent)))
        else ...[
          _buildArrangementArea(),
          const SizedBox(height: 12),
          Expanded(child: _buildMonitorList()),
          if (_statusMsg != null)
            Container(
              padding: const EdgeInsets.all(10),
              color: AppTheme.surface,
              child: Text(_statusMsg!, style: TextStyle(color: AppTheme.success, fontSize: 13)),
            ),
          _buildApplyBar(),
        ],
      ]),
    );
  }

  Widget _buildToolbar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    color: AppTheme.surface,
    child: Row(children: [
      Icon(Icons.monitor, color: AppTheme.accent, size: 20),
      const SizedBox(width: 10),
      Text('Displays & Monitors',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const Spacer(),
      _btn('Detect', Icons.search, _detect),
    ]),
  );

  Widget _btn(String label, IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accentDim,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppTheme.accent, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppTheme.accent, fontSize: 13)),
      ]),
    ),
  );

  Widget _buildArrangementArea() {
  // Drag-and-drop arrangement canvas
    return Container(
      height: 180,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Stack(
        children: [
          Center(child: Text('Arrange displays by dragging',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          ..._monitors.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            if (!m.connected) return const SizedBox.shrink();
  // Simple preview positions (scaled down)
            final scale = 0.06;
            final w = m.physicalSize.width * scale;
            final h = m.physicalSize.height * scale;
            final offsetX = 20.0 + m.x * scale;
            final offsetY = 30.0 + m.y * scale;
            return Positioned(
              left: offsetX, top: offsetY, width: w, height: h,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    m.x = (m.x + d.delta.dx / scale).clamp(-1000, 5000);
                    m.y = (m.y + d.delta.dy / scale).clamp(-1000, 3000);
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: _dragging == i ? AppTheme.accentDim : AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: m.primary ? AppTheme.accent : AppTheme.border,
                      width: m.primary ? 2 : 1,
                    ),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.monitor, color: m.primary ? AppTheme.accent : AppTheme.textSecondary, size: 16),
                    Text(m.output, style: TextStyle(
                      color: m.primary ? AppTheme.accent : AppTheme.textPrimary,
                      fontSize: 9, fontWeight: FontWeight.w600,
                    )),
                    Text(m.resolution, style: TextStyle(color: AppTheme.textSecondary, fontSize: 8)),
                  ]),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonitorList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _monitors.length,
      itemBuilder: (_, i) => _MonitorCard(
        monitor: _monitors[i],
        onSetPrimary: () {
          setState(() {
            for (final m in _monitors) { m.primary = false; }
            _monitors[i].primary = true;
          });
          // Auto-apply primary change immediately via xrandr
          _apply();
        },
        onToggleEnabled: () => setState(() => _monitors[i].enabled = !_monitors[i].enabled),
        onResolutionChanged: (r) => setState(() => _monitors[i].resolution = r),
        onRefreshChanged: (r) => setState(() => _monitors[i].refreshRate = r),
      ),
    );
  }

  Widget _buildApplyBar() => Container(
    padding: const EdgeInsets.all(16),
    color: AppTheme.surface,
    child: Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: _applying ? null : _apply,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _applying ? AppTheme.surfaceAlt : AppTheme.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: _applying
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary)),
                    const SizedBox(width: 10),
                    Text('Applying...', style: TextStyle(color: AppTheme.textPrimary)),
                  ])
                : const Text('Apply Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    ]),
  );
}

class _MonitorCard extends StatelessWidget {
  final _Monitor monitor;
  final VoidCallback onSetPrimary;
  final VoidCallback onToggleEnabled;
  final ValueChanged<String> onResolutionChanged;
  final ValueChanged<int> onRefreshChanged;

  const _MonitorCard({
    required this.monitor,
    required this.onSetPrimary,
    required this.onToggleEnabled,
    required this.onResolutionChanged,
    required this.onRefreshChanged,
  });

  static const _rates = [30, 48, 60, 75, 90, 120, 144, 165, 240];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: monitor.primary
              ? AppTheme.accent.withValues(alpha: 0.6)
              : AppTheme.border.withValues(alpha: 0.5),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.monitor, color: monitor.primary ? AppTheme.accent : AppTheme.textSecondary, size: 20),
          const SizedBox(width: 10),
          Text(monitor.output, style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          if (monitor.primary) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentDim,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('PRIMARY', style: TextStyle(
                color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ],
          const Spacer(),
          Switch(
            value: monitor.enabled,
            activeColor: AppTheme.accent,
            onChanged: (_) => onToggleEnabled(),
          ),
        ]),
        if (monitor.enabled) ...[
          const SizedBox(height: 12),
  // Resolution
          Row(children: [
            SizedBox(width: 100, child: Text('Resolution:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButton<String>(
                  value: monitor.availableResolutions.contains(monitor.resolution)
                      ? monitor.resolution : monitor.availableResolutions.first,
                  items: monitor.availableResolutions.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  )).toList(),
                  onChanged: (v) { if (v != null) onResolutionChanged(v); },
                  dropdownColor: AppTheme.surfaceAlt,
                  underline: const SizedBox(),
                  isExpanded: true,
                  icon: Icon(Icons.expand_more, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
  // Refresh rate
          Row(children: [
            SizedBox(width: 100, child: Text('Refresh rate:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButton<int>(
                  value: _rates.contains(monitor.refreshRate) ? monitor.refreshRate : 60,
                  items: _rates.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text('$r Hz', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                  )).toList(),
                  onChanged: (v) { if (v != null) onRefreshChanged(v); },
                  dropdownColor: AppTheme.surfaceAlt,
                  underline: const SizedBox(),
                  isExpanded: true,
                  icon: Icon(Icons.expand_more, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (!monitor.primary)
            GestureDetector(
              onTap: onSetPrimary,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text('Set as Primary',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
            ),
        ],
      ]),
    );
  }
}