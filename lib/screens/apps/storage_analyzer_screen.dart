import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

class StorageAnalyzerScreen extends StatefulWidget {
  const StorageAnalyzerScreen({super.key});
  @override
  State<StorageAnalyzerScreen> createState() => _StorageAnalyzerScreenState();
}

class _StorageAnalyzerScreenState extends State<StorageAnalyzerScreen> {
  String _path = '/';
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _disks  = [];
  bool _loading = false;
  String? _cleaning;

  // Category colours
  static const _catColors = {
    '/home': Color(0xFF4285F4),
    '/usr':  Color(0xFF34A853),
    '/var':  Color(0xFFFFAA00),
    '/tmp':  Color(0xFFEA4335),
    '/opt':  Color(0xFF9C27B0),
  };

  @override
  void initState() {
    super.initState();
    _scan('/');
    _loadDisks();
  }

  Future<void> _scan(String path) async {
    setState(() { _loading = true; _items = []; _path = path; });
    final r = await SystemBridge.storageAnalyze(path);
  // Sort by size desc
    r.sort((a, b) => ((b['bytes'] as num) - (a['bytes'] as num)).toInt());
    if (mounted) setState(() { _items = r; _loading = false; });
  }

  Future<void> _loadDisks() async {
    final d = await SystemBridge.diskUsage();
    if (mounted) setState(() => _disks = d);
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024*1024) return '${(bytes/1024).toStringAsFixed(0)} KB';
    if (bytes < 1024*1024*1024) return '${(bytes/1024/1024).toStringAsFixed(1)} MB';
    return '${(bytes/1024/1024/1024).toStringAsFixed(2)} GB';
  }

  String _fmtDisk(int bytes) {
    const gb = 1024*1024*1024;
    return '${(bytes/gb).toStringAsFixed(1)} GB';
  }

  int get _totalScanned => _items.fold(0, (s, i) => s + ((i['bytes'] as num).toInt()));

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(children: [
        _buildDiskBars(),
        _buildPathBar(),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(child: ListView(children: [
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text('No data found', style: TextStyle(color: AppTheme.textSecondary)),
              )
            else ...[
              _buildPieRow(),
              const SizedBox(height: 8),
              ..._items.map((item) => _buildRow(item)),
            ],
          ])),
      ]),
    );
  }

  Widget _buildDiskBars() {
    if (_disks.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _disks.map((d) {
          final total = (d['total'] as num?)?.toInt() ?? 1;
          final used  = (d['used']  as num?)?.toInt() ?? 0;
          final pct   = used / total;
          final mp    = d['mountpoint'] as String? ?? '/';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.storage, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(mp, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${_fmtDisk(used)} used of ${_fmtDisk(total)}',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct.clamp(0, 1),
                  backgroundColor: AppTheme.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(
                    pct > 0.9 ? AppTheme.danger : pct > 0.7 ? AppTheme.warning : AppTheme.accent),
                  minHeight: 8,
                ),
              ),
              if (pct > 0.9) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.warning_rounded, size: 12, color: AppTheme.danger),
                  const SizedBox(width: 4),
                  Text('Disk space critical ? only ${_fmtDisk(total - used)} free',
                      style: TextStyle(color: AppTheme.danger, fontSize: 11)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _cleanPath('/tmp'),
                    child: Text('Clean Temp', style: TextStyle(color: AppTheme.accent, fontSize: 11)),
                  ),
                ]),
              ],
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPathBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppTheme.surfaceAlt,
      child: Row(children: [
        if (_path != '/')
          GestureDetector(
            onTap: () => _scan('/'),
            child: Icon(Icons.arrow_back_ios, color: AppTheme.accent, size: 16),
          ),
        const SizedBox(width: 6),
        Text(_path, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        GestureDetector(
          onTap: () => _scan(_path),
          child: Icon(Icons.refresh, color: AppTheme.accent, size: 18),
        ),
      ]),
    );
  }

  Widget _buildPieRow() {
    if (_items.isEmpty) return const SizedBox.shrink();
    final total = _totalScanned;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 100, height: 100,
          child: CustomPaint(painter: _PiePainter(_items, total)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _items.take(5).map((i) {
              final name  = (i['path'] as String? ?? '').split('/').last;
              final bytes = (i['bytes'] as num?)?.toInt() ?? 0;
              return Row(children: [
                Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _colorForPath(i['path'] as String? ?? ''),
                    borderRadius: BorderRadius.circular(2),
                  )),
                Expanded(child: Text(name, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(_fmt(bytes), style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
              ]);
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildRow(Map<String, dynamic> item) {
    final path  = item['path']  as String? ?? '';
    final bytes = (item['bytes'] as num?)?.toInt() ?? 0;
    final name  = path.split('/').last;
    final total = _totalScanned;
    final pct   = total > 0 ? (bytes / total) : 0.0;
    final color = _colorForPath(path);
    final isTemp = path == '/tmp' || path.contains('cache') || path.contains('thumbnails');
    final isCleaning = _cleaning == path;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: GestureDetector(
        onTap: () => _scan(path),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Row(children: [
              Icon(Icons.folder_rounded, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(name.isEmpty ? path : name,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(_fmt(bytes), style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 10),
              Text('${(pct*100).toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              if (isTemp) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: isCleaning ? null : () => _cleanPath(path),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: isCleaning
                        ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.danger))
                        : Text('Clean', style: TextStyle(color: AppTheme.danger, fontSize: 11)),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct.clamp(0, 1),
                backgroundColor: AppTheme.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.7)),
                minHeight: 4,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _cleanPath(String path) async {
    setState(() => _cleaning = path);
    await SystemBridge.diskClean(path);
    await _scan(_path);
    if (mounted) setState(() => _cleaning = null);
  }

  Color _colorForPath(String p) {
    for (final e in _catColors.entries) {
      if (p.startsWith(e.key)) return e.value;
    }
    final colors = [
      const Color(0xFF26A69A), const Color(0xFF5C6BC0),
      const Color(0xFFE91E63), const Color(0xFF8BC34A),
      const Color(0xFFFF7043), const Color(0xFF00BCD4),
    ];
    return colors[p.hashCode.abs() % colors.length];
  }
}

class _PiePainter extends CustomPainter {
  final List<Map<String, dynamic>> items;
  final int total;
  _PiePainter(this.items, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    double start = -90 * (3.14159 / 180);
    final colors = [
      const Color(0xFF4285F4), const Color(0xFF34A853), const Color(0xFFFFAA00),
      const Color(0xFFEA4335), const Color(0xFF9C27B0), const Color(0xFF00BCD4),
    ];
    for (int i = 0; i < items.take(6).length; i++) {
      final bytes  = (items[i]['bytes'] as num?)?.toInt() ?? 0;
      final sweep  = 2 * 3.14159 * bytes / total;
      final paint  = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, true, paint);
      start += sweep;
    }
  // Donut hole
    canvas.drawCircle(center, r * 0.55,
        Paint()..color = AppTheme.background..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_PiePainter o) => o.total != total;
}