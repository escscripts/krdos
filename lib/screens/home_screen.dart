import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/os_state.dart';
import '../core/settings_state.dart';
import '../widgets/desktop_wallpaper_layer.dart';
import '../core/filesystem/vfs.dart';
import '../core/clipboard_manager.dart';
import '../core/mobile_home_manager.dart';
import '../theme/app_theme.dart';
import '../theme/grid_painter.dart';
import '../widgets/status_bar.dart';
import '../widgets/new_taskbar.dart';
import '../widgets/start_menu.dart';
import '../widgets/notification_panel.dart';
import '../widgets/control_center.dart';
import '../core/dock_settings.dart';
import '../core/shell/app_catalog.dart';
import 'app_drawer.dart';
import 'settings_screen.dart';
import 'devices/device_hub_screen.dart';
import 'apps/terminal_screen.dart';
import 'apps/file_manager_screen.dart';
import 'apps/editor_screen.dart';
import 'apps/professional_editor_screen.dart';
import 'mobile_page_builder.dart';
import 'apps/system_monitor_screen.dart';

class AppWindow {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  Offset position;
  Size size;
  bool minimized;
  bool maximized;
  AppWindow({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    required this.position,
    required this.size,
    this.minimized = false,
    this.maximized = false,
  });
}

class TaskbarWindowInfo {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final bool minimized;
  const TaskbarWindowInfo({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.minimized,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Shortcut {
  final String id; // unique key, e.g. 'sc_terminal'
  String appId; // which app to launch (mutable)
  String label;
  IconData icon;
  Color color;
  bool hidden; // true when moved into a folder / trash
  _Shortcut({
    required this.id,
    required this.appId,
    required this.label,
    required this.icon,
    required this.color,
    this.hidden = false,
  });
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _showNotifications = false;
  bool _showControlCenter = false;
  bool _showStartMenu = false;
  late String _time, _date;
  late Timer _timer;
  late AnimationController _notifCtrl;
  late Animation<Offset> _notifSlide;
  double _dragStart = 0;
  final List<AppWindow> _windows = [];
  int _windowZCounter = 0;
  final Map<String, int> _windowZ = {};
  final Map<String, Offset> _iconPositions = {};
  String? _renamingId;
  double _iconSize = 56;
  final List<String> _trashItems = []; // shortcut/file labels
  final List<VfsNode?> _trashNodes = []; // VFS nodes (null for shortcuts)
  final List<_Shortcut?> _trashShortcuts = []; // Shortcut objects
  String? _selectedDesktopItem; // Selected desktop item ID
  Offset? _trashPosition; // Custom trash position (null = default)
  SettingsState? _desktopSettingsAttached;
  OverlayEntry? _desktopMenuOverlay;
  OverlayEntry? _desktopSubMenuOverlay;
  Offset? _desktopMenuPosition;
  Size? _desktopMenuScreenSize;

  // keyboard focus
  final FocusNode _kbFocus = FocusNode();

  // Mobile home screen manager
  late MobileHomeManager _mobileHomeManager;
  int _currentMobilePage = 0;
  int? _draggingMobileItemIndex;
  Offset? _dragMobileOffset;
  bool _isDraggingMobileItem = false;
  bool _mobileEditMode = false;
  Timer? _pageSwipeTimer;
  late PageController _pageController;

  // Grid cell size - dynamically calculated based on icon size
  double get _cellW => _iconSize + 24;
  double get _cellH => _iconSize + 48;

  Offset _snapToGrid(Offset pos) {
    final screenSize = MediaQuery.of(context).size;
    final maxRow = ((screenSize.height - 56 - _cellH) / _cellH)
        .floor(); // Account for taskbar
    final col = (pos.dx / _cellW).round().clamp(0, 20);
    final row = (pos.dy / _cellH).round().clamp(0, maxRow);
    return Offset(col * _cellW + 12, row * _cellH + 12);
  }

  void _removeDesktopSubMenu() {
    _desktopSubMenuOverlay?.remove();
    _desktopSubMenuOverlay = null;
  }

  void _removeDesktopMenu() {
    _removeDesktopSubMenu();
    _desktopMenuOverlay?.remove();
    _desktopMenuOverlay = null;
  }

  void _refreshDesktop() {
    final vfs = context.read<VirtualFileSystem>();
    final desktopItems = vfs.desktopItems;
    _lastDesktopItems = desktopItems;
    _ensurePositions(desktopItems);
    if (_mobileHomeManager.pages.isNotEmpty) {
      _syncDesktopToMobile();
    }
    setState(() {});
  }

  Widget _desktopMenuDivider() {
    return Container(height: 1, color: AppTheme.border);
  }

  Widget _desktopMenuItem({
    required Widget leading,
    required String label,
    required VoidCallback onTap,
    bool trailingChevron = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppTheme.surface,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                ),
              ),
              if (trailingChevron)
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  OverlayEntry _buildDesktopMenuOverlay(
    BuildContext ctx,
    Offset globalPos,
    Size screenSize,
  ) {
    final left = globalPos.dx + 176.0 > screenSize.width
        ? (screenSize.width - 176.0 - 8).clamp(0.0, screenSize.width - 176.0)
        : globalPos.dx;
    final top = globalPos.dy + 260.0 > screenSize.height
        ? (screenSize.height - 260.0 - 8).clamp(0.0, screenSize.height - 260.0)
        : globalPos.dy;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeDesktopMenu,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: 176.0,
              child: Material(
                color: AppTheme.surfaceAlt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppTheme.border),
                ),
                elevation: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _desktopMenuItem(
                      leading: Icon(
                        Icons.create_new_folder_outlined,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                      label: 'New Folder',
                      onTap: () {
                        _removeDesktopMenu();
                        _desktopNewDialog(ctx, true);
                      },
                    ),
                    _desktopMenuItem(
                      leading: Icon(
                        Icons.note_add_outlined,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                      label: 'New File',
                      onTap: () {
                        _removeDesktopMenu();
                        _desktopNewDialog(ctx, false);
                      },
                    ),
                    if (context.read<ClipboardManager>().hasItem) ...[
                      _desktopMenuDivider(),
                      _desktopMenuItem(
                        leading: Icon(
                          Icons.content_paste_outlined,
                          size: 14,
                          color: AppTheme.accent,
                        ),
                        label: 'Paste',
                        onTap: () {
                          _removeDesktopMenu();
                          _pasteToDesktop(globalPos);
                        },
                      ),
                    ],
                    _desktopMenuDivider(),
                    _desktopMenuItem(
                      leading: Icon(
                        Icons.view_module_outlined,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                      label: 'View',
                      trailingChevron: true,
                      onTap: () {
                        _removeDesktopSubMenu();
                        _desktopSubMenuOverlay = _buildDesktopViewOverlay(
                          ctx,
                          globalPos,
                          screenSize,
                          left,
                        );
                        Overlay.of(ctx)?.insert(_desktopSubMenuOverlay!);
                      },
                    ),
                    _desktopMenuDivider(),
                    _desktopMenuItem(
                      leading: Icon(
                        Icons.refresh,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                      label: 'Refresh',
                      onTap: () {
                        _removeDesktopMenu();
                        _refreshDesktop();
                      },
                    ),
                    _desktopMenuItem(
                      leading: Icon(
                        Icons.wallpaper,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                      label: 'Change Wallpaper',
                      onTap: () {
                        _removeDesktopMenu();
                        _openApp(
                          'settings',
                          screenSize,
                          settingsPage: 'personalization',
                          settingsSubTab: 0,
                        );
                      },
                    ),
                    _desktopMenuDivider(),
                    _desktopMenuItem(
                      leading: Icon(
                        Icons.terminal,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                      label: 'Open Terminal',
                      onTap: () {
                        _removeDesktopMenu();
                        _openApp('terminal', screenSize);
                      },
                    ),
                    _desktopMenuItem(
                      leading: Icon(
                        Icons.folder_open,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                      label: 'Open Files',
                      onTap: () {
                        _removeDesktopMenu();
                        _openApp('files', screenSize);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  OverlayEntry _buildDesktopViewOverlay(
    BuildContext ctx,
    Offset globalPos,
    Size screenSize,
    double parentLeft,
  ) {
    final left = parentLeft + 176.0 + 8 <= screenSize.width
        ? parentLeft + 176.0 - 8
        : (parentLeft - 176.0 + 8).clamp(0.0, screenSize.width - 176.0);
    final top = globalPos.dy + 108.0 > screenSize.height
        ? (screenSize.height - 108.0 - 8).clamp(0.0, screenSize.height - 108.0)
        : globalPos.dy;

    return OverlayEntry(
      builder: (context) {
        return Positioned(
          left: left,
          top: top,
          width: 176.0,
          child: Material(
            color: AppTheme.surfaceAlt,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppTheme.border),
            ),
            elevation: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _desktopMenuItem(
                  leading: Icon(
                    Icons.check,
                    size: 14,
                    color: _iconSize == 72
                        ? AppTheme.accent
                        : Colors.transparent,
                  ),
                  label: 'Large icons',
                  onTap: () {
                    _removeDesktopMenu();
                    _setDesktopIconSize(72);
                  },
                ),
                _desktopMenuItem(
                  leading: Icon(
                    Icons.check,
                    size: 14,
                    color: _iconSize == 56
                        ? AppTheme.accent
                        : Colors.transparent,
                  ),
                  label: 'Medium icons',
                  onTap: () {
                    _removeDesktopMenu();
                    _setDesktopIconSize(56);
                  },
                ),
                _desktopMenuItem(
                  leading: Icon(
                    Icons.check,
                    size: 14,
                    color: _iconSize == 40
                        ? AppTheme.accent
                        : Colors.transparent,
                  ),
                  label: 'Small icons',
                  onTap: () {
                    _removeDesktopMenu();
                    _setDesktopIconSize(40);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Desktop shortcuts ? seeded from the shell app registry (single source of truth).
  late final List<_Shortcut> _shortcuts = ShellAppRegistry.all
      .where((d) => d.showOnDesktopByDefault)
      .map(
        (d) => _Shortcut(
          id: 'sc_${d.id}',
          appId: d.id,
          label: d.title,
          icon: d.icon,
          color: d.color,
        ),
      )
      .toList();

  // Track last desktop items to avoid redundant position init
  List<VfsNode> _lastDesktopItems = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vfs = context.read<VirtualFileSystem>();
    final items = vfs.desktopItems;
    if (items.length != _lastDesktopItems.length ||
        !items.every((n) => _lastDesktopItems.any((o) => o.name == n.name))) {
      _lastDesktopItems = items;
      _ensurePositions(items);
  // Sync desktop changes to mobile
      if (_mobileHomeManager.pages.isNotEmpty) {
        _syncDesktopToMobile();
      }
    }
  }

  void _ensurePositions(List<VfsNode> desktopItems) {
    final screenSize = MediaQuery.of(context).size;
    final maxRows = ((screenSize.height - 56 - _cellH) / _cellH)
        .floor(); // Account for taskbar
    var idx = 0;

  // Position shortcuts first
    for (final sc in _shortcuts.where((s) => !s.hidden)) {
      if (!_iconPositions.containsKey(sc.id)) {
        Offset newPos;
        bool positionFound = false;

  // Try to find empty position
        for (var attempt = 0; attempt < 100; attempt++) {
          final col = (idx + attempt) ~/ maxRows;
          final row = (idx + attempt) % maxRows;
          newPos = Offset(col * _cellW + 12, row * _cellH + 12);

  // Check if position is free
          if (!_iconPositions.values.any(
            (p) => (p.dx - newPos.dx).abs() < 5 && (p.dy - newPos.dy).abs() < 5,
          )) {
            _iconPositions[sc.id] = newPos;
            positionFound = true;
            break;
          }
        }

        if (!positionFound) {
  // Fallback: just place it
          final col = idx ~/ maxRows;
          final row = idx % maxRows;
          _iconPositions[sc.id] = Offset(col * _cellW + 12, row * _cellH + 12);
        }
      }
      idx++;
    }

  // Position VFS items
    for (var i = 0; i < desktopItems.length; i++) {
      final key = 'vfs_${desktopItems[i].name}';
      if (!_iconPositions.containsKey(key)) {
        Offset newPos;
        bool positionFound = false;

  // Try to find empty position
        for (var attempt = 0; attempt < 100; attempt++) {
          final col = (idx + i + attempt) ~/ maxRows;
          final row = (idx + i + attempt) % maxRows;
          newPos = Offset(col * _cellW + 12, row * _cellH + 12);

  // Check if position is free
          if (!_iconPositions.values.any(
            (p) => (p.dx - newPos.dx).abs() < 5 && (p.dy - newPos.dy).abs() < 5,
          )) {
            _iconPositions[key] = newPos;
            positionFound = true;
            break;
          }
        }

        if (!positionFound) {
  // Fallback: just place it
          final col = (idx + i) ~/ maxRows;
          final row = (idx + i) % maxRows;
          _iconPositions[key] = Offset(col * _cellW + 12, row * _cellH + 12);
        }
      }
    }
  }

  Widget _screenFor(
    String id, {
    String? path,
    String? settingsInitialPage,
    int settingsInitialSubTab = 0,
  }) {
    final canonical = ShellAppRegistry.canonicalizeId(id) ?? id;
    if (canonical == 'monitor') {
      return SystemMonitorScreen(
        getWindows: () => _windows,
        onFocusWindow: (windowId) {
          final i = _windows.indexWhere((w) => w.id == windowId);
          if (i == -1) return;
          setState(() {
            _windows[i].minimized = false;
            _bringToFront(windowId);
          });
        },
        onToggleMinimize: _toggleMinimize,
        onToggleMaximize: _toggleMaximize,
        onCloseWindow: _closeWindow,
      );
    }
    return ShellAppRegistry.buildShellApp(
      context,
      canonical,
      path: path,
      settingsInitialPage: settingsInitialPage,
      settingsInitialSubTab: settingsInitialSubTab,
    );
  }

  _Shortcut? _scById(String appId) =>
      _shortcuts.where((s) => s.appId == appId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _notifCtrl = AnimationController(vsync: this, duration: 250.ms);
    _notifSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _notifCtrl, curve: Curves.easeOut));
    _mobileHomeManager = MobileHomeManager();
    _pageController = PageController(initialPage: _currentMobilePage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _kbFocus.requestFocus();
      _initializeMobileHome();
      _attachDesktopIconListener();
    });
  }

  void _attachDesktopIconListener() {
    final s = context.read<SettingsState>();
    _desktopSettingsAttached?.removeListener(_onPersistentSettingsChanged);
    _desktopSettingsAttached = s;
    _iconSize = s.desktopIconSize;
    _desktopSettingsAttached!.addListener(_onPersistentSettingsChanged);
  }

  void _onPersistentSettingsChanged() {
    final s = _desktopSettingsAttached;
    if (!mounted || s == null) return;
    final next = s.desktopIconSize;
    if ((next - _iconSize).abs() >= 0.01) setState(() => _iconSize = next);
  }

  void _initializeMobileHome() {
    final vfs = context.read<VirtualFileSystem>();
    final desktopItems = _mobileHomeManager.getDesktopItems(vfs);

    if (_mobileHomeManager.pages.isEmpty) {
      _mobileHomeManager.addPage();
      for (int i = 0; i < desktopItems.length && i < 20; i++) {
        _mobileHomeManager.addItem(0, desktopItems[i]);
      }
    }
  }

  void _syncDesktopToMobile() {
    final vfs = context.read<VirtualFileSystem>();
    final desktopItems = _mobileHomeManager.getDesktopItems(vfs);

  // Get all items currently in mobile pages
    final existingPaths = <String>{};
    for (var page in _mobileHomeManager.pages) {
      for (var item in page) {
        if (item.path.isNotEmpty) {
          existingPaths.add(item.path);
        }
      }
    }

  // Add new desktop items to first page
    for (var item in desktopItems) {
      if (!existingPaths.contains(item.path)) {
        setState(() {
          _mobileHomeManager.addItem(0, item);
        });
      }
    }

  // Remove deleted items from all pages
    final currentDesktopPaths = desktopItems.map((i) => i.path).toSet();
    for (
      var pageIdx = 0;
      pageIdx < _mobileHomeManager.pages.length;
      pageIdx++
    ) {
      final page = _mobileHomeManager.getPage(pageIdx);
      for (var itemIdx = page.length - 1; itemIdx >= 0; itemIdx--) {
        final item = page[itemIdx];
        if (item.path.isNotEmpty && !currentDesktopPaths.contains(item.path)) {
          setState(() {
            _mobileHomeManager.removeItem(pageIdx, itemIdx);
          });
        }
      }
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _time = DateFormat('HH:mm').format(now);
      _date = DateFormat('EEEE, MMMM dd yyyy').format(now);
    });
  }

  @override
  void dispose() {
    _desktopSettingsAttached?.removeListener(_onPersistentSettingsChanged);
    _removeDesktopMenu();
    _timer.cancel();
    _notifCtrl.dispose();
    _kbFocus.dispose();
    _pageSwipeTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _closeAll() {
    if (_showNotifications) {
      _notifCtrl.reverse();
      setState(() => _showNotifications = false);
    }
    if (_showControlCenter) setState(() => _showControlCenter = false);
    if (_showStartMenu) setState(() => _showStartMenu = false);
  // Re-request focus after closing overlays
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _kbFocus.requestFocus();
    });
  }

  void _toggleNotifications() {
    _closeAll();
    setState(() => _showNotifications = true);
    _notifCtrl.forward();
  }

  void _toggleCC() {
    if (_showControlCenter) {
      setState(() => _showControlCenter = false);
      return;
    }
    _closeAll();
    setState(() => _showControlCenter = true);
  }

  void _toggleStart() {
    if (_showStartMenu) {
      setState(() => _showStartMenu = false);
      return;
    }
    _closeAll();
    setState(() => _showStartMenu = true);
  }

  void _openApp(
    String appId,
    Size screenSize, {
    String? settingsPage,
    int settingsSubTab = 0,
  }) {
    _closeAll();
    final canonical =
        ShellAppRegistry.canonicalizeId(appId) ?? appId.toLowerCase().trim();
    final meta = ShellAppRegistry.lookup(canonical);
    if (meta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unknown application: $appId'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final winId = 'win_$canonical';
    final existing = _windows.indexWhere((w) => w.id == winId);
    if (existing != -1) {
      final deepLinkSettings = canonical == 'settings' && settingsPage != null;
      if (!deepLinkSettings) {
        setState(() {
          _windows[existing].minimized = false;
          _bringToFront(winId);
        });
        return;
      }
      setState(() => _windows.removeAt(existing));
    }
    final sc = _scById(canonical);
    final w = AppWindow(
      id: winId,
      title: sc?.label ?? meta.title,
      icon: sc?.icon ?? meta.icon,
      color: sc?.color ?? meta.color,
      child: _screenFor(
        canonical,
        settingsInitialPage: settingsPage,
        settingsInitialSubTab: settingsSubTab,
      ),
      position: Offset(
        40.0 + _windows.length * 24,
        40.0 + _windows.length * 24,
      ),
      size: Size(
        (screenSize.width * 0.72).clamp(520, 1200),
        (screenSize.height * 0.78).clamp(400, 900),
      ),
    );
    setState(() {
      _windows.add(w);
      _bringToFront(winId);
    });
  }

  void _openAppWithPath(String appId, Size screenSize, String path) {
    _closeAll();
    final canonical =
        ShellAppRegistry.canonicalizeId(appId) ?? appId.toLowerCase().trim();
    final winId = 'win_${canonical}_path';
    _windows.removeWhere((w) => w.id == winId);
    final sc = _scById(canonical);
    final meta = ShellAppRegistry.lookup(canonical);
    final icon = sc?.icon ?? meta?.icon ?? Icons.folder_open;
    final color = sc?.color ?? meta?.color ?? AppTheme.warning;
    final label = sc?.label ?? meta?.title ?? 'Files';
    final w = AppWindow(
      id: winId,
      title: '$label , $path',
      icon: icon,
      color: color,
      child: _screenFor(canonical, path: path),
      position: Offset(
        40.0 + _windows.length * 24,
        40.0 + _windows.length * 24,
      ),
      size: Size(
        (screenSize.width * 0.72).clamp(520, 1200),
        (screenSize.height * 0.78).clamp(400, 900),
      ),
    );
    setState(() {
      _windows.add(w);
      _bringToFront(winId);
    });
  }

  void _closeWindow(String id) =>
      setState(() => _windows.removeWhere((w) => w.id == id));
  void _bringToFront(String id) => _windowZ[id] = ++_windowZCounter;

  void _toggleMinimize(String id) {
    final i = _windows.indexWhere((w) => w.id == id);
    if (i == -1) return;
    setState(() => _windows[i].minimized = !_windows[i].minimized);
  }

  void _toggleMaximize(String id) {
    final i = _windows.indexWhere((w) => w.id == id);
    if (i == -1) return;
    setState(() => _windows[i].maximized = !_windows[i].maximized);
  }

  bool _isDraggingWindow = false;
  Offset? _dragStartPos;

  void _moveWindow(String id, Offset delta) {
    final i = _windows.indexWhere((w) => w.id == id);
    if (i == -1) return;
    setState(() {
      _windows[i].position += delta;
    });
  }

  void _onWindowDragStart(String id) {
    final i = _windows.indexWhere((w) => w.id == id);
    if (i == -1) return;
    _isDraggingWindow = true;
    _dragStartPos = _windows[i].position;
  }

  void _onWindowDragEnd(String id) {
    final i = _windows.indexWhere((w) => w.id == id);
    if (i == -1) return;
    _isDraggingWindow = false;

    final w = _windows[i];
    final screenSize = MediaQuery.of(context).size;
    final snapThreshold = 15.0;

  // Only snap if window is not maximized
    if (w.maximized) return;

  // Left edge snap - snap to left half
    if (w.position.dx < snapThreshold) {
      setState(() {
        w.position = Offset.zero;
        w.size = Size(screenSize.width / 2, screenSize.height - 56);
      });
      return;
    }

  // Right edge snap - snap to right half
    if (w.position.dx + w.size.width > screenSize.width - snapThreshold) {
      setState(() {
        w.position = Offset(screenSize.width / 2, 0);
        w.size = Size(screenSize.width / 2, screenSize.height - 56);
      });
      return;
    }

  // Top edge snap - maximize
    if (w.position.dy < snapThreshold) {
      _toggleMaximize(w.id);
      return;
    }
  }

  void _resizeWindow(String id, Offset delta) {
    final i = _windows.indexWhere((w) => w.id == id);
    if (i == -1) return;
    setState(() {
      final w = _windows[i];
      w.size = Size(
        (w.size.width + delta.dx).clamp(320.0, 1600.0),
        (w.size.height + delta.dy).clamp(240.0, 1200.0),
      );
    });
  }

  void _showDesktopMenu(BuildContext ctx, Offset globalPos, Size screenSize) {
    _removeDesktopMenu();
    _desktopMenuPosition = globalPos;
    _desktopMenuScreenSize = screenSize;
    _desktopMenuOverlay = _buildDesktopMenuOverlay(ctx, globalPos, screenSize);
    Overlay.of(ctx)?.insert(_desktopMenuOverlay!);
  }

  void _showDesktopViewMenu(
    BuildContext ctx,
    Offset globalPos,
    Size screenSize,
    double menuWidth,
  ) {
    _removeDesktopSubMenu();
    final parentLeft = globalPos.dx + menuWidth > screenSize.width
        ? (screenSize.width - menuWidth - 8).clamp(
            0.0,
            screenSize.width - menuWidth,
          )
        : globalPos.dx;
    _desktopSubMenuOverlay = _buildDesktopViewOverlay(
      ctx,
      globalPos,
      screenSize,
      parentLeft,
    );
    Overlay.of(ctx)?.insert(_desktopSubMenuOverlay!);
  }

  void _setDesktopIconSize(double size) {
    if (!mounted) return;
    final settings = context.read<SettingsState>();
    settings.setDesktopIconSize(size);
    setState(() {
      _iconSize = size;
      _iconPositions.clear();
    });
  }

  void _pasteToDesktop(Offset pos) {
    final clipboard = context.read<ClipboardManager>();
    if (!clipboard.hasItem) return;

    final item = clipboard.item!;
    final vfs = context.read<VirtualFileSystem>();
    final node = item.node;

  // Check if this is a shortcut being pasted
    if (node is VfsFile && node.content.startsWith('shortcut:')) {
      final parts = node.content.split(':');
      if (parts.length >= 5) {
        final appId = parts[1];
        final originalLabel = parts[2];
        final iconCode = int.tryParse(parts[3]) ?? Icons.apps.codePoint;
        final colorValue = int.tryParse(parts[4]) ?? AppTheme.accent.value;

        if (clipboard.isCut) {
  // Cut: restore the original shortcut
          try {
            final originalSc = _shortcuts.firstWhere(
              (s) => s.appId == appId && s.hidden,
            );
            setState(() {
              originalSc.hidden = false;
              final snapped = _snapToGrid(pos);
              _iconPositions[originalSc.id] = snapped;
            });
          } catch (e) {
  // Original not found, create new
            final newSc = _Shortcut(
              id: 'sc_${appId}_${DateTime.now().millisecondsSinceEpoch}',
              appId: appId,
              label: originalLabel,
              icon: IconData(iconCode, fontFamily: 'MaterialIcons'),
              color: Color(colorValue),
            );
            setState(() {
              _shortcuts.add(newSc);
              final snapped = _snapToGrid(pos);
              _iconPositions[newSc.id] = snapped;
            });
          }
          clipboard.clear();
          vfs.remove(item.path);
        } else {
  // Copy: create a new shortcut with proper naming
          String newLabel = originalLabel;
          var counter = 1;

  // Check if label already exists
          while (_shortcuts.any((s) => !s.hidden && s.label == newLabel)) {
            counter++;
            newLabel = '$originalLabel $counter';
          }

          final newSc = _Shortcut(
            id: 'sc_${appId}_${DateTime.now().millisecondsSinceEpoch}',
            appId: appId,
            label: newLabel,
            icon: IconData(iconCode, fontFamily: 'MaterialIcons'),
            color: Color(colorValue),
          );
          setState(() {
            _shortcuts.add(newSc);
  // Find next available grid position
            Offset snapped = _snapToGrid(pos);
            while (_iconPositions.values.any(
              (p) =>
                  (p.dx - snapped.dx).abs() < 5 &&
                  (p.dy - snapped.dy).abs() < 5,
            )) {
              snapped = Offset(snapped.dx + _cellW, snapped.dy);
            }
            _iconPositions[newSc.id] = snapped;
          });
        }
      }
      return;
    }

    if (clipboard.isCut) {
  // Cut: move to desktop
      final targetPath = '/C:/Users/Admin/Desktop/${node.name}';
      if (item.path == targetPath) {
        clipboard.clear();
        return;
      }
      if (node is VfsDir) {
        vfs.mkdir(targetPath);
      } else {
        vfs.touch(targetPath, content: (node as VfsFile).content);
      }
      vfs.remove(item.path);
      clipboard.clear();
  // Find next available grid position
      Offset snapped = _snapToGrid(pos);
      while (_iconPositions.values.any(
        (p) => (p.dx - snapped.dx).abs() < 5 && (p.dy - snapped.dy).abs() < 5,
      )) {
        snapped = Offset(snapped.dx + _cellW, snapped.dy);
      }
      _iconPositions['vfs_${node.name}'] = snapped;
    } else {
  // Copy: create duplicate on desktop with proper naming
      String copyName;
      var counter = 1;

  // First paste: "file copy.txt" or "folder copy"
      if (node.name.contains('.')) {
        final parts = node.name.split('.');
        final ext = parts.last;
        final nameWithoutExt = parts.sublist(0, parts.length - 1).join('.');
        copyName = '$nameWithoutExt copy.$ext';

        while (vfs.resolve('/C:/Users/Admin/Desktop/$copyName') != null) {
          counter++;
          copyName = '$nameWithoutExt copy $counter.$ext';
        }
      } else {
        copyName = '${node.name} copy';
        while (vfs.resolve('/C:/Users/Admin/Desktop/$copyName') != null) {
          counter++;
          copyName = '${node.name} copy $counter';
        }
      }

      if (node is VfsDir) {
        vfs.mkdir('/C:/Users/Admin/Desktop/$copyName');
      } else {
        vfs.touch(
          '/C:/Users/Admin/Desktop/$copyName',
          content: (node as VfsFile).content,
        );
      }
  // Find next available grid position to avoid stacking
      Offset snapped = _snapToGrid(pos);
      while (_iconPositions.values.any(
        (p) => (p.dx - snapped.dx).abs() < 5 && (p.dy - snapped.dy).abs() < 5,
      )) {
        snapped = Offset(snapped.dx + _cellW, snapped.dy);
      }
      _iconPositions['vfs_$copyName'] = snapped;
    }
    setState(() {});
  }

  void _desktopNewDialog(BuildContext ctx, bool isDir) {
    final vfs = context.read<VirtualFileSystem>();

  // Generate unique name
    String baseName = isDir ? 'New Folder' : 'New File.txt';
    String name = baseName;
    var counter = 1;

    while (vfs.resolve('/C:/Users/Admin/Desktop/$name') != null) {
      counter++;
      if (isDir) {
        name = 'New Folder $counter';
      } else {
        name = 'New File $counter.txt';
      }
    }

    final path = '/C:/Users/Admin/Desktop/$name';
    if (isDir)
      vfs.mkdir(path);
    else
      vfs.touch(path);

  // Find next available grid position
    final screenSize = MediaQuery.of(context).size;
    final maxRows = ((screenSize.height - 56 - _cellH) / _cellH).floor();

  // Start from position after all existing items
    final totalExisting =
        _shortcuts.where((s) => !s.hidden).length + vfs.desktopItems.length;
    final startCol = totalExisting ~/ maxRows;
    final startRow = totalExisting % maxRows;
    Offset newPos = Offset(startCol * _cellW + 12, startRow * _cellH + 12);

  // Find next available position
    while (_iconPositions.values.any(
      (p) => (p.dx - newPos.dx).abs() < 5 && (p.dy - newPos.dy).abs() < 5,
    )) {
      newPos = Offset(newPos.dx + _cellW, newPos.dy);
    }

    _iconPositions['vfs_$name'] = newPos;

  // immediately start renaming
    setState(() => _renamingId = name);
  }

  void _handleKey(KeyEvent event, Size screenSize) {
    if (event is! KeyDownEvent) return;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final ctrlOrMeta = ctrl || meta;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _closeAll();
      return;
    }
    if (meta && key == LogicalKeyboardKey.keyL) {
      context.read<OsState>().lock();
      return;
    }
    if (meta && key == LogicalKeyboardKey.keyD) {
      setState(() {
        final anyVisible = _windows.any((w) => !w.minimized);
        for (final w in _windows) w.minimized = anyVisible;
      });
      return;
    }
    if (ctrlOrMeta && key == LogicalKeyboardKey.keyC) {
      if (_selectedDesktopItem != null) {
        final clipboard = context.read<ClipboardManager>();
        final vfs = context.read<VirtualFileSystem>();

        if (_selectedDesktopItem!.startsWith('vfs_')) {
          final name = _selectedDesktopItem!.substring(4);
          final node = vfs.resolve('/C:/Users/Admin/Desktop/$name');
          if (node != null) {
            clipboard.copy('/C:/Users/Admin/Desktop/$name', node);
            setState(() {}); // Update UI
          }
        } else if (_selectedDesktopItem!.startsWith('sc_')) {
  // Copy shortcut by creating temp VFS node
          try {
            final sc = _shortcuts.firstWhere(
              (s) => s.id == _selectedDesktopItem,
            );
            final tempPath = '/tmp/.shortcut_${sc.appId}';
            vfs.touch(
              tempPath,
              content:
                  'shortcut:${sc.appId}:${sc.label}:${sc.icon.codePoint}:${sc.color.value}',
            );
            final tempNode = vfs.resolve(tempPath);
            if (tempNode != null) {
              clipboard.copy(tempPath, tempNode);
              setState(() {}); // Update UI
            }
          } catch (e) {
  // Shortcut not found, ignore
          }
        }
      }
      return;
    }
    if (ctrlOrMeta && key == LogicalKeyboardKey.keyX) {
      if (_selectedDesktopItem != null) {
        final clipboard = context.read<ClipboardManager>();
        final vfs = context.read<VirtualFileSystem>();

        if (_selectedDesktopItem!.startsWith('vfs_')) {
          final name = _selectedDesktopItem!.substring(4);
          final node = vfs.resolve('/C:/Users/Admin/Desktop/$name');
          if (node != null) {
            clipboard.cut('/C:/Users/Admin/Desktop/$name', node);
            setState(() {}); // Update UI
          }
        } else if (_selectedDesktopItem!.startsWith('sc_')) {
  // Cut shortcut by creating temp VFS node and hiding original
          try {
            final sc = _shortcuts.firstWhere(
              (s) => s.id == _selectedDesktopItem,
            );
            final tempPath = '/tmp/.shortcut_${sc.appId}';
            vfs.touch(
              tempPath,
              content:
                  'shortcut:${sc.appId}:${sc.label}:${sc.icon.codePoint}:${sc.color.value}',
            );
            final tempNode = vfs.resolve(tempPath);
            if (tempNode != null) {
              clipboard.cut(tempPath, tempNode);
              setState(() {
                sc.hidden = true;
                _iconPositions.remove(sc.id);
                _selectedDesktopItem = null;
              });
            }
          } catch (e) {
  // Shortcut not found, ignore
          }
        }
      }
      return;
    }
    if (ctrlOrMeta && key == LogicalKeyboardKey.keyV) {
      final clipboard = context.read<ClipboardManager>();
      if (clipboard.hasItem) {
  // Find a good position for paste - center of screen or near last selected item
        Offset pastePos = const Offset(120, 120);
        if (_selectedDesktopItem != null &&
            _iconPositions.containsKey(_selectedDesktopItem)) {
          final selectedPos = _iconPositions[_selectedDesktopItem]!;
          pastePos = Offset(selectedPos.dx + _cellW, selectedPos.dy);
        }
        _pasteToDesktop(pastePos);
      }
      return;
    }
    if (key == LogicalKeyboardKey.delete) {
      if (_selectedDesktopItem != null) {
        if (_selectedDesktopItem!.startsWith('vfs_')) {
          final name = _selectedDesktopItem!.substring(4);
          final vfs = context.read<VirtualFileSystem>();
          final node = vfs.resolve('/C:/Users/Admin/Desktop/$name');
          if (node != null) {
            setState(() {
              _trashItems.add(name);
              _trashNodes.add(node);
              _trashShortcuts.add(null);
              vfs.remove('/C:/Users/Admin/Desktop/$name');
              _iconPositions.remove(_selectedDesktopItem);
              _selectedDesktopItem = null;
            });
          }
        } else if (_selectedDesktopItem!.startsWith('sc_')) {
          try {
            final sc = _shortcuts.firstWhere(
              (s) => s.id == _selectedDesktopItem,
            );
            setState(() {
              _trashItems.add(sc.label);
              _trashNodes.add(null);
              _trashShortcuts.add(sc);
              sc.hidden = true;
              _iconPositions.remove(sc.id);
              _selectedDesktopItem = null;
            });
          } catch (e) {
  // Shortcut not found
          }
        }
      }
      return;
    }
    if (ctrlOrMeta && key == LogicalKeyboardKey.keyZ) {
      if (_trashNodes.isNotEmpty) {
        final vfs = context.read<VirtualFileSystem>();
        final node = _trashNodes.last;
        final shortcut = _trashShortcuts.last;

        if (node != null) {
  // Restore VFS node
          if (node is VfsDir)
            vfs.mkdir('/C:/Users/Admin/Desktop/${node.name}');
          else
            vfs.touch(
              '/C:/Users/Admin/Desktop/${node.name}',
              content: (node as VfsFile).content,
            );
        } else if (shortcut != null) {
  // Restore shortcut
          shortcut.hidden = false;
        }

        setState(() {
          _trashItems.removeLast();
          _trashNodes.removeLast();
          _trashShortcuts.removeLast();
        });
      }
      return;
    }
    if (key == LogicalKeyboardKey.f5) {
      setState(() {});
      return;
    }
  }

  /// Avoid pulling focus away from text fields (and other [EditableText] widgets).
  ///
  /// [TextField] attaches focus to a [Focus] node whose *child* is the
  /// [EditableText], so only checking ancestors misses almost all fields.
  bool _primaryFocusIsTextEntry() {
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx is! Element) return false;
    if (ctx.findAncestorWidgetOfExactType<EditableText>() != null) return true;
    return _elementSubtreeHasWidget(ctx, (w) => w is EditableText);
  }

  bool _elementSubtreeHasWidget(Element root, bool Function(Widget) test) {
    var found = false;
    void walk(Element e) {
      if (found) return;
      if (test(e.widget)) {
        found = true;
        return;
      }
      e.visitChildren(walk);
    }

    walk(root);
    return found;
  }

  /// Windows WebView renders to a [Texture]; it is not an [EditableText], but it
  /// still needs native keyboard focus ? do not pull focus back to the shell.
  bool _nativeWebContentLikelyHasKeyboardFocus() {
    if (_topVisibleWindowId() == 'win_browser') return true;
    final primary = FocusManager.instance.primaryFocus;
    final ctx = primary?.context;
    if (ctx is! Element) return false;
    return _elementSubtreeHasWidget(ctx, (w) => w is Texture);
  }

  String? _topVisibleWindowId() {
    final visible = _windows.where((w) => !w.minimized).toList();
    if (visible.isEmpty) return null;
    visible.sort(
      (a, b) => (_windowZ[b.id] ?? 0).compareTo(_windowZ[a.id] ?? 0),
    );
    return visible.first.id;
  }

  @override
  Widget build(BuildContext context) {
  // Keep desktop keyboard shortcuts on [KeyboardListener] without stealing
  // focus from TextFields (rebuilds run every second for the clock, etc.).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _kbFocus.hasFocus) return;
      if (_primaryFocusIsTextEntry()) return;
      if (_nativeWebContentLikelyHasKeyboardFocus()) return;
      _kbFocus.requestFocus();
    });

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final isLaptop = w >= 1100;
          final deviceType = w < 600
              ? DeviceType.mobile
              : w < 1100
              ? DeviceType.tablet
              : DeviceType.laptop;
          return GestureDetector(
            onTap: () {
              _closeAll();
              _kbFocus.requestFocus(); // Ensure focus on tap
            },
            child: KeyboardListener(
              focusNode: _kbFocus,
              onKeyEvent: (e) => _handleKey(e, constraints.biggest),
              child: GestureDetector(
                onTap: null, // Prevent double tap handling
                onVerticalDragStart: (d) => _dragStart = d.globalPosition.dy,
                onVerticalDragEnd: (d) {
                  if (!isLaptop) {
                    final delta = d.globalPosition.dy - _dragStart;
                    if (delta > 60 && !_showControlCenter) _toggleCC();
                    if (delta < -60 && _showControlCenter) _toggleCC();
                  }
                },
                child: Stack(
                  children: [
                    if (!isLaptop)
                      CustomPaint(
                        painter: _ScanlinePainter(),
                        child: const SizedBox.expand(),
                      ),
                    isLaptop
                        ? _buildLaptopLayout(constraints.biggest)
                        : _buildMobileLayout(deviceType),
                    SlideTransition(
                      position: _notifSlide,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: EdgeInsets.only(top: isLaptop ? 0 : 32),
                          child: NotificationPanel(
                            onClose: _toggleNotifications,
                          ),
                        ),
                      ),
                    ),
                    if (_showControlCenter)
                      isLaptop ? _buildLaptopCC() : _buildMobileCC(),
                    if (_showStartMenu && isLaptop)
                      Positioned(
                        bottom: 56,
                        left: 8,
                        child: GestureDetector(
                          onTap: () {},
                          child: StartMenu(
                            onClose: () =>
                                setState(() => _showStartMenu = false),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLaptopCC() {
    final dockSettings = context.watch<DockSettings>();
    final position = dockSettings.position;

  // Position control center opposite to taskbar
    if (position == DockPosition.top) {
      return Positioned(
        bottom: 8,
        right: 8,
        child: GestureDetector(
          onTap: () {},
          child: ControlCenter(onClose: _toggleCC, isLaptop: true),
        ),
      );
    } else {
  // Default: bottom taskbar, CC at bottom-right
      return Positioned(
        bottom: dockSettings.size + 8,
        right: 8,
        child: GestureDetector(
          onTap: () {},
          child: ControlCenter(onClose: _toggleCC, isLaptop: true),
        ),
      );
    }
  }

  Widget _buildMobileCC() => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: const EdgeInsets.only(top: 32),
      child: GestureDetector(
        onTap: () {},
        child: ControlCenter(onClose: _toggleCC, isLaptop: false),
      ),
    ),
  );

  Widget _buildLaptopLayout(Size screenSize) {
    final openWindows = _windows
        .map(
          (w) => TaskbarWindowInfo(
            id: w.id,
            title: w.title,
            icon: w.icon,
            color: w.color,
            minimized: w.minimized,
          ),
        )
        .toList();

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(child: DesktopWallpaperLayer()),
                  Consumer<SettingsState>(
                    builder: (_, s, __) => s.blurEffects
                        ? CustomPaint(
                            painter: GridPainter(),
                            child: const SizedBox.expand(),
                          )
                        : const SizedBox.expand(),
                  ),
                  _buildDesktopGrid(screenSize),
                  ..._buildWindowLayer(screenSize),
                ],
              ),
            ),
          ],
        ),
        NewTaskbar(
          openWindows: openWindows,
          onWindowTap: (id) => _toggleMinimize(id),
          onWindowClose: (id) => _closeWindow(id),
          onAppTap: (appId) => _openApp(appId, screenSize),
        ),
        Consumer<OsState>(
          builder: (_, os, __) {
            if (!os.displaySleep) return const SizedBox.shrink();
            return Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: os.wakeFromDisplaySleep,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.94),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bedtime_outlined,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Display sleep',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap anywhere to wake',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  //  Desktop icon grid with right-click  
  Widget _buildDesktopGrid(Size screenSize) {
    final vfs = context.watch<VirtualFileSystem>();
    final desktopItems = vfs.desktopItems;

  // Ensure positions for any new items (safe to call in build  only adds missing keys)
    _ensurePositions(desktopItems);

  // Collect folder positions for drop detection
    final folderPositions = <String, Offset>{};
    for (final node in desktopItems) {
      if (node is VfsDir) {
        final id = 'vfs_${node.name}';
        final pos = _iconPositions[id];
        if (pos != null) folderPositions[node.name] = pos;
      }
    }
    final trashPos =
        _trashPosition ??
        Offset(
          screenSize.width - (_cellW + 12),
          screenSize.height - 56 - (_cellH + 12),
        );

    return Positioned.fill(
      child: GestureDetector(
        onSecondaryTapDown: (d) =>
            _showDesktopMenu(context, d.globalPosition, screenSize),
        onTap: () {
          setState(() {
            _selectedDesktopItem = null;
            _renamingId = null; // Stop renaming when clicking empty space
          });
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
  // App shortcut icons
            ..._shortcuts.where((s) => !s.hidden).map((sc) {
              final pos = _iconPositions[sc.id];
              if (pos == null) return const SizedBox.shrink();
              final isOpen = _windows.any((w) => w.id == 'win_${sc.appId}');
              return _DraggableDesktopIcon(
                key: ValueKey(sc.id),
                position: pos,
                cellW: _cellW,
                cellH: _cellH,
                folderPositions: folderPositions,
                trashPos: trashPos,
                onDragEnd: (newPos) =>
                    setState(() => _iconPositions[sc.id] = _snapToGrid(newPos)),
                onDropToFolder: (folderName) {
                  final vfs = context.read<VirtualFileSystem>();
  // Create a .shortcut file inside the folder
                  vfs.touch(
                    '/C:/Users/Admin/Desktop/$folderName/${sc.label}.shortcut',
                    content: sc.appId,
                  );
                  setState(() {
                    sc.hidden = true;
                    _iconPositions.remove(sc.id);
                  });
                },
                onDropToTrash: () {
                  setState(() {
                    _trashItems.add(sc.label);
                    _trashShortcuts.add(sc);
                    _trashNodes.add(null);
                    sc.hidden = true;
                    _iconPositions.remove(sc.id);
                  });
                },
                child: _ShortcutIcon(
                  sc: sc,
                  size: _iconSize,
                  isOpen: isOpen,
                  isSelected: _selectedDesktopItem == sc.id,
                  onTap: () => setState(() => _selectedDesktopItem = sc.id),
                  onDoubleTap: () => _openApp(sc.appId, screenSize),
                  onRename: (newLabel) => setState(() => sc.label = newLabel),
                  onCopy: () {
                    final clipboard = context.read<ClipboardManager>();
                    final vfs = context.read<VirtualFileSystem>();
                    final tempPath = '/tmp/.shortcut_${sc.appId}';
                    vfs.touch(
                      tempPath,
                      content:
                          'shortcut:${sc.appId}:${sc.label}:${sc.icon.codePoint}:${sc.color.value}',
                    );
                    final tempNode = vfs.resolve(tempPath);
                    if (tempNode != null) {
                      clipboard.copy(tempPath, tempNode);
                    }
                  },
                  onCut: () {
                    final clipboard = context.read<ClipboardManager>();
                    final vfs = context.read<VirtualFileSystem>();
                    final tempPath = '/tmp/.shortcut_${sc.appId}';
                    vfs.touch(
                      tempPath,
                      content:
                          'shortcut:${sc.appId}:${sc.label}:${sc.icon.codePoint}:${sc.color.value}',
                    );
                    final tempNode = vfs.resolve(tempPath);
                    if (tempNode != null) {
                      clipboard.cut(tempPath, tempNode);
                      setState(() {
                        sc.hidden = true;
                        _iconPositions.remove(sc.id);
                      });
                    }
                  },
                  onDelete: () => setState(() {
                    _trashItems.add(sc.label);
                    _trashShortcuts.add(sc);
                    _trashNodes.add(null);
                    sc.hidden = true;
                    _iconPositions.remove(sc.id);
                  }),
                ),
              );
            }),
  // VFS desktop items
            ...desktopItems.map((node) {
              final id = 'vfs_${node.name}';
              final pos = _iconPositions[id];
              if (pos == null) return const SizedBox.shrink();
              return _DraggableDesktopIcon(
                key: ValueKey(id),
                position: pos,
                cellW: _cellW,
                cellH: _cellH,
                folderPositions: folderPositions,
                trashPos: trashPos,
                onDragEnd: (newPos) =>
                    setState(() => _iconPositions[id] = _snapToGrid(newPos)),
                onDropToFolder: (folderName) {
                  if (folderName == node.name) return; // can't drop into itself
                  vfs.rename('/C:/Users/Admin/Desktop/${node.name}', node.name);
  // Move node into the target folder
                  final targetPath =
                      '/C:/Users/Admin/Desktop/$folderName/${node.name}';
                  if (node is VfsDir)
                    vfs.mkdir(targetPath);
                  else
                    vfs.touch(targetPath, content: (node as VfsFile).content);
                  vfs.remove('/C:/Users/Admin/Desktop/${node.name}');
                  setState(() => _iconPositions.remove(id));
                },
                onDropToTrash: () {
                  setState(() {
                    _trashItems.add(node.name);
                    _trashNodes.add(node);
                    _trashShortcuts.add(null);
                    vfs.remove('/C:/Users/Admin/Desktop/${node.name}');
                    _iconPositions.remove(id);
                  });
                },
                child: _VfsDesktopIcon(
                  node: node,
                  iconSize: _iconSize,
                  isRenaming: _renamingId == node.name,
                  isSelected: _selectedDesktopItem == id,
                  onTap: () => setState(() => _selectedDesktopItem = id),
                  onDoubleTap: () {
                    if (node is VfsDir) {
                      _openAppWithPath(
                        'files',
                        screenSize,
                        '/C:/Users/Admin/Desktop/${node.name}',
                      );
                    } else {
  // Open file with editor
                      final filePath = '/C:/Users/Admin/Desktop/${node.name}';
                      final winId = 'win_editor_${node.name}';
                      _windows.removeWhere((w) => w.id == winId);
                      final sc = _scById('editor');
                      final w = AppWindow(
                        id: winId,
                        title: 'Editor Ãƒ¢ - š¬‚¬ ${node.name}',
                        icon: sc?.icon ?? Icons.code,
                        color: sc?.color ?? const Color(0xFF007ACC),
                        child: EditorScreen(
                          vfs: vfs,
                          initialFilePath: filePath,
                        ),
                        position: Offset(
                          40.0 + _windows.length * 24,
                          40.0 + _windows.length * 24,
                        ),
                        size: Size(
                          (screenSize.width * 0.72).clamp(520, 1200),
                          (screenSize.height * 0.78).clamp(400, 900),
                        ),
                      );
                      setState(() {
                        _windows.add(w);
                        _bringToFront(winId);
                      });
                    }
                  },
                  onRenameStart: () => setState(() => _renamingId = node.name),
                  onRenameEnd: (newName) {
                    if (newName.isNotEmpty && newName != node.name) {
                      vfs.rename(
                        '/C:/Users/Admin/Desktop/${node.name}',
                        newName,
                      );
                      final oldPos = _iconPositions.remove(id);
                      if (oldPos != null)
                        _iconPositions['vfs_$newName'] = oldPos;
                    }
                    setState(() => _renamingId = null);
                  },
                  onCopy: () {
                    final clipboard = context.read<ClipboardManager>();
                    clipboard.copy(
                      '/C:/Users/Admin/Desktop/${node.name}',
                      node,
                    );
                  },
                  onCut: () {
                    final clipboard = context.read<ClipboardManager>();
                    clipboard.cut('/C:/Users/Admin/Desktop/${node.name}', node);
                  },
                  onDelete: () {
                    setState(() {
                      _trashItems.add(node.name);
                      _trashNodes.add(node);
                      _trashShortcuts.add(null);
                      vfs.remove('/C:/Users/Admin/Desktop/${node.name}');
                      _iconPositions.remove(id);
                    });
                  },
                ),
              );
            }),
  // Recycle bin  draggable, default bottom-right
            _DraggableDesktopIcon(
              key: const ValueKey('recycle_bin'),
              position: trashPos,
              cellW: _cellW,
              cellH: _cellH,
              folderPositions: const {},
              trashPos: trashPos,
              onDragEnd: (newPos) =>
                  setState(() => _trashPosition = _snapToGrid(newPos)),
              onDropToFolder: (_) {},
              onDropToTrash: () {},
              child: _RecycleBin(
                items: _trashItems,
                iconSize: _iconSize,
                onEmpty: () => setState(() {
                  _trashItems.clear();
                  _trashNodes.clear();
                  _trashShortcuts.clear();
                }),
                onOpen: () => _showTrashBin(screenSize),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  Trash Bin dialog  
  void _showTrashBin(Size screenSize) {
    final winId = 'win_trash';
    final existing = _windows.indexWhere((w) => w.id == winId);
    if (existing != -1) {
      setState(() {
        _windows[existing].minimized = false;
        _bringToFront(winId);
      });
      return;
    }
  // Use a builder so the view rebuilds whenever _trashItems/_trashNodes change
    final w = AppWindow(
      id: winId,
      title: 'Recycle Bin',
      icon: Icons.delete_rounded,
      color: AppTheme.danger,
      child: StatefulBuilder(
        builder: (ctx, setInner) => _TrashBinView(
          items: _trashItems,
          nodes: _trashNodes,
          shortcuts: _trashShortcuts,
          onRestore: (index) {
            final vfs = context.read<VirtualFileSystem>();
            final node = _trashNodes[index];
            final shortcut = _trashShortcuts[index];

            if (node != null) {
  // Restore VFS node
              if (node is VfsDir)
                vfs.mkdir('/C:/Users/Admin/Desktop/${node.name}');
              else
                vfs.touch(
                  '/C:/Users/Admin/Desktop/${node.name}',
                  content: (node as VfsFile).content,
                );
            } else if (shortcut != null) {
  // Restore shortcut
              shortcut.hidden = false;
            }

            setState(() {
              _trashItems.removeAt(index);
              _trashNodes.removeAt(index);
              _trashShortcuts.removeAt(index);
            });
            setInner(() {});
          },
          onDeletePermanent: (index) {
            setState(() {
              _trashItems.removeAt(index);
              _trashNodes.removeAt(index);
              _trashShortcuts.removeAt(index);
            });
            setInner(() {});
          },
          onEmpty: () {
  // Show confirmation dialog
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1C1C1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: AppTheme.danger,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Empty Recycle Bin?',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                content: Text(
                  'This will permanently delete ${_trashItems.length} item${_trashItems.length == 1 ? '' : 's'}. This action cannot be undone.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _trashItems.clear();
                        _trashNodes.clear();
                        _trashShortcuts.clear();
                      });
                      setInner(() {});
                    },
                    child: Text(
                      'Empty',
                      style: TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      position: Offset(60 + _windows.length * 24, 60 + _windows.length * 24),
      size: Size(
        (screenSize.width * 0.55).clamp(480, 900),
        (screenSize.height * 0.65).clamp(360, 700),
      ),
    );
    setState(() {
      _windows.add(w);
      _bringToFront(winId);
    });
  }

  //  Window layer  
  List<Widget> _buildWindowLayer(Size screenSize) {
    final sorted = [..._windows]
      ..sort((a, b) => (_windowZ[a.id] ?? 0).compareTo(_windowZ[b.id] ?? 0));
    return sorted.where((w) => !w.minimized).map((w) {
      final pos = w.maximized ? Offset.zero : w.position;
      final size = w.maximized ? screenSize : w.size;
      return Positioned(
        left: pos.dx,
        top: pos.dy,
        width: size.width,
        height: size.height,
        child: Listener(
          onPointerDown: (_) => setState(() => _bringToFront(w.id)),
          child: _OsWindow(
            windowId: w.id,
            window: w,
            onClose: () => _closeWindow(w.id),
            onMinimize: () => _toggleMinimize(w.id),
            onMaximize: () => _toggleMaximize(w.id),
            onDrag: (d) {
              if (!w.maximized) _moveWindow(w.id, d);
            },
            onDragStart: () => _onWindowDragStart(w.id),
            onDragEnd: () => _onWindowDragEnd(w.id),
            onResize: (d) {
              if (!w.maximized) _resizeWindow(w.id, d);
            },
          ),
        ),
      );
    }).toList();
  }

  //  Mobile/Tablet layout  
  Widget _buildMobileLayout(DeviceType type) {
    final isTablet = type == DeviceType.tablet;
    final totalPages = _mobileHomeManager.pages.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: DesktopWallpaperLayer()),
        Column(
          children: [
            StatusBar(
              onNotifTap: _toggleNotifications,
              showNotif: _showNotifications,
              onCCTap: _toggleCC,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalPages,
                onPageChanged: (page) =>
                    setState(() => _currentMobilePage = page),
                physics: _isDraggingMobileItem
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemBuilder: (_, page) {
                  return _buildDynamicMobilePage(page, isTablet, totalPages);
                },
              ),
            ),
  // Page dots - fixed at bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildPageDots(_currentMobilePage, totalPages),
            ),
            _buildMobileDock(),
          ],
        ),
        Consumer<OsState>(
          builder: (_, os, __) {
            if (!os.displaySleep) return const SizedBox.shrink();
            return Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: os.wakeFromDisplaySleep,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.94),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bedtime_outlined,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Display sleep',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap anywhere to wake',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDynamicMobilePage(int pageIndex, bool isTablet, int totalPages) {
    return MobilePageBuilder.buildPage(
      context: context,
      pageIndex: pageIndex,
      isTablet: isTablet,
      totalPages: totalPages,
      time: _time,
      date: _date,
      manager: _mobileHomeManager,
      editMode: _mobileEditMode,
      onToggleEditMode: () =>
          setState(() => _mobileEditMode = !_mobileEditMode),
      onRemovePage: (index) {
        if (_mobileHomeManager.pages.length > 1) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              title: Text(
                'Delete Page?',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
              content: Text(
                'Remove page ${index + 1} and all its items?',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _mobileHomeManager.removePage(index);
                      if (_currentMobilePage >=
                          _mobileHomeManager.pages.length) {
                        _currentMobilePage =
                            _mobileHomeManager.pages.length - 1;
                      }
                    });
                  },
                  child: Text(
                    'Delete',
                    style: TextStyle(color: AppTheme.danger),
                  ),
                ),
              ],
            ),
          );
        }
      },
      onAddPage: () => setState(() => _mobileHomeManager.addPage()),
      onMoveItem: (fromPage, fromIndex, toPage, toIndex) {
        setState(() {
          _mobileHomeManager.moveItem(fromPage, fromIndex, toPage, toIndex);
          _isDraggingMobileItem = false;
          _draggingMobileItemIndex = null;
        });
      },
      onRemoveItem: (pageIndex, itemIndex) {
        setState(() {
          _mobileHomeManager.removeItem(pageIndex, itemIndex);
        });
      },
      buildDraggableItem: (item, index) =>
          _buildDraggableMobileItem(item, index, pageIndex),
    );
  }

  Widget _buildDraggableMobileItem(
    MobileHomeItem item,
    int index,
    int pageIndex,
  ) {
    return LongPressDraggable<Map<String, dynamic>>(
      data: {'item': item, 'index': index, 'pageIndex': pageIndex},
      feedback: Opacity(
        opacity: 0.85,
        child: Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: 1.2,
            child: Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.5),
                    blurRadius: 24,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, color: item.color, size: 28),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: item.color,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.15,
        child: _buildMobileItemContent(item, index),
      ),
      onDragStarted: () {
        setState(() {
          _draggingMobileItemIndex = index;
          _isDraggingMobileItem = true;
        });
      },
      onDragUpdate: (details) {
        if (!_mobileEditMode) return;

        final screenWidth = MediaQuery.of(context).size.width;
        final totalPages = _mobileHomeManager.pages.length;

        if (details.globalPosition.dx < 50 && _currentMobilePage > 0) {
          _pageSwipeTimer?.cancel();
          _pageSwipeTimer = Timer(const Duration(milliseconds: 500), () {
            if (_isDraggingMobileItem && _currentMobilePage > 0) {
              _pageController
                  .previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
                  .then((_) {
                    if (mounted) {
                      setState(() {
                        _currentMobilePage =
                            _pageController.page?.round() ?? _currentMobilePage;
                      });
                    }
                  });
            }
          });
        } else if (details.globalPosition.dx > screenWidth - 50 &&
            _currentMobilePage < totalPages - 1) {
          _pageSwipeTimer?.cancel();
          _pageSwipeTimer = Timer(const Duration(milliseconds: 500), () {
            if (_isDraggingMobileItem && _currentMobilePage < totalPages - 1) {
              _pageController
                  .nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
                  .then((_) {
                    if (mounted) {
                      setState(() {
                        _currentMobilePage =
                            _pageController.page?.round() ?? _currentMobilePage;
                      });
                    }
                  });
            }
          });
        } else {
          _pageSwipeTimer?.cancel();
        }
      },
      onDragEnd: (_) {
        _pageSwipeTimer?.cancel();
        setState(() {
          _draggingMobileItemIndex = null;
          _isDraggingMobileItem = false;
        });
      },
      onDraggableCanceled: (_, __) {
        _pageSwipeTimer?.cancel();
        setState(() {
          _draggingMobileItemIndex = null;
          _isDraggingMobileItem = false;
        });
      },
      child: DragTarget<Map<String, dynamic>>(
        onWillAcceptWithDetails: (details) {
          final data = details.data;
          return data['index'] != index || data['pageIndex'] != pageIndex;
        },
        onAcceptWithDetails: (details) {
          final data = details.data;
          final fromIndex = data['index'] as int;
          final fromPage = data['pageIndex'] as int;

          setState(() {
            _mobileHomeManager.moveItem(fromPage, fromIndex, pageIndex, index);
            _draggingMobileItemIndex = null;
            _isDraggingMobileItem = false;
          });
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  border: isHovering
                      ? Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.5),
                          width: 2,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _buildMobileItemContent(item, index),
              ),
              if (_mobileEditMode)
                Positioned(
                  top: -3,
                  right: -3,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _mobileHomeManager.removeItem(pageIndex, index);
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileItemContent(MobileHomeItem item, int index) {
    IconData icon;
    String label;
    Color color;
    VoidCallback? onTap;

    switch (item.type) {
      case MobileItemType.app:
  // item.appId contains the actual app ID (e.g., 'terminal')
        final sc = _shortcuts.where((s) => s.appId == item.appId).firstOrNull;
        if (sc == null) return const SizedBox.shrink();
        icon = sc.icon;
        label = sc.label;
        color = sc.color;
        onTap = () => Navigator.push(context, _route(_screenFor(sc.appId)));
        break;

      case MobileItemType.folder:
        final vfs = context.read<VirtualFileSystem>();
        final node = vfs.resolve(item.path);
        if (node == null || node is! VfsDir) return const SizedBox.shrink();
        icon = Icons.folder_rounded;
        label = item.label;
        color = AppTheme.warning;
        onTap = () => Navigator.push(
          context,
          _route(FileManagerScreen(initialPath: item.path)),
        );
        break;

      case MobileItemType.file:
        final vfs = context.read<VirtualFileSystem>();
        final node = vfs.resolve(item.path);
        if (node == null || node is! VfsFile) return const SizedBox.shrink();
        icon = Icons.insert_drive_file_rounded;
        label = item.label;
        color = AppTheme.textSecondary;
        onTap = () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              title: Text(
                label,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              ),
              content: Text(
                node.content,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: TextStyle(color: AppTheme.accent),
                  ),
                ),
              ],
            ),
          );
        };
        break;

      case MobileItemType.shortcut:
        final sc = _shortcuts.where((s) => s.id == item.id).firstOrNull;
        if (sc == null) return const SizedBox.shrink();
        icon = sc.icon;
        label = sc.label;
        color = sc.color;
        onTap = () => Navigator.push(context, _route(_screenFor(sc.appId)));
        break;
    }

    return _AppIcon(
          icon: icon,
          label: label,
          color: color,
          onTap: onTap ?? () {},
        )
        .animate(delay: Duration(milliseconds: index * 35))
        .fadeIn(duration: 200.ms)
        .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1));
  }

  Widget _buildPageDots(int current, int total) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      total,
      (i) => AnimatedContainer(
        duration: 200.ms,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: i == current ? 18 : 6,
        height: 6,
        decoration: BoxDecoration(
          color: i == current ? AppTheme.accent : AppTheme.border,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    ),
  );

  Widget _buildMobileDock() {
    final dockApps = [
      {
        'icon': Icons.terminal,
        'label': 'Terminal',
        'screen': const TerminalScreen(),
        'appId': 'terminal',
      },
      {
        'icon': Icons.folder_open,
        'label': 'Files',
        'screen': const FileManagerScreen(),
        'appId': 'files',
      },
      {
        'icon': Icons.devices_other,
        'label': 'Devices',
        'screen': const DeviceHubScreen(),
        'appId': 'devices',
      },
      {
        'icon': Icons.settings,
        'label': 'Settings',
        'screen': const SettingsScreen(),
        'appId': 'settings',
      },
      {
        'icon': Icons.apps,
        'label': 'Apps',
        'screen': AppDrawer(
          mobileHomeManager: _mobileHomeManager,
          currentPage: _currentMobilePage,
          onAppAdded: (msg) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                duration: const Duration(seconds: 2),
                backgroundColor: AppTheme.accent,
              ),
            );
            setState(() {});
          },
        ),
        'appId': 'allapps',
      },
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.85),
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: dockApps
            .map(
              (a) => _DockIconWithMenu(
                icon: a['icon'] as IconData,
                label: a['label'] as String,
                appId: a['appId'] as String,
                onTap: () =>
                    Navigator.push(context, _route(a['screen'] as Widget)),
                onAddToHome: () {
                  final sc = _shortcuts
                      .where((s) => s.appId == a['appId'])
                      .firstOrNull;
                  if (sc != null) {
                    final pageItems = _mobileHomeManager.getPage(
                      _currentMobilePage,
                    );
                    if (pageItems.any((item) => item.id == sc.id)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${sc.label} is already on this page'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.warning,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _mobileHomeManager.addItem(
                        _currentMobilePage,
                        MobileHomeItem(
                          type: MobileItemType.app,
                          id: sc.id,
                          label: sc.label,
                          icon: sc.icon,
                          color: sc.color,
                          appId: sc.appId,
                        ),
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${sc.label} added to page ${_currentMobilePage + 1}',
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppTheme.accent,
                      ),
                    );
                  }
                },
              ),
            )
            .toList(),
      ),
    );
  }

  PageRoute _route(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.02),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ),
    transitionDuration: 220.ms,
  );
}

