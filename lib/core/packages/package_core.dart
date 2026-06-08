import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platform/system_bridge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum PkgSource { apt, flatpak, appimage, snap, wine, desktop }

enum InstallState { queued, installing, done, failed, cancelled }

class Package {
  final String id;
  final String name;
  final String version;
  final String description;
  final String categories;
  final String iconName;
  final PkgSource source;
  final int sizeKb;
  bool isInstalled;

  Package({
    required this.id,
    required this.name,
    this.version = '',
    this.description = '',
    this.categories = '',
    this.iconName = '',
    required this.source,
    this.sizeKb = 0,
    this.isInstalled = false,
  });

  String get sizeLabel {
    if (sizeKb <= 0) return '';
    if (sizeKb < 1024) return '$sizeKb KB';
    if (sizeKb < 1024 * 1024) return '${(sizeKb / 1024).toStringAsFixed(1)} MB';
    return '${(sizeKb / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String get sourceLabel {
    switch (source) {
      case PkgSource.apt:      return 'APT (deb)';
      case PkgSource.flatpak:  return 'Flatpak';
      case PkgSource.appimage: return 'AppImage';
      case PkgSource.snap:     return 'Snap';
      case PkgSource.wine:     return 'Wine (Win)';
      case PkgSource.desktop:  return 'System';
    }
  }

  factory Package.fromDesktopMap(Map<String, dynamic> m) => Package(
    id:          m['id']         as String? ?? '',
    name:        m['name']       as String? ?? '',
    version:     m['version']    as String? ?? '',
    description: m['desc']       as String? ?? '',
    categories:  m['categories'] as String? ?? '',
    iconName:    m['icon']       as String? ?? '',
    sizeKb:      (m['size_kb']   as num?)?.toInt() ?? 0,
    source:      PkgSource.desktop,
    isInstalled: true,
  );

  factory Package.fromFlatpakMap(Map<String, dynamic> m) => Package(
    id:      m['id']   as String? ?? '',
    name:    m['name'] as String? ?? (m['id'] as String? ?? ''),
    source:  PkgSource.flatpak,
    isInstalled: true,
  );

