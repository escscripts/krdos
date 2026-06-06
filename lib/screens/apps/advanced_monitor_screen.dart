import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

// - Data models -

class _SystemSnapshot {
  final List<double> corePct;
  final double cpuPct, cpuTemp, loadAvg;
  final int freqMhz;
  final String cpuModel, cpuGovernor;
  final int memTotal, memUsed, memFree, memCached;
  final int diskReadBps, diskWriteBps;
  final int rxBps, txBps, rxTotal, txTotal;
  final double gpuPct, gpuTemp;
  final int vramUsed, vramTotal;
  final String gpuName;
  final List<Map<String, dynamic>> processes;
  final double uptime;

  const _SystemSnapshot({
    this.corePct = const [], this.cpuPct = 0, this.cpuTemp = 0,
    this.loadAvg = 0, this.freqMhz = 0, this.cpuModel = '',
    this.cpuGovernor = 'unknown',
    this.memTotal = 0, this.memUsed = 0, this.memFree = 0, this.memCached = 0,
    this.diskReadBps = 0, this.diskWriteBps = 0,
    this.rxBps = 0, this.txBps = 0, this.rxTotal = 0, this.txTotal = 0,
    this.gpuPct = 0, this.gpuTemp = 0, this.vramUsed = 0, this.vramTotal = 0,
    this.gpuName = '', this.processes = const [], this.uptime = 0,
  });
}

// - Main screen -

class AdvancedMonitorScreen extends StatefulWidget {
  const AdvancedMonitorScreen({super.key});
  @override
  State<AdvancedMonitorScreen> createState() => _AdvancedMonitorScreenState();
}