//  _DockIconWithMenu  
class _DockIconWithMenu extends StatefulWidget {
  final IconData icon;
  final String label;
  final String appId;
  final VoidCallback onTap;
  final VoidCallback onAddToHome;
  const _DockIconWithMenu({
    required this.icon,
    required this.label,
    required this.appId,
    required this.onTap,
    required this.onAddToHome,
  });
  @override
  State<_DockIconWithMenu> createState() => _DockIconWithMenuState();
}

class _DockIconWithMenuState extends State<_DockIconWithMenu> {
  bool _pressed = false;

  void _showMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy - 100,
        position.dx + 1,
        position.dy + 1,
      ),
      color: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'open',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 14, color: AppTheme.accent),
              const SizedBox(width: 10),
              Text(
                'Open',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'add',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 14, color: AppTheme.accent),
              const SizedBox(width: 10),
              Text(
                'Add to Home Screen',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'open') widget.onTap();
      if (value == 'add') widget.onAddToHome();
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp: (_) {
      setState(() => _pressed = false);
      widget.onTap();
    },
    onTapCancel: () => setState(() => _pressed = false),
    onLongPressStart: (details) => _showMenu(context, details.globalPosition),
    child: AnimatedContainer(
      duration: 120.ms,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _pressed ? AppTheme.accentDim : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _pressed ? 0.88 : 1.0,
            duration: 120.ms,
            child: Icon(
              widget.icon,
              color: _pressed ? AppTheme.accent : AppTheme.textPrimary,
              size: 26,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.label,
            style: TextStyle(
              color: _pressed ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    ),
  );
}

