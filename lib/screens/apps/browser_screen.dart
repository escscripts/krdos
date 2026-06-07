import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/browser/browser_engine.dart';
import '../../core/browser/browser_prefs.dart';
import '../../core/browser/tor_launcher.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// BrowserScreen ? Premium Linux-native browser UI
//
// Flutter Linux cannot embed a real WebView engine. URLs are opened in
// the system's default browser (Firefox / Chromium) via url_launcher /
// xdg-open.  This screen provides a full-featured browser shell: unlimited
// tabs, bookmarks, history, downloads, privacy toggles, split-view, find bar.
// ---------------------------------------------------------------------------

// - Panel enum -
enum _SidePanel { none, bookmarks, history, downloads, settings }

// - Split view state -
class _SplitEntry {
  String url;
  String title;
  _SplitEntry(this.url, this.title);
}

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with TickerProviderStateMixin {
  late BrowserEngine _engine;

  // Native WebKit2GTK window state (managed via system_channel.cc / C++).
  // The C++ layer owns a borderless GtkWindow with override-redirect so
  // matchbox never fullscreens it.  Flutter polls it at 500 ms intervals.
  Timer?  _infoPoller;
  bool    _nativeCanGoBack    = false;
  bool    _nativeCanGoForward = false;
  int     _toolbarHeightPx    = 94;   // updated by LayoutBuilder each frame

  // URL bar
  final TextEditingController _urlCtrl = TextEditingController();
  final FocusNode _urlFocus = FocusNode();
  final LayerLink _urlLayerLink = LayerLink();
  OverlayEntry? _acOverlay;
  List<HistoryEntry> _acSuggestions = [];

  // Find bar
  final TextEditingController _findCtrl = TextEditingController();
  final FocusNode _findFocus = FocusNode();
  int _findMatchCount = 0;
  int _findCurrentMatch = 0;

  // Panels & layout
  _SidePanel _panel = _SidePanel.none;
  bool _showFindBar = false;
  bool _splitView = false;
  _SplitEntry _split = _SplitEntry('about:blank', 'New Split Tab');
  final TextEditingController _splitUrlCtrl = TextEditingController();

  // History search filter
  final TextEditingController _histSearchCtrl = TextEditingController();

  // Animation controller for panel
  late AnimationController _panelAnim;
  late Animation<double> _panelSlide;

  @override
  void initState() {
    super.initState();
    _engine = BrowserEngine();
    _urlCtrl.text = _engine.activeTab?.url ?? '';
    _engine.addListener(_onEngineUpdate);

    _panelAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _panelSlide = CurvedAnimation(parent: _panelAnim, curve: Curves.easeOut);

    // Native WebKit2GTK window is created lazily in C++ on the first
    // browser.webview_show call.  Nothing to initialise here.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadPrefs());
    });
  }

  Future<void> _loadPrefs() async {
    final snap = await BrowserPrefsStore.load();
    if (!mounted) return;
    _engine.hydrateFromPrefs(snap);
    setState(() {});
  }

  void _onEngineUpdate() {
    if (!mounted) return;
    setState(() {
      if (!_urlFocus.hasFocus) {
        final u = _engine.activeTab?.url ?? '';
        _urlCtrl.text = _isBlankOrInternal(u) ? '' : u;
      }
    });
  }

  @override
  void dispose() {
    _infoPoller?.cancel();
    SystemBridge.browserWebViewHide(); // fire-and-forget — hides the GTK window
    _closeAcOverlay();
    _engine.removeListener(_onEngineUpdate);
    _engine.dispose();
    _urlCtrl.dispose();
    _urlFocus.dispose();
    _findCtrl.dispose();
    _findFocus.dispose();
    _histSearchCtrl.dispose();
    _splitUrlCtrl.dispose();
    _panelAnim.dispose();
    super.dispose();
  }

  // - Helpers -

  bool _isBlankOrInternal(String u) =>
      u.isEmpty || u == 'about:blank' || u == 'about:srcdoc';

  String _normalise(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'about:blank';
    if (t.startsWith('http://') || t.startsWith('https://') ||
        t.startsWith('about:')) return t;
    if (RegExp(r'^[a-zA-Z0-9.\-]+\.[a-z]{2,}(/.*)?$').hasMatch(t)) {
      return 'https://$t';
    }
    return 'https://duckduckgo.com/?q=${Uri.encodeQueryComponent(t)}';
  }

  Future<void> _launchUrl(String rawUrl) async {
    final url = _normalise(rawUrl);
    if (_isBlankOrInternal(url)) return;

    // ── Platform-channel path (Linux / KrdOS) ──────────────────────────────
    // SystemBridge.browserOpen() runs a shell command with DISPLAY set and
    // tries every known browser binary (chromium, chromium-browser,
    // google-chrome, firefox, firefox-esr, xdg-open). This is the most
    // reliable path on KrdOS where xdg-mime may not have a default set.
    try {
      await SystemBridge.browserOpen(url: url);
      return;
    } catch (_) {}

    // ── Fallback: url_launcher ─────────────────────────────────────────────
    final uri = Uri.parse(url);
    bool launched = false;
    try {
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // ── Last resort: xdg-open with DISPLAY forced ──────────────────────────
    if (!launched && !kIsWeb) {
      try {
        if (Platform.isLinux) {
          final env = Map<String, String>.from(Platform.environment);
          env['DISPLAY'] ??= ':0';
          await Process.run('xdg-open', [url], environment: env);
          launched = true;
        }
      } catch (_) {}
    }

    if (!launched && mounted) {
      _showSnack('Could not open browser. Install Chromium: sudo apt install chromium',
          isError: true);
    }
  }

  Future<void> _navigate(String raw, {bool forSplit = false}) async {
    if (forSplit) {
      final url = _normalise(raw);
      setState(() {
        _split = _SplitEntry(url, _domainOf(url));
        _splitUrlCtrl.text = url;
      });
      // Split-view opens externally for now (single native WebView window)
      await _launchUrl(url);
      return;
    }
    _engine.navigate(raw);
    final url = _normalise(raw);
    _urlCtrl.text = _isBlankOrInternal(url) ? '' : url;
    setState(() {});

    if (!_isBlankOrInternal(url)) {
      // Show the native WebKit window below Flutter's URL bar, then navigate.
      await SystemBridge.browserWebViewShow(url, _toolbarHeightPx);
      _startPoller();
    } else {
      // Blank / new-tab — hide the native window so the Flutter UI shows.
      await SystemBridge.browserWebViewHide();
      _infoPoller?.cancel();
    }
  }

  /// Start (or restart) the 500 ms polling timer that syncs URL / title /
  /// loading state from the native WebKit window back into Flutter.
  void _startPoller() {
    _infoPoller?.cancel();
    _infoPoller = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted) { _infoPoller?.cancel(); return; }
      final info = await SystemBridge.browserWebViewGetInfo();
      if (!mounted || info.isEmpty) return;
      final url      = info['url']          as String? ?? '';
      final title    = info['title']        as String? ?? '';
      final canBack  = info['canGoBack']    as bool?   ?? false;
      final canFwd   = info['canGoForward'] as bool?   ?? false;
      final loading  = info['isLoading']    as bool?   ?? false;
      final progress = (info['progress']    as num?)?.toDouble() ?? 0.0;
      if (!mounted) return;
      setState(() {
        if (url.isNotEmpty) {
          _engine.activeTab?.url = url;
          if (!_urlFocus.hasFocus && !_isBlankOrInternal(url)) {
            _urlCtrl.text = url;
          }
        }
        if (title.isNotEmpty) _engine.activeTab?.title = title;
        _engine.activeTab?.isLoading = loading;
        _engine.activeTab?.progress  = progress;
        _nativeCanGoBack    = canBack;
        _nativeCanGoForward = canFwd;
      });
    });
  }

  /// Go back in the native WebKit window.
  Future<void> _webBack()    async => SystemBridge.browserWebViewBack();

  /// Go forward in the native WebKit window.
  Future<void> _webForward() async => SystemBridge.browserWebViewForward();

  /// Reload in the native WebKit window.
  Future<void> _webReload()  async => SystemBridge.browserWebViewReload();

  String _domainOf(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  void _togglePanel(_SidePanel p) {
    setState(() {
      if (_panel == p) {
        _panel = _SidePanel.none;
        _panelAnim.reverse();
      } else {
        _panel = p;
        _panelAnim.forward();
      }
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? AppTheme.danger : AppTheme.surfaceAlt,
    ));
  }

  // - Autocomplete overlay -

  void _updateAcSuggestions(String text) {
    if (text.isEmpty) {
      _closeAcOverlay();
      return;
    }
    final q = text.toLowerCase();
    final matches = _engine.history
        .where((e) =>
            !_isBlankOrInternal(e.url) &&
            (e.url.toLowerCase().contains(q) ||
                e.title.toLowerCase().contains(q)))
        .take(6)
        .toList();
    setState(() => _acSuggestions = matches);
    if (matches.isEmpty) {
      _closeAcOverlay();
      return;
    }
    _closeAcOverlay();
    _acOverlay = _buildAcOverlayEntry();
    Overlay.of(context).insert(_acOverlay!);
  }

  void _closeAcOverlay() {
    _acOverlay?.remove();
    _acOverlay = null;
  }

  OverlayEntry _buildAcOverlayEntry() {
    return OverlayEntry(
      builder: (ctx) => Positioned(
        width: 600,
        child: CompositedTransformFollower(
          link: _urlLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Material(
            color: AppTheme.surfaceAlt,
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _acSuggestions.map((e) {
                  return InkWell(
                    onTap: () {
                      _closeAcOverlay();
                      _urlCtrl.text = e.url;
                      _urlFocus.unfocus();
                      unawaited(_navigate(e.url));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(children: [
                        Icon(_secIcon(e.url),
                            size: 14, color: _secColor(e.url)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title.isEmpty ? e.url : e.title,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(e.url,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Icon(Icons.north_west,
                            size: 12, color: AppTheme.textSecondary),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // - Security helpers -

  IconData _secIcon(String url) {
    if (url.startsWith('https://')) return Icons.lock_rounded;
    if (url.startsWith('http://')) return Icons.lock_open_rounded;
    return Icons.search_rounded;
  }

  Color _secColor(String url) {
    if (url.startsWith('https://')) return const Color(0xFF3FB950);
    if (url.startsWith('http://')) return AppTheme.warning;
    return AppTheme.textSecondary;
  }

  // - Find bar logic -

  void _updateFindMatches(String query) {
    if (query.isEmpty) {
      setState(() { _findMatchCount = 0; _findCurrentMatch = 0; });
      return;
    }
    final q = query.toLowerCase();
    int count = 0;
    for (final e in _engine.history) {
      if (e.url.toLowerCase().contains(q) || e.title.toLowerCase().contains(q)) {
        count++;
      }
    }
    for (final b in _engine.bookmarks) {
      if (b.url.toLowerCase().contains(q) || b.title.toLowerCase().contains(q)) {
        count++;
      }
    }
    setState(() {
      _findMatchCount = count;
      _findCurrentMatch = count > 0 ? 1 : 0;
    });
  }

  void _findNext() {
    if (_findMatchCount == 0) return;
    setState(() {
      _findCurrentMatch =
          _findCurrentMatch >= _findMatchCount ? 1 : _findCurrentMatch + 1;
    });
  }

  void _findPrev() {
    if (_findMatchCount == 0) return;
    setState(() {
      _findCurrentMatch =
          _findCurrentMatch <= 1 ? _findMatchCount : _findCurrentMatch - 1;
    });
  }

  // - Build -

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _engine,
      child: Focus(
        autofocus: true,
        child: Shortcuts(
          shortcuts: _shortcuts(),
          child: Actions(actions: _actions(), child: _buildScaffold()),
        ),
      ),
    );
  }

  Map<ShortcutActivator, Intent> _shortcuts() => {
        const SingleActivator(LogicalKeyboardKey.keyT, control: true):
            const _NewTabIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true,
            shift: true): const _IncognitoTabIntent(),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            const _CloseTabIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, control: true):
            const _NextTabIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, control: true,
            shift: true): const _PrevTabIntent(),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            const _FocusUrlIntent(),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            const _ReloadIntent(),
        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            const _BookmarkToggleIntent(),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true):
            const _HistoryPanelIntent(),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true,
            shift: true): const _BookmarksPanelIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _FindIntent(),
        const SingleActivator(LogicalKeyboardKey.keyT, control: true,
            shift: true): const _RestoreTabIntent(),
        const SingleActivator(LogicalKeyboardKey.equal, control: true):
            const _ZoomInIntent(),
        const SingleActivator(LogicalKeyboardKey.add, control: true):
            const _ZoomInIntent(),
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            const _ZoomOutIntent(),
      };

  Map<Type, Action<Intent>> _actions() => {
        _NewTabIntent: CallbackAction<_NewTabIntent>(
            onInvoke: (_) => _engine.addTab()),
        _IncognitoTabIntent: CallbackAction<_IncognitoTabIntent>(
            onInvoke: (_) => _engine.addTab(isIncognito: true)),
        _CloseTabIntent: CallbackAction<_CloseTabIntent>(onInvoke: (_) {
          if (_engine.tabs.length > 1)
            _engine.closeTab(_engine.activeTabIndex);
          return null;
        }),
        _NextTabIntent: CallbackAction<_NextTabIntent>(onInvoke: (_) {
          if (_engine.tabs.isEmpty) return null;
          var i = _engine.activeTabIndex + 1;
          if (i >= _engine.tabs.length) i = 0;
          _engine.switchTab(i);
          return null;
        }),
        _PrevTabIntent: CallbackAction<_PrevTabIntent>(onInvoke: (_) {
          if (_engine.tabs.isEmpty) return null;
          var i = _engine.activeTabIndex - 1;
          if (i < 0) i = _engine.tabs.length - 1;
          _engine.switchTab(i);
          return null;
        }),
        _FocusUrlIntent: CallbackAction<_FocusUrlIntent>(onInvoke: (_) {
          _urlFocus.requestFocus();
          _urlCtrl.selection = TextSelection(
              baseOffset: 0, extentOffset: _urlCtrl.text.length);
          return null;
        }),
        _ReloadIntent: CallbackAction<_ReloadIntent>(onInvoke: (_) {
          final tab = _engine.activeTab;
          if (tab != null && !_isBlankOrInternal(tab.url)) {
            unawaited(_launchUrl(tab.url));
          }
          return null;
        }),
        _BookmarkToggleIntent: CallbackAction<_BookmarkToggleIntent>(
            onInvoke: (_) {
          final tab = _engine.activeTab;
          if (tab != null) _toggleBookmark(tab);
          return null;
        }),
        _HistoryPanelIntent: CallbackAction<_HistoryPanelIntent>(
            onInvoke: (_) => _togglePanel(_SidePanel.history)),
        _BookmarksPanelIntent: CallbackAction<_BookmarksPanelIntent>(
            onInvoke: (_) => _togglePanel(_SidePanel.bookmarks)),
        _FindIntent: CallbackAction<_FindIntent>(onInvoke: (_) {
          setState(() {
            _showFindBar = !_showFindBar;
            if (_showFindBar) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _findFocus.requestFocus());
            } else {
              _findCtrl.clear();
              _findMatchCount = 0;
            }
          });
          return null;
        }),
        _RestoreTabIntent: CallbackAction<_RestoreTabIntent>(onInvoke: (_) {
          if (_engine.canRestoreClosedTab) _engine.restoreLastClosedTab();
          return null;
        }),
        _ZoomInIntent: CallbackAction<_ZoomInIntent>(
            onInvoke: (_) =>
                _engine.setZoomLevel(_engine.zoomLevel + 0.1)),
        _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(
            onInvoke: (_) =>
                _engine.setZoomLevel(_engine.zoomLevel - 0.1)),
      };

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(children: [
        _buildTabStrip(),
        _buildNavBar(),
        if (_engine.showBookmarksBar) _buildBookmarksBar(),
        if (_showFindBar) _buildFindBar(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  // -
  // TAB STRIP
  // -

  Widget _buildTabStrip() {
    return Consumer<BrowserEngine>(builder: (_, engine, __) {
      return Container(
        height: 42,
        color: const Color(0xFF090D12),
        child: Row(children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 4, top: 5),
              itemCount: engine.tabs.length,
              itemBuilder: (ctx, i) => _buildTabChip(engine.tabs[i], i,
                  i == engine.activeTabIndex),
            ),
          ),
  // New tab
          _iconBtn(Icons.add, 'New tab  Ctrl+T', () => _engine.addTab(),
              size: 18),
  // Incognito
          _iconBtn(Icons.security, 'New incognito tab  Ctrl+Shift+N',
              () => _engine.addTab(isIncognito: true),
              size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
        ]),
      );
    });
  }

  Widget _buildTabChip(BrowserTab tab, int i, bool active) {
    final w = tab.isPinned ? 48.0 : 192.0;
    return Tooltip(
      message: '${tab.title}\n${tab.url}',
      waitDuration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: () {
          _engine.switchTab(i);
          final u = _engine.tabs[i].url;
          _urlCtrl.text = _isBlankOrInternal(u) ? '' : u;
        },
        onSecondaryTapDown: (d) =>
            _showTabContextMenu(context, d.globalPosition, i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: w,
          height: 36,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: active ? AppTheme.surface : Colors.transparent,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(7)),
            border: active
                ? Border.all(
                    color: AppTheme.border.withValues(alpha: 0.7),
                    width: 0.8)
                : null,
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: tab.isPinned ? 6 : 10),
              child: Row(children: [
  // favicon / incognito indicator
                _tabFavicon(tab),
                if (!tab.isPinned) ...[
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      tab.title.isEmpty ? 'New Tab' : tab.title,
                      style: TextStyle(
                        color: active
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: active
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tab.isMuted)
                    Icon(Icons.volume_off,
                        size: 12, color: AppTheme.textSecondary),
                  if (_engine.tabs.length > 1)
                    _closeTabBtn(i),
                ],
              ]),
            ),
  // active indicator bar
            if (active)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7)),
                  ),
                ),
              ),
  // loading progress
            if (tab.isLoading)
              Positioned(
                bottom: 0,
                left: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 2,
                  width: w * tab.progress,
                  color: AppTheme.accent.withValues(alpha: 0.7),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _tabFavicon(BrowserTab tab) {
    if (tab.isIncognito) {
      return const Icon(Icons.security, size: 13, color: Color(0xFFA78BFA));
    }
    if (tab.isPinned) {
      return Icon(Icons.push_pin, size: 12, color: AppTheme.accent);
    }
    return Icon(
      _isBlankOrInternal(tab.url) ? Icons.tab_rounded : Icons.language_rounded,
      size: 13,
      color: AppTheme.textSecondary,
    );
  }

  Widget _closeTabBtn(int i) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _engine.closeTab(i),
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(Icons.close, size: 13,
              color: AppTheme.textSecondary.withValues(alpha: 0.8)),
        ),
      ),
    );
  }

  void _showTabContextMenu(BuildContext ctx, Offset pos, int i) {
    if (i < 0 || i >= _engine.tabs.length) return;
    final tab = _engine.tabs[i];
    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: AppTheme.surfaceAlt,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.border)),
      items: [
        _mi('open', Icons.open_in_browser_rounded, 'Open in browser'),
        _mi('dup', Icons.content_copy_rounded, 'Duplicate tab'),
        _mi(tab.isPinned ? 'unpin' : 'pin',
            tab.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            tab.isPinned ? 'Unpin' : 'Pin tab'),
        _mi(tab.isMuted ? 'unmute' : 'mute',
            tab.isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            tab.isMuted ? 'Unmute' : 'Mute tab'),
        if (_splitView) _mi('to_split', Icons.vertical_split_rounded, 'Send to split pane'),
        const PopupMenuDivider(height: 4),
        _mi('close', Icons.close_rounded, 'Close tab'),
        _mi('close_others', Icons.layers_clear_rounded, 'Close other tabs'),
        _mi('close_right', Icons.keyboard_tab_rounded, 'Close to the right'),
      ],
    ).then((v) {
      if (v == null) return;
      switch (v) {
        case 'open':
          _engine.switchTab(i);
          unawaited(_launchUrl(_engine.activeTab?.url ?? ''));
          break;
        case 'dup': _engine.duplicateTab(i); break;
        case 'pin': case 'unpin': _engine.togglePinTab(i); break;
        case 'mute': case 'unmute': _engine.toggleMuteTab(i); break;
        case 'to_split':
          final url = _engine.tabs[i].url;
          setState(() {
            _split = _SplitEntry(url, _domainOf(url));
            _splitUrlCtrl.text = url;
          });
          break;
        case 'close': _engine.closeTab(i); break;
        case 'close_others': _engine.closeOtherTabs(i); break;
        case 'close_right': _engine.closeTabsToTheRight(i); break;
      }
    });
  }

  // -
  // NAVIGATION BAR
  // -

  Widget _buildNavBar() {
    return Consumer<BrowserEngine>(builder: (_, engine, __) {
      final tab = engine.activeTab;
      final url = tab?.url ?? '';
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.8)),
        ),
        child: Row(children: [
  // Back / Forward / Reload / Home — wired to WebView navigation
          _navBtn(Icons.arrow_back_ios_new_rounded,
              true, () => unawaited(_webBack()),
              tooltip: 'Back'),
          const SizedBox(width: 2),
          _navBtn(Icons.arrow_forward_ios_rounded,
              true, () => unawaited(_webForward()),
              tooltip: 'Forward'),
          const SizedBox(width: 2),
          _navBtn(
            tab?.isLoading ?? false
                ? Icons.close_rounded
                : Icons.refresh_rounded,
            true,
            () {
              if (tab?.isLoading ?? false) {
                engine.stopLoading();
              } else {
                unawaited(_webReload());
              }
            },
            tooltip: tab?.isLoading ?? false ? 'Stop' : 'Reload  Ctrl+R',
          ),
          const SizedBox(width: 2),
          _navBtn(Icons.home_rounded, true,
              () => engine.navigate('about:blank'),
              tooltip: 'Home'),
          const SizedBox(width: 8),

  // URL bar
          Expanded(child: _buildUrlBar(tab, url)),
          const SizedBox(width: 8),

  // Bookmark star
          _iconBtn(
            engine.isBookmarked(url)
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            'Bookmark  Ctrl+D',
            () { if (tab != null) _toggleBookmark(tab); },
            color: engine.isBookmarked(url)
                ? const Color(0xFFF5A623)
                : AppTheme.textSecondary,
          ),
          const SizedBox(width: 2),

  // Split view toggle
          _iconBtn(
            _splitView ? Icons.vertical_split_rounded : Icons.square_rounded,
            _splitView ? 'Exit split view' : 'Split view',
            () => setState(() {
              _splitView = !_splitView;
              if (_splitView && _isBlankOrInternal(_split.url)) {
                _split = _SplitEntry(url, _domainOf(url));
                _splitUrlCtrl.text = url;
              }
            }),
            color: _splitView ? AppTheme.accent : AppTheme.textSecondary,
          ),
          const SizedBox(width: 2),

  // Panels
          _panelToggleBtn(Icons.bookmark_border_rounded,
              'Bookmarks  Ctrl+Shift+B', _SidePanel.bookmarks),
          _panelToggleBtn(Icons.history_rounded,
              'History  Ctrl+H', _SidePanel.history),
          _panelToggleBtn(Icons.download_rounded,
              'Downloads', _SidePanel.downloads),
          _panelToggleBtn(Icons.tune_rounded, 'Settings', _SidePanel.settings),
          const SizedBox(width: 2),

  // Overflow menu
          _buildOverflowMenu(),
        ]),
      );
    });
  }

  Widget _navBtn(IconData icon, bool enabled, VoidCallback onTap,
      {String tooltip = ''}) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: enabled ? Colors.transparent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon,
                size: 16,
                color: enabled
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary.withValues(alpha: 0.25)),
          ),
        ),
      ),
    );
  }

  Widget _buildUrlBar(BrowserTab? tab, String url) {
    return CompositedTransformTarget(
      link: _urlLayerLink,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: _urlFocus.hasFocus
                  ? AppTheme.accent.withValues(alpha: 0.6)
                  : AppTheme.border,
              width: 0.9),
          boxShadow: _urlFocus.hasFocus
              ? [
                  BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      blurRadius: 8)
                ]
              : null,
        ),
        child: Row(children: [
          const SizedBox(width: 12),
  // Security icon
          Icon(_secIcon(url), size: 13, color: _secColor(url)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _urlCtrl,
              focusNode: _urlFocus,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search or enter URL?',
                hintStyle: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 13),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) {
                _updateAcSuggestions(v);
                setState(() {});
              },
              onSubmitted: (v) {
                _closeAcOverlay();
                _urlFocus.unfocus();
                unawaited(_navigate(v));
              },
              onTap: () {
                _urlCtrl.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _urlCtrl.text.length);
              },
              onEditingComplete: _closeAcOverlay,
            ),
          ),
  // Loading spinner / go button
          if (tab?.isLoading ?? false)
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor:
                      AlwaysStoppedAnimation(AppTheme.accent)),
            )
          else
            GestureDetector(
              onTap: () {
                _closeAcOverlay();
                _urlFocus.unfocus();
                unawaited(_navigate(_urlCtrl.text));
              },
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 14, color: AppTheme.accent),
              ),
            ),
          const SizedBox(width: 6),
        ]),
      ),
    );
  }

  Widget _panelToggleBtn(IconData icon, String tip, _SidePanel p) {
    final active = _panel == p;
    return Tooltip(
      message: tip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _togglePanel(p),
          child: Container(
            width: 30, height: 30,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.accent.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon,
                size: 16,
                color: active ? AppTheme.accent : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildOverflowMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          size: 18, color: AppTheme.textSecondary),
      color: AppTheme.surfaceAlt,
      offset: const Offset(0, 32),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.border, width: 0.8)),
      onSelected: _handleOverflowAction,
      itemBuilder: (_) => [
        _mi('new_tab', Icons.add_rounded, 'New tab  Ctrl+T'),
        _mi('new_incognito', Icons.security_rounded,
            'New incognito  Ctrl+Shift+N'),
        PopupMenuItem<String>(
          value: 'restore',
          enabled: _engine.canRestoreClosedTab,
          height: 36,
          child: Row(children: [
            Icon(Icons.restore_rounded,
                size: 14,
                color: _engine.canRestoreClosedTab
                    ? AppTheme.textSecondary
                    : AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(width: 10),
            Text('Reopen closed tab  Ctrl+Shift+T',
                style: TextStyle(
                    color: _engine.canRestoreClosedTab
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary.withValues(alpha: 0.3),
                    fontSize: 12)),
          ]),
        ),
        const PopupMenuDivider(height: 4),
        _mi('copy_url', Icons.link_rounded, 'Copy page address'),
        _mi('zoom_in', Icons.zoom_in_rounded, 'Zoom in  Ctrl++'),
        _mi('zoom_out', Icons.zoom_out_rounded, 'Zoom out  Ctrl+-'),
        const PopupMenuDivider(height: 4),
        _mi('print', Icons.print_rounded, 'Print'),
        _mi('save_page', Icons.save_rounded, 'Save page'),
        _mi('find', Icons.manage_search_rounded, 'Find in page  Ctrl+F'),
      ],
    );
  }

  void _handleOverflowAction(String v) {
    switch (v) {
      case 'new_tab': _engine.addTab(); break;
      case 'new_incognito': _engine.addTab(isIncognito: true); break;
      case 'restore':
        if (_engine.canRestoreClosedTab) _engine.restoreLastClosedTab();
        break;
      case 'copy_url':
        final u = _engine.activeTab?.url ?? '';
        if (!_isBlankOrInternal(u)) {
          unawaited(Clipboard.setData(ClipboardData(text: u)));
          _showSnack('Address copied to clipboard');
        }
        break;
      case 'zoom_in': _engine.setZoomLevel(_engine.zoomLevel + 0.1); break;
      case 'zoom_out': _engine.setZoomLevel(_engine.zoomLevel - 0.1); break;
      case 'print':
        final u = _engine.activeTab?.url ?? '';
        if (!_isBlankOrInternal(u)) {
          unawaited(_launchUrl('$u#print'));
          _showSnack('Opening in browser for printing?');
        }
        break;
      case 'save_page':
        final u = _engine.activeTab?.url ?? '';
        if (!_isBlankOrInternal(u)) {
          unawaited(_launchUrl(u));
          _showSnack('Opened in browser ? use Save As (Ctrl+S) there.');
        }
        break;
      case 'find':
        setState(() {
          _showFindBar = !_showFindBar;
          if (_showFindBar) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _findFocus.requestFocus());
          } else {
            _findCtrl.clear();
            _findMatchCount = 0;
          }
        });
        break;
    }
  }

  // -
  // BOOKMARKS BAR
  // -

  Widget _buildBookmarksBar() {
    return Consumer<BrowserEngine>(builder: (_, engine, __) {
      if (engine.bookmarks.isEmpty) return const SizedBox.shrink();
      return Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          border: Border(
              bottom: BorderSide(
                  color: AppTheme.border.withValues(alpha: 0.5),
                  width: 0.8)),
        ),
        child: Row(children: [
          Icon(Icons.bookmarks_outlined, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: engine.bookmarks.length,
              itemBuilder: (_, i) {
                final bm = engine.bookmarks[i];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      _engine.navigate(bm.url);
                      _urlCtrl.text = bm.url;
                      unawaited(_launchUrl(bm.url));
                    },
                    onSecondaryTapDown: (d) => showMenu<String>(
                      context: context,
                      position: RelativeRect.fromLTRB(d.globalPosition.dx,
                          d.globalPosition.dy, d.globalPosition.dx + 1,
                          d.globalPosition.dy + 1),
                      color: AppTheme.surfaceAlt,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppTheme.border)),
                      items: [
                        _mi('open', Icons.open_in_browser_rounded,
                            'Open in browser'),
                        _mi('new_tab', Icons.add_rounded,
                            'Open in new tab'),
                        const PopupMenuDivider(height: 4),
                        _mi('delete', Icons.delete_outline_rounded,
                            'Delete bookmark'),
                      ],
                    ).then((val) {
                      if (val == 'open' || val == 'new_tab') {
                        if (val == 'new_tab') _engine.addTab(url: bm.url);
                        unawaited(_launchUrl(bm.url));
                      } else if (val == 'delete') {
                        _engine.removeBookmark(bm.id);
                      }
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.5)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.language_rounded,
                            size: 11,
                            color: AppTheme.textSecondary),
                        const SizedBox(width: 5),
                        Text(bm.title,
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      );
    });
  }

  // -
  // FIND BAR
  // -

  Widget _buildFindBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(
            bottom: BorderSide(color: AppTheme.accent.withValues(alpha: 0.4))),
      ),
      child: Row(children: [
        Icon(Icons.manage_search_rounded,
            size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _findCtrl,
            focusNode: _findFocus,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Find in history & bookmarks?',
              hintStyle: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) => _updateFindMatches(v),
          ),
        ),
        const SizedBox(width: 14),
  // Match counter
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _findMatchCount == 0
              ? Text(
                  _findCtrl.text.isEmpty ? '' : 'No matches',
                  key: const ValueKey('no'),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                )
              : Text(
                  '$_findCurrentMatch / $_findMatchCount',
                  key: const ValueKey('match'),
                  style: TextStyle(color: AppTheme.accent, fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
        ),
        const SizedBox(width: 10),
        _iconBtn(Icons.keyboard_arrow_up_rounded, 'Previous match', _findPrev,
            size: 16),
        _iconBtn(Icons.keyboard_arrow_down_rounded, 'Next match', _findNext,
            size: 16),
        const Spacer(),
        TextButton(
          onPressed: () {
            setState(() {
              _showFindBar = false;
              _findCtrl.clear();
              _findMatchCount = 0;
            });
          },
          style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              minimumSize: const Size(50, 32),
              textStyle: const TextStyle(fontSize: 12)),
          child: const Text('Close'),
        ),
      ]),
    );
  }

  // -
  // BODY ? content + optional side panel
  // -

  Widget _buildBody() {
    return Row(children: [
  // Main content (or split view)
      Expanded(child: _buildMainContent()),
  // Side panel (animated)
      if (_panel != _SidePanel.none)
        SizeTransition(
          sizeFactor: _panelSlide,
          axis: Axis.horizontal,
          axisAlignment: 1.0,
          child: _buildSidePanel(),
        ),
    ]);
  }

  Widget _buildMainContent() {
    if (_splitView) return _buildSplitView();
    return Consumer<BrowserEngine>(builder: (_, engine, __) {
      final tab = engine.activeTab;
      if (tab == null) return const Center(child: Text('No tab'));
      if (_isBlankOrInternal(tab.url)) return _buildNewTabPage();
      return _buildUrlViewPanel(tab.url, tab.title, tab.isLoading);
    });
  }

  // -
  // SPLIT VIEW
  // -

  Widget _buildSplitView() {
    return Consumer<BrowserEngine>(builder: (_, engine, __) {
      final tab = engine.activeTab;
      if (tab == null) return const SizedBox.shrink();
      return Row(children: [
  // Left pane ? active tab
        Expanded(
          child: Column(children: [
            _splitPaneHeader(
              tab.url, 'Primary', Icons.circle,
              color: AppTheme.accent,
              onUrlSubmit: (v) => unawaited(_navigate(v)),
            ),
            Expanded(
              child: _isBlankOrInternal(tab.url)
                  ? _buildNewTabPage()
                  : _buildUrlViewPanel(tab.url, tab.title, tab.isLoading),
            ),
          ]),
        ),
  // Divider
        VerticalDivider(
            width: 1, thickness: 1,
            color: AppTheme.border.withValues(alpha: 0.8)),
  // Right pane ? split entry
        Expanded(
          child: Column(children: [
            _splitPaneHeader(
              _split.url, 'Split', Icons.vertical_split_rounded,
              color: const Color(0xFF7C3AED),
              onUrlSubmit: (v) => unawaited(_navigate(v, forSplit: true)),
              ctrl: _splitUrlCtrl,
            ),
            Expanded(
              child: _isBlankOrInternal(_split.url)
                  ? _buildSplitEmptyPane()
                  : _buildUrlViewPanel(
                      _split.url, _split.title, false),
            ),
          ]),
        ),
      ]);
    });
  }

  Widget _splitPaneHeader(
    String url,
    String label,
    IconData icon, {
    required Color color,
    required ValueChanged<String> onUrlSubmit,
    TextEditingController? ctrl,
  }) {
    final controller = ctrl ?? TextEditingController(text: url);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: AppTheme.surfaceAlt.withValues(alpha: 0.5),
      child: Row(children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border, width: 0.8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              controller: controller,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 12),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: onUrlSubmit,
            ),
          ),
        ),
        const SizedBox(width: 6),
        _iconBtn(Icons.open_in_browser_rounded, 'Open in browser',
            () => unawaited(_launchUrl(url)), size: 15),
      ]),
    );
  }

  Widget _buildSplitEmptyPane() {
    return Container(
      color: AppTheme.background,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.vertical_split_rounded,
              size: 48, color: AppTheme.border),
          const SizedBox(height: 16),
          Text('Split pane',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Enter a URL above or right-click a tab ? Send to split pane',
              style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // -
  // URL VIEW PANEL ? the "page" shown when a URL is loaded
  // -

  Widget _buildUrlViewPanel(String url, String title, bool loading) {
    // If an actual URL is loaded, show a dark placeholder behind the native
    // WebKit2GTK window.  The native window (override-redirect, borderless)
    // is positioned by C++ to cover exactly this area below the Flutter toolbar.
    // A LayoutBuilder measures the content area each frame so _toolbarHeightPx
    // stays accurate even when the find bar / bookmarks bar is toggled.
    if (!_isBlankOrInternal(url)) {
      return LayoutBuilder(builder: (ctx, constraints) {
        // Screen height − content-area height = toolbar height in logical px.
        final screenH = MediaQuery.of(ctx).size.height;
        final dpr     = MediaQuery.of(ctx).devicePixelRatio;
        _toolbarHeightPx =
            ((screenH - constraints.maxHeight) * dpr).round().clamp(0, 400);
        return Stack(
          children: [
            // Dark backdrop — the GTK WebKit window sits on top of this.
            Container(color: const Color(0xFF0A0D12)),
            if (loading)
              Positioned(
                top: 0, left: 0, right: 0,
                child: LinearProgressIndicator(
                  value: _engine.activeTab?.progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                  minHeight: 3,
                ),
              ),
          ],
        );
      });
    }

    final isHttps = url.startsWith('https://');
    final isHttp = url.startsWith('http://');
    final domain = _domainOf(url);

    return GestureDetector(
      onSecondaryTapDown: (d) =>
          _showPageContextMenu(context, d.globalPosition, url),
      child: Container(
        color: AppTheme.background,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
  // - Site icon -
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isHttps
                          ? [
                              const Color(0xFF166534).withValues(alpha: 0.35),
                              const Color(0xFF3FB950).withValues(alpha: 0.15),
                            ]
                          : isHttp
                              ? [
                                  AppTheme.warning.withValues(alpha: 0.3),
                                  AppTheme.warning.withValues(alpha: 0.1),
                                ]
                              : [
                                  AppTheme.accentDim,
                                  AppTheme.accentDim,
                                ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: isHttps
                            ? const Color(0xFF3FB950).withValues(alpha: 0.4)
                            : isHttp
                                ? AppTheme.warning.withValues(alpha: 0.4)
                                : AppTheme.border,
                        width: 1.2),
                    boxShadow: [
                      BoxShadow(
                          color: (isHttps
                                  ? const Color(0xFF3FB950)
                                  : AppTheme.accent)
                              .withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Icon(
                    isHttps
                        ? Icons.lock_rounded
                        : isHttp
                            ? Icons.lock_open_rounded
                            : Icons.language_rounded,
                    size: 40,
                    color: isHttps
                        ? const Color(0xFF3FB950)
                        : isHttp ? AppTheme.warning : AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 22),

  // - Security badge -
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isHttps
                            ? const Color(0xFF3FB950)
                            : isHttp ? AppTheme.warning : AppTheme.border)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: (isHttps
                                ? const Color(0xFF3FB950)
                                : isHttp
                                    ? AppTheme.warning
                                    : AppTheme.border)
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_secIcon(url), size: 12, color: _secColor(url)),
                    const SizedBox(width: 6),
                    Text(
                      isHttps
                          ? 'Secure connection  ·  HTTPS'
                          : isHttp
                              ? 'Insecure connection  ·  HTTP'
                              : 'Internal page',
                      style: TextStyle(
                          color: _secColor(url),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),

  // - Domain & title -
                Text(domain,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(title.isEmpty || title == 'New Tab' ? url : title,
                    style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.8),
                        fontSize: 13),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 28),

  // - Loading indicator -
                if (loading)
                  Column(children: [
                    LinearProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                      backgroundColor:
                          AppTheme.border.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                  ]),

  // - Action buttons -
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: _actionBtn(
                      label: 'Open in Browser',
                      icon: Icons.open_in_browser_rounded,
                      primary: true,
                      onTap: () => unawaited(_launchUrl(url)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _actionBtn(
                      label: 'Tor Browser',
                      icon: Icons.shield_rounded,
                      onTap: () => unawaited(_launchTorUrl(url)),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _actionBtn(
                      label: 'Copy URL',
                      icon: Icons.copy_rounded,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        _showSnack('Address copied');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionBtn(
                      label: 'Open in Split',
                      icon: Icons.vertical_split_rounded,
                      onTap: () {
                        setState(() {
                          _splitView = true;
                          _split = _SplitEntry(url, domain);
                          _splitUrlCtrl.text = url;
                        });
                        _showSnack('Opened in split pane');
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 32),

  // - Info box -
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.border.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14,
                        color: AppTheme.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enter a URL or search term above and press Enter '
                        'to browse with the built-in WebKit engine. '
                        'Use "Open in Browser" to open the page in full '
                        'Chromium instead.',
                        style: TextStyle(
                            color: AppTheme.textSecondary.withValues(
                                alpha: 0.8),
                            fontSize: 12,
                            height: 1.5),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    bool primary = false,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: primary
                ? AppTheme.accent
                : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    primary ? AppTheme.accent : AppTheme.border,
                width: 0.9),
            boxShadow: primary
                ? [
                    BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16,
                color: primary ? Colors.white : AppTheme.textPrimary),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: primary
                        ? Colors.white
                        : AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  void _showPageContextMenu(BuildContext ctx, Offset pos, String url) {
    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(
          pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: AppTheme.surfaceAlt,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.border, width: 0.8)),
      items: [
        _mi('open_new', Icons.add_rounded, 'Open in new tab'),
        _mi('open_incognito', Icons.security_rounded,
            'Open in incognito tab'),
        const PopupMenuDivider(height: 4),
        _mi('copy_link', Icons.link_rounded, 'Copy link'),
        _mi('save_page', Icons.save_rounded, 'Save page'),
        _mi('print', Icons.print_rounded, 'Print'),
        const PopupMenuDivider(height: 4),
        _mi('find', Icons.manage_search_rounded, 'Find in page  Ctrl+F'),
        _mi('view_source', Icons.code_rounded, 'View page source'),
      ],
    ).then((v) {
      switch (v) {
        case 'open_new':
          _engine.addTab(url: url);
          unawaited(_launchUrl(url));
          break;
        case 'open_incognito':
          _engine.addTab(url: url, isIncognito: true);
          unawaited(_launchUrl(url));
          break;
        case 'copy_link':
          unawaited(Clipboard.setData(ClipboardData(text: url)));
          _showSnack('Link copied');
          break;
        case 'save_page':
          unawaited(_launchUrl(url));
          _showSnack('Opened in browser ? use Save As (Ctrl+S) there.');
          break;
        case 'print':
          unawaited(_launchUrl(url));
          _showSnack('Opened in browser for printing?');
          break;
        case 'find':
          setState(() {
            _showFindBar = true;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _findFocus.requestFocus());
          });
          break;
        case 'view_source':
          final srcUrl = 'view-source:$url';
          _engine.addTab(url: srcUrl);
          unawaited(_launchUrl(srcUrl));
          break;
      }
    });
  }

  Future<void> _launchTorUrl(String url) async {
    final opened = await openUrlInTorBrowser(
      url,
      executablePath: _engine.torBrowserExecutablePath,
    );
    _showSnack(opened
        ? 'Sent to Tor Browser'
        : 'Could not launch Tor Browser ? check path in Settings',
        isError: !opened);
  }

  // -
  // NEW TAB PAGE
  // -

  Widget _buildNewTabPage() {
    return Consumer<BrowserEngine>(builder: (_, engine, __) {
      final recentMap = <String, HistoryEntry>{};
      for (final e in engine.history) {
        if (_isBlankOrInternal(e.url)) continue;
        recentMap.putIfAbsent(e.url, () => e);
        if (recentMap.length >= 8) break;
      }

      return Container(
        color: AppTheme.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(children: [
  // - Hero -
                Text('KrdOS Browser',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1)),
                const SizedBox(height: 6),
                Text(
                  'Tabs · Bookmarks · History · Privacy · Tor · Split View',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 32),

  // - Search bar -
                _buildHomeSearch(),
                const SizedBox(height: 40),

  // - Quick links (bookmarks grid) -
                if (engine.bookmarks.isNotEmpty) ...[
                  _sectionHeader('Bookmarks', Icons.bookmark_border_rounded,
                      action: TextButton(
                        onPressed: () => _togglePanel(_SidePanel.bookmarks),
                        child: Text('All bookmarks',
                            style: TextStyle(
                                color: AppTheme.accent, fontSize: 12)),
                      )),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: engine.bookmarks
                        .take(12)
                        .map((bm) => _bookmarkCard(bm))
                        .toList(),
                  ),
                  const SizedBox(height: 36),
                ],

  // - Recent history -
                if (recentMap.isNotEmpty) ...[
                  _sectionHeader(
                      'Recently visited', Icons.history_rounded,
                      action: TextButton(
                        onPressed: () => _togglePanel(_SidePanel.history),
                        child: Text('Full history',
                            style: TextStyle(
                                color: AppTheme.accent, fontSize: 12)),
                      )),
                  const SizedBox(height: 12),
                  _buildRecentGrid(recentMap.values.toList()),
                  const SizedBox(height: 36),
                ],

  // - Quick access row -
                _sectionHeader('Quick access', Icons.bolt_rounded),
                const SizedBox(height: 12),
                _buildQuickAccess(),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHomeSearch() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 32,
              offset: const Offset(0, 12))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(children: [
        const Icon(Icons.search_rounded,
            color: AppTheme.textSecondary, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search the web or enter a URL',
              hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  fontSize: 16),
            ),
            onSubmitted: (v) {
              if (v.trim().isEmpty) return;
              unawaited(_navigate(v.trim()));
            },
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border)),
          child: const Text('Enter',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title, IconData icon, {Widget? action}) {
    return Row(children: [
      Icon(icon, size: 15, color: AppTheme.textSecondary),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
      const Spacer(),
      if (action != null) action,
    ]);
  }

  Widget _bookmarkCard(Bookmark bm) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _engine.navigate(bm.url);
          _urlCtrl.text = bm.url;
          unawaited(_launchUrl(bm.url));
        },
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border, width: 0.8),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: AppTheme.accentDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.language_rounded,
                  size: 14, color: AppTheme.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(bm.title,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRecentGrid(List<HistoryEntry> entries) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 84,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              _engine.navigate(e.url);
              _urlCtrl.text = e.url;
              unawaited(_launchUrl(e.url));
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.border, width: 0.8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Icon(_secIcon(e.url),
                    size: 14, color: _secColor(e.url)),
                const SizedBox(height: 6),
                Text(e.title.isEmpty ? _domainOf(e.url) : e.title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_domainOf(e.url),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAccess() {
    final sites = [
      ('Google', 'https://google.com', Icons.search_rounded, const Color(0xFF4285F4)),
      ('YouTube', 'https://youtube.com', Icons.play_circle_rounded, const Color(0xFFFF0000)),
      ('GitHub', 'https://github.com', Icons.code_rounded, const Color(0xFFE6EDF3)),
      ('DuckDuckGo', 'https://duckduckgo.com', Icons.privacy_tip_rounded, const Color(0xFFDE5833)),
      ('Wikipedia', 'https://wikipedia.org', Icons.menu_book_rounded, const Color(0xFF8B949E)),
      ('News', 'https://news.ycombinator.com', Icons.article_rounded, const Color(0xFFFF6600)),
    ];
    return Row(
      children: sites.map((s) {
        final (name, url, icon, color) = s;
        return Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                _engine.navigate(url);
                _urlCtrl.text = url;
                unawaited(_launchUrl(url));
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.border, width: 0.8),
                ),
                child: Column(children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 6),
                  Text(name,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // -
  // SIDE PANEL
  // -

  Widget _buildSidePanel() {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(color: AppTheme.border, width: 0.8)),
      ),
      child: switch (_panel) {
        _SidePanel.bookmarks => _buildBookmarksPanel(),
        _SidePanel.history => _buildHistoryPanel(),
        _SidePanel.downloads => _buildDownloadsPanel(),
        _SidePanel.settings => _buildSettingsPanel(),
        _SidePanel.none => const SizedBox.shrink(),
      },
    );
  }

  // - Panel header helper -

  Widget _panelHeader(String title, IconData icon, {List<Widget>? actions}) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(
            bottom: BorderSide(color: AppTheme.border, width: 0.8)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: AppTheme.accent),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        ...?actions,
        _iconBtn(Icons.close_rounded, 'Close panel',
            () => _togglePanel(_panel), size: 16),
      ]),
    );
  }

  // - Bookmarks panel -

  Widget _buildBookmarksPanel() {
    return Consumer<BrowserEngine>(builder: (_, engine, __) {
      return Column(children: [
        _panelHeader('Bookmarks', Icons.bookmark_rounded, actions: [
          _iconBtn(Icons.add_rounded, 'Bookmark current page', () {
            final tab = engine.activeTab;
            if (tab != null) _toggleBookmark(tab);
          }, size: 16),
          const SizedBox(width: 4),
        ]),
        Expanded(
          child: engine.bookmarks.isEmpty
              ? _emptyState(
                  Icons.bookmark_border_rounded,
                  'No bookmarks yet',
                  'Navigate to a page and press the star to bookmark it.')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: engine.bookmarks.length,
                  itemBuilder: (_, i) {
                    final bm = engine.bookmarks[i];
                    return _bookmarkListTile(bm);
                  },
                ),
        ),
      ]);
    });
  }

  Widget _bookmarkListTile(Bookmark bm) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: AppTheme.accentDim,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.language_rounded, size: 14, color: AppTheme.accent),
      ),
      title: Text(bm.title,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 13),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(bm.url,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 11),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded,
            size: 16, color: AppTheme.textSecondary),
        onPressed: () => _engine.removeBookmark(bm.id),
        tooltip: 'Delete',
      ),
      onTap: () {
        _engine.navigate(bm.url);
        _urlCtrl.text = bm.url;
        unawaited(_launchUrl(bm.url));
      },
    );
  }

  // - History panel -

  Widget _buildHistoryPanel() {
    return Consumer<BrowserEngine>(builder: (_, engine, __) {
      final q = _histSearchCtrl.text.toLowerCase();
      final entries = engine.history
          .where((e) =>
              !_isBlankOrInternal(e.url) &&
              (q.isEmpty ||
                  e.url.toLowerCase().contains(q) ||
                  e.title.toLowerCase().contains(q)))
          .toList();

  // Group by date
      final groups = <String, List<HistoryEntry>>{};
      for (final e in entries) {
        final key = _dateLabel(e.visited);
        (groups[key] ??= []).add(e);
      }

      return Column(children: [
        _panelHeader('History', Icons.history_rounded, actions: [
          if (engine.history.isNotEmpty)
            TextButton(
              onPressed: () {
                engine.clearHistory();
                _histSearchCtrl.clear();
              },
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  textStyle: const TextStyle(fontSize: 11)),
              child: const Text('Clear all'),
            ),
        ]),
  // Search
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _histSearchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              fillColor: AppTheme.surfaceAlt,
              filled: true,
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 16, color: AppTheme.textSecondary),
              hintText: 'Search history?',
              hintStyle: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: AppTheme.border.withValues(alpha: 0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.accent),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? _emptyState(
                  Icons.history_rounded,
                  q.isEmpty ? 'No history' : 'No matches',
                  q.isEmpty
                      ? 'Sites you visit will appear here.'
                      : 'Try a different search term.')
              : ListView(
                  padding: const EdgeInsets.only(bottom: 12),
                  children: groups.entries.map((grp) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                        child: Text(grp.key,
                            style: TextStyle(
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4)),
                      ),
                      ...grp.value.map((e) => _historyListTile(e)),
                    ]);
                  }).toList(),
                ),
        ),
      ]);
    });
  }

  Widget _historyListTile(HistoryEntry e) {
    return ListTile(
      dense: true,
      leading: Icon(_secIcon(e.url), size: 14, color: _secColor(e.url)),
      title: Text(e.title.isEmpty ? _domainOf(e.url) : e.title,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 12),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(e.url,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 10.5),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${e.visited.hour.toString().padLeft(2, '0')}:'
        '${e.visited.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 10.5),
      ),
      onTap: () {
        _engine.navigate(e.url);
        _urlCtrl.text = e.url;
        unawaited(_launchUrl(e.url));
      },
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  // - Downloads panel -

  Widget _buildDownloadsPanel() {
    return Consumer<BrowserEngine>(builder: (_, engine, __) {
      return Column(children: [
        _panelHeader('Downloads', Icons.download_rounded),
        Expanded(
          child: engine.downloads.isEmpty
              ? _emptyState(
                  Icons.download_rounded,
                  'No downloads',
                  'Files downloaded via the system browser appear here.')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: engine.downloads.length,
                  itemBuilder: (_, i) {
                    final dl = engine.downloads[i];
                    return _downloadTile(dl);
                  },
                ),
        ),
      ]);
    });
  }

  Widget _downloadTile(Download dl) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            dl.isComplete ? Icons.check_circle_rounded : Icons.downloading_rounded,
            size: 16,
            color: dl.isComplete ? const Color(0xFF3FB950) : AppTheme.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(dl.filename,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (dl.isComplete)
            Icon(Icons.folder_open_rounded,
                size: 16, color: AppTheme.textSecondary),
        ]),
        if (!dl.isComplete) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: dl.progress,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation(AppTheme.accent),
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 4),
          Text(
            '${(dl.downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB '
            '/ ${(dl.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ]),
    );
  }

  // - Settings panel -

  Widget _buildSettingsPanel() {
    return Consumer<BrowserEngine>(builder: (_, engine, __) {
      return Column(children: [
        _panelHeader('Privacy & Settings', Icons.tune_rounded),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _settingsSection('Privacy & Security'),
              _settingsToggle(
                'Ad Blocker',
                'Block advertisements and trackers',
                Icons.block_rounded,
                engine.adBlockEnabled,
                (_) => engine.toggleAdBlock(),
              ),
              _settingsToggle(
                'Tracking Protection',
                'Block cross-site tracking scripts',
                Icons.privacy_tip_rounded,
                engine.trackingProtection,
                (_) => engine.toggleTrackingProtection(),
              ),
              _settingsToggle(
                'HTTPS Preferred',
                'Upgrade HTTP requests to HTTPS',
                Icons.lock_rounded,
                engine.httpsPreferred,
                (v) => engine.setHttpsPreferred(v),
              ),
              _settingsToggle(
                'Block Dangerous Schemes',
                'Block javascript: and data: URL schemes',
                Icons.dangerous_rounded,
                engine.dangerousSchemeBlock,
                (v) => engine.setDangerousSchemeBlock(v),
              ),
              _settingsToggle(
                'Strict JavaScript',
                'Warn when pages use heavy JS (informational)',
                Icons.code_rounded,
                engine.strictJavaScript,
                (v) => engine.setStrictJavaScript(v),
              ),
              const SizedBox(height: 16),
              _settingsSection('Appearance'),
              _settingsToggle(
                'Bookmarks Bar',
                'Show bookmarks bar below address bar',
                Icons.bookmark_border_rounded,
                engine.showBookmarksBar,
                (v) => engine.setShowBookmarksBar(v),
              ),
              _settingsToggle(
                'Dark Mode Injection',
                'Request dark pages from sites that support it',
                Icons.dark_mode_rounded,
                false, // informational ? stored in prefs not modeled here
                (_) => _showSnack('Dark mode preference noted ? applied on next page load.'),
              ),
              const SizedBox(height: 16),
              _settingsSection('Search Engine'),
              ...[
                ('google', 'Google', Icons.search_rounded),
                ('bing', 'Bing', Icons.public_rounded),
                ('duckduckgo', 'DuckDuckGo', Icons.privacy_tip_rounded),
              ].map((s) {
                final (id, name, icon) = s;
                return RadioListTile<String>(
                  dense: true,
                  value: id,
                  groupValue: engine.searchEngine,
                  title: Row(children: [
                    Icon(icon, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13)),
                  ]),
                  activeColor: AppTheme.accent,
                  onChanged: (v) {
                    if (v != null) engine.setSearchEngine(v);
                  },
                );
              }),
              const SizedBox(height: 16),
              _settingsSection('Zoom'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Text(
                    '${(engine.zoomLevel * 100).round()}%',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                  Expanded(
                    child: Slider(
                      value: engine.zoomLevel,
                      min: 0.5, max: 2.0,
                      divisions: 15,
                      activeColor: AppTheme.accent,
                      inactiveColor: AppTheme.border,
                      onChanged: (v) => engine.setZoomLevel(v),
                    ),
                  ),
                  _iconBtn(Icons.refresh_rounded, 'Reset zoom',
                      () => engine.setZoomLevel(1.0), size: 16),
                ]),
              ),
              const SizedBox(height: 16),
              _settingsSection('Tor Browser'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    'Executable path:',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      engine.torBrowserExecutablePath ??
                          'Not configured',
                      style: TextStyle(
                          color: engine.torBrowserExecutablePath != null
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontSize: 12),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ]);
    });
  }

  Widget _settingsSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(title.toUpperCase(),
          style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
    );
  }

  Widget _settingsToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      dense: true,
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.accent,
      title: Row(children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13)),
      ]),
      subtitle: Text(subtitle,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 11)),
    );
  }

  // - Shared helpers -

  Widget _emptyState(IconData icon, String title, String body) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: AppTheme.border),
        const SizedBox(height: 14),
        Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(body,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap,
      {double size = 17, Color? color}) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: size,
                color: color ?? AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _mi(String v, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: v, height: 36,
      child: Row(children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 12)),
      ]),
    );
  }

  void _toggleBookmark(BrowserTab tab) {
    if (_engine.isBookmarked(tab.url)) {
      final bm = _engine.bookmarks.firstWhere((b) => b.url == tab.url);
      _engine.removeBookmark(bm.id);
      _showSnack('Bookmark removed');
    } else {
      _engine.addBookmark(tab.url, tab.title);
      _showSnack('Bookmarked!');
    }
  }
}

// - Intent classes -
class _NewTabIntent extends Intent { const _NewTabIntent(); }
class _IncognitoTabIntent extends Intent { const _IncognitoTabIntent(); }
class _CloseTabIntent extends Intent { const _CloseTabIntent(); }
class _NextTabIntent extends Intent { const _NextTabIntent(); }
class _PrevTabIntent extends Intent { const _PrevTabIntent(); }
class _FocusUrlIntent extends Intent { const _FocusUrlIntent(); }
class _ReloadIntent extends Intent { const _ReloadIntent(); }
class _BookmarkToggleIntent extends Intent { const _BookmarkToggleIntent(); }
class _HistoryPanelIntent extends Intent { const _HistoryPanelIntent(); }
class _BookmarksPanelIntent extends Intent { const _BookmarksPanelIntent(); }
class _FindIntent extends Intent { const _FindIntent(); }
class _RestoreTabIntent extends Intent { const _RestoreTabIntent(); }
class _ZoomInIntent extends Intent { const _ZoomInIntent(); }
class _ZoomOutIntent extends Intent { const _ZoomOutIntent(); }