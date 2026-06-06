import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

class AppInstallerScreen extends StatefulWidget {
  const AppInstallerScreen({super.key});
  @override
  State<AppInstallerScreen> createState() => _AppInstallerScreenState();
}

enum _InstallPhase { idle, detecting, installing, done, error }

class _AppInstallerScreenState extends State<AppInstallerScreen> {
  int _tab = 0; // 0=install file, 1=app store

  // File installer state
  String? _selectedPath;
  String? _detectedType;
  _InstallPhase _phase = _InstallPhase.idle;
  String _output = '';
  String _appName = '';

  // App store state
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _storeResults = [];
  bool _storeSearching = false;
  String? _installingApp;
  String _installStatus = '';
  final List<Map<String, dynamic>> _installedApps = [];

  // Featured apps by category
  static const _featured = {
    'Security Tools': [
      {'id': 'org.wireshark.Wireshark', 'name': 'Wireshark', 'desc': 'Network packet analyzer', 'icon': Icons.network_check},
      {'id': 'com.burpsuite.BurpSuite', 'name': 'Burp Suite', 'desc': 'Web security testing', 'icon': Icons.security},
      {'id': 'org.nmap.Zenmap', 'name': 'Zenmap', 'desc': 'Network scanner', 'icon': Icons.radar},
    ],
    'Productivity': [
      {'id': 'org.libreoffice.LibreOffice', 'name': 'LibreOffice', 'desc': 'Office suite', 'icon': Icons.description},
      {'id': 'md.obsidian.Obsidian', 'name': 'Obsidian', 'desc': 'Note-taking app', 'icon': Icons.note_alt},
      {'id': 'org.mozilla.firefox', 'name': 'Firefox', 'desc': 'Web browser', 'icon': Icons.language},
    ],
    'Development': [
      {'id': 'com.visualstudio.code', 'name': 'VS Code', 'desc': 'Code editor', 'icon': Icons.code},
      {'id': 'io.github.shiftey.Desktop', 'name': 'GitHub Desktop', 'desc': 'Git GUI', 'icon': Icons.source},
      {'id': 'com.getpostman.Postman', 'name': 'Postman', 'desc': 'API testing', 'icon': Icons.send},
    ],
    'Media': [
      {'id': 'org.videolan.VLC', 'name': 'VLC', 'desc': 'Media player', 'icon': Icons.play_circle},
      {'id': 'org.gimp.GIMP', 'name': 'GIMP', 'desc': 'Image editor', 'icon': Icons.palette},
      {'id': 'org.audacityteam.Audacity', 'name': 'Audacity', 'desc': 'Audio editor', 'icon': Icons.music_note},
    ],
    'System Tools': [
      {'id': 'org.gnome.Nautilus', 'name': 'Files', 'desc': 'File manager', 'icon': Icons.folder},
      {'id': 'org.flameshot.Flameshot', 'name': 'Flameshot', 'desc': 'Screenshot tool', 'icon': Icons.screenshot},
      {'id': 'com.github.tchx84.Flatseal', 'name': 'Flatseal', 'desc': 'Flatpak permissions', 'icon': Icons.admin_panel_settings},
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadInstalled();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInstalled() async {
    final list = await SystemBridge.flatpakList();
    if (mounted) setState(() { _installedApps.clear(); _installedApps.addAll(list); });
  }

  String _detectType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'exe': return '.exe  ?  Wine (Windows app)';
      case 'msi': return '.msi  ?  Wine (Windows installer)';
      case 'deb': return '.deb  ?  dpkg (Debian package)';
      case 'appimage': return '.AppImage  ?  direct launch';
      case 'flatpak': return '.flatpak  ?  Flatpak install';
      case 'snap': return '.snap  ?  Snap install';
      default: return 'Unknown format';
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _selectedPath = path;
        _detectedType = _detectType(path);
        _appName = path.split('/').last.split('.').first;
        _phase = _InstallPhase.idle;
        _output = '';
      });
    }
  }

  Future<void> _install() async {
    if (_selectedPath == null) return;
    setState(() { _phase = _InstallPhase.installing; _output = 'Installing?'; });
    final result = await SystemBridge.appInstall(_selectedPath!);
    setState(() {
      _output = result;
      _phase = result.toLowerCase().contains('error') || result.toLowerCase().contains('failed')
          ? _InstallPhase.error : _InstallPhase.done;
    });
  }

  Future<void> _searchStore(String q) async {
    if (q.isEmpty) return;
    setState(() { _storeSearching = true; _storeResults = []; });
    final r = await SystemBridge.flatpakSearch(q);
    if (mounted) setState(() { _storeResults = r; _storeSearching = false; });
  }

  Future<void> _storeInstall(String appId, String name) async {
    setState(() { _installingApp = appId; _installStatus = 'Installing $name?'; });
    final result = await SystemBridge.flatpakInstall(appId);
    if (mounted) {
      setState(() {
        _installingApp = null;
        _installStatus = result.contains('error') ? 'Failed: $result' : '$name installed';
      });
      _loadInstalled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(children: [
  // Tab bar
        Container(
          color: AppTheme.surface,
          child: Row(children: [
            _tabBtn('Install File', Icons.file_open_rounded, 0),
            _tabBtn('App Store', Icons.storefront_rounded, 1),
            _tabBtn('Installed', Icons.check_circle_outline, 2),
          ]),
        ),
        Expanded(child: [_buildFileInstaller(), _buildStore(), _buildInstalled()][_tab]),
      ]),
    );
  }

  Widget _tabBtn(String label, IconData icon, int idx) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: _tab == idx ? AppTheme.accent : Colors.transparent, width: 2)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16,
              color: _tab == idx ? AppTheme.accent : AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: _tab == idx ? AppTheme.accent : AppTheme.textSecondary,
            fontSize: 13, fontWeight: FontWeight.w500,
          )),
        ]),
      ),
    ),
  );

  Widget _buildFileInstaller() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Install any app', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w300)),
        const SizedBox(height: 4),
        Text('Supports .exe .msi .deb .AppImage .flatpak .snap',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 24),

  // Drop zone / picker
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            width: double.infinity, height: 140,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedPath != null
                    ? AppTheme.accent.withValues(alpha: 0.6) : AppTheme.border,
                style: BorderStyle.solid, width: 2,
              ),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                _selectedPath != null ? Icons.check_circle_outline : Icons.file_upload_outlined,
                color: _selectedPath != null ? AppTheme.accent : AppTheme.textSecondary,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                _selectedPath != null
                    ? _selectedPath!.split('/').last
                    : 'Click to choose a file',
                style: TextStyle(
                  color: _selectedPath != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 14,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              if (_detectedType != null) ...[
                const SizedBox(height: 4),
                Text(_detectedType!, style: TextStyle(color: AppTheme.accent, fontSize: 12)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 20),

        if (_selectedPath != null) ...[
  // App name input
          TextField(
            decoration: InputDecoration(
              labelText: 'App name (for launcher)',
              labelStyle: TextStyle(color: AppTheme.textSecondary),
              filled: true, fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.border),
              ),
            ),
            style: TextStyle(color: AppTheme.textPrimary),
            onChanged: (v) => setState(() => _appName = v),
            controller: TextEditingController(text: _appName),
          ),
          const SizedBox(height: 16),

  // Install button
          GestureDetector(
            onTap: _phase == _InstallPhase.installing ? null : _install,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _phase == _InstallPhase.done ? AppTheme.success
                    : _phase == _InstallPhase.error ? AppTheme.danger
                    : AppTheme.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: _phase == _InstallPhase.installing
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(
                        _phase == _InstallPhase.done ? Icons.check : Icons.download_rounded,
                        color: Colors.white, size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _phase == _InstallPhase.done ? 'Installed!'
                            : _phase == _InstallPhase.error ? 'Retry'
                            : 'Install',
                        style: const TextStyle(color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
            ),
          ),
        ],

        if (_output.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(_output,
              style: TextStyle(
                color: _phase == _InstallPhase.error ? AppTheme.danger : AppTheme.textSecondary,
                fontFamily: 'monospace', fontSize: 12,
              ),
              maxLines: 20, overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildStore() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search Flatpak apps?',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
            suffixIcon: _storeSearching
                ? Padding(padding: const EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)))
                : null,
            filled: true, fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.border)),
          ),
          onSubmitted: _searchStore,
          textInputAction: TextInputAction.search,
        ),
      ),
      if (_installStatus.isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _installStatus.startsWith('Failed')
                ? AppTheme.danger.withValues(alpha: 0.15)
                : AppTheme.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_installStatus, style: TextStyle(
            color: _installStatus.startsWith('Failed') ? AppTheme.danger : AppTheme.success,
            fontSize: 13,
          )),
        ),
      Expanded(
        child: _storeResults.isNotEmpty
            ? ListView.builder(
                itemCount: _storeResults.length,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemBuilder: (_, i) => _storeRow(_storeResults[i]),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: _featured.entries.map((cat) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(cat.key, style: TextStyle(
                        color: AppTheme.accent, fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 1.2,
                      )),
                    ),
                    ...cat.value.map((app) => _featuredRow(app)),
                  ],
                )).toList(),
              ),
      ),
    ]);
  }

  Widget _storeRow(Map<String, dynamic> app) {
    final id   = app['id']   as String? ?? '';
    final name = app['name'] as String? ?? id;
    final desc = app['desc'] as String? ?? '';
    final installing = _installingApp == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(
          color: AppTheme.accentDim, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.apps, color: AppTheme.accent, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(desc, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(id, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ])),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: installing ? null : () => _storeInstall(id, name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: installing ? AppTheme.surfaceAlt : AppTheme.accentDim,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
            ),
            child: installing
                ? SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accent))
                : Text('Get', style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _featuredRow(Map<String, dynamic> app) {
    final id   = app['id']   as String;
    final name = app['name'] as String;
    final desc = app['desc'] as String;
    final icon = app['icon'] as IconData;
    final installing = _installingApp == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: AppTheme.accentDim, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppTheme.accent, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(desc, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ])),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: installing ? null : () => _storeInstall(id, name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentDim, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
            ),
            child: installing
                ? SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accent))
                : Text('Get', style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _buildInstalled() {
    return _installedApps.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.apps, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text('No Flatpak apps installed', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _installedApps.length,
            itemBuilder: (_, i) {
              final app = _installedApps[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  Icon(Icons.extension, color: AppTheme.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app['name'] as String? ?? app['id'] as String? ?? '',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    Text(app['id'] as String? ?? '',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ])),
                  Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                ]),
              );
            },
          );
  }
}