//  End of state class  

//  _ShortcutIcon  
class _ShortcutIcon extends StatefulWidget {
  final _Shortcut sc;
  final double size;
  final bool isOpen;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(String) onRename;
  final VoidCallback onCopy;
  final VoidCallback onCut;
  final VoidCallback onDelete;
  const _ShortcutIcon({
    required this.sc,
    required this.size,
    required this.isOpen,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onRename,
    required this.onCopy,
    required this.onCut,
    required this.onDelete,
  });
  @override
  State<_ShortcutIcon> createState() => _ShortcutIconState();
}

class _ShortcutIconState extends State<_ShortcutIcon> {
  bool _hovered = false;
  bool _renaming = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.sc.label);
  }

  @override
  void didUpdateWidget(_ShortcutIcon old) {
    super.didUpdateWidget(old);
    if (old.sc.label != widget.sc.label && !_renaming) {
      _ctrl.text = widget.sc.label;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _showMenu(BuildContext ctx, Offset pos) {
    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      items: [
        _mi('open', Icons.open_in_new, 'Open'),
        const PopupMenuDivider(),
        _mi('rename', Icons.drive_file_rename_outline, 'Rename'),
        _mi('copy', Icons.copy_outlined, 'Copy'),
        _mi('cut', Icons.content_cut, 'Cut'),
        const PopupMenuDivider(),
        _mi('properties', Icons.settings_outlined, 'Properties'),
        const PopupMenuDivider(),
        _mi('trash', Icons.delete_outline, 'Move to Trash', danger: true),
      ],
    ).then((v) {
      if (v == 'open') widget.onTap();
      if (v == 'rename') {
        setState(() {
          _renaming = true;
          _ctrl.text = widget.sc.label;
        });
  // Select all text after the widget is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_ctrl.text.isNotEmpty) {
            _ctrl.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _ctrl.text.length,
            );
          }
        });
      }
      if (v == 'copy') widget.onCopy();
      if (v == 'cut') widget.onCut();
      if (v == 'trash') widget.onDelete();
      if (v == 'properties') _showPropertiesDialog(ctx);
    });
  }

  void _showPropertiesDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _ShortcutPropertiesDialog(
        shortcut: widget.sc,
        onSave: (appId, label, icon, color) {
          setState(() {
            widget.sc.appId = appId;
            widget.sc.label = label;
            widget.sc.icon = icon;
            widget.sc.color = color;
          });
          widget.onRename(label);
        },
      ),
    );
  }

  PopupMenuItem<String> _mi(
    String v,
    IconData icon,
    String label, {
    bool danger = false,
  }) => PopupMenuItem<String>(
    value: v,
    height: 34,
    child: Row(
      children: [
        Icon(
          icon,
          size: 13,
          color: danger ? AppTheme.danger : AppTheme.textSecondary,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: danger ? AppTheme.danger : AppTheme.textPrimary,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _renaming ? null : widget.onTap,
        onDoubleTap: _renaming ? null : widget.onDoubleTap,
        onSecondaryTapDown: (d) => _showMenu(context, d.globalPosition),
        child: SizedBox(
          width: s + 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  AnimatedContainer(
                    duration: 150.ms,
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? widget.sc.color.withValues(alpha: 0.25)
                          : _hovered
                          ? widget.sc.color.withValues(alpha: 0.18)
                          : AppTheme.surfaceAlt.withValues(alpha: 0.9),
                      border: Border.all(
                        color: widget.isSelected || _hovered
                            ? widget.sc.color
                            : AppTheme.border,
                      ),
                      borderRadius: BorderRadius.circular(s * 0.22),
                      boxShadow: _hovered
                          ? [
                              BoxShadow(
                                color: widget.sc.color.withValues(alpha: 0.25),
                                blurRadius: 14,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      widget.sc.icon,
                      color: widget.sc.color,
                      size: s * 0.46,
                    ),
                  ),
  // Arrow badge  shortcut indicator
                  Positioned(
                    left: 2,
                    bottom: 2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: AppTheme.border, width: 0.5),
                      ),
                      child: const Icon(
                        Icons.north_east,
                        size: 8,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _renaming
                  ? SizedBox(
                      width: s + 12,
                      child: Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus && _ctrl.text.isNotEmpty) {
  // Select all text when focused
                            Future.microtask(() {
                              _ctrl.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _ctrl.text.length,
                              );
                            });
                          }
                        },
                        child: TextField(
                          key: ValueKey('rename_shortcut_${widget.sc.id}'),
                          controller: _ctrl,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 10,
                          ),
                          cursorColor: AppTheme.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            filled: true,
                            fillColor: AppTheme.accentDim,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: AppTheme.accent),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: AppTheme.accent),
                            ),
                          ),
                          onSubmitted: (v) {
                            if (v.trim().isNotEmpty) widget.onRename(v.trim());
                            setState(() => _renaming = false);
                          },
                          onTapOutside: (_) {
                            if (_ctrl.text.trim().isNotEmpty)
                              widget.onRename(_ctrl.text.trim());
                            setState(() => _renaming = false);
                          },
                        ),
                      ),
                    )
                  : Text(
                      widget.sc.label,
                      style: TextStyle(
                        color: _hovered
                            ? widget.sc.color
                            : AppTheme.textPrimary,
                        fontSize: 10,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: 200.ms,
                width: widget.isOpen ? 5 : 0,
                height: widget.isOpen ? 5 : 0,
                decoration: BoxDecoration(
                  color: widget.sc.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//  _AppIcon  
class _AppIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isOpen;
  final double size;
  const _AppIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isOpen = false,
    this.size = 56,
  });
  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: 150.ms,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.15)
                  : AppTheme.surfaceAlt,
              border: Border.all(
                color: _hovered ? widget.color : AppTheme.border,
              ),
              borderRadius: BorderRadius.circular(widget.size * 0.25),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.2),
                        blurRadius: 12,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              widget.icon,
              color: widget.color,
              size: widget.size * 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? widget.color : AppTheme.textSecondary,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: 200.ms,
            width: widget.isOpen ? 4 : 0,
            height: widget.isOpen ? 4 : 0,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    ),
  );
}

