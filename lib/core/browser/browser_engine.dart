import 'dart:collection';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'browser_models.dart';
import 'browser_prefs.dart';

// - Browser Tab Model -
class BrowserTab {
  final String id;
  String url;
  String title;
  String favicon;
  bool isLoading;
  bool canGoBack;
  bool canGoForward;
  double progress;
  bool isIncognito;
  bool isPinned;
  bool isMuted;
  DateTime created;
  List<String> history;
  int historyIndex;
  
  BrowserTab({
    required this.id,
    this.url = 'about:blank',
    this.title = 'New Tab',
    this.favicon = '',
    this.isLoading = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.progress = 0.0,
    this.isIncognito = false,
    this.isPinned = false,
    this.isMuted = false,
    DateTime? created,
    List<String>? history,
    this.historyIndex = 0,
  }) : created = created ?? DateTime.now(),
       history = history ?? [url];
}

/// Snapshot for ?Reopen closed tab?.
class ClosedTabSnapshot {
  final String url;
  final String title;
  final bool isIncognito;
  final bool wasPinned;

  const ClosedTabSnapshot({
    required this.url,
    required this.title,
    required this.isIncognito,
    this.wasPinned = false,
  });
}

// - Browser Engine State -
class BrowserEngine extends ChangeNotifier {
  final List<BrowserTab> _tabs = [];
  int _activeTabIndex = 0;
  bool _isFullscreen = false;
  String _searchEngine = 'google'; // google, bing, duckduckgo
  bool _adBlockEnabled = true;
  bool _trackingProtection = true;
  bool _autoFillEnabled = true;
  bool _showBookmarksBar = true;
  bool _httpsPreferred = true;
  bool _dangerousSchemeBlock = true;
  bool _strictJavaScript = false;
  double _zoomLevel = 1.0;
  BrowserShellBackend _shellBackend = BrowserShellBackend.chromiumEmbedded;
  bool _promptShellOnEveryOpen = false;
  String? _torBrowserExecutablePath;
  String _torSocksHost = '127.0.0.1';
  int _torSocksPort = 9050;
  final List<StarterShortcut> _starterShortcuts = [];
  static const int _maxClosedTabs = 15;
  final Queue<ClosedTabSnapshot> _closedTabs = Queue<ClosedTabSnapshot>();
  
  // Bookmarks
  final List<Bookmark> _bookmarks = [];
  
  // Downloads
  final List<Download> _downloads = [];
  
  // History
  final List<HistoryEntry> _history = [];
  
  // Getters
  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  BrowserTab? get activeTab => _tabs.isEmpty ? null : _tabs[_activeTabIndex];
  int get activeTabIndex => _activeTabIndex;
  bool get isFullscreen => _isFullscreen;
  String get searchEngine => _searchEngine;
  bool get adBlockEnabled => _adBlockEnabled;
  bool get trackingProtection => _trackingProtection;
  bool get autoFillEnabled => _autoFillEnabled;
  bool get showBookmarksBar => _showBookmarksBar;
  double get zoomLevel => _zoomLevel;
  bool get canRestoreClosedTab => _closedTabs.isNotEmpty;
  List<Bookmark> get bookmarks => List.unmodifiable(_bookmarks);
  List<Download> get downloads => List.unmodifiable(_downloads);
  List<HistoryEntry> get history => List.unmodifiable(_history);
  BrowserShellBackend get shellBackend => _shellBackend;
  bool get promptShellOnEveryOpen => _promptShellOnEveryOpen;
  String? get torBrowserExecutablePath => _torBrowserExecutablePath;
  String get torSocksHost => _torSocksHost;
  int get torSocksPort => _torSocksPort;
  List<StarterShortcut> get starterShortcuts => List.unmodifiable(_starterShortcuts);
  bool get httpsPreferred => _httpsPreferred;
  bool get dangerousSchemeBlock => _dangerousSchemeBlock;
  bool get strictJavaScript => _strictJavaScript;
  
