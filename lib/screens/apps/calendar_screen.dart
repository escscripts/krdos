import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _Event {
  String title, color, time;
  _Event({required this.title, required this.color, required this.time});
  Map<String, String> toMap() => {'title': title, 'color': color, 'time': time};
  factory _Event.fromMap(Map<String, String> m) => _Event(
    title: m['title'] ?? '', color: m['color'] ?? 'accent', time: m['time'] ?? '');
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  final Map<String, List<_Event>> _events = {};
  int _viewMode = 0; // 0=month 1=week

  @override
  void initState() {
    super.initState();
    _selected = DateTime.now();
    _loadEvents();
  }

  String _key(DateTime d) => '${d.year}-${_p2(d.month)}-${_p2(d.day)}';
  String _p2(int v) => v.toString().padLeft(2, '0');

  Future<File> _eventsFile() async {
    if (!kIsWeb && Platform.isLinux) {
      final dir = Directory('/home/admin/.config/KrdOS');
      if (!await dir.exists()) await dir.create(recursive: true);
      return File('${dir.path}/calendar.json');
    }
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/calendar.json');
  }

  Future<void> _loadEvents() async {
    try {
      final f = await _eventsFile();
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      setState(() {
        _events.clear();
        for (final entry in raw.entries) {
          final list = (entry.value as List).map((e) => _Event(
            title: e['title'] as String? ?? '',
            color: e['color'] as String? ?? 'accent',
            time:  e['time']  as String? ?? '',
          )).toList();
          _events[entry.key] = list;
        }
      });
    } catch (_) {}
  }

  Future<void> _saveEvents(String day) async {
    try {
      final f = await _eventsFile();
  // Serialize entire event map to JSON
      final map = <String, dynamic>{};
      for (final entry in _events.entries) {
        if (entry.value.isNotEmpty) {
          map[entry.key] = entry.value.map((e) => e.toMap()).toList();
        }
      }
      await f.writeAsString(jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _addEvent() async {
    final day = _selected ?? DateTime.now();
    final key = _key(day);
    final title = await _inputDialog('New Event', 'Event title');
    if (title.isEmpty) return;
    final time = await _timeDialog();
    setState(() {
      _events.putIfAbsent(key, () => []);
      _events[key]!.add(_Event(title: title, color: 'accent', time: time));
    });
    await _saveEvents(key);
  }

  Future<String> _inputDialog(String title, String hint) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        title: Text(title, style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Add', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    return ctrl.text.trim();
  }

  Future<String> _timeDialog() async {
    TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.dark(primary: AppTheme.accent)),
        child: child!,
      ),
    );
    if (t == null) return '';
    return '${_p2(t.hour)}:${_p2(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(children: [
        _buildHeader(),
        _buildDayLabels(),
        if (_viewMode == 0) Expanded(child: _buildMonth()),
        if (_viewMode == 0) _buildEventList(),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppTheme.surface,
      child: Row(children: [
        GestureDetector(
          onTap: () => setState(() => _focused = DateTime(_focused.year, _focused.month - 1)),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.chevron_left, color: AppTheme.accent, size: 20),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${_monthName(_focused.month)} ${_focused.year}',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _focused = DateTime(_focused.year, _focused.month + 1)),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.chevron_right, color: AppTheme.accent, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _addEvent,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildDayLabels() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: days.map((d) => Expanded(
          child: Center(
            child: Text(d, style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildMonth() {
    final firstDay = DateTime(_focused.year, _focused.month, 1);
    final startOffset = firstDay.weekday % 7; // 0=Sun
    final daysInMonth = DateTime(_focused.year, _focused.month + 1, 0).day;
    final rows = ((daysInMonth + startOffset) / 7).ceil();
    final today = DateTime.now();

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.9,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: rows * 7,
      itemBuilder: (_, i) {
        final dayNum = i - startOffset + 1;
        if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox();
        final date = DateTime(_focused.year, _focused.month, dayNum);
        final key = _key(date);
        final hasEvents = (_events[key]?.isNotEmpty ?? false);
        final isToday = date.day == today.day &&
            date.month == today.month && date.year == today.year;
        final isSelected = _selected != null &&
            date.day == _selected!.day &&
            date.month == _selected!.month &&
            date.year == _selected!.year;

        return GestureDetector(
          onTap: () => setState(() => _selected = date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accentDim : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.accent.withValues(alpha: 0.6)
                    : isToday ? AppTheme.accent.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 28, height: 28,
                decoration: isToday ? BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ) : null,
                alignment: Alignment.center,
                child: Text('$dayNum', style: TextStyle(
                  color: isToday ? Colors.white
                      : isSelected ? AppTheme.accent
                      : AppTheme.textPrimary,
                  fontSize: 13, fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                )),
              ),
              if (hasEvents)
                Container(
                  width: 5, height: 5,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildEventList() {
    final key = _selected != null ? _key(_selected!) : '';
    final events = _events[key] ?? [];
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            Text(
              _selected != null
                  ? '${_monthName(_selected!.month)} ${_selected!.day}'
                  : 'Select a day',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (_selected != null)
              GestureDetector(
                onTap: _addEvent,
                child: Text('+ Add', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
              ),
          ]),
        ),
        Expanded(
          child: events.isEmpty
              ? Center(child: Text('No events', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: events.length,
                  itemBuilder: (_, i) {
                    final e = events[i];
                    return Dismissible(
                      key: Key('$key-$i'),
                      onDismissed: (_) {
                        setState(() => events.removeAt(i));
                        _saveEvents(key);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: AppTheme.accent, width: 3)),
                        ),
                        child: Row(children: [
                          if (e.time.isNotEmpty) ...[
                            Text(e.time, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            const SizedBox(width: 10),
                          ],
                          Expanded(child: Text(e.title,
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14))),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  String _monthName(int m) {
    const names = ['', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return names[m.clamp(1, 12)];
  }
}