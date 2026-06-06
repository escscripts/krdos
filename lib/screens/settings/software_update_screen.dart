import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/platform/system_bridge.dart';
import '../../core/update_state.dart';
import '../../theme/app_theme.dart';

class SoftwareUpdateScreen extends StatefulWidget {
  const SoftwareUpdateScreen({super.key});

  @override
  State<SoftwareUpdateScreen> createState() => _SoftwareUpdateScreenState();
}

class _SoftwareUpdateScreenState extends State<SoftwareUpdateScreen> {
  final _repoCtrl = TextEditingController();
  bool _repoEditing = false;
  bool _showLog = false;
  String _log = '';
  Timer? _logTimer;

  @override
  void initState() {
    super.initState();
    final us = context.read<UpdateState>();
    _repoCtrl.text = us.githubRepo;
  }

  @override
  void dispose() {
    _repoCtrl.dispose();
    _logTimer?.cancel();
    super.dispose();
  }

  void _startLogPolling() {
    _logTimer?.cancel();
    _logTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final l = await SystemBridge.updateLog();
      if (mounted) setState(() => _log = l);
    });
  }

  void _stopLogPolling() {
    _logTimer?.cancel();
    _logTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Update confirmation dialog
  // ---------------------------------------------------------------------------
  Future<void> _confirmAndApply(UpdateState us) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.accent),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentDim,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.system_update_alt_rounded,
                  color: AppTheme.accent, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Install Update',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              us.updateInfo?.releaseName ?? us.updateInfo?.latestVersion ?? '',
              style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.08),
                border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'KrdOS will restart automatically to apply the update.\n'
                    'Save any work before continuing.',
                    style: TextStyle(
                        color: AppTheme.warning.withOpacity(0.9), fontSize: 12),
                  ),
                ),
              ]),
            ),
            if ((us.updateInfo?.releaseBody ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    us.updateInfo!.releaseBody,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.6),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: _btn('Cancel', AppTheme.border, AppTheme.textSecondary,
                    () => Navigator.pop(context, false)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _btn('Update Now', AppTheme.accent, AppTheme.accent,
                    () => Navigator.pop(context, true)),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (confirmed != true) return;

    // Show restart overlay then apply
    _showRestartOverlay(us);
  }

  void _showRestartOverlay(UpdateState us) {
    setState(() {
      _showLog = true;
      _log = 'Starting update…\n';
    });
    _startLogPolling();

    us.applyUpdate();

    // Show full-screen overlay
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _RestartOverlay(
        releaseName: us.updateInfo?.releaseName ?? 'update',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final us = context.watch<UpdateState>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page title ─────────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.system_update_alt_rounded,
                    color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Software Update',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text('Keep KrdOS up to date',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ]),
            ]),

            const SizedBox(height: 28),

            // ── Current version card ────────────────────────────────────────
            _Card(
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Installed Version',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      us.currentVersion == 'unknown' ||
                              us.currentVersion == 'dev-build'
                          ? us.currentVersion
                          : _formatVersion(us.currentVersion),
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace'),
                    ),
                    if (us.lastChecked != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Last checked: ${_fmtDateTime(us.lastChecked!)}',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ]),
                ),
                _CheckButton(us: us, onCheck: () => us.checkForUpdate()),
              ]),
            ).animate().fadeIn(duration: 200.ms),

            const SizedBox(height: 12),

            // ── Status / update available ───────────────────────────────────
            _StatusCard(
              us: us,
              onUpdate: () => _confirmAndApply(us),
            ).animate().fadeIn(duration: 200.ms, delay: 80.ms),

            const SizedBox(height: 20),

            // ── Live update log (shown during update) ──────────────────────
            if (_showLog) ...[
              _SectionLabel('Update Log'),
              const SizedBox(height: 8),
              Container(
                height: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: SelectableText(
                    _log.isEmpty ? 'Waiting for output…' : _log,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Preferences ────────────────────────────────────────────────
            _SectionLabel('Update Preferences'),
            const SizedBox(height: 10),

            _Card(
              child: Column(children: [
                _PrefRow(
                  icon: Icons.search_rounded,
                  title: 'Check for updates on startup',
                  subtitle: 'Automatically check when KrdOS starts. '
                      'You are still asked before anything is installed.',
                  value: us.autoCheck,
                  onChanged: us.setAutoCheck,
                ),
                const Divider(color: AppTheme.border, height: 1),
                _PrefRow(
                  icon: Icons.download_rounded,
                  title: 'Auto-install updates',
                  subtitle:
                      'Silently download and install updates in the background. '
                      'KrdOS restarts automatically when ready.\n'
                      '⚠️  Off by default — recommended only for advanced users.',
                  value: us.autoInstall,
                  onChanged: us.setAutoInstall,
                  disabled: !us.autoCheck,
                  warningIfEnabled: true,
                ),
              ]),
            ).animate().fadeIn(duration: 200.ms, delay: 160.ms),

            const SizedBox(height: 20),

            // ── Repository config ──────────────────────────────────────────
            _SectionLabel('Update Source'),
            const SizedBox(height: 10),

            _Card(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Icon(Icons.hub_rounded,
                      color: AppTheme.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('GitHub Repository',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      Text(
                          'owner/repository — e.g. meeru/krdos',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _repoEditing = !_repoEditing),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _repoEditing
                            ? AppTheme.accentDim
                            : AppTheme.surfaceAlt,
                        border: Border.all(
                            color: _repoEditing
                                ? AppTheme.accent
                                : AppTheme.border),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(_repoEditing ? 'Save' : 'Edit',
                          style: TextStyle(
                              color: _repoEditing
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                _repoEditing
                    ? TextField(
                        controller: _repoCtrl,
                        autofocus: true,
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontFamily: 'monospace'),
                        cursorColor: AppTheme.accent,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'username/repository',
                          hintStyle: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  BorderSide(color: AppTheme.accent)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                  color: AppTheme.accent, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (v) {
                          us.setGithubRepo(v);
                          setState(() => _repoEditing = false);
                        },
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          border: Border.all(
                              color: us.githubRepo.isEmpty
                                  ? AppTheme.danger.withOpacity(0.5)
                                  : AppTheme.border),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(children: [
                          Icon(
                            us.githubRepo.isEmpty
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            color: us.githubRepo.isEmpty
                                ? AppTheme.danger
                                : AppTheme.accent,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            us.githubRepo.isEmpty
                                ? 'Not configured — tap Edit to set'
                                : us.githubRepo,
                            style: TextStyle(
                                color: us.githubRepo.isEmpty
                                    ? AppTheme.danger
                                    : AppTheme.textPrimary,
                                fontSize: 13,
                                fontFamily: 'monospace'),
                          ),
                        ]),
                      ),
                if (_repoEditing) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      us.setGithubRepo(_repoCtrl.text);
                      setState(() => _repoEditing = false);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentDim,
                        border: Border.all(color: AppTheme.accent),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Save Repository',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ]),
            ).animate().fadeIn(duration: 200.ms, delay: 240.ms),

            const SizedBox(height: 12),

            // ── Token status row ──────────────────────────────────────────
            _Card(
              child: Row(children: [
                Icon(
                  us.hasToken
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  size: 16,
                  color: us.hasToken
                      ? const Color(0xFF4CAF50)
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Private Repository Access',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        us.hasToken
                            ? 'GitHub token configured in /etc/krdos/update.conf ✓'
                            : 'No token — only public repos work. '
                              'To use a private repo, run:\n'
                              '  sudo nano /etc/krdos/update.conf\n'
                              'Add: GITHUB_TOKEN=ghp_your_token',
                        style: TextStyle(
                            color: us.hasToken
                                ? const Color(0xFF4CAF50)
                                : AppTheme.textSecondary,
                            fontSize: 11,
                            height: 1.45),
                      ),
                    ],
                  ),
                ),
              ]),
            ).animate().fadeIn(duration: 200.ms, delay: 260.ms),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _formatVersion(String v) {
    // "20250606-1430-abc1234" → "Build 2025-06-06 14:30 (abc1234)"
    final re = RegExp(r'^(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})-([a-f0-9]+)$');
    final m = re.firstMatch(v);
    if (m == null) return v;
    return 'Build ${m.group(1)}-${m.group(2)}-${m.group(3)} '
        '${m.group(4)}:${m.group(5)}  (${m.group(6)})';
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  Widget _btn(String label, Color border, Color text, VoidCallback fn) =>
      GestureDetector(
        onTap: fn,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: border == AppTheme.accent
                ? AppTheme.accentDim
                : AppTheme.surface,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: text,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      );
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5),
      );
}

// ── Check button (spinner when checking) ─────────────────────────────────────
class _CheckButton extends StatelessWidget {
  final UpdateState us;
  final VoidCallback onCheck;
  const _CheckButton({required this.us, required this.onCheck});

  @override
  Widget build(BuildContext context) {
    final busy = us.status == UpdateStatus.checking;
    return GestureDetector(
      onTap: busy ? null : onCheck,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: busy ? AppTheme.surfaceAlt : AppTheme.accentDim,
          border: Border.all(
              color: busy ? AppTheme.border : AppTheme.accent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2),
              )
            : Text('Check Now',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final UpdateState us;
  final VoidCallback onUpdate;
  const _StatusCard({required this.us, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    switch (us.status) {
      case UpdateStatus.checking:
        return _infoTile(
          color: AppTheme.accent,
          icon: Icons.sync_rounded,
          title: 'Checking for updates…',
          subtitle: 'Contacting GitHub releases…',
          spinning: true,
        );

      case UpdateStatus.upToDate:
        return _infoTile(
          color: AppTheme.accent,
          icon: Icons.check_circle_rounded,
          title: 'KrdOS is up to date',
          subtitle: us.updateInfo != null
              ? 'You have the latest build: ${us.updateInfo!.latestVersion}'
              : 'No newer version available.',
        );

      case UpdateStatus.available:
        final info = us.updateInfo!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.accentDim,
            border: Border.all(color: AppTheme.accent, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.system_update_alt_rounded,
                    color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Update Available',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  Text(info.releaseName,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ]),
              ),
            ]),
            if (info.releaseBody.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseBody,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.6),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onUpdate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.download_rounded,
                          color: Colors.black, size: 16),
                      const SizedBox(width: 8),
                      Text('Update Now',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  Text(info.publishedAt.isNotEmpty
                      ? 'Released: ${_fmtDate(info.publishedAt)}'
                      : '',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
            ]),
          ]),
        );

      case UpdateStatus.downloading:
        return _infoTile(
          color: AppTheme.warning,
          icon: Icons.downloading_rounded,
          title: 'Applying update…',
          subtitle: 'KrdOS will restart automatically. Do not power off.',
          spinning: true,
        );

      case UpdateStatus.error:
        return _infoTile(
          color: AppTheme.danger,
          icon: Icons.error_outline_rounded,
          title: 'Update check failed',
          subtitle: us.errorMessage,
        );

      case UpdateStatus.idle:
      default:
        return _infoTile(
          color: AppTheme.textSecondary,
          icon: Icons.info_outline_rounded,
          title: 'Not checked yet',
          subtitle: 'Tap "Check Now" to look for updates.',
        );
    }
  }

  Widget _infoTile({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    bool spinning = false,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          spinning
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(color: color, strokeWidth: 2),
                )
              : Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.5)),
            ]),
          ),
        ]),
      );

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso; }
  }
}

