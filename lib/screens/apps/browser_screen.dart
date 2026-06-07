// lib/screens/apps/browser_screen.dart
// KrdOS Browser — rebuilt from scratch
// Features: multi-tab, GtkOverlay WebKit, password manager, cookies, history,
//   bookmarks, find-in-page, auto-fill, password generator, settings panel.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/browser/browser_engine.dart';
import '../../core/browser/browser_prefs.dart';
import '../../core/browser/password_manager.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

// ─── Colour aliases ──────────────────────────────────────────────────────────
const _bg    = AppTheme.background;
const _surf  = AppTheme.surface;
const _surf2 = AppTheme.surfaceAlt;
const _bord  = AppTheme.border;
const _txt   = AppTheme.textPrimary;
const _sub   = AppTheme.textSecondary;
const _green = Color(0xFF3FB950);
const _amber = Color(0xFFF59E0B);

// ─── Keyboard-shortcut intents ───────────────────────────────────────────────
class _NewTabIntent    extends Intent { const _NewTabIntent(); }
class _CloseTabIntent  extends Intent { const _CloseTabIntent(); }
class _FocusUrlIntent  extends Intent { const _FocusUrlIntent(); }
class _ReloadIntent    extends Intent { const _ReloadIntent(); }
class _FindIntent      extends Intent { const _FindIntent(); }
class _BookmarkIntent  extends Intent { const _BookmarkIntent(); }
class _NextTabIntent   extends Intent { const _NextTabIntent(); }
class _PrevTabIntent   extends Intent { const _PrevTabIntent(); }
class _IncognitoIntent extends Intent { const _IncognitoIntent(); }

// ─── Side-panel selector ─────────────────────────────────────────────────────
enum _Panel { none, settings, passwords, history, bookmarks }

