import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});
  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedResult {
  final DateTime date;
  final String cpu, diskRead, diskWrite, ramSpeed;
  _SpeedResult({required this.date, required this.cpu,
    required this.diskRead, required this.diskWrite, required this.ramSpeed});
  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(), 'cpu': cpu,
    'disk_read': diskRead, 'disk_write': diskWrite, 'ram': ramSpeed,
  };
  factory _SpeedResult.fromJson(Map<String, dynamic> m) => _SpeedResult(
    date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
    cpu: m['cpu'] as String? ?? '',
    diskRead: m['disk_read'] as String? ?? '',
    diskWrite: m['disk_write'] as String? ?? '',
    ramSpeed: m['ram'] as String? ?? '',
  );
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  bool _running = false;
  String _currentStep = '';
  double _progress = 0;
  _SpeedResult? _latest;
  List<_SpeedResult> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<File> _histFile() async {
    if (!kIsWeb && Platform.isLinux) {
      return File('/home/admin/.config/KrdOS/speedtest.json');
    }
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/speedtest.json');
  }

  Future<void> _loadHistory() async {
    try {
      final f = await _histFile();
      if (!await f.exists()) return;
      final list = jsonDecode(await f.readAsString()) as List;
      setState(() => _history = list.map((e) => _SpeedResult.fromJson(e as Map<String, dynamic>)).toList());
      if (_history.isNotEmpty) _latest = _history.last;
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final f = await _histFile();
      await f.writeAsString(jsonEncode(_history.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _run() async {
    setState(() { _running = true; _progress = 0; _currentStep = 'Benchmarking?'; });

    setState(() { _currentStep = 'Running benchmark?'; _progress = 0.1; });
    final raw = await SystemBridge.benchmarkRun();
    setState(() => _progress = 0.9);

    final result = _SpeedResult(
      date: DateTime.now(),
      cpu:       raw['cpu']        as String? ?? 'N/A',
      diskRead:  raw['disk_read']  as String? ?? 'N/A',
      diskWrite: raw['disk_write'] as String? ?? 'N/A',
      ramSpeed:  raw['ram_speed']  as String? ?? 'N/A',
    );

    _history.add(result);
    if (_history.length > 10) _history.removeAt(0);
    await _saveHistory();

    if (mounted) {
      setState(() { _running = false; _latest = result; _progress = 1.0; _currentStep = 'Done'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  // Header
          Row(children: [
            Icon(Icons.speed_rounded, color: AppTheme.accent, size: 24),
            const SizedBox(width: 10),
            Text('Speed Test', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w300)),
            const Spacer(),
            GestureDetector(
              onTap: _running ? null : _run,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _running ? AppTheme.surfaceAlt : AppTheme.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _running
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 8),
                        const Text('Running?', style: TextStyle(color: Colors.white)),
                      ])
                    : const Text('Run Test', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Measures CPU, RAM, and disk performance. Takes about 30 seconds.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),

          if (_running) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppTheme.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(_currentStep, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],

          if (_latest != null) ...[
            const SizedBox(height: 24),
            _sectionLabel('Latest Results ? ${_fmtDate(_latest!.date)}'),
            const SizedBox(height: 12),
            Row(children: [
              _resultCard('CPU', _latest!.cpu, Icons.memory_rounded, AppTheme.accent),
              const SizedBox(width: 10),
              _resultCard('RAM Speed', _latest!.ramSpeed, Icons.storage_rounded, const Color(0xFF7B68FF)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _resultCard('Disk Read', _latest!.diskRead, Icons.read_more_rounded, AppTheme.success),
              const SizedBox(width: 10),
              _resultCard('Disk Write', _latest!.diskWrite, Icons.save_rounded, AppTheme.warning),
            ]),
          ],

          if (_history.length > 1) ...[
            const SizedBox(height: 24),
            _sectionLabel('Test History'),
            const SizedBox(height: 10),
            ..._history.reversed.skip(1).take(5).map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_fmtDate(r.date), style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Row(children: [
                  _miniStat('CPU', r.cpu),
                  _miniStat('RAM', r.ramSpeed),
                  _miniStat('Read', r.diskRead),
                  _miniStat('Write', r.diskWrite),
                ]),
              ]),
            )),
          ],

          if (_latest == null && !_running) ...[
            const SizedBox(height: 60),
            Center(child: Column(children: [
              Icon(Icons.timer_outlined, color: AppTheme.textSecondary, size: 56),
              const SizedBox(height: 12),
              Text('No tests run yet. Tap "Run Test" to start.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ])),
          ],
        ]),
      ),
    );
  }

  Widget _resultCard(String label, String value, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 8),
        Text(value.isEmpty ? 'N/A' : value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w500)),
      ]),
    ),
  );

  Widget _miniStat(String label, String val) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      Text(val.isEmpty ? 'N/A' : val,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );

  Widget _sectionLabel(String t) => Text(t, style: TextStyle(
    color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2));

  String _fmtDate(DateTime d) =>
      '${d.year}-${_p2(d.month)}-${_p2(d.day)} ${_p2(d.hour)}:${_p2(d.minute)}';
  String _p2(int v) => v.toString().padLeft(2, '0');
}