// ── Preferences row ───────────────────────────────────────────────────────────
class _PrefRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;
  final bool warningIfEnabled;

  const _PrefRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.disabled = false,
    this.warningIfEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effective = !disabled && value;
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon,
              color: effective ? AppTheme.accent : AppTheme.textSecondary,
              size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.5)),
              if (warningIfEnabled && value && !disabled) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.12),
                    border:
                        Border.all(color: AppTheme.warning.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Enabled — updates apply automatically',
                      style: TextStyle(
                          color: AppTheme.warning, fontSize: 10)),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 14),
          Switch(
            value: disabled ? false : value,
            onChanged: disabled ? null : onChanged,
            activeColor: AppTheme.accent,
            inactiveThumbColor: AppTheme.textSecondary,
            inactiveTrackColor: AppTheme.border,
          ),
        ]),
      ),
    );
  }
}

// ── Restart overlay ───────────────────────────────────────────────────────────
class _RestartOverlay extends StatefulWidget {
  final String releaseName;
  const _RestartOverlay({required this.releaseName});

  @override
  State<_RestartOverlay> createState() => _RestartOverlayState();
}

class _RestartOverlayState extends State<_RestartOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Opacity(
              opacity: 0.6 + 0.4 * _pulse.value,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.system_update_alt_rounded,
                    color: AppTheme.accent, size: 52),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text('Updating KrdOS…',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(widget.releaseName,
              style:
                  TextStyle(color: AppTheme.accent, fontSize: 14)),
          const SizedBox(height: 32),
          SizedBox(
            width: 280,
            child: LinearProgressIndicator(
              color: AppTheme.accent,
              backgroundColor: AppTheme.border,
            ),
          ),
          const SizedBox(height: 20),
          Text('Downloading & installing…',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Text('KrdOS will restart automatically',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 40),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              border:
                  Border.all(color: AppTheme.warning.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.power_settings_new,
                  color: AppTheme.warning, size: 14),
              const SizedBox(width: 8),
              Text('Do not power off',
                  style: TextStyle(
                      color: AppTheme.warning, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}