  BrowserEngine() {
    _initializeDefaultTab();
  }

  void hydrateFromPrefs(BrowserPrefsSnapshot snapshot) {
    _shellBackend = snapshot.shell;
    _promptShellOnEveryOpen = snapshot.promptShellOnEveryOpen;
    _torBrowserExecutablePath = snapshot.torBrowserExecutablePath;
    _torSocksHost = snapshot.torSocksHost;
    _torSocksPort = snapshot.torSocksPort;
    final starterShortcuts = snapshot.starterShortcuts;
    _starterShortcuts
      ..clear()
      ..addAll(starterShortcuts);
    _httpsPreferred = snapshot.httpsPreferred;
    _dangerousSchemeBlock = snapshot.dangerousSchemeBlock;
    _strictJavaScript = snapshot.strictJavaScript;
    notifyListeners();
  }

  Future<void> _persistPrivacyHardFlags() => BrowserPrefsStore.savePrivacyHardFlags(
        httpsPreferred: _httpsPreferred,
        dangerousSchemeBlock: _dangerousSchemeBlock,
        strictJavaScript: _strictJavaScript,
      );

  Future<void> setShellBackend(BrowserShellBackend backend, {
    required bool persistChoiceCommitted,
    bool? promptShellOnEveryOpen,
  }) async {
    _shellBackend = backend;
    if (promptShellOnEveryOpen != null) {
      _promptShellOnEveryOpen = promptShellOnEveryOpen;
    }
    notifyListeners();
    await BrowserPrefsStore.saveShellChoice(
      shell: backend,
      committed: persistChoiceCommitted,
      promptOnEveryOpen: _promptShellOnEveryOpen,
    );
  }

  Future<void> setPromptShellOnEveryOpen(bool value) async {
    if (_promptShellOnEveryOpen == value) return;
    _promptShellOnEveryOpen = value;
    notifyListeners();
    await BrowserPrefsStore.saveShellChoice(
      shell: _shellBackend,
      committed: true,
      promptOnEveryOpen: value,
    );
  }

  Future<void> setTorBrowserExecutablePath(String? path) async {
    _torBrowserExecutablePath = path;
    notifyListeners();
    await BrowserPrefsStore.saveTorExecutablePath(path);
  }

  Future<void> setTorSocksEndpoint({required String host, required int port}) async {
    _torSocksHost = host.trim().isEmpty ? '127.0.0.1' : host.trim();
    _torSocksPort = port < 1 || port > 65535 ? 9050 : port;
    notifyListeners();
    await BrowserPrefsStore.saveTorSocksEndpoint(host: _torSocksHost, port: _torSocksPort);
  }

  void addStarterShortcut({String? id, required String title, required String url, int? iconCodePoint}) {
    final trimmedUrl = url.trim();
    final trimmedTitle = title.trim();
    if (trimmedUrl.isEmpty || trimmedTitle.isEmpty) return;
    _starterShortcuts.add(StarterShortcut(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: trimmedTitle,
      url: trimmedUrl,
      iconCodePoint: iconCodePoint,
    ));
    _persistShortcuts();
    notifyListeners();
  }

  void updateStarterShortcut(String id, {String? title, String? url, int? iconCodePoint}) {
    final i = _starterShortcuts.indexWhere((s) => s.id == id);
    if (i < 0) return;
    if (title != null) _starterShortcuts[i].title = title.trim();
    if (url != null) _starterShortcuts[i].url = url.trim();
    if (iconCodePoint != null) _starterShortcuts[i].iconCodePoint = iconCodePoint;
    _persistShortcuts();
    notifyListeners();
  }

  void removeStarterShortcut(String id) {
    _starterShortcuts.removeWhere((s) => s.id == id);
    _persistShortcuts();
    notifyListeners();
  }

