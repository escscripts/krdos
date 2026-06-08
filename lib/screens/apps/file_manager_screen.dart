import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';
import '../../theme/grid_painter.dart';
import '../../widgets/status_bar.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class DriveEntry {
  final String name;
  final String device;
  final String label;
  final String size;
  final String type;
  final String mountpoint;
  final bool removable;
  final String vendor;
  final String model;

  const DriveEntry({
    required this.name,
    required this.device,
    required this.label,
    required this.size,
    required this.type,
    required this.mountpoint,
    required this.removable,
    required this.vendor,
    required this.model,
  });

  bool get isMounted => mountpoint.isNotEmpty && mountpoint != '[SWAP]';

  factory DriveEntry.fromMap(Map<String, dynamic> m) => DriveEntry(
    name:       (m['name']       as String?) ?? '',
    device:     (m['device']     as String?) ?? '',
    label:      (m['label']      as String?) ?? '',
    size:       (m['size']       as String?) ?? '',
    type:       (m['type']       as String?) ?? '',
    mountpoint: (m['mountpoint'] as String?) ?? '',
    removable:  (m['removable']  as bool?)   ?? false,
    vendor:     (m['vendor']     as String?) ?? '',
    model:      (m['model']      as String?) ?? '',
  );
}

class FsEntry {
  final String name;
  final bool isDir;
  final bool isLink;
  final int size;
  final DateTime modified;
  final String owner;
  final String perms;

  const FsEntry({
    required this.name,
    required this.isDir,
    this.isLink = false,
    this.size = 0,
    required this.modified,
    this.owner = 'root',
    this.perms = '-rw-r--r--',
  });

  factory FsEntry.fromMap(Map<String, dynamic> m) {
    return FsEntry(
      name: (m['name'] as String?) ?? '',
      isDir: (m['is_dir'] as bool?) ?? false,
      isLink: (m['is_link'] as bool?) ?? false,
      size: (m['size'] as num?)?.toInt() ?? 0,
      modified: () {
        final mod = m['modified'];
        if (mod == null) return DateTime.now();
        // C++ sends modified as a Unix-epoch STRING (ls --time-style=+%s).
        // Guard against num too in case future C++ change returns int directly.
        int? epoch;
        if (mod is num) {
          epoch = mod.toInt();
        } else if (mod is String) {
          epoch = int.tryParse(mod.trim());
        }
        if (epoch != null && epoch > 0) {
          return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
        }
        return DateTime.now();
      }(),
      owner: (m['owner'] as String?) ?? 'root',
      perms: (m['perms'] as String?) ?? '----------',
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class FileManagerScreen extends StatefulWidget {
  final String initialPath;
  const FileManagerScreen({super.key, this.initialPath = '/root'});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  late String _cwd;
  FsEntry? _selected;
  bool _loading = false;
  String? _loadError;
  List<FsEntry> _entries = [];

  // Drives
  List<DriveEntry> _drives = [];
  Timer? _drivesTimer;

  // History
  final List<String> _history = [];
  int _historyIndex = -1;

  // View / sort
  String _viewMode = 'list'; // 'list', 'grid'
  String _sortBy = 'name';
  bool _sortAscending = true;

  // Search
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;
  List<FsEntry> _searchResults = [];

  // Address bar
  final _addressCtrl = TextEditingController();
  bool _addressEditing = false;

  // Preview content
  String? _previewText;
  bool _loadingPreview = false;

  // Keyboard focus
  final FocusNode _kbFocus = FocusNode();

  // Rename
  String? _renamingName;
  final _renameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cwd = widget.initialPath;
    _addressCtrl.text = _cwd;
    _addToHistory(_cwd);
    _loadDir(_cwd);
    _loadDrives();
    _drivesTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadDrives());
    WidgetsBinding.instance.addPostFrameCallback((_) => _kbFocus.requestFocus());
  }

  @override
  void dispose() {
    _drivesTimer?.cancel();
    _searchCtrl.dispose();
    _addressCtrl.dispose();
    _renameCtrl.dispose();
    _kbFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _addToHistory(String p) {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(p);
    _historyIndex = _history.length - 1;
  }

  void _navigateTo(String path) {
    setState(() {
      _cwd = path;
      _addressCtrl.text = path;
      _addToHistory(path);
      _selected = null;
      _previewText = null;
      _renamingName = null;
    });
    _loadDir(path);
  }

  void _navigateBack() {
    if (_historyIndex > 0) {
      _historyIndex--;
      final p = _history[_historyIndex];
      setState(() { _cwd = p; _addressCtrl.text = p; _selected = null; _previewText = null; });
      _loadDir(p);
    }
  }

  void _navigateForward() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      final p = _history[_historyIndex];
      setState(() { _cwd = p; _addressCtrl.text = p; _selected = null; _previewText = null; });
      _loadDir(p);
    }
  }

