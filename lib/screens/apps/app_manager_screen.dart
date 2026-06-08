import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

enum _AppSource { deb, flatpak, appimage }

class _AppInfo {
  final String id;
  final String name;
  final String version;
  final int sizeKb;
  final String desc;
  final _AppSource source;

  // Permissions — mutable, set lazily after construction
  bool? networkAllowed;
  bool cameraAllowed = true;
  bool micAllowed = true;
  bool filesAllowed = true;

  _AppInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.sizeKb,
    required this.desc,
    required this.source,
  });

  String get sizeLabel {
    if (sizeKb <= 0) return '—';
    if (sizeKb < 1024) return '$sizeKb KB';
    if (sizeKb < 1024 * 1024) return '${(sizeKb / 1024).toStringAsFixed(1)} MB';
    return '${(sizeKb / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  String get sourceLabel {
    switch (source) {
      case _AppSource.deb:     return 'System (deb)';
      case _AppSource.flatpak: return 'Flatpak';
      case _AppSource.appimage:return 'AppImage';
    }
  }

  Color get sourceColor {
    switch (source) {
      case _AppSource.deb:     return const Color(0xFF4FC3F7);
      case _AppSource.flatpak: return const Color(0xFF81C784);
      case _AppSource.appimage:return const Color(0xFFFFB74D);
    }
  }

  IconData get sourceIcon {
    switch (source) {
      case _AppSource.deb:     return Icons.inventory_2_rounded;
      case _AppSource.flatpak: return Icons.widgets_rounded;
      case _AppSource.appimage:return Icons.rocket_launch_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AppManagerScreen extends StatefulWidget {
  const AppManagerScreen({super.key});

  @override
  State<AppManagerScreen> createState() => _AppManagerScreenState();
}

class _AppManagerScreenState extends State<AppManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Library state
  List<_AppInfo> _allApps = [];
  List<_AppInfo> _filtered = [];
  bool _loading = false;
  String _searchQuery = '';
  String _sourceFilter = 'ALL'; // ALL | deb | flatpak
  _AppInfo? _selectedApp;
  String _detailText = '';
  bool _detailLoading = false;
  bool _uninstalling = false;
  String _uninstallOutput = '';

  // Install state
  String? _installPath;
  String? _installType;
  bool _installing = false;
  String _installOutput = '';

  // Store state
  final _storeSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _storeResults = [];
  bool _storeSearching = false;
  String? _storeInstallingId;
  String _storeStatus = '';

  // Featured store apps
  static const _featured = [
    {'id': 'org.wireshark.Wireshark',     'name': 'Wireshark',   'desc': 'Network analyzer',         'cat': 'Security'},
    {'id': 'org.videolan.VLC',             'name': 'VLC',         'desc': 'Media player',             'cat': 'Media'},
    {'id': 'com.visualstudio.code',        'name': 'VS Code',     'desc': 'Code editor',              'cat': 'Dev'},
    {'id': 'org.libreoffice.LibreOffice',  'name': 'LibreOffice', 'desc': 'Office suite',             'cat': 'Office'},
    {'id': 'org.gimp.GIMP',               'name': 'GIMP',        'desc': 'Image editor',             'cat': 'Media'},
    {'id': 'md.obsidian.Obsidian',         'name': 'Obsidian',    'desc': 'Note-taking',              'cat': 'Productivity'},
    {'id': 'com.github.tchx84.Flatseal',   'name': 'Flatseal',   'desc': 'Flatpak permissions',      'cat': 'System'},
    {'id': 'org.flameshot.Flameshot',       'name': 'Flameshot',  'desc': 'Screenshot tool',          'cat': 'System'},
    {'id': 'com.getpostman.Postman',        'name': 'Postman',    'desc': 'API testing',              'cat': 'Dev'},
    {'id': 'net.mullvad.MullvadBrowser',   'name': 'Mullvad',    'desc': 'Privacy browser',          'cat': 'Security'},
    {'id': 'org.audacityteam.Audacity',    'name': 'Audacity',   'desc': 'Audio editor',             'cat': 'Media'},
    {'id': 'io.github.shiftey.Desktop',    'name': 'GH Desktop', 'desc': 'Git GUI',                  'cat': 'Dev'},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadLibrary();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _storeSearchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadLibrary() async {
    setState(() { _loading = true; _allApps = []; _filtered = []; });
    final debFuture = SystemBridge.appsListDpkg();
    final flatpakFuture = SystemBridge.flatpakList();
    final results = await Future.wait([debFuture, flatpakFuture]);

    final debs = results[0].map((m) => _AppInfo(
      id:      m['id']      as String? ?? '',
      name:    m['name']    as String? ?? '',
      version: m['version'] as String? ?? '',
      sizeKb:  (m['size_kb'] as num?)?.toInt() ?? 0,
      desc:    m['desc']    as String? ?? '',
      source:  _AppSource.deb,
    )).toList();

    final flatpaks = results[1].map((m) => _AppInfo(
      id:      m['id']   as String? ?? '',
      name:    m['name'] as String? ?? (m['id'] as String? ?? ''),
      version: '',
      sizeKb:  0,
      desc:    '',
      source:  _AppSource.flatpak,
    )).toList();

    final all = [...debs, ...flatpaks];
    all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (mounted) {
      setState(() {
        _allApps = all;
        _loading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    var list = _allApps.toList();
    if (_sourceFilter != 'ALL') {
      final src = _sourceFilter == 'deb' ? _AppSource.deb : _AppSource.flatpak;
      list = list.where((a) => a.source == src).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.id.toLowerCase().contains(q) ||
          a.desc.toLowerCase().contains(q)).toList();
    }
    setState(() => _filtered = list);
  }

  Future<void> _selectApp(_AppInfo app) async {
    setState(() {
      _selectedApp = app;
      _detailLoading = true;
      _detailText = '';
      _uninstallOutput = '';
    });
    String raw;
    if (app.source == _AppSource.deb) {
      raw = await SystemBridge.appsGetInfoDeb(app.id);
    } else {
      raw = await SystemBridge.appsGetPermissionsFlatpak(app.id);
    }
    if (!mounted) return;
    setState(() { _detailText = raw; _detailLoading = false; });
  }

  Future<void> _uninstall(_AppInfo app) async {
    setState(() { _uninstalling = true; _uninstallOutput = ''; });
    String out;
    if (app.source == _AppSource.deb) {
      out = await SystemBridge.appsUninstallDeb(app.id);
    } else {
      out = await SystemBridge.appsUninstallFlatpak(app.id);
    }
    if (!mounted) return;
    setState(() {
      _uninstalling = false;
      _uninstallOutput = out;
    });
    // Reload library after a short delay
    Future.delayed(const Duration(milliseconds: 800), _loadLibrary);
  }

  Future<void> _toggleNetwork(_AppInfo app, bool allowed) async {
    if (app.source != _AppSource.flatpak) return;
    await SystemBridge.appsSetNetworkFlatpak(app.id, allowed: allowed);
    setState(() => app.networkAllowed = allowed);
  }

  // ── Install ───────────────────────────────────────────────────────────────

  Future<void> _pickInstallFile() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    if (r != null && r.files.single.path != null) {
      final p = r.files.single.path!;
      setState(() {
        _installPath = p;
        _installType = _detectInstallType(p);
        _installOutput = '';
      });
    }
  }

  String _detectInstallType(String path) {
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'deb': '.deb → dpkg',
      'exe': '.exe → Wine',
      'msi': '.msi → Wine',
      'appimage': '.AppImage → chmod +x & run',
      'flatpak': '.flatpak → Flatpak',
      'snap': '.snap → Snap',
    };
    return map[ext] ?? 'Unknown format';
  }

  Future<void> _runInstall() async {
    if (_installPath == null) return;
    setState(() { _installing = true; _installOutput = 'Installing…'; });
    final out = await SystemBridge.appInstall(_installPath!);
    if (mounted) {
      setState(() { _installing = false; _installOutput = out; });
      _loadLibrary();
    }
  }

  // ── Store ─────────────────────────────────────────────────────────────────

  Future<void> _searchStore(String q) async {
    if (q.isEmpty) return;
    setState(() { _storeSearching = true; _storeResults = []; });
    final r = await SystemBridge.flatpakSearch(q);
    if (mounted) setState(() { _storeResults = r; _storeSearching = false; });
  }

  Future<void> _storeInstall(String appId, String name) async {
    setState(() { _storeInstallingId = appId; _storeStatus = 'Installing $name…'; });
    final out = await SystemBridge.flatpakInstall(appId);
    if (mounted) {
      setState(() {
        _storeInstallingId = null;
        _storeStatus = out.toLowerCase().contains('error') || out.toLowerCase().contains('failed')
            ? 'Failed: check logs'
            : '$name installed successfully';
      });
      _loadLibrary();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(children: [
        _buildHeader(),
        Expanded(child: TabBarView(
          controller: _tabs,
          children: [
            _buildLibrary(),
            _buildInstall(),
            _buildStore(),
          ],
        )),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Icon(Icons.apps_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 10),
            Text('App Manager',
                style: TextStyle(color: AppTheme.textPrimary,
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_tabs.index == 0)
              _hBtn(Icons.refresh_rounded, 'Refresh', _loadLibrary),
          ]),
        ),
        TabBar(
          controller: _tabs,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'Library'),
            Tab(text: 'Install'),
            Tab(text: 'Store'),
          ],
        ),
      ]),
    );
  }

  Widget _hBtn(IconData icon, String tip, VoidCallback fn) => Tooltip(
    message: tip,
    child: GestureDetector(
      onTap: fn,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, color: AppTheme.textSecondary, size: 16),
      ),
    ),
  );

  // ── Library tab ───────────────────────────────────────────────────────────

  Widget _buildLibrary() {
    return Row(children: [
      Expanded(child: _buildAppList()),
      if (_selectedApp != null) ...[
        Container(width: 1, color: AppTheme.border),
        SizedBox(width: 340, child: _buildDetailPanel()),
      ],
    ]);
  }

  Widget _buildAppList() {
    return Column(children: [
      _buildLibraryToolbar(),
      Expanded(child: _buildAppGrid()),
    ]);
  }

  Widget _buildLibraryToolbar() {
    return Container(
      color: AppTheme.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        // Search
        Expanded(
          child: Container(
            height: 32,
            decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              const SizedBox(width: 8),
              Icon(Icons.search, color: AppTheme.textSecondary, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  cursorColor: AppTheme.accent,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Search apps…',
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  onChanged: (v) {
                    _searchQuery = v;
                    _applyFilter();
                  },
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        // Source filter chips
        _filterChip('ALL', 'ALL'),
        const SizedBox(width: 4),
        _filterChip('deb', 'System'),
        const SizedBox(width: 4),
        _filterChip('flatpak', 'Flatpak'),
        const SizedBox(width: 10),
        Text('${_filtered.length} apps',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ]),
    );
  }

  Widget _filterChip(String value, String label) {
    final active = _sourceFilter == value;
    return GestureDetector(
      onTap: () { _sourceFilter = value; _applyFilter(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.accentDim : AppTheme.surface,
          border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildAppGrid() {
    if (_loading) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2),
        const SizedBox(height: 12),
        Text('Loading installed apps…',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ]));
    }
    if (_filtered.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.apps, color: AppTheme.border, size: 56),
        const SizedBox(height: 12),
        Text('No apps found', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildAppCard(_filtered[i], i),
    );
  }

  Widget _buildAppCard(_AppInfo app, int index) {
    final sel = _selectedApp?.id == app.id && _selectedApp?.source == app.source;
    return GestureDetector(
      onTap: () => _selectApp(app),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppTheme.accentDim : AppTheme.surface,
          border: Border.all(color: sel ? AppTheme.accent : AppTheme.border.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          // App icon placeholder
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: app.sourceColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                app.name.isNotEmpty ? app.name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: app.sourceColor,
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(app.name,
                    style: TextStyle(
                        color: sel ? AppTheme.accent : AppTheme.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              if (app.version.isNotEmpty)
                Text(' v${app.version}',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ]),
            if (app.desc.isNotEmpty)
              Text(app.desc,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Source badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: app.sourceColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: app.sourceColor.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(app.sourceIcon, color: app.sourceColor, size: 10),
                const SizedBox(width: 4),
                Text(app.source == _AppSource.deb ? 'deb' : 'flatpak',
                    style: TextStyle(color: app.sourceColor, fontSize: 9,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            if (app.sizeKb > 0) ...[
              const SizedBox(height: 2),
              Text(app.sizeLabel,
                  style: TextStyle(color: AppTheme.border, fontSize: 9)),
            ],
          ]),
        ]),
      ),
    );
  }

  // ── Detail panel ──────────────────────────────────────────────────────────

  Widget _buildDetailPanel() {
    final app = _selectedApp!;
    return Container(
      color: AppTheme.surface,
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: app.sourceColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(app.name.isNotEmpty ? app.name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: app.sourceColor,
                          fontSize: 26, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.name,
                    style: TextStyle(color: AppTheme.textPrimary,
                        fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                if (app.version.isNotEmpty)
                  Text('v${app.version}',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: app.sourceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(app.sourceLabel,
                      style: TextStyle(color: app.sourceColor, fontSize: 10)),
                ),
              ])),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedApp = null;
                  _detailText = '';
                }),
                child: Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
              ),
            ]),
            if (app.desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(app.desc,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info row
            if (app.sizeKb > 0) _detailRow('Size', app.sizeLabel),
            _detailRow('Package', app.id),
            _detailRow('Source', app.sourceLabel),
            const SizedBox(height: 16),

            // Permissions
            _sectionTitle('PERMISSIONS'),
            const SizedBox(height: 8),
            _permissionTile(
              icon: Icons.wifi_rounded,
              label: 'Network Access',
              sublabel: app.source == _AppSource.flatpak
                  ? 'Enforced via Flatpak override'
                  : 'Tracked locally',
              value: app.networkAllowed ?? true,
              onChanged: app.source == _AppSource.flatpak
                  ? (v) => _toggleNetwork(app, v)
                  : (v) => setState(() => app.networkAllowed = v),
            ),
            _permissionTile(
              icon: Icons.videocam_rounded,
              label: 'Camera',
              sublabel: 'Access to video devices',
              value: app.cameraAllowed,
              onChanged: (v) => setState(() => app.cameraAllowed = v),
            ),
            _permissionTile(
              icon: Icons.mic_rounded,
              label: 'Microphone',
              sublabel: 'Access to audio input',
              value: app.micAllowed,
              onChanged: (v) => setState(() => app.micAllowed = v),
            ),
            _permissionTile(
              icon: Icons.folder_rounded,
              label: 'File System',
              sublabel: 'Access to your files',
              value: app.filesAllowed,
              onChanged: (v) => setState(() => app.filesAllowed = v),
            ),
            const SizedBox(height: 16),

            // Raw info (collapsible)
            if (_detailLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ))
            else if (_detailText.isNotEmpty) ...[
              _sectionTitle('PACKAGE INFO'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border)),
                child: SelectableText(_detailText,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10, fontFamily: 'monospace', height: 1.5)),
              ),
              const SizedBox(height: 16),
            ],

            // Uninstall output
            if (_uninstallOutput.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _uninstallOutput.toLowerCase().contains('error')
                      ? AppTheme.danger.withValues(alpha: 0.08)
                      : AppTheme.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _uninstallOutput.toLowerCase().contains('error')
                          ? AppTheme.danger
                          : AppTheme.success),
                ),
                child: Text(_uninstallOutput,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10, fontFamily: 'monospace')),
              ),
              const SizedBox(height: 16),
            ],
          ]),
        )),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border))),
          child: Column(children: [
            // Uninstall
            _uninstalling
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.danger)),
                    const SizedBox(width: 8),
                    Text('Uninstalling…',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ])
                : _confirmUninstallBtn(app),
          ]),
        ),
      ]),
    );
  }

  Widget _confirmUninstallBtn(_AppInfo app) {
    return GestureDetector(
      onTap: () => _showUninstallConfirm(app),
      child: Container(
        width: double.infinity, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.08),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 16),
          const SizedBox(width: 6),
          Text('Uninstall',
              style: TextStyle(color: AppTheme.danger,
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _showUninstallConfirm(_AppInfo app) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surfaceAlt,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5))),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.danger, size: 48),
            const SizedBox(height: 12),
            Text('Uninstall "${app.name}"?',
                style: TextStyle(color: AppTheme.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('This will permanently remove the package and its data.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _dialogBtn('Cancel', AppTheme.border, AppTheme.textSecondary,
                  () => Navigator.pop(context)),
              const SizedBox(width: 10),
              _dialogBtn('Uninstall', AppTheme.danger, AppTheme.danger, () {
                Navigator.pop(context);
                _uninstall(app);
              }),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 70,
          child: Text('$label:', style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 11))),
      Expanded(child: Text(value,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _sectionTitle(String t) => Text(t,
      style: TextStyle(color: AppTheme.textSecondary,
          fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.bold));

  Widget _permissionTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.4))),
      child: Row(children: [
        Icon(icon,
            color: value ? AppTheme.accent : AppTheme.border, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
          Text(sublabel,
              style: TextStyle(color: AppTheme.border, fontSize: 9)),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppTheme.accentDim,
          activeThumbColor: AppTheme.accent,
          inactiveThumbColor: AppTheme.border,
          inactiveTrackColor: AppTheme.surfaceAlt,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  // ── Install tab ───────────────────────────────────────────────────────────

  Widget _buildInstall() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Install a Package',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 20, fontWeight: FontWeight.w300)),
        const SizedBox(height: 4),
        Text('Supports .deb  .AppImage  .flatpak  .snap  .exe (Wine)',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 24),

        // Drop zone
        GestureDetector(
          onTap: _pickInstallFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity, height: 130,
            decoration: BoxDecoration(
              color: _installPath != null
                  ? AppTheme.accent.withValues(alpha: 0.05)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _installPath != null ? AppTheme.accent : AppTheme.border,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                _installPath != null
                    ? Icons.check_circle_outline_rounded
                    : Icons.cloud_upload_outlined,
                color: _installPath != null ? AppTheme.accent : AppTheme.textSecondary,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                _installPath != null
                    ? _installPath!.split('/').last
                    : 'Click to choose a file',
                style: TextStyle(
                    color: _installPath != null
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              if (_installType != null) ...[
                const SizedBox(height: 4),
                Text(_installType!,
                    style: TextStyle(color: AppTheme.accent, fontSize: 11)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 20),

        if (_installPath != null) ...[
          GestureDetector(
            onTap: _installing ? null : _runInstall,
            child: Container(
              height: 48, width: double.infinity,
              decoration: BoxDecoration(
                color: _installing ? AppTheme.surfaceAlt : AppTheme.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: _installing
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      const Text('Installing…',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                    ])
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.download_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text('Install',
                          style: TextStyle(color: Colors.white,
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
            ),
          ),
        ],

        if (_installOutput.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: SelectableText(_installOutput,
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11, fontFamily: 'monospace', height: 1.5)),
          ),
        ],

        const SizedBox(height: 32),
        // Format guide
        _sectionTitle('SUPPORTED FORMATS'),
        const SizedBox(height: 10),
        for (final f in _formatGuide) _formatRow(f),
      ]),
    );
  }

  static const _formatGuide = [
    {'ext': '.deb',      'tool': 'dpkg / apt',     'desc': 'Debian package — native system install'},
    {'ext': '.AppImage', 'tool': 'Direct run',      'desc': 'Portable app, no installation needed'},
    {'ext': '.flatpak',  'tool': 'Flatpak',         'desc': 'Sandboxed Flatpak bundle'},
    {'ext': '.snap',     'tool': 'Snap',             'desc': 'Snap package (requires snapd)'},
    {'ext': '.exe / .msi','tool': 'Wine',            'desc': 'Windows app via Wine compatibility layer'},
  ];

  Widget _formatRow(Map<String, String> f) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
    ),
    child: Row(children: [
      SizedBox(width: 80,
          child: Text(f['ext']!,
              style: TextStyle(color: AppTheme.accent,
                  fontSize: 12, fontFamily: 'monospace',
                  fontWeight: FontWeight.bold))),
      const SizedBox(width: 8),
      Container(width: 1, height: 16, color: AppTheme.border),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f['desc']!,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
        Text('via ${f['tool']!}',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      ])),
    ]),
  );

  // ── Store tab ─────────────────────────────────────────────────────────────

  Widget _buildStore() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _storeSearchCtrl,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          cursorColor: AppTheme.accent,
          decoration: InputDecoration(
            hintText: 'Search Flathub…',
            hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
            suffixIcon: _storeSearching
                ? Padding(padding: const EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.accent)))
                : null,
            filled: true, fillColor: AppTheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.accent, width: 1.5)),
          ),
          onSubmitted: _searchStore,
          textInputAction: TextInputAction.search,
        ),
      ),
      if (_storeStatus.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _storeStatus.startsWith('Failed')
                ? AppTheme.danger.withValues(alpha: 0.1)
                : AppTheme.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _storeStatus.startsWith('Failed')
                    ? AppTheme.danger.withValues(alpha: 0.4)
                    : AppTheme.success.withValues(alpha: 0.4)),
          ),
          child: Text(_storeStatus, style: TextStyle(
              color: _storeStatus.startsWith('Failed')
                  ? AppTheme.danger : AppTheme.success,
              fontSize: 12)),
        ),
      Expanded(
        child: _storeResults.isNotEmpty
            ? ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _storeResults.length,
                itemBuilder: (_, i) => _storeRow(_storeResults[i]),
              )
            : _buildFeaturedStore(),
      ),
    ]);
  }

  Widget _buildFeaturedStore() {
    final cats = _featured.map((f) => f['cat']!).toSet().toList();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: cats.map((cat) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(cat.toUpperCase(),
                style: TextStyle(color: AppTheme.accent,
                    fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
          ),
          ..._featured.where((f) => f['cat'] == cat)
              .map((f) => _storeFeaturedRow(f)),
        ],
      )).toList(),
    );
  }

  Widget _storeRow(Map<String, dynamic> app) {
    final id   = app['id']   as String? ?? '';
    final name = app['name'] as String? ?? id;
    final desc = app['desc'] as String? ?? '';
    final busy = _storeInstallingId == id;
    return _storeCard(id: id, name: name, desc: desc, busy: busy);
  }

  Widget _storeFeaturedRow(Map<String, String> app) {
    final id   = app['id']!;
    final name = app['name']!;
    final desc = app['desc']!;
    final busy = _storeInstallingId == id;
    return _storeCard(id: id, name: name, desc: desc, busy: busy);
  }

  Widget _storeCard({
    required String id,
    required String name,
    required String desc,
    required bool busy,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: const Color(0xFF81C784).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: TextStyle(color: AppTheme.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w500)),
          if (desc.isNotEmpty)
            Text(desc,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(id,
              style: TextStyle(color: AppTheme.border, fontSize: 9),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: busy ? null : () => _storeInstall(id, name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: busy ? AppTheme.surfaceAlt : AppTheme.accentDim,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.accent.withValues(alpha: busy ? 0.2 : 0.5)),
            ),
            child: busy
                ? SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppTheme.accent))
                : Text('Get',
                    style: TextStyle(color: AppTheme.accent,
                        fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _dialogBtn(String label, Color border, Color text, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: border == AppTheme.danger
              ? AppTheme.danger.withValues(alpha: 0.08)
              : AppTheme.surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(color: text,
                fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