  void reorderStarterShortcut(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _starterShortcuts.length) return;
    if (newIndex < 0 || newIndex > _starterShortcuts.length) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _starterShortcuts.removeAt(oldIndex);
    _starterShortcuts.insert(newIndex, item);
    _persistShortcuts();
    notifyListeners();
  }

  Future<void> _persistShortcuts() => BrowserPrefsStore.saveStarterShortcuts(_starterShortcuts);

  void setHttpsPreferred(bool value) {
    if (_httpsPreferred == value) return;
    _httpsPreferred = value;
    notifyListeners();
    unawaited(_persistPrivacyHardFlags());
  }

  void setDangerousSchemeBlock(bool value) {
    if (_dangerousSchemeBlock == value) return;
    _dangerousSchemeBlock = value;
    notifyListeners();
    unawaited(_persistPrivacyHardFlags());
  }

  void setStrictJavaScript(bool value) {
    if (_strictJavaScript == value) return;
    _strictJavaScript = value;
    notifyListeners();
    unawaited(_persistPrivacyHardFlags());
  }
  
  void _initializeDefaultTab() {
    addTab();
  }
  
  // - Tab Management -
  void addTab({String? url, bool isIncognito = false, bool pinned = false}) {
    final tab = BrowserTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url ?? 'about:blank',
      title: url ?? 'New Tab',
      isIncognito: isIncognito,
      isPinned: pinned,
    );
    if (pinned) {
      int insertAt = 0;
      while (insertAt < _tabs.length && _tabs[insertAt].isPinned) {
        insertAt++;
      }
      _tabs.insert(insertAt, tab);
      _activeTabIndex = insertAt;
    } else {
      _tabs.add(tab);
      _activeTabIndex = _tabs.length - 1;
    }
    notifyListeners();
  }

  void _rememberClosedTab(BrowserTab tab) {
    if (tab.url == 'about:blank' || tab.url.isEmpty) return;
    _closedTabs.addFirst(ClosedTabSnapshot(
      url: tab.url,
      title: tab.title,
      isIncognito: tab.isIncognito,
      wasPinned: tab.isPinned,
    ));
    while (_closedTabs.length > _maxClosedTabs) {
      _closedTabs.removeLast();
    }
  }

  /// Reopens the most recently closed tab (URL + mode). WebView state is not restored.
  void restoreLastClosedTab() {
    if (_closedTabs.isEmpty) return;
    final snap = _closedTabs.removeFirst();
    addTab(url: snap.url, isIncognito: snap.isIncognito, pinned: snap.wasPinned);
    navigate(snap.url);
  }
  
  void closeTab(int index) {
    if (_tabs.length <= 1) return;
    if (index < 0 || index >= _tabs.length) return;
    _rememberClosedTab(_tabs[index]);
    final wasActive = index == _activeTabIndex;
    _tabs.removeAt(index);
    if (wasActive) {
      _activeTabIndex =
          index < _tabs.length ? index : (_tabs.isEmpty ? 0 : _tabs.length - 1);
    } else if (index < _activeTabIndex) {
      _activeTabIndex--;
    }
    notifyListeners();
  }

  void togglePinTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    final id = tab.id;
    tab.isPinned = !tab.isPinned;
    _tabs.removeAt(index);
    int insertAt = 0;
    while (insertAt < _tabs.length && _tabs[insertAt].isPinned) {
      insertAt++;
    }
    _tabs.insert(insertAt, tab);
    final newIdx = _tabs.indexWhere((t) => t.id == id);
    _activeTabIndex = newIdx >= 0 ? newIdx : 0;
    notifyListeners();
  }

  void closeOtherTabs(int keepIndex) {
    if (keepIndex < 0 || keepIndex >= _tabs.length) return;
    final keepId = _tabs[keepIndex].id;
    for (var i = _tabs.length - 1; i >= 0; i--) {
      if (i == keepIndex) continue;
      if (_tabs.length <= 1) break;
      _rememberClosedTab(_tabs[i]);
      _tabs.removeAt(i);
    }
    _activeTabIndex = _tabs.indexWhere((t) => t.id == keepId);
    if (_activeTabIndex < 0) _activeTabIndex = 0;
    notifyListeners();
  }

  void closeTabsToTheRight(int index) {
    if (index < 0 || index >= _tabs.length) return;
    for (var i = _tabs.length - 1; i > index; i--) {
      if (_tabs.length <= 1) break;
      _rememberClosedTab(_tabs[i]);
      _tabs.removeAt(i);
    }
    _activeTabIndex = _activeTabIndex.clamp(0, _tabs.length - 1);
    notifyListeners();
  }

  void toggleMuteTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _tabs[index].isMuted = !_tabs[index].isMuted;
    notifyListeners();
  }
  
  void switchTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }
  
  void duplicateTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      final original = _tabs[index];
      final duplicate = BrowserTab(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: original.url,
        title: original.title,
        favicon: original.favicon,
        isIncognito: original.isIncognito,
        isPinned: false,
      );
      _tabs.insert(index + 1, duplicate);
      _activeTabIndex = index + 1;
      notifyListeners();
    }
  }
  
  void moveTab(int from, int to) {
    if (from >= 0 && from < _tabs.length && to >= 0 && to < _tabs.length) {
      final tab = _tabs.removeAt(from);
      _tabs.insert(to, tab);
      _activeTabIndex = to;
      notifyListeners();
    }
  }
  
  // - Navigation -
  void navigate(String url) {
    if (activeTab == null) return;
    
  // Process URL
    final processedUrl = _processUrl(url);
    
    activeTab!.url = processedUrl;
    activeTab!.isLoading = true;
    activeTab!.progress = 0.0;
    
  // Add to history
    if (activeTab!.historyIndex < activeTab!.history.length - 1) {
      activeTab!.history = activeTab!.history.sublist(0, activeTab!.historyIndex + 1);
    }
    activeTab!.history.add(processedUrl);
    activeTab!.historyIndex = activeTab!.history.length - 1;
    
    _updateNavigationState();
    _addToHistory(processedUrl);
    notifyListeners();
    
  // Simulate loading
    _simulatePageLoad();
  }
  
  String _processUrl(String input) {
    input = input.trim();

    String out;
  // If it's a search query (no dots, no protocol)
    if (!input.contains('.') && !input.startsWith('http')) {
      out = _getSearchUrl(input);
    } else if (!input.startsWith('http://') && !input.startsWith('https://')) {
      out = 'https://$input';
    } else {
      out = input;
    }

    return _preferHttpsUpgrade(out);
  }

  /// Best-effort `http:` ? `https:` when privacy hardening is on.
  String _preferHttpsUpgrade(String url) {
    if (!_httpsPreferred || !url.startsWith('http://')) return url;
    return url.replaceFirst('http://', 'https://');
  }
  
  String _getSearchUrl(String query) {
    final encoded = Uri.encodeComponent(query);
    switch (_searchEngine) {
      case 'google':
        return 'https://www.google.com/search?q=$encoded';
      case 'bing':
        return 'https://www.bing.com/search?q=$encoded';
      case 'duckduckgo':
        return 'https://duckduckgo.com/?q=$encoded';
      default:
        return 'https://www.google.com/search?q=$encoded';
    }
  }
  
  void goBack() {
    if (activeTab == null || !activeTab!.canGoBack) return;
    
    activeTab!.historyIndex--;
    activeTab!.url = activeTab!.history[activeTab!.historyIndex];
    _updateNavigationState();
    notifyListeners();
  }
  
  void goForward() {
    if (activeTab == null || !activeTab!.canGoForward) return;
    
    activeTab!.historyIndex++;
    activeTab!.url = activeTab!.history[activeTab!.historyIndex];
    _updateNavigationState();
    notifyListeners();
  }
  
  void reload() {
    if (activeTab == null) return;
    
    activeTab!.isLoading = true;
    activeTab!.progress = 0.0;
    notifyListeners();
    _simulatePageLoad();
  }
  
  void stopLoading() {
    if (activeTab == null) return;
    
    activeTab!.isLoading = false;
    notifyListeners();
  }
  
  void _updateNavigationState() {
    if (activeTab == null) return;
    
    activeTab!.canGoBack = activeTab!.historyIndex > 0;
    activeTab!.canGoForward = activeTab!.historyIndex < activeTab!.history.length - 1;
  }
  
  void _simulatePageLoad() {
    if (activeTab == null) return;
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (activeTab != null) {
        activeTab!.progress = 0.3;
        notifyListeners();
      }
    });
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (activeTab != null) {
        activeTab!.progress = 0.7;
        notifyListeners();
      }
    });
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (activeTab != null) {
        activeTab!.isLoading = false;
        activeTab!.progress = 1.0;
        activeTab!.title = _extractTitle(activeTab!.url);
        notifyListeners();
      }
    });
  }
  
  String _extractTitle(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceAll('www.', '');
    } catch (e) {
      return url;
    }
  }
  
  // - Bookmarks -
  void addBookmark(String url, String title, {String folder = 'Bookmarks Bar'}) {
    final bookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      title: title,
      folder: folder,
      created: DateTime.now(),
    );
    _bookmarks.add(bookmark);
    notifyListeners();
  }
  
  void removeBookmark(String id) {
    _bookmarks.removeWhere((b) => b.id == id);
    notifyListeners();
  }
  
  bool isBookmarked(String url) {
    return _bookmarks.any((b) => b.url == url);
  }
  
  // - History -
  void _addToHistory(String url) {
    if (activeTab?.isIncognito ?? false) return;
    
    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      title: _extractTitle(url),
      visited: DateTime.now(),
    );
    _history.insert(0, entry);
    
  // Keep only last 1000 entries
    if (_history.length > 1000) {
      _history.removeLast();
    }
  }
  
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }
  
  // - Settings -
  void setSearchEngine(String engine) {
    _searchEngine = engine;
    notifyListeners();
  }
  
  void toggleAdBlock() {
    _adBlockEnabled = !_adBlockEnabled;
    notifyListeners();
  }
  
  void toggleTrackingProtection() {
    _trackingProtection = !_trackingProtection;
    notifyListeners();
  }
  
  void toggleAutoFill() {
    _autoFillEnabled = !_autoFillEnabled;
    notifyListeners();
  }
  
  void setZoomLevel(double level) {
    _zoomLevel = level.clamp(0.5, 3.0);
    notifyListeners();
  }
  
  void toggleFullscreen() {
    _isFullscreen = !_isFullscreen;
    notifyListeners();
  }

  void setShowBookmarksBar(bool value) {
    if (_showBookmarksBar == value) return;
    _showBookmarksBar = value;
    notifyListeners();
  }

  /// Called when external code (e.g. Win32 WebView streams) mutates the active [BrowserTab] in place.
  void notifyTabMutated() {
    notifyListeners();
  }
}

// - Bookmark Model -
class Bookmark {
  final String id;
  final String url;
  final String title;
  final String folder;
  final DateTime created;
  
  Bookmark({
    required this.id,
    required this.url,
    required this.title,
    required this.folder,
    required this.created,
  });
}

// - Download Model -
class Download {
  final String id;
  final String filename;
  final String url;
  final int totalBytes;
  int downloadedBytes;
  bool isComplete;
  bool isPaused;
  DateTime started;
  
  Download({
    required this.id,
    required this.filename,
    required this.url,
    required this.totalBytes,
    this.downloadedBytes = 0,
    this.isComplete = false,
    this.isPaused = false,
    DateTime? started,
  }) : started = started ?? DateTime.now();
  
  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
}

// - History Entry Model -
class HistoryEntry {
  final String id;
  final String url;
  final String title;
  final DateTime visited;
  
  HistoryEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.visited,
  });
}