  void _navigateUp() {
    if (_cwd == '/') return;
    final parts = _cwd.split('/')..removeLast();
    _navigateTo(parts.join('/').isEmpty ? '/' : parts.join('/'));
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadDir(String path) async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final raw = await SystemBridge.fsList(path);
      final entries = raw.map(FsEntry.fromMap).toList();
      _sortEntries(entries);
      setState(() { _entries = entries; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _loadError = e.toString(); });
    }
  }

  Future<void> _loadDrives() async {
    final raw = await SystemBridge.drivesList();
    if (!mounted) return;
    final drives = raw.map(DriveEntry.fromMap).toList();
    setState(() => _drives = drives);
  }

  Future<void> _mountAndNavigate(DriveEntry d) async {
    if (d.isMounted) {
      _navigateTo(d.mountpoint);
      return;
    }
    // Try to mount, then reload drives to get the mountpoint
    final mp = await SystemBridge.usbMount(d.device);
    await _loadDrives();
    // Find updated entry
    if (!mounted) return;
    final updated = _drives.firstWhere((x) => x.device == d.device,
        orElse: () => d);
    if (updated.isMounted) {
      _navigateTo(updated.mountpoint);
    } else if (mp.isNotEmpty && mp != '{}') {
      // udisksctl returns "Mounted /dev/sdb1 at /media/root/USB_DRIVE."
      final match = RegExp(r'at (.+?)\.?$').firstMatch(mp);
      if (match != null) _navigateTo(match.group(1)!.trim());
    }
  }

  Future<void> _ejectDrive(DriveEntry d) async {
    if (d.isMounted) {
      await SystemBridge.usbUnmount(d.device);
    }
    await _loadDrives();
  }

  void _sortEntries(List<FsEntry> list) {
    list.sort((a, b) {
      if (a.isDir && !b.isDir) return -1;
      if (!a.isDir && b.isDir) return 1;
      int cmp = 0;
      switch (_sortBy) {
        case 'name': cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase()); break;
        case 'size': cmp = a.size.compareTo(b.size); break;
        case 'date': cmp = a.modified.compareTo(b.modified); break;
        case 'type':
          final extA = a.name.contains('.') ? a.name.split('.').last : '';
          final extB = b.name.contains('.') ? b.name.split('.').last : '';
          cmp = extA.compareTo(extB);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  // ---------------------------------------------------------------------------
  // File operations
  // ---------------------------------------------------------------------------

  Future<void> _deleteEntry(FsEntry e) async {
    final fullPath = '$_cwd/${e.name}';
    final ok = await SystemBridge.fsDelete(fullPath);
    if (ok) {
      setState(() { _selected = null; _previewText = null; });
      await _loadDir(_cwd);
    }
  }

  Future<void> _renameEntry(FsEntry e, String newName) async {
    if (newName.trim().isEmpty || newName == e.name) return;
    final from = '$_cwd/${e.name}';
    final to = '$_cwd/${newName.trim()}';
    final ok = await SystemBridge.fsRename(from, to);
    if (ok) await _loadDir(_cwd);
    setState(() { _renamingName = null; _selected = null; });
  }

  Future<void> _mkdirEntry(String name) async {
    if (name.trim().isEmpty) return;
    await SystemBridge.fsMkdir('$_cwd/${name.trim()}');
    await _loadDir(_cwd);
  }

  Future<void> _touchEntry(String name) async {
    if (name.trim().isEmpty) return;
    await SystemBridge.fsWriteText('$_cwd/${name.trim()}', '');
    await _loadDir(_cwd);
  }

  Future<void> _loadPreview(FsEntry e) async {
    if (e.isDir) { setState(() { _previewText = null; }); return; }
    setState(() { _loadingPreview = true; _previewText = null; });
    final content = await SystemBridge.fsReadText('$_cwd/${e.name}');
    setState(() { _previewText = content; _loadingPreview = false; });
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  void _doSearch(String query) {
    if (query.isEmpty) {
      setState(() { _isSearching = false; _searchResults.clear(); });
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _isSearching = true;
      _searchResults = _entries.where((e) => e.name.toLowerCase().contains(q)).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final displayList = _isSearching ? _searchResults : _entries;

    return KeyboardListener(
      focusNode: _kbFocus,
      onKeyEvent: (ev) {
        if (ev is KeyDownEvent && ev.logicalKey == LogicalKeyboardKey.f2) {
          if (_selected != null && _renamingName == null) {
            setState(() {
              _renamingName = _selected!.name;
              _renameCtrl.text = _selected!.name;
            });
          }
        }
        if (ev is KeyDownEvent && ev.logicalKey == LogicalKeyboardKey.delete) {
          if (_selected != null) _confirmDelete(_selected!);
        }
        if (ev is KeyDownEvent && ev.logicalKey == LogicalKeyboardKey.escape) {
          setState(() { _renamingName = null; });
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            CustomPaint(painter: GridPainter(), child: const SizedBox.expand()),
            Column(
              children: [
                const StatusBar(),
                _buildHeader(),
                _buildNavBar(),
                _buildAddressBar(),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(width: 200, child: _buildSidebar()),
                      Container(width: 1, color: AppTheme.border),
                      Expanded(child: _buildMainView(displayList)),
                      if (_selected != null) ...[
                        Container(width: 1, color: AppTheme.border),
                        SizedBox(width: 300, child: _buildPreviewPanel()),
                      ],
                    ],
                  ),
                ),
                _buildBottomBar(displayList),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('FILES', style: TextStyle(color: AppTheme.accent, fontSize: 13,
              fontWeight: FontWeight.bold, letterSpacing: 3)),
          const Spacer(),
          _viewModeBtn(Icons.view_list, 'list'),
          _viewModeBtn(Icons.grid_view, 'grid'),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: AppTheme.border),
          const SizedBox(width: 8),
          _headerBtn(Icons.create_new_folder_outlined, 'New Folder', () => _showNewDialog(true)),
          _headerBtn(Icons.note_add_outlined, 'New File', () => _showNewDialog(false)),
          _headerBtn(Icons.delete_outline, 'Delete',
              _selected != null ? () => _confirmDelete(_selected!) : null),
          _headerBtn(Icons.info_outline, 'Properties',
              _selected != null ? () => _showProperties(_selected!) : null),
          _headerBtn(Icons.refresh, 'Refresh', () => _loadDir(_cwd)),
        ],
      ),
    );
  }

  Widget _viewModeBtn(IconData icon, String mode) {
    final active = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accentDim : AppTheme.surface,
          border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: active ? AppTheme.accent : AppTheme.textSecondary, size: 14),
      ),
    );
  }

  Widget _headerBtn(IconData icon, String tooltip, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: enabled ? AppTheme.surfaceAlt : AppTheme.surface,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon,
              color: enabled ? AppTheme.textSecondary : AppTheme.border, size: 14),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Nav bar
  // ---------------------------------------------------------------------------

  Widget _buildNavBar() {
    return Container(
      height: 40, color: AppTheme.surfaceAlt,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _navBtn(Icons.arrow_back, 'Back', _historyIndex > 0, _navigateBack),
          const SizedBox(width: 4),
          _navBtn(Icons.arrow_forward, 'Forward', _historyIndex < _history.length - 1, _navigateForward),
          const SizedBox(width: 4),
          _navBtn(Icons.arrow_upward, 'Up', _cwd != '/', _navigateUp),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, String tooltip, bool enabled, VoidCallback fn) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? fn : null,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled ? AppTheme.surface : AppTheme.surfaceAlt,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon,
              color: enabled ? AppTheme.textPrimary : AppTheme.border, size: 14),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Address bar
  // ---------------------------------------------------------------------------

  Widget _buildAddressBar() {
    return Container(
      height: 36, color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, color: AppTheme.textSecondary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _addressEditing = true;
                _addressCtrl.selection = TextSelection(
                    baseOffset: 0, extentOffset: _addressCtrl.text.length);
              }),
              child: _addressEditing
                  ? TextField(
                      controller: _addressCtrl, autofocus: true,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                      cursorColor: AppTheme.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        filled: true, fillColor: AppTheme.surfaceAlt,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: AppTheme.accent)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: AppTheme.accent)),
                      ),
                      onSubmitted: (v) {
                        final p = v.trim();
                        if (p.isNotEmpty) _navigateTo(p);
                        else _addressCtrl.text = _cwd;
                        setState(() => _addressEditing = false);
                      },
                      onTapOutside: (_) {
                        _addressCtrl.text = _cwd;
                        setState(() => _addressEditing = false);
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          Expanded(child: Text(_cwd,
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                              overflow: TextOverflow.ellipsis)),
                          const Icon(Icons.edit, color: AppTheme.textSecondary, size: 12),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          // Search
          SizedBox(
            width: 200,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                border: Border.all(
                    color: _isSearching ? AppTheme.accent : AppTheme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.search,
                      color: _isSearching ? AppTheme.accent : AppTheme.textSecondary,
                      size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                      cursorColor: AppTheme.accent,
                      decoration: const InputDecoration(
                        isDense: true, border: InputBorder.none,
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _doSearch,
                    ),
                  ),
                  if (_isSearching)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() { _isSearching = false; _searchResults.clear(); });
                      },
                      child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 12),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sidebar
  // ---------------------------------------------------------------------------

  Widget _buildSidebar() {
    // Drives: show partitions (type=part) that are removable OR are mounted
    // somewhere other than system paths. Also always show disks with no children.
    final systemMounts = {'/boot', '/boot/efi', '/home', '/tmp', '/', '[SWAP]'};
    final removableDrives = _drives.where((d) =>
        d.removable && d.type == 'part').toList();
    final nonRemovablePartitions = _drives.where((d) =>
        !d.removable && d.type == 'part' &&
        d.isMounted &&
        !systemMounts.any((sm) => d.mountpoint == sm)).toList();

    return Container(
      color: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── PLACES ──────────────────────────────────────────────────────
          _sidebarSection('PLACES'),
          _sidebarItem('Home',   '/root',      Icons.home_rounded),
          _sidebarItem('Root',   '/',          Icons.computer),
          _sidebarItem('etc',    '/etc',       Icons.settings_rounded),
          _sidebarItem('var',    '/var',       Icons.storage_rounded),
          _sidebarItem('tmp',    '/tmp',       Icons.delete_sweep_rounded),
          _sidebarItem('usr',    '/usr',       Icons.folder_rounded),
          _sidebarItem('KrdOS',  '/opt/krdos', Icons.apps_rounded),

          // ── DRIVES ──────────────────────────────────────────────────────
          _sidebarSection('DRIVES'),
          if (_drives.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text('No drives detected',
                  style: TextStyle(color: AppTheme.border, fontSize: 10)),
            ),
          // Internal mounted partitions (not system paths)
          for (final d in nonRemovablePartitions)
            _driveItem(d),
          // Removable / USB drives
          for (final d in removableDrives)
            _driveItem(d),

          // ── NETWORK ──────────────────────────────────────────────────────
          _sidebarSection('NETWORK'),
          _sidebarItem('media',  '/media',     Icons.usb_rounded),
          _sidebarItem('mnt',    '/mnt',       Icons.disc_full_rounded),
        ],
      ),
    );
  }

  Widget _sidebarSection(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    child: Text(label, style: TextStyle(
        color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 2)),
  );

  Widget _driveItem(DriveEntry d) {
    final isActive = _cwd == d.mountpoint && d.isMounted;
    final icon = d.removable
        ? Icons.usb_rounded
        : Icons.storage_rounded;
    final label = d.label.isEmpty ? d.name : d.label;
    final subtitle = d.isMounted ? d.mountpoint : '${d.size} — tap to mount';

    return GestureDetector(
      onTap: () => _mountAndNavigate(d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: isActive ? AppTheme.accentDim : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon,
                color: d.isMounted
                    ? (isActive ? AppTheme.accent : AppTheme.success)
                    : AppTheme.border,
                size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: isActive ? AppTheme.accent : AppTheme.textSecondary,
                          fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                  Text(subtitle,
                      style: TextStyle(color: AppTheme.border, fontSize: 9),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (d.removable)
              GestureDetector(
                onTap: () => _ejectDrive(d),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.eject,
                      color: AppTheme.textSecondary, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(String label, String path, IconData icon) {
    final sel = _cwd == path;
    return GestureDetector(
      onTap: () => _navigateTo(path),
      child: AnimatedContainer(
        duration: 100.ms,
        color: sel ? AppTheme.accentDim : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: sel ? AppTheme.accent : AppTheme.textSecondary, size: 14),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
                color: sel ? AppTheme.accent : AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Main view
  // ---------------------------------------------------------------------------

  Widget _buildMainView(List<FsEntry> list) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_loadError != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
          const SizedBox(height: 12),
          Text(_loadError!,
              style: TextStyle(color: AppTheme.danger, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _loadDir(_cwd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accent),
                  borderRadius: BorderRadius.circular(4)),
              child: Text('Retry',
                  style: TextStyle(color: AppTheme.accent, fontSize: 12)),
            ),
          ),
        ]),
      );
    }
    return _viewMode == 'grid' ? _buildGridView(list) : _buildListView(list);
  }

  Widget _buildListView(List<FsEntry> list) {
    return Column(
      children: [
        // Column headers
        Container(
          height: 32, color: AppTheme.surfaceAlt,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _colHeader('Name', 'name', flex: 3),
              _colHeader('Type', 'type', flex: 1),
              _colHeader('Size', 'size', flex: 1),
              _colHeader('Modified', 'date', flex: 2),
              _colHeader('Owner', 'owner', flex: 1),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text(
                  _isSearching ? 'No results' : 'Empty directory',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)))
              : GestureDetector(
                  onSecondaryTapDown: (d) =>
                      _showEmptyMenu(context, d.globalPosition),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _buildListItem(list[i], i),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _colHeader(String label, String key, {int flex = 1}) {
    final active = _sortBy == key;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => setState(() {
          if (_sortBy == key) _sortAscending = !_sortAscending;
          else { _sortBy = key; _sortAscending = true; }
          _sortEntries(_entries);
        }),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
              color: active ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal)),
          if (active) ...[
            const SizedBox(width: 4),
            Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: AppTheme.accent, size: 11),
          ],
        ]),
      ),
    );
  }

  Widget _buildListItem(FsEntry e, int i) {
    final sel = _selected?.name == e.name;
    return GestureDetector(
      onTap: () {
        setState(() => _selected = e);
        if (!e.isDir) _loadPreview(e);
      },
      onDoubleTap: () {
        if (e.isDir) {
          _navigateTo('$_cwd/${e.name}'.replaceAll('//', '/'));
        }
      },
      onSecondaryTapDown: (d) => _showContextMenu(context, d.globalPosition, e),
      child: AnimatedContainer(
        duration: 100.ms,
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppTheme.accentDim : Colors.transparent,
          border: Border.all(
              color: sel ? AppTheme.accent : Colors.transparent),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Stack(children: [
              Icon(_entryIcon(e),
                  color: e.isDir ? AppTheme.warning : AppTheme.textSecondary,
                  size: 16),
              if (e.isLink)
                Positioned(right: -2, bottom: -2, child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.border, width: 0.5),
                      borderRadius: BorderRadius.circular(2)),
                  child: const Icon(Icons.north_east, size: 5,
                      color: AppTheme.textSecondary),
                )),
            ]),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _renamingName == e.name
                  ? TextField(
                      key: ValueKey('rename_${e.name}'),
                      controller: _renameCtrl,
                      autofocus: true,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                      cursorColor: AppTheme.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        filled: true, fillColor: AppTheme.accentDim,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3),
                            borderSide: BorderSide(color: AppTheme.accent)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3),
                            borderSide:
                                BorderSide(color: AppTheme.accent, width: 2)),
                      ),
                      onSubmitted: (n) => _renameEntry(e, n),
                      onTapOutside: (_) =>
                          setState(() => _renamingName = null),
                    )
                  : Text(e.name,
                      style: TextStyle(
                          color: sel ? AppTheme.accent : AppTheme.textPrimary,
                          fontSize: 12),
                      overflow: TextOverflow.ellipsis),
            ),
            Expanded(
                flex: 1,
                child: Text(e.isDir ? 'Folder' : _fileType(e.name),
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11))),
            Expanded(
                flex: 1,
                child: Text(e.isDir ? '--' : _fmtSize(e.size),
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11))),
            Expanded(
                flex: 2,
                child: Text(_fmtDate(e.modified),
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11))),
            Expanded(
                flex: 1,
                child: Text(e.owner,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11))),
          ],
        ),
      ).animate(delay: Duration(milliseconds: i * 10)).fadeIn(duration: 100.ms),
    );
  }

  Widget _buildGridView(List<FsEntry> list) {
    if (list.isEmpty) {
      return Center(
          child: Text('Empty directory',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final e = list[i];
        final sel = _selected?.name == e.name;
        return GestureDetector(
          onTap: () {
            setState(() => _selected = e);
            if (!e.isDir) _loadPreview(e);
          },
          onDoubleTap: () {
            if (e.isDir) _navigateTo('$_cwd/${e.name}'.replaceAll('//', '/'));
          },
          onSecondaryTapDown: (d) => _showContextMenu(context, d.globalPosition, e),
          child: AnimatedContainer(
            duration: 100.ms,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: sel ? AppTheme.accentDim : AppTheme.surfaceAlt,
              border: Border.all(
                  color: sel ? AppTheme.accent : AppTheme.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_entryIcon(e),
                  color: e.isDir ? AppTheme.warning : AppTheme.textSecondary,
                  size: 48),
              const SizedBox(height: 8),
              Text(e.name,
                  style: TextStyle(
                      color: sel ? AppTheme.accent : AppTheme.textPrimary,
                      fontSize: 11),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ).animate(delay: Duration(milliseconds: i * 10)).fadeIn(duration: 100.ms),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Preview panel
  // ---------------------------------------------------------------------------

  Widget _buildPreviewPanel() {
    final e = _selected!;
    return Container(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration:
                BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
            child: Row(
              children: [
                Icon(_entryIcon(e), color: AppTheme.accent, size: 14),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(e.name,
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow('Type', e.isDir ? 'Directory' : _fileType(e.name)),
              _infoRow('Permissions', e.perms),
              _infoRow('Owner', e.owner),
              if (!e.isDir) _infoRow('Size', _fmtSize(e.size)),
              _infoRow('Modified', _fmtDate(e.modified)),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.border),
          if (!e.isDir)
            Expanded(
              child: _loadingPreview
                  ? Center(
                      child: CircularProgressIndicator(color: AppTheme.accent))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        _previewText ?? '',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 11,
                            height: 1.6,
                            fontFamily: 'monospace'),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text('$label: ',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      Expanded(
          child: Text(value,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 10))),
    ]),
  );

  // ---------------------------------------------------------------------------
  // Bottom bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar(List<FsEntry> list) {
    final files = list.where((e) => !e.isDir).length;
    final dirs = list.where((e) => e.isDir).length;
    return Container(
      height: 24, color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('$dirs dirs, $files files',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          const Spacer(),
          if (_selected != null)
            Text('Selected: ${_selected!.name}',
                style: TextStyle(color: AppTheme.accent, fontSize: 10)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Menus
  // ---------------------------------------------------------------------------

  void _showContextMenu(BuildContext ctx, Offset pos, FsEntry e) {
    showMenu<void>(
      context: ctx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: AppTheme.surfaceAlt,
      items: [
        if (e.isDir)
          PopupMenuItem<void>(
            child: Text('Open', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            onTap: () => _navigateTo('$_cwd/${e.name}'.replaceAll('//', '/')),
          ),
        PopupMenuItem<void>(
          child: Text('Rename', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
          onTap: () => setState(() {
            _renamingName = e.name;
            _renameCtrl.text = e.name;
          }),
        ),
        PopupMenuItem<void>(
          child: Text('Properties', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
          onTap: () => _showProperties(e),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          child: Text('Delete', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
          onTap: () => _confirmDelete(e),
        ),
      ],
    );
  }

  void _showEmptyMenu(BuildContext ctx, Offset pos) {
    showMenu<void>(
      context: ctx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: AppTheme.surfaceAlt,
      items: [
        PopupMenuItem<void>(
            child: Text('New Folder',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            onTap: () => _showNewDialog(true)),
        PopupMenuItem<void>(
            child: Text('New File',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            onTap: () => _showNewDialog(false)),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
            child: Text('Refresh',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            onTap: () => _loadDir(_cwd)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  void _showNewDialog(bool isDir) {
    final ctrl = TextEditingController(text: isDir ? 'New Folder' : 'new_file.txt');
    showDialog<void>(
      context: context,
      builder: (_) => _inputDialog(
        title: isDir ? 'NEW FOLDER' : 'NEW FILE',
        ctrl: ctrl,
        onConfirm: () {
          if (isDir) _mkdirEntry(ctrl.text);
          else _touchEntry(ctrl.text);
        },
      ),
    );
  }

  void _confirmDelete(FsEntry e) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surfaceAlt,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AppTheme.danger)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.delete_forever, color: AppTheme.danger, size: 48),
            const SizedBox(height: 12),
            Text('Delete "${e.name}"?',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
                e.isDir
                    ? 'This will permanently delete the folder and ALL its contents.'
                    : 'This file will be permanently deleted.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _dialogBtn('CANCEL', AppTheme.border, AppTheme.textSecondary,
                  () => Navigator.pop(context)),
              const SizedBox(width: 12),
              _dialogBtn('DELETE', AppTheme.danger, AppTheme.danger, () {
                Navigator.pop(context);
                _deleteEntry(e);
              }),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showProperties(FsEntry e) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surfaceAlt,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.border)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_entryIcon(e), color: AppTheme.accent, size: 32),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name,
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(e.isDir ? 'Directory' : 'File',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 20),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 16),
            _propRow('Location', _cwd),
            _propRow('Type', e.isDir ? 'Folder' : _fileType(e.name)),
            if (!e.isDir) _propRow('Size', '${e.size} bytes (${_fmtSize(e.size)})'),
            _propRow('Owner', e.owner),
            _propRow('Permissions', e.perms),
            _propRow('Modified', _fmtDate(e.modified)),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: _dialogBtn('CLOSE', AppTheme.accent, AppTheme.accent,
                  () => Navigator.pop(context)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _propRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 110,
          child: Text('$label:',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600))),
      Expanded(
          child: Text(value,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
    ]),
  );

  Widget _inputDialog({
    required String title,
    required TextEditingController ctrl,
    required VoidCallback onConfirm,
  }) {
    return Dialog(
      backgroundColor: AppTheme.surfaceAlt,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.border)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(4)),
            child: TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              cursorColor: AppTheme.accent,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) {
                onConfirm();
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _dialogBtn('CANCEL', AppTheme.border, AppTheme.textSecondary,
                () => Navigator.pop(context)),
            const SizedBox(width: 8),
            _dialogBtn('OK', AppTheme.accent, AppTheme.accent, () {
              onConfirm();
              Navigator.pop(context);
            }),
          ]),
        ]),
      ),
    );
  }

  Widget _dialogBtn(String label, Color border, Color text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: border == AppTheme.accent
                ? AppTheme.accentDim
                : AppTheme.surface,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: TextStyle(
                color: text, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  IconData _entryIcon(FsEntry e) {
    if (e.isDir) return Icons.folder_rounded;
    if (e.isLink) return Icons.link;
    if (!e.name.contains('.')) return Icons.insert_drive_file;
    switch (e.name.split('.').last.toLowerCase()) {
      case 'txt': case 'md': case 'rst': return Icons.article;
      case 'conf': case 'cfg': case 'ini': return Icons.settings;
      case 'log': return Icons.list_alt;
      case 'sh': case 'bash': return Icons.terminal;
      case 'key': case 'pem': return Icons.vpn_key;
      case 'json': case 'yaml': case 'yml': return Icons.data_object;
      case 'jpg': case 'jpeg': case 'png': case 'gif': return Icons.image;
      case 'mp4': case 'avi': case 'mkv': return Icons.video_file;
      case 'mp3': case 'wav': case 'flac': return Icons.audio_file;
      case 'zip': case 'tar': case 'gz': case 'xz': return Icons.folder_zip;
      default: return Icons.insert_drive_file;
    }
  }

  String _fileType(String name) {
    if (!name.contains('.')) return 'File';
    return '${name.split('.').last.toUpperCase()} File';
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