//  _MiniChip  
class _MiniChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.surfaceAlt,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

//  _DockIcon  
class _DockIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DockIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  State<_DockIcon> createState() => _DockIconState();
}

class _DockIconState extends State<_DockIcon> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp: (_) {
      setState(() => _pressed = false);
      widget.onTap();
    },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: 120.ms,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _pressed ? AppTheme.accentDim : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _pressed ? 0.88 : 1.0,
            duration: 120.ms,
            child: Icon(
              widget.icon,
              color: _pressed ? AppTheme.accent : AppTheme.textPrimary,
              size: 26,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.label,
            style: TextStyle(
              color: _pressed ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 9,
            ),
          ),
        ],
      ),
    ),
  );
}

//  _ScanlinePainter  
class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

//  _OsWindow  
class _OsWindow extends StatelessWidget {
  final String windowId;
  final AppWindow window;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final void Function(Offset) onDrag;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final void Function(Offset) onResize;

  const _OsWindow({
    required this.windowId,
    required this.window,
    required this.onClose,
    required this.onMinimize,
    required this.onMaximize,
    required this.onDrag,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  children: [
  // Title bar
                    GestureDetector(
                      onPanStart: (_) => onDragStart(),
                      onPanUpdate: (d) => onDrag(d.delta),
                      onPanEnd: (_) => onDragEnd(),
                      onDoubleTap: onMaximize,
                      child: Container(
                        height: 38,
                        color: AppTheme.surfaceAlt,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(window.icon, color: window.color, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                window.title,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _WinBtn(
                              color: const Color(0xFFFFBD2E),
                              icon: Icons.remove,
                              onTap: onMinimize,
                            ),
                            const SizedBox(width: 6),
                            _WinBtn(
                              color: const Color(0xFF28CA41),
                              icon: Icons.crop_square,
                              onTap: onMaximize,
                            ),
                            const SizedBox(width: 6),
                            _WinBtn(
                              color: const Color(0xFFFF5F57),
                              icon: Icons.close,
                              onTap: onClose,
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.border),
                    Expanded(child: window.child),
                  ],
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 150.ms)
            .scale(
              begin: const Offset(0.96, 0.96),
              end: const Offset(1, 1),
              duration: 150.ms,
              curve: Curves.easeOut,
            ),
  // Resize handle  bottom-right
        if (!window.maximized)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onPanUpdate: (d) => onResize(d.delta),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.south_east,
                    size: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

//  _WinBtn  
class _WinBtn extends StatefulWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _WinBtn({required this.color, required this.icon, required this.onTap});
  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: 100.ms,
        width: 13,
        height: 13,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        child: _hovered
            ? Icon(
                widget.icon,
                size: 9,
                color: Colors.black.withValues(alpha: 0.7),
              )
            : null,
      ),
    ),
  );
}

//  Recycle Bin  
class _RecycleBin extends StatefulWidget {
  final List<String> items;
  final double iconSize;
  final VoidCallback onEmpty;
  final VoidCallback onOpen;
  const _RecycleBin({
    required this.items,
    required this.iconSize,
    required this.onEmpty,
    required this.onOpen,
  });
  @override
  State<_RecycleBin> createState() => _RecycleBinState();
}

class _RecycleBinState extends State<_RecycleBin> {
  bool _hovered = false;

