import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});
  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> with TickerProviderStateMixin {
  Timer? _timer;
  DateTime _now = DateTime.now();
  int _tab = 0; // 0=clock 1=alarms 2=world 3=stopwatch 4=timer

  // Stopwatch
  Stopwatch _sw = Stopwatch();
  Duration _swDisplay = Duration.zero;
  final List<Duration> _swLaps = [];

  // Timer
  int _timerSeconds = 0;
  int _timerTotal = 0;
  Timer? _timerTicker;
  bool _timerRunning = false;
  final _timerCtrl = TextEditingController(text: '00:05:00');

  // Alarms
  final List<Map<String, dynamic>> _alarms = [];

  // World clocks
  final List<Map<String, String>> _worldClocks = const [
    {'city': 'New York',    'tz': 'America/New_York',   'offset': '-5'},
    {'city': 'London',      'tz': 'Europe/London',       'offset': '+0'},
    {'city': 'Dubai',       'tz': 'Asia/Dubai',          'offset': '+4'},
    {'city': 'Tokyo',       'tz': 'Asia/Tokyo',          'offset': '+9'},
    {'city': 'Sydney',      'tz': 'Australia/Sydney',    'offset': '+11'},
    {'city': 'Los Angeles', 'tz': 'America/Los_Angeles', 'offset': '-8'},
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      setState(() {
        _now = DateTime.now();
        if (_sw.isRunning) _swDisplay = _sw.elapsed;
      });
    });
    _loadAlarms();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerTicker?.cancel();
    _timerCtrl.dispose();
    super.dispose();
  }

  Future<File> _alarmsFile() async {
    if (!kIsWeb && Platform.isLinux) {
  // Real filesystem ? survives reinstall and settings wipe
      final dir = Directory('/home/admin/.config/KrdOS');
      if (!await dir.exists()) await dir.create(recursive: true);
      return File('${dir.path}/alarms.json');
    }
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/alarms.json');
  }

  Future<void> _loadAlarms() async {
    try {
      final f = await _alarmsFile();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString()) as List;
        setState(() {
          _alarms.clear();
          for (final e in raw) {
            _alarms.add({
              'time':    e['time']    as String? ?? '',
              'label':   e['label']   as String? ?? '',
              'enabled': e['enabled'] as bool?   ?? true,
            });
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAlarms() async {
    try {
      final f = await _alarmsFile();
      await f.writeAsString(jsonEncode(_alarms));
    } catch (_) {}
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _clockStr(DateTime t) =>
      '${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}';

  String _durationStr(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final ms = (d.inMilliseconds % 1000) ~/ 10;
    return h > 0
        ? '${_pad(h)}:${_pad(m)}:${_pad(s)}'
        : '${_pad(m)}:${_pad(s)}.${_pad(ms)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(children: [
  // Tab bar
        Container(
          height: 48,
          color: AppTheme.surface,
          child: Row(
            children: ['Clock', 'Alarms', 'World', 'Stopwatch', 'Timer']
                .asMap()
                .entries
                .map((e) => GestureDetector(
                      onTap: () => setState(() => _tab = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(
                            color: _tab == e.key ? AppTheme.accent : Colors.transparent,
                            width: 2,
                          )),
                        ),
                        child: Text(e.value,
                            style: TextStyle(
                              color: _tab == e.key ? AppTheme.accent : AppTheme.textSecondary,
                              fontSize: 13, fontWeight: FontWeight.w500,
                            )),
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(child: _buildTab()),
      ]),
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 0: return _buildClock();
      case 1: return _buildAlarms();
      case 2: return _buildWorld();
      case 3: return _buildStopwatch();
      case 4: return _buildTimer();
      default: return _buildClock();
    }
  }

  Widget _buildClock() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
  // Analog clock face
        SizedBox(
          width: 220, height: 220,
          child: CustomPaint(painter: _AnalogClockPainter(_now)),
        ),
        const SizedBox(height: 24),
        Text(_clockStr(_now), style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 56,
          fontWeight: FontWeight.w100, letterSpacing: 4,
        )),
        const SizedBox(height: 8),
        Text(
          '${_now.year}-${_pad(_now.month)}-${_pad(_now.day)}  '
          '${['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][_now.weekday % 7]}',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
      ]),
    );
  }

  Widget _buildAlarms() {
    return Column(children: [
      Expanded(
        child: _alarms.isEmpty
            ? Center(child: Text('No alarms set',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _alarms.length,
                itemBuilder: (_, i) {
                  final a = _alarms[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a['time'] as String, style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w300)),
                        Text(a['label'] as String, style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                      ]),
                      const Spacer(),
                      Switch(
                        value: a['enabled'] as bool,
                        activeColor: AppTheme.accent,
                        onChanged: (v) {
                          setState(() => _alarms[i]['enabled'] = v);
                          _saveAlarms();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppTheme.textSecondary,
                        onPressed: () {
                          setState(() => _alarms.removeAt(i));
                          _saveAlarms();
                        },
                      ),
                    ]),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _addAlarm,
          icon: const Icon(Icons.add),
          label: const Text('Add Alarm'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ]);
  }

  Future<void> _addAlarm() async {
    TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.dark(primary: AppTheme.accent)),
        child: child!,
      ),
    );
    if (t == null) return;
    final label = await _inputDialog('Alarm label', 'Alarm');
    setState(() {
      _alarms.add({
        'time': '${_pad(t.hour)}:${_pad(t.minute)}',
        'label': label,
        'enabled': true,
      });
    });
    await _saveAlarms();
  }

  Future<String> _inputDialog(String title, String hint) async {
    final ctrl = TextEditingController(text: hint);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        title: Text(title, style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
    return ctrl.text.isEmpty ? hint : ctrl.text;
  }

  Widget _buildWorld() {
    final offset = _now.timeZoneOffset.inHours;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _worldClocks.length,
      itemBuilder: (_, i) {
        final c = _worldClocks[i];
        final diff = int.tryParse(c['offset']!) ?? 0;
        final localTime = _now.toUtc().add(Duration(hours: diff));
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['city']!, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
              Text('UTC${c['offset']!}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ]),
            const Spacer(),
            Text(_clockStr(localTime), style: TextStyle(
              color: AppTheme.accent, fontSize: 24, fontWeight: FontWeight.w300,
            )),
          ]),
        );
      },
    );
  }

  Widget _buildStopwatch() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_durationStr(_swDisplay), style: TextStyle(
        color: AppTheme.textPrimary, fontSize: 60, fontWeight: FontWeight.w100,
      )),
      const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _circleBtn(
          icon: _sw.isRunning ? Icons.pause : Icons.play_arrow,
          color: AppTheme.accent,
          onTap: () => setState(() {
            if (_sw.isRunning) { _sw.stop(); } else { _sw.start(); }
          }),
        ),
        const SizedBox(width: 24),
        _circleBtn(
          icon: Icons.flag,
          color: AppTheme.surfaceAlt,
          onTap: () { if (_sw.isRunning) setState(() => _swLaps.add(_swDisplay)); },
        ),
        const SizedBox(width: 24),
        _circleBtn(
          icon: Icons.stop,
          color: AppTheme.surfaceAlt,
          onTap: () => setState(() { _sw.stop(); _sw.reset(); _swDisplay = Duration.zero; _swLaps.clear(); }),
        ),
      ]),
      const SizedBox(height: 20),
      Expanded(
        child: ListView.builder(
          itemCount: _swLaps.length,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text('Lap ${_swLaps.length - i}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const Spacer(),
              Text(_durationStr(_swLaps[_swLaps.length - 1 - i]),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildTimer() {
    final remaining = _timerRunning ? Duration(seconds: _timerSeconds) : Duration.zero;
    final progress = _timerTotal > 0 ? _timerSeconds / _timerTotal : 0.0;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 180, height: 180,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: _timerRunning ? progress.clamp(0.0, 1.0) : 0.0,
            strokeWidth: 8,
            backgroundColor: AppTheme.surfaceAlt,
            valueColor: AlwaysStoppedAnimation(AppTheme.accent),
          ),
          Text(
            _timerRunning ? _durationStr(Duration(seconds: _timerSeconds)) : _timerCtrl.text,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.w300),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      if (!_timerRunning)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: TextField(
            controller: _timerCtrl,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 20),
            decoration: InputDecoration(
              labelText: 'Duration (HH:MM:SS)',
              labelStyle: TextStyle(color: AppTheme.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
            ),
          ),
        ),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _circleBtn(
          icon: _timerRunning ? Icons.pause : Icons.play_arrow,
          color: AppTheme.accent,
          onTap: _toggleTimer,
        ),
        const SizedBox(width: 24),
        _circleBtn(
          icon: Icons.stop,
          color: AppTheme.surfaceAlt,
          onTap: _resetTimer,
        ),
      ]),
    ]);
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timerTicker?.cancel();
      setState(() => _timerRunning = false);
    } else {
      final parts = _timerCtrl.text.split(':');
      int s = 0;
      if (parts.length == 3) {
        s = (int.tryParse(parts[0]) ?? 0) * 3600 +
            (int.tryParse(parts[1]) ?? 0) * 60 +
            (int.tryParse(parts[2]) ?? 0);
      }
      if (s <= 0) return;
      setState(() { _timerSeconds = s; _timerTotal = s; _timerRunning = true; });
      _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          if (_timerSeconds > 0) {
            _timerSeconds--;
          } else {
            _timerTicker?.cancel();
            _timerRunning = false;
          }
        });
      });
    }
  }

  void _resetTimer() {
    _timerTicker?.cancel();
    setState(() { _timerRunning = false; _timerSeconds = 0; _timerTotal = 0; });
  }

  Widget _circleBtn({required IconData icon, required Color color, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, color: AppTheme.textPrimary, size: 28),
        ),
      );
}