// ─────────────────────────────────────────────────────────────────────────────
// BrowserScreen
// ─────────────────────────────────────────────────────────────────────────────
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen>
    with TickerProviderStateMixin {

  // ── Engine ────────────────────────────────────────────────────────────────
  late final BrowserEngine _engine;

  // ── WebKit overlay state ──────────────────────────────────────────────────
  final _contentKey = GlobalKey();
  int    _webX = 0, _webY = 0, _webW = 1280, _webH = 720;
  String? _pendingUrl;       // consumed by _onContentLayout
  bool    _webVisible = false;
  Timer?  _poller;
  String? _lastActiveTabId;  // detects tab switches

  // ── WebKit-reported nav state ─────────────────────────────────────────────
  bool _canBack = false, _canFwd = false;

  // ── URL bar ───────────────────────────────────────────────────────────────
  final _urlCtrl  = TextEditingController();
  final _urlFocus = FocusNode();

  // ── Find bar ──────────────────────────────────────────────────────────────
  final _findCtrl  = TextEditingController();
  final _findFocus = FocusNode();
  bool  _showFind  = false;

  // ── Side panel ────────────────────────────────────────────────────────────
  _Panel _panel = _Panel.none;
  late final AnimationController _panelAnim;
  late final Animation<double>   _panelSlide;

  // ── Password manager ──────────────────────────────────────────────────────
  List<SavedPassword> _savedPwds  = [];
  SavedPassword?      _autoFillHint;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _engine = BrowserEngine();
    _engine.addListener(_onEngineChanged);

    _panelAnim  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 210));
    _panelSlide = CurvedAnimation(parent: _panelAnim, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final snap = await BrowserPrefsStore.load();
      if (!mounted) return;
      _engine.hydrateFromPrefs(snap);
      _savedPwds = await PasswordManager.load();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    unawaited(SystemBridge.browserWebViewHide());
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    _urlCtrl.dispose();
    _urlFocus.dispose();
    _findCtrl.dispose();
    _findFocus.dispose();
    _panelAnim.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Engine listener + tab-switch handler
  // ─────────────────────────────────────────────────────────────────────────

  void _onEngineChanged() {
    if (!mounted) return;
    final curId = _engine.activeTab?.id;
    if (curId != _lastActiveTabId) {
      _lastActiveTabId = curId;
      _onTabSwitched();
    }
    setState(() {
      if (!_urlFocus.hasFocus) {
        final u = _engine.activeTab?.url ?? '';
        _urlCtrl.text = _isBlank(u) ? '' : u;
      }
    });
  }

  void _onTabSwitched() {
    final tab = _engine.activeTab;
    if (tab == null || _isBlank(tab.url)) {
      _pendingUrl = null;
      _autoFillHint = null;
      _poller?.cancel();
      if (_webVisible) {
        _webVisible = false;
        unawaited(SystemBridge.browserWebViewHide());
      }
    } else {
      _pendingUrl   = tab.url;
      _webVisible   = true;
      _autoFillHint = null;
      _startPoller();
      unawaited(_checkAutoFill(tab.url));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  bool _isBlank(String u) =>
      u.isEmpty || u == 'about:blank' || u == 'about:srcdoc';

  String _normalise(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'about:blank';
    if (t.startsWith('http://') || t.startsWith('https://') ||
        t.startsWith('about:')) return t;
    if (RegExp(r'^[a-zA-Z0-9.\-]+\.[a-z]{2,}(/.*)?$').hasMatch(t))
      return 'https://$t';
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(t)}';
  }

  String _domainOf(String url) {
    try { return Uri.parse(url).host.replaceFirst('www.', ''); }
    catch (_) { return url; }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _navigate(String raw) async {
    final url = _normalise(raw);
    _engine.navigate(raw);

    if (_isBlank(url)) {
      _pendingUrl   = null;
      _webVisible   = false;
      _autoFillHint = null;
      _poller?.cancel();
      setState(() { _urlCtrl.text = ''; });
      await SystemBridge.browserWebViewHide();
    } else {
      if (!_urlFocus.hasFocus) _urlCtrl.text = url;
      _pendingUrl   = url;
      _webVisible   = true;
      _autoFillHint = null;
      setState(() {});
      _startPoller();
      unawaited(_checkAutoFill(url));
    }
  }

  Future<void> _checkAutoFill(String url) async {
    final p = await PasswordManager.findForSite(url);
    if (!mounted) return;
    setState(() => _autoFillHint = p);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content layout → places/repositions the WebKit overlay
  // ─────────────────────────────────────────────────────────────────────────

  void _onContentLayout(BoxConstraints c) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;

      final pos = box.localToGlobal(Offset.zero);
      final x   = pos.dx.round();
      final y   = pos.dy.round();
      final w   = c.maxWidth .isFinite ? c.maxWidth .round().clamp(10, 8192) : 1280;
      final h   = c.maxHeight.isFinite ? c.maxHeight.round().clamp(10, 8192) : 720;

      final pending = _pendingUrl;
      if (pending != null && pending.isNotEmpty) {
        _pendingUrl = null;
        _webX = x; _webY = y; _webW = w; _webH = h;
        await SystemBridge.browserWebViewShow(pending, x, y, w, h);
      } else if (x != _webX || y != _webY || w != _webW || h != _webH) {
        _webX = x; _webY = y; _webW = w; _webH = h;
        SystemBridge.browserWebViewReposition(x, y, w, h);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WebKit state poller (500 ms)
  // ─────────────────────────────────────────────────────────────────────────

  void _startPoller() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted) { _poller?.cancel(); return; }
      final info = await SystemBridge.browserWebViewGetInfo();
      if (!mounted || info.isEmpty) return;

      final url      = info['url']          as String? ?? '';
      final title    = info['title']        as String? ?? '';
      final canBack  = info['canGoBack']    as bool?   ?? false;
      final canFwd   = info['canGoForward'] as bool?   ?? false;
      final loading  = info['isLoading']    as bool?   ?? false;
      final progress = (info['progress']    as num?)?.toDouble() ?? 0.0;

      setState(() {
        final tab = _engine.activeTab;
        if (tab != null) {
          if (url.isNotEmpty)   tab.url      = url;
          if (title.isNotEmpty) tab.title    = title;
          tab.isLoading = loading;
          tab.progress  = progress;
        }
        _canBack = canBack;
        _canFwd  = canFwd;
        if (!_urlFocus.hasFocus && url.isNotEmpty && !_isBlank(url))
          _urlCtrl.text = url;
      });
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Password manager — auto-fill, save dialog
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _doAutoFill() async {
    final s = _autoFillHint;
    if (s == null) return;
    final uEsc = _jsEscape(s.username);
    final pEsc = _jsEscape(s.password);
    final script =
        "(function(){"
        "var u=document.querySelector('input[type=email],input[type=text],"
        "input[name*=user],input[name*=email],input[name*=login]');"
        "var p=document.querySelector('input[type=password]');"
        "if(u){u.value='$uEsc';"
        "u.dispatchEvent(new Event('input',{bubbles:true}));}"
        "if(p){p.value='$pEsc';"
        "p.dispatchEvent(new Event('input',{bubbles:true}));}"
        "})()";
    await SystemBridge.browserJsRun(script);
    _showSnack('Auto-filled: ${s.username}');
  }

  String _jsEscape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '')
      .replaceAll('\r', '');

  Future<void> _showSavePasswordDialog({
    String? site, String? username, String? password}) async {
    if (!mounted) return;
    final siteCtrl = TextEditingController(
        text: site ?? _domainOf(_engine.activeTab?.url ?? ''));
    final userCtrl = TextEditingController(text: username ?? '');
    final passCtrl = TextEditingController(text: password ?? '');
    bool obscure = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, ss) => AlertDialog(
        backgroundColor: _surf2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _bord),
        ),
        title: const Text('Save Password',
            style: TextStyle(color: _txt, fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dlgField('Site / Domain', siteCtrl),
            const SizedBox(height: 12),
            _dlgField('Username / Email', userCtrl),
            const SizedBox(height: 12),
            _dlgField('Password', passCtrl, obscure: obscure,
              suffix: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                    size: 16, color: _sub),
                onPressed: () => ss(() => obscure = !obscure),
                padding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              TextButton.icon(
                icon: Icon(Icons.auto_fix_high_rounded, size: 14,
                    color: AppTheme.accent),
                label: Text('Generate password',
                    style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                onPressed: () =>
                    ss(() => passCtrl.text = PasswordManager.generate()),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                icon: const Icon(Icons.person_outline, size: 14, color: _sub),
                label: const Text('Username',
                    style: TextStyle(color: _sub, fontSize: 12)),
                onPressed: () =>
                    ss(() => userCtrl.text = PasswordManager.generateUsername()),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _sub, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent, foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final s = siteCtrl.text.trim();
              final p = passCtrl.text.trim();
              if (s.isEmpty || p.isEmpty) return;
              final pwd = SavedPassword(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                site: s, username: userCtrl.text.trim(), password: p,
              );
              await PasswordManager.add(pwd);
              _savedPwds = await PasswordManager.load();
              if (mounted) setState(() {});
              if (ctx.mounted) Navigator.pop(ctx);
              _showSnack('Password saved for $s');
            },
            child: const Text('Save'),
          ),
        ],
      )),
    );
  }

  Widget _dlgField(String label, TextEditingController ctrl,
      {bool obscure = false, Widget? suffix}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          color: _sub, fontSize: 11.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
          color: _surf, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bord),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: ctrl, obscureText: obscure,
              style: const TextStyle(color: _txt, fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          if (suffix != null) suffix,
        ]),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cookies / Find
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _clearCookies() async {
    await SystemBridge.browserCookiesClear();
    _showSnack('All cookies cleared');
  }

  Future<void> _findInPage(String q) async {
    if (q.isEmpty || !_webVisible) return;
    await SystemBridge.browserJsRun("window.find('${_jsEscape(q)}',false,false,true)");
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Panel helper
  // ─────────────────────────────────────────────────────────────────────────

  void _setPanel(_Panel p) {
    setState(() {
      if (_panel == p) { _panel = _Panel.none; _panelAnim.reverse(); }
      else             { _panel = p;           _panelAnim.forward(); }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Snackbar
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: err ? AppTheme.danger : _surf2,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Keyboard shortcuts
  // ─────────────────────────────────────────────────────────────────────────

  Map<ShortcutActivator, Intent> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.keyT, control: true):
        const _NewTabIntent(),
    const SingleActivator(LogicalKeyboardKey.keyW, control: true):
        const _CloseTabIntent(),
    const SingleActivator(LogicalKeyboardKey.keyL, control: true):
        const _FocusUrlIntent(),
    const SingleActivator(LogicalKeyboardKey.keyK, control: true):
        const _FocusUrlIntent(),
    const SingleActivator(LogicalKeyboardKey.keyR, control: true):
        const _ReloadIntent(),
    const SingleActivator(LogicalKeyboardKey.f5):
        const _ReloadIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const _FindIntent(),
    const SingleActivator(LogicalKeyboardKey.keyD, control: true):
        const _BookmarkIntent(),
    const SingleActivator(LogicalKeyboardKey.tab, control: true):
        const _NextTabIntent(),
    const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
        const _PrevTabIntent(),
    const SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true):
        const _IncognitoIntent(),
  };

  Map<Type, Action<Intent>> get _actions => {
    _NewTabIntent: CallbackAction<_NewTabIntent>(
        onInvoke: (_) { _engine.addTab(); return null; }),

    _CloseTabIntent: CallbackAction<_CloseTabIntent>(onInvoke: (_) {
      if (_engine.tabs.length > 1) {
        final i = _engine.activeTabIndex;
        _engine.closeTab(i);
        final u = _engine.activeTab?.url ?? '';
        if (_isBlank(u)) {
          _webVisible = false;
          unawaited(SystemBridge.browserWebViewHide());
        }
      }
      return null;
    }),

    _FocusUrlIntent: CallbackAction<_FocusUrlIntent>(onInvoke: (_) {
      _urlFocus.requestFocus();
      _urlCtrl.selection = TextSelection(
          baseOffset: 0, extentOffset: _urlCtrl.text.length);
      return null;
    }),

    _ReloadIntent: CallbackAction<_ReloadIntent>(onInvoke: (_) {
      if (_webVisible) unawaited(SystemBridge.browserWebViewReload());
      return null;
    }),

    _FindIntent: CallbackAction<_FindIntent>(onInvoke: (_) {
      setState(() {
        _showFind = !_showFind;
        if (_showFind) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _findFocus.requestFocus());
        } else {
          _findCtrl.clear();
        }
      });
      return null;
    }),

    _BookmarkIntent: CallbackAction<_BookmarkIntent>(onInvoke: (_) {
      final tab = _engine.activeTab;
      if (tab != null && !_isBlank(tab.url)) {
        if (_engine.isBookmarked(tab.url)) {
          final bm = _engine.bookmarks.firstWhere((b) => b.url == tab.url);
          _engine.removeBookmark(bm.id);
          _showSnack('Bookmark removed');
        } else {
          _engine.addBookmark(tab.url,
              tab.title.isEmpty ? _domainOf(tab.url) : tab.title);
          _showSnack('Bookmarked!');
        }
      }
      return null;
    }),

    _NextTabIntent: CallbackAction<_NextTabIntent>(onInvoke: (_) {
      _engine.switchTab(
          (_engine.activeTabIndex + 1) % _engine.tabs.length);
      return null;
    }),

    _PrevTabIntent: CallbackAction<_PrevTabIntent>(onInvoke: (_) {
      _engine.switchTab(
          (_engine.activeTabIndex - 1 + _engine.tabs.length) %
          _engine.tabs.length);
      return null;
    }),

    _IncognitoIntent: CallbackAction<_IncognitoIntent>(
        onInvoke: (_) { _engine.addTab(isIncognito: true); return null; }),
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _engine,
      child: Focus(
        autofocus: true,
        child: Shortcuts(
          shortcuts: _shortcuts,
          child: Actions(
            actions: _actions,
            child: Scaffold(
              backgroundColor: _bg,
              body: Column(children: [
                _buildTabStrip(),
                _buildNavBar(),
                if (_showFind) _buildFindBar(),
                Expanded(child: _buildBody()),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tab strip
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTabStrip() {
    return Consumer<BrowserEngine>(builder: (_, eng, __) {
      return Container(
        height: 40,
        color: const Color(0xFF070C10),
        child: Row(children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 4, top: 4),
              itemCount: eng.tabs.length,
              itemBuilder: (_, i) =>
                  _buildTab(eng.tabs[i], i, i == eng.activeTabIndex),
            ),
          ),
          _iBtn(Icons.add_rounded, 'New tab  Ctrl+T',
              () => _engine.addTab(), sz: 16),
          _iBtn(Icons.security_outlined, 'Incognito  Ctrl+Shift+N',
              () => _engine.addTab(isIncognito: true), sz: 15, col: _sub),
          if (eng.canRestoreClosedTab)
            _iBtn(Icons.restore_rounded, 'Reopen closed tab',
                () => _engine.restoreLastClosedTab(), sz: 15, col: _sub),
          const SizedBox(width: 4),
        ]),
      );
    });
  }

  Widget _buildTab(BrowserTab tab, int i, bool active) {
    final w = tab.isPinned ? 44.0 : 176.0;
    return GestureDetector(
      onTap: () => _engine.switchTab(i),
      onSecondaryTapDown: (d) => _tabCtxMenu(context, d.globalPosition, i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: w, height: 36,
        margin: const EdgeInsets.only(right: 1),
        decoration: BoxDecoration(
          color: active ? _surf : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          border: active
              ? const Border(
                  top:   BorderSide(color: _bord, width: 0.7),
                  left:  BorderSide(color: _bord, width: 0.7),
                  right: BorderSide(color: _bord, width: 0.7),
                )
              : null,
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          // Accent top stripe on active tab
          if (active)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: tab.isPinned ? 6 : 10),
            child: Row(children: [
              _tabIcon(tab),
              if (!tab.isPinned) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tab.title.isEmpty ? 'New Tab' : tab.title,
                    style: TextStyle(
                      color: active ? _txt : _sub,
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_engine.tabs.length > 1)
                  GestureDetector(
                    onTap: () {
                      final wasActive = i == _engine.activeTabIndex;
                      _engine.closeTab(i);
                      if (wasActive) {
                        final u = _engine.activeTab?.url ?? '';
                        if (_isBlank(u)) {
                          _webVisible = false;
                          unawaited(SystemBridge.browserWebViewHide());
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.close_rounded, size: 12,
                          color: _sub.withValues(alpha: 0.7)),
                    ),
                  ),
              ],
            ]),
          ),

          // Loading progress underline
          if (tab.isLoading && tab.progress > 0 && tab.progress < 1)
            Positioned(
              bottom: 0, left: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 2,
                width: w * tab.progress.clamp(0.0, 1.0),
                color: AppTheme.accent.withValues(alpha: 0.8),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _tabIcon(BrowserTab tab) {
    if (tab.isIncognito)
      return const Icon(Icons.security_rounded, size: 13,
          color: Color(0xFFA78BFA));
    if (tab.isPinned)
      return Icon(Icons.push_pin_rounded, size: 12, color: AppTheme.accent);
    if (tab.isLoading)
      return SizedBox.square(
        dimension: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(AppTheme.accent),
        ),
      );
    return Icon(
      _isBlank(tab.url) ? Icons.tab_rounded : Icons.language_rounded,
      size: 13, color: _sub,
    );
  }

  void _tabCtxMenu(BuildContext ctx, Offset pos, int i) {
    if (i < 0 || i >= _engine.tabs.length) return;
    final tab = _engine.tabs[i];
    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      color: _surf2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _bord),
      ),
      items: [
        _mi('dup',   Icons.content_copy_rounded,  'Duplicate tab'),
        _mi(tab.isPinned ? 'unpin' : 'pin',
            tab.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            tab.isPinned ? 'Unpin' : 'Pin tab'),
        _mi(tab.isMuted ? 'unmute' : 'mute',
            tab.isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            tab.isMuted ? 'Unmute' : 'Mute tab'),
        const PopupMenuDivider(height: 4),
        _mi('close_others', Icons.layers_clear_rounded, 'Close other tabs'),
        _mi('close', Icons.close_rounded, 'Close tab', col: AppTheme.danger),
      ],
    ).then((v) {
      if (v == null || i >= _engine.tabs.length) return;
      switch (v) {
        case 'dup':          _engine.duplicateTab(i); break;
        case 'pin':
        case 'unpin':        _engine.togglePinTab(i); break;
        case 'mute':
        case 'unmute':       _engine.toggleMuteTab(i); break;
        case 'close_others': _engine.closeOtherTabs(i); break;
        case 'close':        _engine.closeTab(i); break;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    return Consumer<BrowserEngine>(builder: (_, eng, __) {
      final tab     = eng.activeTab;
      final url     = tab?.url      ?? '';
      final loading = tab?.isLoading ?? false;
      final starred = !_isBlank(url) && eng.isBookmarked(url);

      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: const BoxDecoration(
          color: _surf,
          border: Border(bottom: BorderSide(color: _bord, width: 0.8)),
        ),
        child: Row(children: [
          _navBtn(Icons.arrow_back_ios_new_rounded, _canBack,
              () => SystemBridge.browserWebViewBack(), tip: 'Back'),
          _navBtn(Icons.arrow_forward_ios_rounded, _canFwd,
              () => SystemBridge.browserWebViewForward(), tip: 'Forward'),
          _navBtn(
            loading ? Icons.close_rounded : Icons.refresh_rounded, true,
            () => loading
                ? SystemBridge.browserWebViewStop()
                : SystemBridge.browserWebViewReload(),
            tip: loading ? 'Stop' : 'Reload  Ctrl+R',
          ),
          _navBtn(Icons.home_outlined, true,
              () => unawaited(_navigate('about:blank')), tip: 'Home'),

          const SizedBox(width: 6),
          Expanded(child: _buildUrlBar(url, loading)),
          const SizedBox(width: 6),

          // Auto-fill key icon (only when we have a matching password)
          if (_autoFillHint != null)
            _iBtn(Icons.key_rounded,
                'Auto-fill: ${_autoFillHint!.username}',
                _doAutoFill, col: AppTheme.accent, sz: 15),

          // Bookmark star
          _iBtn(
            starred ? Icons.star_rounded : Icons.star_border_rounded,
            starred ? 'Remove bookmark' : 'Bookmark  Ctrl+D',
            () {
              if (_isBlank(url)) return;
              if (starred) {
                final bm = eng.bookmarks.firstWhere((b) => b.url == url);
                eng.removeBookmark(bm.id);
              } else {
                eng.addBookmark(url,
                    (tab?.title.isEmpty ?? true)
                        ? _domainOf(url)
                        : tab!.title);
                _showSnack('Bookmarked!');
              }
            },
            col: starred ? const Color(0xFFF5A623) : _sub,
          ),

          // Save password
          _iBtn(Icons.lock_outline_rounded, 'Save password',
              () => unawaited(_showSavePasswordDialog()), col: _sub, sz: 15),

          // Side-panel toggles
          _panelBtn(Icons.history_rounded,        'History',   _Panel.history),
          _panelBtn(Icons.bookmark_border_rounded, 'Bookmarks', _Panel.bookmarks),
          _panelBtn(Icons.settings_rounded,        'Settings',  _Panel.settings),
        ]),
      );
    });
  }

  Widget _buildUrlBar(String url, bool loading) {
    final isHttps = url.startsWith('https://');
    final isHttp  = url.startsWith('http://');
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: _surf2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _urlFocus.hasFocus
              ? AppTheme.accent.withValues(alpha: 0.5)
              : _bord,
          width: 0.9,
        ),
      ),
      child: Row(children: [
        const SizedBox(width: 10),
        Icon(
          isHttps ? Icons.lock_rounded
              : isHttp ? Icons.lock_open_rounded
              : Icons.search_rounded,
          size: 13,
          color: isHttps ? _green : isHttp ? _amber : _sub,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: TextField(
            controller: _urlCtrl, focusNode: _urlFocus,
            style: const TextStyle(color: _txt, fontSize: 13),
            decoration: InputDecoration(
              border: InputBorder.none, isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'Search or enter a URL...',
              hintStyle: TextStyle(
                  color: _sub.withValues(alpha: 0.55), fontSize: 13),
            ),
            onTap: () => _urlCtrl.selection = TextSelection(
                baseOffset: 0, extentOffset: _urlCtrl.text.length),
            onSubmitted: (v) {
              _urlFocus.unfocus();
              unawaited(_navigate(v));
            },
          ),
        ),
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(AppTheme.accent),
              ),
            ),
          )
        else
          GestureDetector(
            onTap: () {
              _urlFocus.unfocus();
              unawaited(_navigate(_urlCtrl.text));
            },
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_forward_rounded, size: 13,
                  color: AppTheme.accent),
            ),
          ),
        const SizedBox(width: 3),
      ]),
    );
  }

  Widget _navBtn(IconData icon, bool enabled, VoidCallback fn,
      {String tip = ''}) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: enabled ? fn : null,
        child: Container(
          width: 30, height: 30,
          margin: const EdgeInsets.only(right: 2),
          child: Icon(icon, size: 15,
              color: enabled ? _txt : _sub.withValues(alpha: 0.25)),
        ),
      ),
    );
  }

  Widget _panelBtn(IconData icon, String tip, _Panel p) {
    final active = _panel == p;
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: () => _setPanel(p),
        child: Container(
          width: 30, height: 30,
          margin: const EdgeInsets.only(left: 2),
          decoration: active
              ? BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Icon(icon, size: 16,
              color: active ? AppTheme.accent : _sub),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Find bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildFindBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: _surf2,
        border: Border(bottom: BorderSide(color: _bord, width: 0.8)),
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 15, color: _sub),
        const SizedBox(width: 8),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _findCtrl, focusNode: _findFocus,
            style: const TextStyle(color: _txt, fontSize: 13),
            decoration: InputDecoration(
              border: InputBorder.none, isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'Find in page...',
              hintStyle: TextStyle(
                  color: _sub.withValues(alpha: 0.55), fontSize: 13),
            ),
            onChanged: _findInPage,
            onSubmitted: _findInPage,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() { _showFind = false; _findCtrl.clear(); }),
          style: TextButton.styleFrom(
              foregroundColor: _sub,
              textStyle: const TextStyle(fontSize: 12),
              minimumSize: const Size(50, 32)),
          child: const Text('Close'),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Body = content + optional side panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return Row(children: [
      Expanded(child: _buildContent()),
      if (_panel != _Panel.none)
        SizeTransition(
          sizeFactor: _panelSlide,
          axis: Axis.horizontal,
          axisAlignment: 1.0,
          child: _buildSidePanel(),
        ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content area
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    return Consumer<BrowserEngine>(builder: (_, eng, __) {
      final tab = eng.activeTab;

      if (tab == null || _isBlank(tab.url)) {
        // Ensure WebKit is hidden when blank tab is shown
        if (_webVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _webVisible = false;
            unawaited(SystemBridge.browserWebViewHide());
          });
        }
        return _buildNewTabPage();
      }

      return LayoutBuilder(builder: (ctx, constraints) {
        _onContentLayout(constraints);
        return SizedBox.expand(
          key: _contentKey,
          child: Stack(children: [
            // Dark fill — WebKit GTK overlay renders on top of this
            Container(color: const Color(0xFF050A0E)),
            // Loading progress bar
            if (tab.isLoading)
              Positioned(
                top: 0, left: 0, right: 0,
                child: LinearProgressIndicator(
                  value: (tab.progress <= 0 || tab.progress >= 1)
                      ? null : tab.progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(AppTheme.accent),
                  minHeight: 2,
                ),
              ),
          ]),
        );
      });
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // New-tab page
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNewTabPage() {
    const sites = [
      ('Google',     'https://google.com',               Icons.search_rounded,        Color(0xFF4285F4)),
      ('YouTube',    'https://youtube.com',              Icons.play_circle_outline,   Color(0xFFFF0000)),
      ('GitHub',     'https://github.com',               Icons.code_rounded,          Color(0xFF6E76E5)),
      ('Gmail',      'https://mail.google.com',          Icons.email_rounded,         Color(0xFFEA4335)),
      ('Twitter/X',  'https://x.com',                   Icons.tag_rounded,           Color(0xFF1DA1F2)),
      ('Reddit',     'https://reddit.com',               Icons.forum_rounded,         Color(0xFFFF4500)),
      ('Wikipedia',  'https://wikipedia.org',            Icons.menu_book_rounded,     Color(0xFFE6EDF3)),
      ('HackerNews', 'https://news.ycombinator.com',     Icons.trending_up_rounded,   Color(0xFFFF6600)),
    ];

    return Consumer<BrowserEngine>(builder: (_, eng, __) {
      return Container(
        color: _bg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Branding
                Center(child: Column(children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.language_rounded, size: 26, color: AppTheme.accent),
                    const SizedBox(width: 10),
                    Text('KrdOS Browser',
                        style: TextStyle(
                          color: AppTheme.accent, fontSize: 22,
                          fontWeight: FontWeight.w700, letterSpacing: 0.5,
                        )),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Private. Fast. Yours.',
                      style: TextStyle(color: _sub, fontSize: 13)),
                ])),

                const SizedBox(height: 30),

                // Search bar
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _surf2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _bord),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20, offset: const Offset(0, 6)),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, color: _sub, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        style: const TextStyle(color: _txt, fontSize: 15),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search the web or enter a URL',
                          hintStyle: TextStyle(
                              color: _sub.withValues(alpha: 0.6), fontSize: 15),
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty)
                            unawaited(_navigate(v.trim()));
                        },
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 30),

                // Quick sites
                const Text('Quick access',
                    style: TextStyle(color: _sub, fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 0.7)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, mainAxisExtent: 88,
                    crossAxisSpacing: 10, mainAxisSpacing: 10,
                  ),
                  itemCount: sites.length,
                  itemBuilder: (_, i) {
                    final (name, url, icon, color) = sites[i];
                    return _quickSiteCard(name, url, icon, color);
                  },
                ),

                // Recent history
                if (eng.history.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Row(children: [
                    const Icon(Icons.history_rounded, size: 13, color: _sub),
                    const SizedBox(width: 7),
                    const Text('Recently visited',
                        style: TextStyle(color: _sub, fontSize: 11,
                            fontWeight: FontWeight.w700, letterSpacing: 0.7)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _setPanel(_Panel.history),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      child: Text('See all',
                          style: TextStyle(
                              color: AppTheme.accent, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ...eng.history.take(5).map(_historyRow),
                ],
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _quickSiteCard(
      String name, String url, IconData icon, Color color) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => unawaited(_navigate(url)),
        child: Container(
          decoration: BoxDecoration(
            color: _surf,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _bord, width: 0.8),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(name, style: const TextStyle(
                color: _txt, fontSize: 11.5, fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }

  Widget _historyRow(HistoryEntry e) {
    return GestureDetector(
      onTap: () => unawaited(_navigate(e.url)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _surf,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _bord, width: 0.6),
        ),
        child: Row(children: [
          const Icon(Icons.language_rounded, size: 13, color: _sub),
          const SizedBox(width: 10),
          Expanded(
            child: Text(e.title.isEmpty ? e.url : e.title,
                style: const TextStyle(color: _txt, fontSize: 12.5),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(_domainOf(e.url),
              style: TextStyle(
                  color: _sub.withValues(alpha: 0.65), fontSize: 11)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Side panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSidePanel() {
    return Container(
      width: 310,
      decoration: const BoxDecoration(
        color: _surf,
        border: Border(left: BorderSide(color: _bord, width: 0.8)),
      ),
      child: switch (_panel) {
        _Panel.settings  => _buildSettingsPanel(),
        _Panel.passwords => _buildPasswordsPanel(),
        _Panel.history   => _buildHistoryPanel(),
        _Panel.bookmarks => _buildBookmarksPanel(),
        _Panel.none      => const SizedBox.shrink(),
      },
    );
  }

  Widget _panelHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _bord, width: 0.8))),
      child: Row(children: [
        Icon(icon, size: 15, color: AppTheme.accent),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(
            color: _txt, fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 15, color: _sub),
          onPressed: () => _setPanel(_Panel.none),
          padding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Settings panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSettingsPanel() {
    return Consumer<BrowserEngine>(builder: (_, eng, __) {
      return Column(children: [
        _panelHeader('Settings', Icons.settings_rounded),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              _sLabel('Search Engine'),
              ...['google', 'bing', 'duckduckgo'].map((e) =>
                RadioListTile<String>(
                  dense: true,
                  value: e, groupValue: eng.searchEngine,
                  title: Text(_engineLabel(e),
                      style: const TextStyle(color: _txt, fontSize: 12.5)),
                  activeColor: AppTheme.accent,
                  onChanged: (v) { if (v != null) eng.setSearchEngine(v); },
                ),
              ),

              const Divider(color: _bord, height: 20),
              _sLabel('Privacy & Security'),
              _toggle('HTTPS preferred', eng.httpsPreferred,
                  eng.setHttpsPreferred),
              _toggle('Block dangerous URLs', eng.dangerousSchemeBlock,
                  eng.setDangerousSchemeBlock),
              _toggle('Strict JavaScript mode', eng.strictJavaScript,
                  eng.setStrictJavaScript),

              const Divider(color: _bord, height: 20),
              _sLabel('Cookies & Data'),
              _actTile('Clear all cookies', Icons.cookie_outlined,
                  _clearCookies, col: AppTheme.danger),
              _actTile('Clear browsing history', Icons.history_rounded, () {
                eng.clearHistory();
                _showSnack('History cleared');
              }, col: AppTheme.danger),

              const Divider(color: _bord, height: 20),
              _sLabel('Passwords'),
              _actTile('View saved passwords', Icons.key_rounded,
                  () => _setPanel(_Panel.passwords)),
              _actTile('Add password manually', Icons.add_rounded,
                  () => unawaited(_showSavePasswordDialog())),

              const Divider(color: _bord, height: 20),
              _sLabel('Interface'),
              _toggle('Show bookmarks bar', eng.showBookmarksBar,
                  eng.setShowBookmarksBar),
            ],
          ),
        ),
      ]);
    });
  }

  Widget _sLabel(String t) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 2, left: 4),
    child: Text(t, style: const TextStyle(
        color: _sub, fontSize: 11,
        fontWeight: FontWeight.w700, letterSpacing: 0.6)),
  );

  Widget _toggle(String label, bool val, void Function(bool) fn) =>
    SwitchListTile(
      dense: true,
      title: Text(label, style: const TextStyle(color: _txt, fontSize: 12.5)),
      value: val, onChanged: fn, activeColor: AppTheme.accent,
    );

  Widget _actTile(String label, IconData icon, VoidCallback fn, {Color? col}) =>
    ListTile(
      dense: true,
      leading: Icon(icon, size: 15, color: col ?? _sub),
      title: Text(label, style: TextStyle(color: col ?? _txt, fontSize: 12.5)),
      onTap: fn,
    );

  String _engineLabel(String e) => switch (e) {
    'bing'       => 'Bing',
    'duckduckgo' => 'DuckDuckGo',
    _            => 'Google',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Passwords panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPasswordsPanel() {
    return Column(children: [
      _panelHeader('Saved Passwords', Icons.key_rounded),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 14),
            label: const Text('Add Password',
                style: TextStyle(fontSize: 12)),
            onPressed: () => unawaited(_showSavePasswordDialog()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: _savedPwds.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_open_rounded,
                    size: 44, color: _bord),
                const SizedBox(height: 12),
                const Text('No saved passwords',
                    style: TextStyle(color: _sub, fontSize: 13)),
                const SizedBox(height: 5),
                const Text(
                    'Save passwords to auto-fill\non login pages.',
                    style: TextStyle(color: _sub, fontSize: 11.5),
                    textAlign: TextAlign.center),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _savedPwds.length,
                itemBuilder: (_, i) => _passwordTile(_savedPwds[i]),
              ),
      ),
    ]);
  }

  Widget _passwordTile(SavedPassword p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surf2, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bord, width: 0.7),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(Icons.language_rounded, size: 14,
                color: AppTheme.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.site, style: const TextStyle(
                  color: _txt, fontSize: 13, fontWeight: FontWeight.w600)),
              if (p.username.isNotEmpty)
                Text(p.username,
                    style: const TextStyle(color: _sub, fontSize: 11.5)),
            ],
          )),
          _iBtn(Icons.copy_rounded, 'Copy password', () async {
            await Clipboard.setData(ClipboardData(text: p.password));
            _showSnack('Password copied');
          }, sz: 13, col: _sub),
          _iBtn(Icons.auto_fix_high_rounded, 'Auto-fill', () async {
            setState(() => _autoFillHint = p);
            _setPanel(_Panel.none);
            await _doAutoFill();
          }, sz: 13, col: AppTheme.accent),
          _iBtn(Icons.edit_rounded, 'Edit', () => unawaited(
              _showSavePasswordDialog(
                site: p.site, username: p.username, password: p.password)),
              sz: 13, col: _sub),
          _iBtn(Icons.delete_outline_rounded, 'Delete', () async {
            await PasswordManager.remove(p.id);
            _savedPwds = await PasswordManager.load();
            if (mounted) setState(() {});
            _showSnack('Password deleted');
          }, sz: 13, col: AppTheme.danger),
        ]),
        const SizedBox(height: 7),
        Row(children: [
          const Text('Password: ',
              style: TextStyle(color: _sub, fontSize: 11)),
          Text('•' * math.min(p.password.length, 14),
              style: const TextStyle(
                  color: _sub, fontSize: 9, letterSpacing: 1.5)),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // History panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHistoryPanel() {
    return Consumer<BrowserEngine>(builder: (_, eng, __) {
      return Column(children: [
        _panelHeader('History', Icons.history_rounded),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            Text('${eng.history.length} entries',
                style: const TextStyle(color: _sub, fontSize: 12)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 13),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
              onPressed: () {
                eng.clearHistory();
                _showSnack('History cleared');
              },
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  visualDensity: VisualDensity.compact),
            ),
          ]),
        ),
        Expanded(
          child: eng.history.isEmpty
              ? const Center(child: Text('No history',
                    style: TextStyle(color: _sub, fontSize: 13)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: eng.history.length,
                  itemBuilder: (_, i) {
                    final e = eng.history[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.language_rounded,
                          size: 13, color: _sub),
                      title: Text(e.title.isEmpty ? e.url : e.title,
                          style: const TextStyle(color: _txt, fontSize: 12.5),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_domainOf(e.url),
                          style: const TextStyle(color: _sub, fontSize: 11),
                          maxLines: 1),
                      onTap: () {
                        _setPanel(_Panel.none);
                        unawaited(_navigate(e.url));
                      },
                    );
                  },
                ),
        ),
      ]);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bookmarks panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBookmarksPanel() {
    return Consumer<BrowserEngine>(builder: (_, eng, __) {
      return Column(children: [
        _panelHeader('Bookmarks', Icons.bookmark_rounded),
        const SizedBox(height: 4),
        Expanded(
          child: eng.bookmarks.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bookmark_border_rounded,
                      size: 44, color: _bord),
                  const SizedBox(height: 12),
                  const Text('No bookmarks yet',
                      style: TextStyle(color: _sub, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Press Ctrl+D to bookmark the current page.',
                      style: TextStyle(
                          color: _sub.withValues(alpha: 0.7), fontSize: 11.5),
                      textAlign: TextAlign.center),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  itemCount: eng.bookmarks.length,
                  itemBuilder: (_, i) {
                    final bm = eng.bookmarks[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      decoration: BoxDecoration(
                        color: _surf2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _bord, width: 0.6),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.bookmark_rounded,
                            size: 14, color: AppTheme.accent),
                        title: Text(bm.title,
                            style: const TextStyle(
                                color: _txt, fontSize: 12.5),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_domainOf(bm.url),
                            style: const TextStyle(
                                color: _sub, fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 14, color: _sub),
                          onPressed: () => eng.removeBookmark(bm.id),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        onTap: () {
                          _setPanel(_Panel.none);
                          unawaited(_navigate(bm.url));
                        },
                      ),
                    );
                  },
                ),
        ),
      ]);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Utility widgets
  // ─────────────────────────────────────────────────────────────────────────

  Widget _iBtn(IconData icon, String tip, VoidCallback fn,
      {double sz = 16, Color? col}) {
    return Tooltip(
      message: tip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: fn,
          child: Container(
            width: 30, height: 30,
            alignment: Alignment.center,
            child: Icon(icon, size: sz, color: col ?? _sub),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _mi(String v, IconData icon, String label,
      {Color? col}) {
    return PopupMenuItem<String>(
      value: v, height: 36,
      child: Row(children: [
        Icon(icon, size: 14, color: col ?? _sub),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: col ?? _txt, fontSize: 12)),
      ]),
    );
  }
}