  factory Package.fromSearchMap(Map<String, dynamic> m, PkgSource src) => Package(
    id:          m['id']   as String? ?? '',
    name:        m['name'] as String? ?? (m['id'] as String? ?? ''),
    description: m['desc'] as String? ?? '',
    source:      src,
    isInstalled: false,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Install Job
// ─────────────────────────────────────────────────────────────────────────────

class InstallJob {
  final String jobId;
  final String pkgId;
  final String pkgName;
  final PkgSource source;
  final String? filePath; // for local file installs

  InstallState state;
  String log;
  double progress;

  InstallJob({
    required this.jobId,
    required this.pkgId,
    required this.pkgName,
    required this.source,
    this.filePath,
    this.state = InstallState.queued,
    this.log = '',
    this.progress = 0.0,
  });

  bool get isActive => state == InstallState.queued || state == InstallState.installing;
  bool get isFinished => state == InstallState.done || state == InstallState.failed;
}

// ─────────────────────────────────────────────────────────────────────────────
// PackageCore  (ChangeNotifier — register as Provider in app root)
// ─────────────────────────────────────────────────────────────────────────────

class PackageCore extends ChangeNotifier {
  PackageCore._();
  static final instance = PackageCore._();

  // ── Installed app cache ───────────────────────────────────────────────────

  List<Package> _installed = [];
  bool _loadingInstalled = false;
  DateTime? _lastRefresh;

  List<Package> get installed => List.unmodifiable(_installed);
  bool get loadingInstalled => _loadingInstalled;

  /// Reload installed app list from .desktop files + flatpak.
  /// Skips if last refresh was < [staleSecs] ago.
  Future<void> refreshInstalled({int staleSecs = 30}) async {
    if (_loadingInstalled) return;
    final now = DateTime.now();
    if (_lastRefresh != null &&
        now.difference(_lastRefresh!).inSeconds < staleSecs) return;

    _loadingInstalled = true;
    notifyListeners();

    try {
      final desktopFuture = SystemBridge.appsListDpkg();
      final flatpakFuture = SystemBridge.flatpakList();
      final results = await Future.wait([desktopFuture, flatpakFuture]);

      final desktopPkgs = results[0].map(Package.fromDesktopMap).toList();
      final flatpakPkgs = results[1].map(Package.fromFlatpakMap).toList();

      final all = [...desktopPkgs, ...flatpakPkgs];
      all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _installed = all;
      _lastRefresh = DateTime.now();
    } catch (_) {
      // keep stale data
    } finally {
      _loadingInstalled = false;
      notifyListeners();
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<List<Package>> searchApt(String query) async {
    if (query.trim().isEmpty) return [];
    final raw = await SystemBridge.appsSearchApt(query.trim());
    return raw.map((m) => Package.fromSearchMap(m, PkgSource.apt)).toList();
  }

  Future<List<Package>> searchFlatpak(String query) async {
    if (query.trim().isEmpty) return [];
    final raw = await SystemBridge.flatpakSearch(query.trim());
    return raw.map((m) => Package.fromSearchMap(m, PkgSource.flatpak)).toList();
  }

  // ── Install queue ─────────────────────────────────────────────────────────

  final List<InstallJob> _queue = [];
  bool _processingQueue = false;

  final _jobController = StreamController<InstallJob>.broadcast();
  Stream<InstallJob> get jobStream => _jobController.stream;

  List<InstallJob> get queue => List.unmodifiable(_queue);
  List<InstallJob> get activeJobs =>
      _queue.where((j) => j.isActive).toList();

  /// Queue a Flatpak install from the store.
  InstallJob queueFlatpak(String appId, String name) {
    final job = InstallJob(
      jobId: '${DateTime.now().millisecondsSinceEpoch}',
      pkgId: appId,
      pkgName: name,
      source: PkgSource.flatpak,
    );
    _queue.add(job);
    notifyListeners();
    _processQueue();
    return job;
  }

  /// Queue an APT package install by name.
  InstallJob queueApt(String pkgName) {
    final job = InstallJob(
      jobId: '${DateTime.now().millisecondsSinceEpoch}',
      pkgId: pkgName,
      pkgName: pkgName,
      source: PkgSource.apt,
    );
    _queue.add(job);
    notifyListeners();
    _processQueue();
    return job;
  }

  /// Queue a local file install (.deb, .AppImage, .snap, .exe, .flatpak).
  InstallJob queueFile(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    final source = _extSource(ext);
    final name = filePath.split('/').last;
    final job = InstallJob(
      jobId: '${DateTime.now().millisecondsSinceEpoch}',
      pkgId: name,
      pkgName: name,
      source: source,
      filePath: filePath,
    );
    _queue.add(job);
    notifyListeners();
    _processQueue();
    return job;
  }

  /// Cancel a queued (not yet started) job.
  void cancelJob(String jobId) {
    final idx = _queue.indexWhere((j) => j.jobId == jobId);
    if (idx < 0) return;
    final job = _queue[idx];
    if (job.state == InstallState.queued) {
      job.state = InstallState.cancelled;
      _jobController.add(job);
      notifyListeners();
    }
  }

  Future<void> _processQueue() async {
    if (_processingQueue) return;
    _processingQueue = true;

    for (final job in _queue) {
      if (job.state != InstallState.queued) continue;
      job.state = InstallState.installing;
      job.progress = 0.1;
      _jobController.add(job);
      notifyListeners();

      try {
        String out;
        if (job.filePath != null) {
          out = await SystemBridge.appInstall(job.filePath!);
        } else if (job.source == PkgSource.flatpak) {
          out = await SystemBridge.flatpakInstall(job.pkgId);
        } else {
          out = await SystemBridge.appsInstallApt(job.pkgId);
        }

        job.log = out;
        job.progress = 1.0;
        final lower = out.toLowerCase();
        job.state = (lower.contains('error') || lower.contains('failed') ||
                     lower.contains('unable') || lower.contains('not found'))
            ? InstallState.failed
            : InstallState.done;
      } catch (e) {
        job.log = e.toString();
        job.state = InstallState.failed;
        job.progress = 0.0;
      }

      _jobController.add(job);
      notifyListeners();
    }

    _processingQueue = false;

    // Refresh installed list after queue clears
    if (_queue.any((j) => j.state == InstallState.done)) {
      await refreshInstalled(staleSecs: 0);
    }
  }

  // ── Uninstall ─────────────────────────────────────────────────────────────

  Future<UninstallResult> uninstall(Package pkg) async {
    String out;
    try {
      if (pkg.source == PkgSource.flatpak) {
        out = await SystemBridge.appsUninstallFlatpak(pkg.id);
      } else {
        out = await SystemBridge.appsUninstallDeb(pkg.id);
      }
    } catch (e) {
      return UninstallResult(success: false, log: e.toString());
    }
    final success = !out.toLowerCase().contains('error') &&
                    !out.toLowerCase().contains('failed');
    if (success) {
      _installed.removeWhere((p) => p.id == pkg.id && p.source == pkg.source);
      notifyListeners();
    }
    return UninstallResult(success: success, log: out);
  }

  // ── Sources ───────────────────────────────────────────────────────────────

  Future<List<AptSource>> getAptSources() async {
    final raw = await SystemBridge.appsGetAptSources();
    return raw.map((m) => AptSource(
      uri:        m['uri']        as String? ?? '',
      suite:      m['suite']      as String? ?? '',
      components: m['components'] as String? ?? '',
      enabled:    m['enabled']    as bool?   ?? true,
    )).toList();
  }

  Future<List<FlatpakRemote>> getFlatpakRemotes() async {
    final raw = await SystemBridge.flatpakListRemotes();
    return raw.map((m) => FlatpakRemote(
      name: m['name'] as String? ?? '',
      url:  m['url']  as String? ?? '',
    )).toList();
  }

  Future<bool> addFlatpakRemote(String name, String url) =>
      SystemBridge.flatpakAddRemote(name, url);

  // ── Helpers ───────────────────────────────────────────────────────────────

  PkgSource _extSource(String ext) {
    switch (ext) {
      case 'deb':      return PkgSource.apt;
      case 'flatpak':  return PkgSource.flatpak;
      case 'snap':     return PkgSource.snap;
      case 'appimage': return PkgSource.appimage;
      case 'exe':
      case 'msi':      return PkgSource.wine;
      default:         return PkgSource.appimage;
    }
  }

  @override
  void dispose() {
    _jobController.close();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small result types
// ─────────────────────────────────────────────────────────────────────────────

class UninstallResult {
  final bool success;
  final String log;
  const UninstallResult({required this.success, required this.log});
}

class AptSource {
  final String uri;
  final String suite;
  final String components;
  final bool enabled;
  const AptSource({
    required this.uri,
    required this.suite,
    required this.components,
    required this.enabled,
  });
}

class FlatpakRemote {
  final String name;
  final String url;
  const FlatpakRemote({required this.name, required this.url});
}