class _AnalogClockPainter extends CustomPainter {
  final DateTime now;
  _AnalogClockPainter(this.now);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) - 4;

    final paintFace = Paint()..color = AppTheme.surface;
    final paintBorder = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(cx, cy), r, paintFace);
    canvas.drawCircle(Offset(cx, cy), r, paintBorder);

  // Hour marks
    for (int i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 - math.pi / 2;
      final len = i % 3 == 0 ? 12.0 : 6.0;
      final p1 = Offset(cx + (r - len) * math.cos(angle), cy + (r - len) * math.sin(angle));
      final p2 = Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
      canvas.drawLine(p1, p2, Paint()
        ..color = AppTheme.textSecondary
        ..strokeWidth = i % 3 == 0 ? 2 : 1);
    }

    void drawHand(double angle, double length, Color color, double width) {
      final p = Offset(cx + length * math.cos(angle - math.pi / 2),
                       cy + length * math.sin(angle - math.pi / 2));
      canvas.drawLine(Offset(cx, cy), p, Paint()
        ..color = color ..strokeWidth = width ..strokeCap = StrokeCap.round);
    }

    final sec  = now.second + now.millisecond / 1000;
    final min  = now.minute + sec / 60;
    final hour = (now.hour % 12) + min / 60;

    drawHand(hour * math.pi / 6,  r * 0.50, AppTheme.textPrimary, 4);
    drawHand(min  * math.pi / 30, r * 0.75, AppTheme.textPrimary, 2.5);
    drawHand(sec  * math.pi / 30, r * 0.85, AppTheme.danger,      1.5);

    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = AppTheme.accent);
  }

  @override
  bool shouldRepaint(_AnalogClockPainter old) => old.now.second != now.second;
}