  void _showMenu(BuildContext ctx, Offset pos) {
    showMenu<void>(
      context: ctx,
      position: RelativeRect.fromLTRB(
        pos.dx - 160,
        pos.dy - 80,
        pos.dx,
        pos.dy,
      ),
      color: AppTheme.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border),
      ),
      items: [
        PopupMenuItem<void>(
          height: 34,
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.accent, size: 13),
              const SizedBox(width: 8),
              Text(
                '${widget.items.length} item${widget.items.length == 1 ? '' : 's'}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        PopupMenuItem<void>(
          onTap: widget.onOpen,
          height: 34,
          child: Row(
            children: [
              Icon(Icons.folder_open, color: AppTheme.accent, size: 13),
              const SizedBox(width: 8),
              Text(
                'Open Recycle Bin',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              ),
            ],
          ),
        ),
        if (widget.items.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem<void>(
            onTap: widget.onEmpty,
            height: 34,
            child: Row(
              children: [
                Icon(
                  Icons.delete_forever_rounded,
                  color: AppTheme.danger,
                  size: 13,
                ),
                SizedBox(width: 8),
                Text(
                  'Empty Recycle Bin',
                  style: TextStyle(color: AppTheme.danger, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = widget.items.isNotEmpty;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        onSecondaryTapDown: (d) => _showMenu(context, d.globalPosition),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: 150.ms,
              width: widget.iconSize,
              height: widget.iconSize,
              decoration: BoxDecoration(
                color: _hovered
                    ? AppTheme.danger.withValues(alpha: 0.12)
                    : AppTheme.surfaceAlt,
                border: Border.all(
                  color: _hovered ? AppTheme.danger : AppTheme.border,
                ),
                borderRadius: BorderRadius.circular(widget.iconSize * 0.25),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: AppTheme.danger.withValues(alpha: 0.15),
                          blurRadius: 12,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                hasItems ? Icons.delete_rounded : Icons.delete_outline_rounded,
                color: hasItems ? AppTheme.danger : AppTheme.textSecondary,
                size: widget.iconSize * 0.46,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Recycle Bin',
              style: TextStyle(
                color: _hovered ? AppTheme.danger : AppTheme.textSecondary,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: 200.ms,
              width: hasItems ? 5 : 0,
              height: hasItems ? 5 : 0,
              decoration: BoxDecoration(
                color: AppTheme.danger,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//  Draggable desktop icon wrapper  
class _DraggableDesktopIcon extends StatefulWidget {
  final Offset position;
  final double cellW, cellH;
  final Map<String, Offset> folderPositions;
  final Offset trashPos;
  final void Function(Offset) onDragEnd;
  final void Function(String folderName) onDropToFolder;
  final VoidCallback onDropToTrash;
  final Widget child;
  const _DraggableDesktopIcon({
    super.key,
    required this.position,
    required this.cellW,
    required this.cellH,
    required this.folderPositions,
    required this.trashPos,
    required this.onDragEnd,
    required this.onDropToFolder,
    required this.onDropToTrash,
    required this.child,
  });
  @override
  State<_DraggableDesktopIcon> createState() => _DraggableDesktopIconState();
}

class _DraggableDesktopIconState extends State<_DraggableDesktopIcon> {
  late Offset _pos;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _pos = widget.position;
  }

  @override
  void didUpdateWidget(_DraggableDesktopIcon old) {
    super.didUpdateWidget(old);
    if (!_dragging && old.position != widget.position) _pos = widget.position;
  }

  bool _isNear(Offset a, Offset b) =>
      (a.dx - b.dx).abs() < widget.cellW && (a.dy - b.dy).abs() < widget.cellH;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (d) => setState(() => _pos += d.delta),
        onPanEnd: (_) {
          setState(() => _dragging = false);
  // Check trash drop
          if (_isNear(_pos, widget.trashPos)) {
            widget.onDropToTrash();
            return;
          }
  // Check folder drop
          for (final entry in widget.folderPositions.entries) {
            if (_isNear(_pos, entry.value)) {
              widget.onDropToFolder(entry.key);
              return;
            }
          }
          widget.onDragEnd(_pos);
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _dragging ? 0.7 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}

//  VFS desktop icon (folder / file)  
class _VfsDesktopIcon extends StatefulWidget {
  final VfsNode node;
  final double iconSize;
  final bool isRenaming;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onRenameStart;
  final void Function(String) onRenameEnd;
  final VoidCallback onCopy;
  final VoidCallback onCut;
  final VoidCallback onDelete;
  const _VfsDesktopIcon({
    required this.node,
    required this.iconSize,
    required this.isRenaming,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onRenameStart,
    required this.onRenameEnd,
    required this.onCopy,
    required this.onCut,
    required this.onDelete,
  });
  @override
  State<_VfsDesktopIcon> createState() => _VfsDesktopIconState();
}

class _VfsDesktopIconState extends State<_VfsDesktopIcon> {
  bool _hovered = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.node.name);
  }

  @override
  void didUpdateWidget(_VfsDesktopIcon old) {
    super.didUpdateWidget(old);
    if (old.node.name != widget.node.name && !widget.isRenaming) {
      _ctrl.text = widget.node.name;
    }
    if (!old.isRenaming && widget.isRenaming) {
      _ctrl.text = widget.node.name;
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctrl.text.length,
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isDir => widget.node is VfsDir;

  void _showContextMenu(BuildContext ctx, Offset pos) {
    final node = widget.node;
    final isFile = node is VfsFile;
    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      items: [
        _cmItem('open', Icons.open_in_new, _isDir ? 'Open' : 'Open File'),
        if (!_isDir) _cmItem('editor', Icons.code, 'Open with Editor'),
        if (_isDir)
          _cmItem('editor_folder', Icons.code, 'Open Folder in Editor'),
        const PopupMenuDivider(),
        _cmItem('rename', Icons.drive_file_rename_outline, 'Rename'),
        _cmItem('copy', Icons.copy_outlined, 'Copy'),
        _cmItem('cut', Icons.content_cut, 'Cut'),
        _cmItem('dup', Icons.file_copy_outlined, 'Duplicate'),
        const PopupMenuDivider(),
        _cmItem('info', Icons.info_outline, 'Get Info'),
        const PopupMenuDivider(),
        _cmItem('trash', Icons.delete_outline, 'Move to Trash', danger: true),
      ],
    ).then((v) {
      if (v == 'open') {
        if (_isDir) {
          widget.onDoubleTap();
        } else {
  // Open file with editor - use context menu action
          final homeState = ctx.findAncestorStateOfType<_HomeScreenState>();
          if (homeState != null) {
            final screenSize = MediaQuery.of(ctx).size;
            final filePath = '/C:/Users/Admin/Desktop/${widget.node.name}';
            final winId = 'win_editor_${widget.node.name}';
            homeState._windows.removeWhere((w) => w.id == winId);
            final sc = homeState._scById('editor');
            final w = AppWindow(
              id: winId,
              title: 'Editor Ãƒ¢ - š¬‚¬ ${widget.node.name}',
              icon: sc?.icon ?? Icons.code,
              color: sc?.color ?? const Color(0xFF007ACC),
              child: EditorScreen(
                vfs: homeState.context.read<VirtualFileSystem>(),
                initialFilePath: filePath,
              ),
              position: Offset(
                40.0 + homeState._windows.length * 24,
                40.0 + homeState._windows.length * 24,
              ),
              size: Size(
                (screenSize.width * 0.72).clamp(520, 1200),
                (screenSize.height * 0.78).clamp(400, 900),
              ),
            );
            homeState.setState(() {
              homeState._windows.add(w);
              homeState._bringToFront(winId);
            });
          }
        }
      }
      if (v == 'editor_folder') {
  // Open folder with editor
        final homeState = ctx.findAncestorStateOfType<_HomeScreenState>();
        if (homeState != null) {
          final screenSize = MediaQuery.of(ctx).size;
          final folderPath = '/C:/Users/Admin/Desktop/${widget.node.name}';
          final winId = 'win_editor_folder_${widget.node.name}';
          homeState._windows.removeWhere((w) => w.id == winId);
          final sc = homeState._scById('editor');
          final w = AppWindow(
            id: winId,
            title: 'Editor Ãƒ¢ - š¬‚¬ ${widget.node.name}',
            icon: sc?.icon ?? Icons.code,
            color: sc?.color ?? const Color(0xFF007ACC),
            child: ProfessionalEditorScreen(
              vfs: homeState.context.read<VirtualFileSystem>(),
              rootFolder: folderPath,
            ),
            position: Offset(
              40.0 + homeState._windows.length * 24,
              40.0 + homeState._windows.length * 24,
            ),
            size: Size(
              (screenSize.width * 0.72).clamp(520, 1200),
              (screenSize.height * 0.78).clamp(400, 900),
            ),
          );
          homeState.setState(() {
            homeState._windows.add(w);
            homeState._bringToFront(winId);
          });
        }
      }

      if (v == 'rename') {
        widget.onRenameStart();
  // Select all text after the widget is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_ctrl.text.isNotEmpty) {
            _ctrl.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _ctrl.text.length,
            );
          }
        });
      }
      if (v == 'copy') widget.onCopy();
      if (v == 'cut') widget.onCut();
      if (v == 'trash') widget.onDelete();
      if (v == 'dup') {
        final vfsCtx = ctx;
        if (vfsCtx.mounted) {
          final vfs = vfsCtx.read<VirtualFileSystem>();
          final copyName = '${widget.node.name} copy';
          if (widget.node is VfsDir)
            vfs.mkdir('/C:/Users/Admin/Desktop/$copyName');
          else
            vfs.touch(
              '/C:/Users/Admin/Desktop/$copyName',
              content: (widget.node as VfsFile).content,
            );
        }
      }
      if (v == 'info') _showProperties(ctx);
    });
  }

  void _showProperties(BuildContext ctx) {
    final node = widget.node;
    final isFile = node is VfsFile;
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isDir
                          ? Icons.folder_rounded
                          : Icons.insert_drive_file_rounded,
                      color: _isDir ? AppTheme.warning : AppTheme.textSecondary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        node.name,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 12),
                _propRow('Kind', _isDir ? 'Folder' : 'File'),
                _propRow(
                  'Size',
                  isFile ? '${(node as VfsFile).size} bytes' : '--',
                ),
                _propRow('Location', '/C:/Users/Admin/Desktop'),
                _propRow('Permissions', node.permissions),
                _propRow('Owner', node.owner),
                _propRow(
                  'Modified',
                  '${node.modified.day}/${node.modified.month}/${node.modified.year}',
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK', style: TextStyle(color: AppTheme.accent)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _propRow(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            k,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
          ),
        ),
      ],
    ),
  );

  PopupMenuItem<String> _cmItem(
    String v,
    IconData icon,
    String label, {
    bool danger = false,
  }) => PopupMenuItem<String>(
    value: v,
    height: 34,
    child: Row(
      children: [
        Icon(
          icon,
          size: 13,
          color: danger ? AppTheme.danger : AppTheme.textSecondary,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: danger ? AppTheme.danger : AppTheme.textPrimary,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final color = _isDir ? AppTheme.warning : AppTheme.textSecondary;
    final icon = _isDir ? Icons.folder_rounded : _fileIcon(widget.node.name);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.isRenaming
            ? null
            : () {
                widget.onDoubleTap();
              },
        onLongPress: widget.isRenaming ? null : widget.onRenameStart,
        onSecondaryTapDown: (d) => _showContextMenu(context, d.globalPosition),
        child: SizedBox(
          width: widget.iconSize + 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: 150.ms,
                width: widget.iconSize,
                height: widget.iconSize,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? color.withValues(alpha: 0.25)
                      : _hovered
                      ? color.withValues(alpha: 0.15)
                      : AppTheme.surfaceAlt,
                  border: Border.all(
                    color: widget.isSelected || _hovered
                        ? color
                        : AppTheme.border,
                  ),
                  borderRadius: BorderRadius.circular(widget.iconSize * 0.25),
                  boxShadow: _hovered
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ]
                      : [],
                ),
                child: Icon(icon, color: color, size: widget.iconSize * 0.5),
              ),
              const SizedBox(height: 4),
              widget.isRenaming
                  ? SizedBox(
                      width: 70,
                      child: Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus && _ctrl.text.isNotEmpty) {
  // Select all text when focused
                            Future.microtask(() {
                              _ctrl.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _ctrl.text.length,
                              );
                            });
                          }
                        },
                        child: TextField(
                          key: ValueKey('rename_vfs_${widget.node.name}'),
                          controller: _ctrl,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 10,
                          ),
                          cursorColor: AppTheme.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            filled: true,
                            fillColor: AppTheme.accentDim,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: AppTheme.accent),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: AppTheme.accent),
                            ),
                          ),
                          onSubmitted: widget.onRenameEnd,
                          onTapOutside: (_) => widget.onRenameEnd(_ctrl.text),
                        ),
                      ),
                    )
                  : Text(
                      widget.node.name,
                      style: TextStyle(
                        color: _hovered ? color : AppTheme.textPrimary,
                        fontSize: 10,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'txt':
      case 'md':
        return Icons.article_rounded;
      case 'sh':
        return Icons.terminal;
      case 'conf':
      case 'cfg':
      case 'ini':
        return Icons.settings;
      case 'log':
        return Icons.list_alt_rounded;
      case 'key':
      case 'pem':
        return Icons.vpn_key_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

//  _TrashBinView  
class _TrashBinView extends StatefulWidget {
  final List<String> items;
  final List<VfsNode?> nodes;
  final List<_Shortcut?> shortcuts;
  final void Function(int) onRestore;
  final void Function(int) onDeletePermanent;
  final VoidCallback onEmpty;
  const _TrashBinView({
    required this.items,
    required this.nodes,
    required this.shortcuts,
    required this.onRestore,
    required this.onDeletePermanent,
    required this.onEmpty,
  });
  @override
  State<_TrashBinView> createState() => _TrashBinViewState();
}

class _TrashBinViewState extends State<_TrashBinView> {
  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final nodes = widget.nodes;
    final shortcuts = widget.shortcuts;
    return Column(
      children: [
        Container(
          color: AppTheme.surfaceAlt,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.delete_rounded,
                color: AppTheme.danger,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length} item${items.length == 1 ? '' : 's'}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const Spacer(),
              if (items.isNotEmpty)
                GestureDetector(
                  onTap: widget.onEmpty,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.12),
                      border: Border.all(color: AppTheme.danger),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Empty Recycle Bin',
                      style: TextStyle(color: AppTheme.danger, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Recycle Bin is empty',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final node = i < nodes.length ? nodes[i] : null;
                    final shortcut = i < shortcuts.length ? shortcuts[i] : null;
                    final isDir = node is VfsDir;
                    final isShortcut = shortcut != null;

                    IconData itemIcon;
                    Color itemColor;

                    if (isShortcut) {
                      itemIcon = shortcut.icon;
                      itemColor = shortcut.color;
                    } else if (isDir) {
                      itemIcon = Icons.folder_rounded;
                      itemColor = AppTheme.warning;
                    } else {
                      itemIcon = Icons.insert_drive_file_rounded;
                      itemColor = AppTheme.textSecondary;
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt,
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(itemIcon, color: itemColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  items[i],
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                                if (isShortcut)
                                  Text(
                                    'Shortcut',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              widget.onRestore(i);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentDim,
                                border: Border.all(color: AppTheme.accent),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Restore',
                                style: TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              widget.onDeletePermanent(i);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.danger.withValues(alpha: 0.1),
                                border: Border.all(color: AppTheme.danger),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Delete',
                                style: TextStyle(
                                  color: AppTheme.danger,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

//  Shortcut Properties Dialog  
class _ShortcutPropertiesDialog extends StatefulWidget {
  final _Shortcut shortcut;
  final void Function(String appId, String label, IconData icon, Color color)
  onSave;
  const _ShortcutPropertiesDialog({
    required this.shortcut,
    required this.onSave,
  });
  @override
  State<_ShortcutPropertiesDialog> createState() =>
      _ShortcutPropertiesDialogState();
}

class _ShortcutPropertiesDialogState extends State<_ShortcutPropertiesDialog> {
  late TextEditingController _labelCtrl;
  late String _selectedAppId;
  late IconData _selectedIcon;
  late Color _selectedColor;
  String _targetType = 'app'; // 'app' or 'file'
  String _filePath = '';

  List<Map<String, dynamic>> get _availableApps =>
      ShellAppRegistry.forShortcutPicker()
          .map(
            (d) => {
              'id': d.id,
              'label': d.title,
              'icon': d.icon,
            },
          )
          .toList();

  final List<IconData> _availableIcons = [
    Icons.terminal,
    Icons.folder_open,
    Icons.devices_other,
    Icons.settings,
    Icons.manage_accounts,
    Icons.security,
    Icons.wifi,
    Icons.monitor_heart,
    Icons.apps,
    Icons.code,
    Icons.storage,
    Icons.cloud,
    Icons.dashboard,
    Icons.extension,
    Icons.build,
    Icons.bug_report,
    Icons.language,
    Icons.lock,
    Icons.vpn_key,
    Icons.shield,
    Icons.admin_panel_settings,
  ];

  final List<Color> _availableColors = [
    AppTheme.accent,
    AppTheme.warning,
    AppTheme.danger,
    const Color(0xFF58A6FF),
    const Color(0xFFFF6B6B),
    const Color(0xFF4ECDC4),
    const Color(0xFFFFA07A),
    const Color(0xFF9B59B6),
    const Color(0xFF3498DB),
    const Color(0xFFE74C3C),
    const Color(0xFF2ECC71),
    const Color(0xFFF39C12),
    const Color(0xFF1ABC9C),
    const Color(0xFFE67E22),
    const Color(0xFF95A5A6),
  ];

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.shortcut.label);
    _selectedAppId = widget.shortcut.appId;
    _selectedIcon = widget.shortcut.icon;
    _selectedColor = widget.shortcut.color;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_selectedIcon, color: _selectedColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Shortcut Properties',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 16),

  // Label
              Text(
                'Label',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _labelCtrl,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                cursorColor: AppTheme.accent,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: AppTheme.accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),

  // Icon Selection
              Text(
                'Icon',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Container(
                height: 80,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: _availableIcons.length,
                  itemBuilder: (ctx, i) {
                    final icon = _availableIcons[i];
                    final isSelected = _selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = icon),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accentDim
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.accent
                                : AppTheme.border.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected
                              ? AppTheme.accent
                              : AppTheme.textSecondary,
                          size: 18,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

  // Color Selection
              Text(
                'Color',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableColors.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

  // Target Type
              Text(
                'Opens',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _RadioOption(
                    label: 'Application',
                    selected: _targetType == 'app',
                    onTap: () => setState(() => _targetType = 'app'),
                  ),
                  const SizedBox(width: 12),
                  _RadioOption(
                    label: 'File Location',
                    selected: _targetType == 'file',
                    onTap: () => setState(() => _targetType = 'file'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

  // App Selection or File Path
              if (_targetType == 'app')
                Text(
                  'Select Application',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              if (_targetType == 'app') const SizedBox(height: 8),
              if (_targetType == 'app')
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListView.builder(
                    itemCount: _availableApps.length,
                    itemBuilder: (ctx, i) {
                      final app = _availableApps[i];
                      final isSelected = _selectedAppId == app['id'];
                      return GestureDetector(
                        onTap: () => setState(
                          () => _selectedAppId = app['id'] as String,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accentDim
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: AppTheme.border.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                app['icon'] as IconData,
                                color: isSelected
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                app['label'] as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.accent
                                      : AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.accent,
                                  size: 16,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (_targetType == 'file')
                Text(
                  'File Path',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              if (_targetType == 'file') const SizedBox(height: 6),
              if (_targetType == 'file')
                TextField(
                  onChanged: (v) => _filePath = v,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  cursorColor: AppTheme.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceAlt,
                    hintText: '/path/to/executable',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: AppTheme.accent),
                    ),
                  ),
                ),
              if (_targetType == 'file') const SizedBox(height: 8),
              if (_targetType == 'file')
                Text(
                  'Note: File execution is not yet implemented',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onSave(
                        _selectedAppId,
                        _labelCtrl.text.trim(),
                        _selectedIcon,
                        _selectedColor,
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop right-click shell menu: hover on **View** opens icon-size submenu (no extra click).
class _DesktopContextMenuOverlay extends StatefulWidget {
  final Offset position;
  final double menuWidth;
  final bool hasPaste;
  final double iconSize;
  final VoidCallback onNewFolder;
  final VoidCallback onNewFile;
  final VoidCallback? onPaste;
  final VoidCallback onRefresh;
  final VoidCallback onWallpaper;
  final VoidCallback onTerminal;
  final VoidCallback onFiles;
  final ValueChanged<double> onIconSize;

  const _DesktopContextMenuOverlay({
    required this.position,
    required this.menuWidth,
    required this.hasPaste,
    required this.iconSize,
    required this.onNewFolder,
    required this.onNewFile,
    this.onPaste,
    required this.onRefresh,
    required this.onWallpaper,
    required this.onTerminal,
    required this.onFiles,
    required this.onIconSize,
  });

  @override
  State<_DesktopContextMenuOverlay> createState() =>
      _DesktopContextMenuOverlayState();
}

class _DesktopContextMenuOverlayState
    extends State<_DesktopContextMenuOverlay> {
  bool _viewSubVisible = false;
  Timer? _hideTimer;

  static const double _rowH = 36;
  static const double _divSlot = 17;
  static const double _panelPadTop = 6;
  static const double _subW = 152;
  static const double _subGap = 4;
  static const double _edgePad = 10;

  bool _isHoveringViewRow = false;
  bool _isHoveringSubmenu = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  double _viewRowTopInsideColumn() {
    var y = 2 * _rowH + _divSlot;
    if (widget.hasPaste && widget.onPaste != null) y += _rowH;
    return y;
  }

  BoxDecoration _deco() => BoxDecoration(
    color: AppTheme.surfaceAlt,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppTheme.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Widget _divider() => SizedBox(
    height: _divSlot,
    child: Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          height: 1,
          color: AppTheme.border.withValues(alpha: 0.45),
        ),
      ),
    ),
  );

  Widget _row(IconData icon, String label, VoidCallback onTap) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      hoverColor: Colors.white.withValues(alpha: 0.06),
      child: SizedBox(
        height: _rowH,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.accent, size: 14),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _viewRow(bool subOpensToRight) {
    final chevron = Icon(
      subOpensToRight ? Icons.chevron_right : Icons.chevron_left,
      color: AppTheme.textSecondary.withValues(alpha: 0.9),
      size: 14,
    );
    return MouseRegion(
      onEnter: (_) {
        _hideTimer?.cancel();
        setState(() {
          _isHoveringViewRow = true;
          _viewSubVisible = true;
        });
      },
      onExit: (_) {
        setState(() => _isHoveringViewRow = false);
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted && !_isHoveringViewRow && !_isHoveringSubmenu) {
            setState(() => _viewSubVisible = false);
          }
        });
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _viewSubVisible = !_viewSubVisible);
          },
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: SizedBox(
            height: _rowH,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.view_module_outlined,
                    color: AppTheme.accent,
                    size: 14,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'View',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  chevron,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sizeChoice(String label, double size) {
    final sel = (widget.iconSize - size).abs() < 0.51;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onIconSize(size);
  // Don't hide immediately, let the normal exit handler do it
        },
        hoverColor: AppTheme.accent.withValues(alpha: 0.1),
        child: Container(
          height: _rowH,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Icons.check,
                color: sel ? AppTheme.accent : Colors.transparent,
                size: 14,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: sel ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _submenu(BoxDecoration deco) => MouseRegion(
    onEnter: (_) {
      _hideTimer?.cancel();
      setState(() => _isHoveringSubmenu = true);
    },
    onExit: (_) {
      setState(() => _isHoveringSubmenu = false);
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted && !_isHoveringViewRow && !_isHoveringSubmenu) {
          setState(() => _viewSubVisible = false);
        }
      });
    },
    child: Material(
      elevation: 8,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: _subW,
        decoration: deco,
        padding: const EdgeInsets.symmetric(vertical: _panelPadTop),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sizeChoice('Large icons', 72),
            _sizeChoice('Medium icons', 56),
            _sizeChoice('Small icons', 40),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    final deco = _deco();

    final estH =
        _panelPadTop +
        (_rowH * 2 +
            _divSlot +
            (widget.hasPaste && widget.onPaste != null ? _rowH : 0) +
            _rowH +
            _divSlot +
            _rowH * 2 +
            _divSlot +
            _rowH * 2) +
        _panelPadTop +
        8;

    final fullSpread = widget.menuWidth + _subGap + _subW;
    final top = widget.position.dy
        .clamp(_edgePad, math.max(_edgePad, mq.height - estH - _edgePad))
        .toDouble();
    final maxLeft = math.max(_edgePad, mq.width - _edgePad - fullSpread);
    final left = widget.position.dx.clamp(_edgePad, maxLeft).toDouble();

    final spaceRight =
        mq.width - _edgePad - (left + widget.menuWidth + _subGap + _subW);
    final spaceLeft = left - _edgePad - (_subGap + _subW);
    final subOpensToRight = spaceRight >= spaceLeft || spaceLeft < 0;

    return Positioned(
      left: left,
      top: top,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topLeft,
        children: [
          Container(
            width: widget.menuWidth,
            decoration: deco,
            padding: const EdgeInsets.symmetric(vertical: _panelPadTop),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _row(
                  Icons.create_new_folder_outlined,
                  'New Folder',
                  widget.onNewFolder,
                ),
                _row(Icons.note_add_outlined, 'New File', widget.onNewFile),
                _divider(),
                if (widget.hasPaste && widget.onPaste != null)
                  _row(Icons.content_paste_outlined, 'Paste', widget.onPaste!),
                _viewRow(subOpensToRight),
                _divider(),
                _row(Icons.refresh, 'Refresh', widget.onRefresh),
                _row(Icons.wallpaper, 'Change Wallpaper', widget.onWallpaper),
                _divider(),
                _row(Icons.terminal, 'Open Terminal', widget.onTerminal),
                _row(Icons.folder_open, 'Open Files', widget.onFiles),
              ],
            ),
          ),
          if (_viewSubVisible)
            Positioned(
              left: subOpensToRight
                  ? widget.menuWidth + _subGap
                  : -(_subGap + _subW),
              top: _panelPadTop + _viewRowTopInsideColumn(),
              child: _submenu(deco),
            ),
  // Invisible bridge to prevent hover break between menu and submenu
          if (_viewSubVisible)
            Positioned(
              left: subOpensToRight ? widget.menuWidth : -_subGap,
              top: _panelPadTop + _viewRowTopInsideColumn(),
              child: MouseRegion(
                onEnter: (_) {
                  _hideTimer?.cancel();
                  setState(() {
                    _isHoveringViewRow = true;
                  });
                },
                onExit: (_) {
  // Don't do anything, let the actual menu items handle it
                },
                child: Container(
                  width: _subGap,
                  height: _rowH * 3,
                  color: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

//  Radio Option Widget  
class _RadioOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppTheme.accent : AppTheme.border,
                width: 2,
              ),
              color: selected ? AppTheme.accent : Colors.transparent,
            ),
            child: selected
                ? const Center(
                    child: Icon(Icons.circle, size: 8, color: Colors.black),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.accent : AppTheme.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}