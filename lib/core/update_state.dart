import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'platform/system_bridge.dart';

/// Describes the result of a GitHub release check.
class UpdateInfo {
  final String latestVersion;
  final String releaseName;
  final String releaseBody;
  final String publishedAt;
  final bool available;

  const UpdateInfo({
    required this.latestVersion,
    required this.releaseName,
    required this.releaseBody,
    required this.publishedAt,
    required this.available,
  });
}

enum UpdateStatus {
  idle,
  checking,
  available,
  upToDate,
  downloading, // reserved for future progress tracking
  error,
}

class UpdateState extends ChangeNotifier {
  // ── Persisted settings ────────────────────────────────────────────────────
  /// GitHub repo in "owner/repo" format.
  String _githubRepo = '';
  String get githubRepo => _githubRepo;

  /// Check for updates automatically on every OS start.
  bool _autoCheck = true;
  bool get autoCheck => _autoCheck;

  /// If true, apply update silently without asking (like background update).
  /// Off by default — user always confirms.
  bool _autoInstall = false;
  bool get autoInstall => _autoInstall;

  // ── Runtime state ─────────────────────────────────────────────────────────
  String _currentVersion = 'unknown';
  String get currentVersion => _currentVersion;

  UpdateStatus _status = UpdateStatus.idle;
  UpdateStatus get status => _status;

  UpdateInfo? _updateInfo;
  UpdateInfo? get updateInfo => _updateInfo;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  DateTime? _lastChecked;
  DateTime? get lastChecked => _lastChecked;

  // ── Load prefs ────────────────────────────────────────────────────────────
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _githubRepo   = p.getString('update_github_repo')   ?? '';
    _autoCheck    = p.getBool('update_auto_check')       ?? true;
    _autoInstall  = p.getBool('update_auto_install')     ?? false;
    final lastMs  = p.getInt('update_last_checked_ms');
    if (lastMs != null) _lastChecked = DateTime.fromMillisecondsSinceEpoch(lastMs);

    // Read current version from OS
    _currentVersion = await SystemBridge.getOsVersion();

    notifyListeners();

    // Auto-check on startup if enabled and repo is configured
    if (_autoCheck && _githubRepo.isNotEmpty) {
      // Small delay — let UI finish painting first
      Future.delayed(const Duration(seconds: 4), checkForUpdate);
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('update_github_repo',    _githubRepo);
    await p.setBool('update_auto_check',        _autoCheck);
    await p.setBool('update_auto_install',      _autoInstall);
    if (_lastChecked != null) {
      await p.setInt('update_last_checked_ms', _lastChecked!.millisecondsSinceEpoch);
    }
  }

  // ── Settings setters ──────────────────────────────────────────────────────
  void setGithubRepo(String repo) {
    _githubRepo = repo.trim();
    notifyListeners();
    _save();
  }

  void setAutoCheck(bool v) {
    _autoCheck = v;
    notifyListeners();
    _save();
  }

  void setAutoInstall(bool v) {
    _autoInstall = v;
    notifyListeners();
    _save();
  }

  // ── Check for update ──────────────────────────────────────────────────────
  Future<void> checkForUpdate() async {
    if (_githubRepo.isEmpty) {
      _status = UpdateStatus.error;
      _errorMessage = 'GitHub repository not configured.\nGo to Settings → Software Update → set your repository.';
      notifyListeners();
      return;
    }

    _status = UpdateStatus.checking;
    _errorMessage = '';
    notifyListeners();

    try {
      // Refresh local version in case it changed
      _currentVersion = await SystemBridge.getOsVersion();

      final raw = await SystemBridge.checkForUpdate(_githubRepo);
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;

      if (json.isEmpty || json.containsKey('message')) {
        // GitHub API error (rate limit, 404, etc.)
        final msg = json['message'] as String? ?? 'GitHub API returned an error';
        throw Exception(msg);
      }

      final tagName      = (json['tag_name']     as String?) ?? '';
      final releaseName  = (json['name']          as String?) ?? tagName;
      final body         = (json['body']          as String?) ?? '';
      final publishedAt  = (json['published_at']  as String?) ?? '';

      // "latest" is our release tag — use the release name which contains
      // the version stamp like "KrdOS 20250606-1200-abc1234"
      // Compare by extracting the timestamp+sha portion
      final remoteVer = _extractVersion(releaseName) ?? releaseName;
      final isNewer   = _isNewer(remoteVer, _currentVersion);

      _updateInfo = UpdateInfo(
        latestVersion: remoteVer,
        releaseName: releaseName,
        releaseBody: body,
        publishedAt: publishedAt,
        available: isNewer,
      );

      _status       = isNewer ? UpdateStatus.available : UpdateStatus.upToDate;
      _lastChecked  = DateTime.now();
      notifyListeners();
      _save();

    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  // ── Apply update ──────────────────────────────────────────────────────────
  Future<void> applyUpdate() async {
    _status = UpdateStatus.downloading;
    notifyListeners();
    // This launches krdos-update in background.
    // The update script stops krdos-ui → swaps binary → restarts krdos-ui.
    // Flutter will be killed and relaunched — caller should show a
    // "Restarting..." screen immediately before calling this.
    await SystemBridge.applyUpdate();
    // We won't reach here in production (service kills us),
    // but handle the dev-build case:
    await Future.delayed(const Duration(seconds: 3));
    _status = UpdateStatus.idle;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extract the "YYYYMMDD-HHMM-sha" portion from a release name.
  String? _extractVersion(String name) {
    // Matches "20250606-1200-abc1234" anywhere in the string
    final re = RegExp(r'\d{8}-\d{4}-[a-f0-9]+');
    final m = re.firstMatch(name);
    return m?.group(0);
  }

  /// Returns true if [remote] is newer than [local].
  /// Versions are "YYYYMMDD-HHMM-sha" — lexicographic comparison works because
  /// the date/time prefix is zero-padded.
  bool _isNewer(String remote, String local) {
    if (local == 'unknown' || local == 'dev-build') return false;
    // Strip the sha suffix for comparison (keep date+time)
    String trimmed(String v) {
      final parts = v.split('-');
      return parts.length >= 2 ? '${parts[0]}-${parts[1]}' : v;
    }
    return trimmed(remote).compareTo(trimmed(local)) > 0;
  }

  String get statusLabel {
    switch (_status) {
      case UpdateStatus.idle:       return 'Not checked yet';
      case UpdateStatus.checking:   return 'Checking for updates…';
      case UpdateStatus.available:  return 'Update available';
      case UpdateStatus.upToDate:   return 'KrdOS is up to date';
      case UpdateStatus.downloading:return 'Downloading update…';
      case UpdateStatus.error:      return 'Check failed';
    }
  }
}