class _AdvancedMonitorScreenState extends State<AdvancedMonitorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Timer? _timer;
  bool _polling = false;
  _SystemSnapshot _snap = const _SystemSnapshot();
  String _processFilter = '';
  String _sortCol = 'cpu';
  bool _sortAsc = false;
  int _prevRx = 0, _prevTx = 0;

  // Rolling chart history (60 points = 60s)
  final _cpuHistory  = <double>[];
  final _memHistory  = <double>[];
  final _netHistory  = <double>[];
  final _diskHistory = <double>[];

  // Demo data for Windows dev machine
  final _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      if (!kIsWeb) {
        final sys    = await SystemBridge.systemStats();
        final cpu    = await SystemBridge.cpuDetail();
        final disk   = await SystemBridge.diskIoStats();
        final net    = await SystemBridge.networkStats();
        final gpu    = await SystemBridge.gpuStats();
        final procs  = await SystemBridge.processListFull();

        final memT   = (sys['mem_total_kb']  as num?)?.toInt() ?? 1;
        final memU   = (sys['mem_used_kb']   as num?)?.toInt() ?? 0;
        final memF   = memT - memU;

        final rxNow  = (net['rx_bytes'] as num?)?.toInt() ?? 0;
        final txNow  = (net['tx_bytes'] as num?)?.toInt() ?? 0;

        final corePct = (cpu['cores'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ?? <double>[];
        final cpuPct  = corePct.isEmpty ? 0.0
            : corePct.reduce((a, b) => a + b) / corePct.length;

        if (!mounted) return;
        setState(() {
          _snap = _SystemSnapshot(
            corePct:    corePct,
            cpuPct:     cpuPct,
            cpuTemp:    (cpu['temperature_c'] as num?)?.toDouble() ?? 0,
            loadAvg:    (sys['load_avg_1']    as num?)?.toDouble() ?? 0,
            freqMhz:    (cpu['freq_mhz']      as num?)?.toInt()    ?? 0,
            cpuModel:   cpu['model']      as String? ?? '',
            cpuGovernor:cpu['governor']   as String? ?? '',
            memTotal:   memT,
            memUsed:    memU,
            memFree:    memF,
            memCached:  0,
            diskReadBps: (disk['read_bytes_s']  as num?)?.toInt() ?? 0,
            diskWriteBps:(disk['write_bytes_s'] as num?)?.toInt() ?? 0,
            rxBps:      (rxNow - _prevRx).abs(),
            txBps:      (txNow - _prevTx).abs(),
            rxTotal:    rxNow,
            txTotal:    txNow,
            gpuPct:     (gpu['gpu_percent']   as num?)?.toDouble() ?? 0,
            gpuTemp:    (gpu['temperature_c'] as num?)?.toDouble() ?? 0,
            vramUsed:   (gpu['vram_used']     as num?)?.toInt()    ?? 0,
            vramTotal:  (gpu['vram_total']    as num?)?.toInt()    ?? 0,
            gpuName:    gpu['name'] as String? ?? '',
            processes:  procs,
            uptime:     (sys['uptime_seconds'] as num?)?.toDouble() ?? 0,
          );
          _prevRx = rxNow; _prevTx = txNow;
          _push(_cpuHistory,  cpuPct / 100);
          _push(_memHistory,  memT > 0 ? memU / memT : 0);
          _push(_netHistory,  ((_snap.rxBps + _snap.txBps) / 1e6).clamp(0, 1));
          _push(_diskHistory, ((_snap.diskReadBps + _snap.diskWriteBps) / 1e8).clamp(0, 1));
        });
  // Thermal throttle: if CPU > 85 C switch to powersave
        if (_snap.cpuTemp > 85) {
          await SystemBridge.setCpuGovernor('powersave');
        }
      } else {
  // Demo mode
        _demoTick();
      }
    } finally { _polling = false; }
  }

  void _demoTick() {
    if (!mounted) return;
    setState(() {
      final prev = _snap;
      final cores = List.generate(4, (i) => (_rng.nextDouble() * 80 + 5));
      final cpu = cores.reduce((a,b)=>a+b)/cores.length;
      _snap = _SystemSnapshot(
        corePct: cores, cpuPct: cpu, cpuTemp: 45 + _rng.nextDouble()*20,
        loadAvg: 0.8 + _rng.nextDouble(),
        freqMhz: 3200 + (_rng.nextInt(800)),
        cpuModel: 'Intel Core i7-12700K @ 3.60GHz',
        cpuGovernor: 'performance',
        memTotal: 16384000, memUsed: 6000000 + (_rng.nextInt(2000000)),
        memFree: 8000000, memCached: 2000000,
        diskReadBps: (_rng.nextInt(50000000)), diskWriteBps: (_rng.nextInt(20000000)),
        rxBps: _rng.nextInt(1000000), txBps: _rng.nextInt(500000),
        rxTotal: prev.rxTotal + _rng.nextInt(100000),
        txTotal: prev.txTotal + _rng.nextInt(50000),
        gpuPct: _rng.nextDouble() * 60, gpuTemp: 55 + _rng.nextDouble() * 20,
        vramUsed: 2048000000, vramTotal: 8192000000, gpuName: 'NVIDIA RTX 3060',
        processes: _demoProcs(),
        uptime: prev.uptime + 1,
      );
      _push(_cpuHistory, cpu / 100);
      _push(_memHistory, 0.4 + _rng.nextDouble() * 0.2);
      _push(_netHistory, _rng.nextDouble() * 0.3);
      _push(_diskHistory, _rng.nextDouble() * 0.2);
    });
  }

  List<Map<String, dynamic>> _demoProcs() => [
    {'pid': 1234, 'name': 'krdos_ui', 'cpu': 4.2,  'rss_kb': 212000, 'user': 'admin'},
    {'pid': 567,  'name': 'systemd',      'cpu': 0.1,  'rss_kb': 8000,   'user': 'root'},
    {'pid': 789,  'name': 'NetworkMgr',   'cpu': 0.5,  'rss_kb': 24000,  'user': 'root'},
    {'pid': 1001, 'name': 'pulseaudio',   'cpu': 1.2,  'rss_kb': 16000,  'user': 'admin'},
    {'pid': 1100, 'name': 'weston',       'cpu': 3.8,  'rss_kb': 80000,  'user': 'admin'},
  ];

  void _push(List<double> l, double v) {
    l.add(v.clamp(0.0, 1.0));
    if (l.length > 60) l.removeAt(0);
  }

  // - Helpers -

  String _fmtBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024*1024) return '${(b/1024).toStringAsFixed(1)} KB';
    if (b < 1024*1024*1024) return '${(b/1024/1024).toStringAsFixed(1)} MB';
    return '${(b/1024/1024/1024).toStringAsFixed(2)} GB';
  }

  String _fmtBps(int bps) {
    if (bps < 1024) return '$bps B/s';
    if (bps < 1024*1024) return '${(bps/1024).toStringAsFixed(1)} KB/s';
    return '${(bps/1024/1024).toStringAsFixed(2)} MB/s';
  }

  String _fmtUptime(double s) {
    final d = s ~/ 86400, h = (s ~/ 3600) % 24, m = (s ~/ 60) % 60;
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Color _tempColor(double t) =>
      t > 85 ? AppTheme.danger : t > 70 ? AppTheme.warning : AppTheme.success;

  Color _cpuColor(double p) =>
      p > 90 ? AppTheme.danger : p > 70 ? AppTheme.warning : AppTheme.accent;

  // - Build -

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(children: [
        _buildHeader(),
        TabBar(
          controller: _tabs,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'CPU'),
            Tab(text: 'MEMORY'),
            Tab(text: 'DISK & NET'),
            Tab(text: 'GPU'),
            Tab(text: 'PROCESSES'),
          ],
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _buildCpuTab(),
            _buildMemTab(),
            _buildDiskNetTab(),
            _buildGpuTab(),
            _buildProcessTab(),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AppTheme.surface,
      child: Row(children: [
        Icon(Icons.monitor_heart, color: AppTheme.accent, size: 18),
        const SizedBox(width: 8),
        Text('System Monitor', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (_snap.uptime > 0)
          Text('Up: ${_fmtUptime(_snap.uptime)}',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(width: 16),
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('Live', style: TextStyle(color: AppTheme.success, fontSize: 12)),
      ]),
    );
  }

  // - CPU tab -
  Widget _buildCpuTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  // Summary row
        Row(children: [
          _metricCard('Overall', '${_snap.cpuPct.toStringAsFixed(1)}%',
              subtitle: 'Load: ${_snap.loadAvg.toStringAsFixed(2)}',
              color: _cpuColor(_snap.cpuPct)),
          const SizedBox(width: 12),
          _metricCard('Temperature',
              _snap.cpuTemp > 0 ? '${_snap.cpuTemp.toStringAsFixed(1)}°C' : 'N/A',
              color: _tempColor(_snap.cpuTemp)),
          const SizedBox(width: 12),
          _metricCard('Frequency',
              _snap.freqMhz > 0 ? '${_snap.freqMhz} MHz' : 'N/A',
              subtitle: _snap.cpuGovernor),
        ]),
        if (_snap.cpuModel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_snap.cpuModel, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
        const SizedBox(height: 16),

  // CPU history chart
        _ChartWidget(data: _cpuHistory, color: AppTheme.accent, label: 'CPU Usage History'),
        const SizedBox(height: 16),

  // Per-core bars
        _sectionLabel('Per Core'),
        const SizedBox(height: 8),
        if (_snap.corePct.isEmpty)
          Text('Core data unavailable', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, childAspectRatio: 1.4,
              crossAxisSpacing: 8, mainAxisSpacing: 8,
            ),
            itemCount: _snap.corePct.length,
            itemBuilder: (_, i) {
              final pct = _snap.corePct[i];
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: (pct / 100).clamp(0.03, 1.0),
                        widthFactor: 0.6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _cpuColor(pct),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Core $i', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                  Text('${pct.toStringAsFixed(0)}%',
                      style: TextStyle(color: _cpuColor(pct), fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              );
            },
          ),

        if (_snap.cpuTemp > 80) ...[
          const SizedBox(height: 12),
          _warningBanner(
            _snap.cpuTemp > 85
                ? '[TEMP] CPU Critical (${_snap.cpuTemp.toStringAsFixed(0)}°C) — switching to powersave'
                : '(!!) CPU Hot (${_snap.cpuTemp.toStringAsFixed(0)}°C) — consider cleaning dust',
            _snap.cpuTemp > 85 ? AppTheme.danger : AppTheme.warning,
          ),
        ],
      ]),
    );
  }

  // - Memory tab -
  Widget _buildMemTab() {
    final usedPct = _snap.memTotal > 0
        ? (_snap.memUsed / _snap.memTotal * 100).clamp(0, 100) : 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _metricCard('Used', '${usedPct.toStringAsFixed(1)}%',
              subtitle: _fmtBytes(_snap.memUsed * 1024), color: _cpuColor(usedPct.toDouble())),
          const SizedBox(width: 12),
          _metricCard('Total', _fmtBytes(_snap.memTotal * 1024)),
          const SizedBox(width: 12),
          _metricCard('Free', _fmtBytes(_snap.memFree * 1024), color: AppTheme.success),
        ]),
        const SizedBox(height: 16),

  // Memory bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('RAM Usage', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_fmtBytes(_snap.memUsed * 1024)} / ${_fmtBytes(_snap.memTotal * 1024)}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (usedPct / 100).clamp(0.0, 1.0),
                backgroundColor: AppTheme.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(_cpuColor(usedPct.toDouble())),
                minHeight: 16,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        _ChartWidget(data: _memHistory, color: const Color(0xFF7B68FF), label: 'RAM History'),
        const SizedBox(height: 16),

  // RAM cleaner
        GestureDetector(
          onTap: () async {
            await SystemBridge.dropCaches();
            _poll();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.accentDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cleaning_services, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text('Free Cached Memory', style: TextStyle(color: AppTheme.accent, fontSize: 14)),
            ]),
          ),
        ),

        if (usedPct > 90) ...[
          const SizedBox(height: 12),
          _warningBanner('?? RAM Critical (${usedPct.toStringAsFixed(0)}%) ? consider closing apps', AppTheme.danger),
        ],
      ]),
    );
  }

  // - Disk & Network tab -
  Widget _buildDiskNetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Disk I/O'),
        const SizedBox(height: 8),
        Row(children: [
          _metricCard('Read', _fmtBps(_snap.diskReadBps), color: AppTheme.success),
          const SizedBox(width: 12),
          _metricCard('Write', _fmtBps(_snap.diskWriteBps), color: AppTheme.warning),
        ]),
        const SizedBox(height: 12),
        _ChartWidget(data: _diskHistory, color: AppTheme.warning, label: 'Disk I/O History'),
        const SizedBox(height: 20),

        _sectionLabel('Network'),
        const SizedBox(height: 8),
        Row(children: [
          _metricCard('Download', _fmtBps(_snap.rxBps),
              subtitle: 'Total: ${_fmtBytes(_snap.rxTotal)}', color: AppTheme.accent),
          const SizedBox(width: 12),
          _metricCard('Upload', _fmtBps(_snap.txBps),
              subtitle: 'Total: ${_fmtBytes(_snap.txTotal)}', color: const Color(0xFFE91E63)),
        ]),
        const SizedBox(height: 12),
        _ChartWidget(data: _netHistory, color: AppTheme.accent, label: 'Network History'),
      ]),
    );
  }

  // - GPU tab -
  Widget _buildGpuTab() {
    final hasGpu = _snap.gpuName.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_snap.gpuName.isNotEmpty)
          Text(_snap.gpuName,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        Row(children: [
          _metricCard('GPU Usage', '${_snap.gpuPct.toStringAsFixed(1)}%',
              color: _cpuColor(_snap.gpuPct)),
          const SizedBox(width: 12),
          _metricCard('Temperature',
              _snap.gpuTemp > 0 ? '${_snap.gpuTemp.toStringAsFixed(1)}°C' : 'N/A',
              color: _tempColor(_snap.gpuTemp)),
        ]),
        const SizedBox(height: 12),
        if (_snap.vramTotal > 0) ...[
          Row(children: [
            _metricCard('VRAM Used', _fmtBytes(_snap.vramUsed), color: const Color(0xFF7B68FF)),
            const SizedBox(width: 12),
            _metricCard('VRAM Free',
                _fmtBytes(_snap.vramTotal - _snap.vramUsed), color: AppTheme.success),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('VRAM', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _snap.vramTotal > 0
                      ? (_snap.vramUsed / _snap.vramTotal).clamp(0, 1) : 0,
                  backgroundColor: AppTheme.surfaceAlt,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7B68FF)),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text('${_fmtBytes(_snap.vramUsed)} / ${_fmtBytes(_snap.vramTotal)}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ]),
          ),
        ],
        if (!hasGpu)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text('No GPU detected or driver not installed',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
          )),
        if (_snap.gpuTemp > 80) ...[
          const SizedBox(height: 12),
          _warningBanner('[TEMP] GPU Hot (${_snap.gpuTemp.toStringAsFixed(0)}°C)', AppTheme.warning),
        ],
      ]),
    );
  }

  // - Process tab -
  Widget _buildProcessTab() {
    var procs = List<Map<String, dynamic>>.from(_snap.processes);

  // Filter
    if (_processFilter.isNotEmpty) {
      procs = procs.where((p) {
        final name = (p['name'] as String? ?? '').toLowerCase();
        return name.contains(_processFilter.toLowerCase());
      }).toList();
    }

  // Sort
    procs.sort((a, b) {
      dynamic va = a[_sortCol], vb = b[_sortCol];
      if (va is num && vb is num) {
        return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
      }
      return _sortAsc
          ? va.toString().compareTo(vb.toString())
          : vb.toString().compareTo(va.toString());
    });

    return Column(children: [
  // Search + kill all over 90%
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _processFilter = v),
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search process?',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
                filled: true,
                fillColor: AppTheme.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ]),
      ),
  // Column headers
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: AppTheme.surface,
        child: Row(children: [
          _colHeader('PID',     'pid',  55),
          _colHeader('Name',    'name', null),
          _colHeader('CPU%',    'cpu',  60),
          _colHeader('RAM',     'rss_kb', 72),
          SizedBox(width: 40),
        ]),
      ),
  // Process rows
      Expanded(
        child: procs.isEmpty
            ? Center(child: Text('No processes', style: TextStyle(color: AppTheme.textSecondary)))
            : ListView.builder(
                itemCount: procs.length,
                itemBuilder: (_, i) => _processRow(procs[i]),
              ),
      ),
    ]);
  }

  Widget _colHeader(String label, String col, double? width) {
    final active = _sortCol == col;
    return GestureDetector(
      onTap: () => setState(() {
        if (_sortCol == col) _sortAsc = !_sortAsc;
        else { _sortCol = col; _sortAsc = false; }
      }),
      child: SizedBox(
        width: width,
        child: Row(children: [
          if (width == null) Expanded(child: Text(label, style: _headerStyle(active)))
          else Text(label, style: _headerStyle(active)),
          if (active) Icon(
            _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
            size: 11, color: AppTheme.accent,
          ),
        ]),
      ),
    );
  }

  TextStyle _headerStyle(bool active) => TextStyle(
    color: active ? AppTheme.accent : AppTheme.textSecondary,
    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5,
  );

  Widget _processRow(Map<String, dynamic> p) {
    final cpu  = (p['cpu']    as num?)?.toDouble() ?? 0;
    final rss  = (p['rss_kb'] as num?)?.toInt()    ?? 0;
    final pid  = (p['pid']    as num?)?.toInt()    ?? 0;
    final name = p['name'] as String? ?? '?';
    final Color rowColor = cpu > 80 ? AppTheme.danger
        : cpu > 50 ? AppTheme.warning : AppTheme.textPrimary;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.2))),
        color: cpu > 80 ? AppTheme.danger.withValues(alpha: 0.06)
            : cpu > 50 ? AppTheme.warning.withValues(alpha: 0.04)
            : Colors.transparent,
      ),
      child: Row(children: [
        SizedBox(width: 55, child: Text('$pid', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
        Expanded(child: Text(name, style: TextStyle(color: rowColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
        SizedBox(width: 60, child: Text('${cpu.toStringAsFixed(1)}%', style: TextStyle(color: rowColor, fontSize: 12, fontWeight: FontWeight.w600))),
        SizedBox(width: 72, child: Text(_fmtBytes(rss * 1024), style: TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
        SizedBox(
          width: 40,
          child: GestureDetector(
            onTap: () => _confirmKill(pid, name),
            child: Container(
              width: 28, height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A0A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.close, color: AppTheme.danger, size: 14),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmKill(int pid, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceAlt,
        title: Text('Kill Process?', style: TextStyle(color: AppTheme.danger)),
        content: Text('Force stop $name (PID $pid)?\nUnsaved data will be lost.',
            style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Kill', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SystemBridge.processKill(pid);
      _poll();
    }
  }

  // - Shared widgets -

  Widget _metricCard(String label, String value, {String? subtitle, Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
            color: color ?? AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w300)),
          if (subtitle != null)
            Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t, style: TextStyle(
    color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2,
  ));

  Widget _warningBanner(String msg, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(msg, style: TextStyle(color: color, fontSize: 13)),
  );
}

// - Sparkline chart -

class _ChartWidget extends StatelessWidget {
  final List<double> data;
  final Color color;
  final String label;
  const _ChartWidget({required this.data, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 8),
        Expanded(child: CustomPaint(
          size: Size.infinite,
          painter: _SparkPainter(data, color),
        )),
      ]),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final step = size.width / math.max(data.length - 1, 1);
    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height * (1 - data[i]);
      if (i == 0) { path.moveTo(x, y); fillPath.moveTo(x, size.height); fillPath.lineTo(x, y); }
      else { path.lineTo(x, y); fillPath.lineTo(x, y); }
    }
    fillPath.lineTo((data.length - 1) * step, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.data != data;
}