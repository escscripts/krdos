import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'browser_models.dart';
import 'browser_engine.dart';
import 'tor_launcher.dart';
import '../../theme/app_theme.dart';

const Map<String, IconData> _starterIconPresets = {
  'Web': Icons.public,
  'Search': Icons.search,
  'Mail': Icons.mail_outline,
  'Video': Icons.play_circle_outline,
  'News': Icons.article_outlined,
  'Code': Icons.code,
  'Cloud': Icons.cloud_outlined,
  'Chat': Icons.forum_outlined,
};

class BookmarksPanel extends StatelessWidget {
  final BrowserEngine engine;
  final VoidCallback onClose;
  final ValueChanged<String>? onOpenUrl;

  const BookmarksPanel({
    super.key,
    required this.engine,
    required this.onClose,
    this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBookmarksList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          Text(
            'Bookmarks',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksList() {
    if (engine.bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No bookmarks yet',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Click the star icon in the address bar to bookmark pages',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: engine.bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = engine.bookmarks[index];
        return _buildBookmarkItem(bookmark);
      },
    );
  }

  Widget _buildBookmarkItem(Bookmark bookmark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenUrl == null ? null : () => onOpenUrl!(bookmark.url),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(Icons.language, size: 18, color: AppTheme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookmark.title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bookmark.url,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onOpenUrl != null)
                Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.open_in_new, size: 16, color: AppTheme.textSecondary),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                onPressed: () => engine.removeBookmark(bookmark.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryPanel extends StatelessWidget {
  final BrowserEngine engine;
  final VoidCallback onClose;
  final ValueChanged<String>? onOpenUrl;

  const HistoryPanel({
    super.key,
    required this.engine,
    required this.onClose,
    this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildHistoryList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          Text(
            'History',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (engine.history.isNotEmpty)
            TextButton(
              onPressed: () => engine.clearHistory(),
              child: Text(
                'Clear All',
                style: TextStyle(color: AppTheme.danger, fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (engine.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No browsing history',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: engine.history.length,
      itemBuilder: (context, index) {
        final entry = engine.history[index];
        return _buildHistoryItem(entry);
      },
    );
  }

  Widget _buildHistoryItem(HistoryEntry entry) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenUrl == null
            ? null
            : () {
                onOpenUrl!(entry.url);
              },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.language, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.url,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(entry.visited),
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpenUrl != null)
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

class DownloadsPanel extends StatelessWidget {
  final BrowserEngine engine;
  final VoidCallback onClose;

  const DownloadsPanel({
    super.key,
    required this.engine,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildDownloadsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.download, color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          Text(
            'Downloads',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList() {
    if (engine.downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No downloads yet',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: engine.downloads.length,
      itemBuilder: (context, index) {
        final download = engine.downloads[index];
        return _buildDownloadItem(download);
      },
    );
  }

  Widget _buildDownloadItem(Download download) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                download.isComplete ? Icons.check_circle : Icons.downloading,
                size: 18,
                color: download.isComplete ? const Color(0xFF4CAF50) : AppTheme.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  download.filename,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (!download.isComplete) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: download.progress,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),
            const SizedBox(height: 4),
            Text(
              '${(download.progress * 100).toStringAsFixed(0)}% - ${_formatBytes(download.downloadedBytes)} / ${_formatBytes(download.totalBytes)}',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class SettingsPanel extends StatelessWidget {
  final BrowserEngine engine;
  final VoidCallback onClose;
  final Future<void> Function()? onRecycleNativeEmbedded;

  const SettingsPanel({
    super.key,
    required this.engine,
    required this.onClose,
    this.onRecycleNativeEmbedded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListenableBuilder(
              listenable: engine,
              builder: (_, _) => _buildSettingsList(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.settings, color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          Text(
            'Browser Settings',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection('Browsing shell'),
        _buildShellChoices(context),
        const SizedBox(height: 24),
        _buildSection('New-tab shortcuts'),
        _buildShortcutsEditor(context),
        const SizedBox(height: 24),
        _buildSection('Tor SOCKS (Windows embedded)'),
        _buildTorSocksEndpointCard(context),
        const SizedBox(height: 24),
        _buildSection('Tor Browser app (optional)'),
        _buildTorPathCard(context),
        const SizedBox(height: 24),
        _buildSection('Search engine'),
        _buildSearchEngineSelector(),
        const SizedBox(height: 24),
        _buildSection('Privacy & security'),
        _buildToggle(
          'Prefer HTTPS upgrades',
          'Rewrite typed or followed http:// addresses to https://',
          engine.httpsPreferred,
          () {
            engine.setHttpsPreferred(!engine.httpsPreferred);
          },
        ),
        _buildToggle(
          'Block risky URL schemes',
          'Prevent file:, javascript:, and other non-http(s) navigations',
          engine.dangerousSchemeBlock,
          () {
            engine.setDangerousSchemeBlock(!engine.dangerousSchemeBlock);
          },
        ),
        _buildToggle(
          'Disable embedded JavaScript',
          'Highest hardening ? most sites stop working until toggled back off.',
          engine.strictJavaScript,
          () {
            engine.setStrictJavaScript(!engine.strictJavaScript);
            unawaited(onRecycleNativeEmbedded?.call());
          },
        ),
        _buildToggle(
          'Ad Blocker',
          'Block ads and trackers (planned integration)',
          engine.adBlockEnabled,
          () => engine.toggleAdBlock(),
        ),
        _buildToggle(
          'Tracking protection',
          'Reduce cross-site trackers (planned integration)',
          engine.trackingProtection,
          () => engine.toggleTrackingProtection(),
        ),
        const SizedBox(height: 24),
        _buildSection('Appearance'),
        _buildToggle(
          'Bookmarks bar',
          'Show starred bookmarks beneath the toolbar',
          engine.showBookmarksBar,
          () => engine.setShowBookmarksBar(!engine.showBookmarksBar),
        ),
        const SizedBox(height: 12),
        _buildZoomControl(),
        const SizedBox(height: 24),
        _buildSection('Advanced'),
        _buildToggle(
          'Autofill suggestions',
          'Offer to autocomplete forms',
          engine.autoFillEnabled,
          () => engine.toggleAutoFill(),
        ),
      ],
    );
  }

  Widget _buildShellChoices(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final mode in BrowserShellBackend.values)
            RadioListTile<BrowserShellBackend>(
              dense: true,
              value: mode,
              groupValue: engine.shellBackend,
              onChanged: (v) {
                if (v == null) return;
                final wasTor = engine.shellBackend == BrowserShellBackend.torEmbeddedSocks;
                final nowTor = v == BrowserShellBackend.torEmbeddedSocks;
                unawaited(() async {
                  await engine.setShellBackend(
                    v,
                    persistChoiceCommitted: true,
                    promptShellOnEveryOpen: engine.promptShellOnEveryOpen,
                  );
                  await onRecycleNativeEmbedded?.call();
                  if (!context.mounted) return;
                  if (wasTor != nowTor) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          'Quit and relaunch KrdOS after switching Tor SOCKS and '
                          'direct browsing ? WebView2 reads the proxy only at startup.',
                        ),
                      ),
                    );
                  }
                }());
              },
              title: Text(
                mode.displayLabel,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: engine.promptShellOnEveryOpen,
            onChanged: (checked) =>
                unawaited(engine.setPromptShellOnEveryOpen(checked ?? false)),
            title: Text(
              'Ask which shell each time Browser opens',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          Text(
            'Tor mode adds a SOCKS `--proxy-server` flag to Chromium-based WebView2 and uses a '
            'separate on-disk profile. Run `tor.exe` or keep Tor Browser?s SOCKS listener open '
            '(9050 or 9150).',
            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildTorSocksEndpointCard(BuildContext context) {
    return BrowserTorSocksEndpointForm(engine: engine, snackContext: context);
  }

  Widget _buildShortcutsEditor(BuildContext context) {
    final shortcuts = engine.starterShortcuts;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shortcuts.isEmpty
                ? 'No tiles yet ? shortcuts stay empty until you add them.'
                : '${shortcuts.length} shortcut${shortcuts.length == 1 ? '' : 's'}',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (shortcuts.isNotEmpty)
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: engine.reorderStarterShortcut,
              children: [
                for (final s in shortcuts)
                  ListTile(
                    key: ValueKey<String>(s.id),
                    dense: true,
                    leading: Icon(
                      IconData(s.iconCodePoint, fontFamily: 'MaterialIcons'),
                      color: AppTheme.accent,
                      size: 20,
                    ),
                    title: Text(s.title,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    subtitle: Text(s.url,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSecondary),
                          onPressed: () => _openShortcutSheet(context, existing: s),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                          onPressed: () => engine.removeStarterShortcut(s.id),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openShortcutSheet(context),
              icon: Icon(Icons.add, size: 16, color: AppTheme.accent),
              label: Text('Add shortcut', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openShortcutSheet(BuildContext context, {StarterShortcut? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    int pickedIcon =
        existing?.iconCodePoint ?? _starterIconPresets.values.first.codePoint;

    try {
      await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).padding.bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'Add shortcut tile' : 'Edit shortcut',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      enabledBorder:
                          OutlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                      focusedBorder:
                          OutlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'URL (example.com auto-prefixed with https://)',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      enabledBorder:
                          OutlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                      focusedBorder:
                          OutlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Icon preset', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _starterIconPresets.entries.map((e) {
                      final selected = e.value.codePoint == pickedIcon;
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setSheet(() => pickedIcon = e.value.codePoint),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? AppTheme.accent : AppTheme.border,
                              width: selected ? 2 : 1,
                            ),
                            color:
                                selected ? AppTheme.accent.withValues(alpha: 0.12) : AppTheme.surface,
                          ),
                          child:
                              Icon(e.value, size: 22, color: selected ? AppTheme.accent : AppTheme.textSecondary),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          if (existing == null) {
                            engine.addStarterShortcut(
                              title: titleCtrl.text,
                              url: urlCtrl.text,
                              iconCodePoint: pickedIcon,
                            );
                          } else {
                            engine.updateStarterShortcut(
                              existing.id,
                              title: titleCtrl.text,
                              url: urlCtrl.text,
                              iconCodePoint: pickedIcon,
                            );
                          }
                          Navigator.pop(ctx);
                        },
                        child: Text(existing == null ? 'Add' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    } finally {
      titleCtrl.dispose();
      urlCtrl.dispose();
    }
  }

  Widget _buildTorPathCard(BuildContext context) {
    final pathLabel = engine.torBrowserExecutablePath?.isNotEmpty == true
        ? engine.torBrowserExecutablePath!
        : 'Autodetect (Windows default paths)';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            pathLabel,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final r = await FilePicker.platform.pickFiles();
                  final p = r?.files.single.path;
                  if (p != null) await engine.setTorBrowserExecutablePath(p);
                },
                icon: Icon(Icons.folder_open, size: 16, color: AppTheme.accent),
                label: Text('Browse', style: TextStyle(color: AppTheme.accent)),
              ),
              TextButton(
                onPressed: () async {
                  final guessed = await pickDefaultTorExecutable();
                  if (guessed != null) await engine.setTorBrowserExecutablePath(guessed);
                },
                child: Text('Guess path', style: TextStyle(color: AppTheme.accent)),
              ),
              TextButton(
                onPressed: () => engine.setTorBrowserExecutablePath(null),
                child: Text('Clear', style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.accent,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSearchEngineSelector() {
    final engines = ['google', 'bing', 'duckduckgo'];
    final labels = {'google': 'Google', 'bing': 'Bing', 'duckduckgo': 'DuckDuckGo'};

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: engines.map((engine) {
          final isSelected = this.engine.searchEngine == engine;
          return GestureDetector(
            onTap: () => this.engine.setSearchEngine(engine),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 18,
                    color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    labels[engine]!,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, VoidCallback onToggle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) => onToggle(),
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControl() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zoom Level',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: () => engine.setZoomLevel(engine.zoomLevel - 0.1),
              ),
              Expanded(
                child: Slider(
                  value: engine.zoomLevel,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  label: '${(engine.zoomLevel * 100).toInt()}%',
                  onChanged: (value) => engine.setZoomLevel(value),
                  activeColor: AppTheme.accent,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => engine.setZoomLevel(engine.zoomLevel + 0.1),
              ),
              Text(
                '${(engine.zoomLevel * 100).toInt()}%',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// SOCKS host/port for embedded Tor routing (Windows WebView2 `--proxy-server`).
class BrowserTorSocksEndpointForm extends StatefulWidget {
  final BrowserEngine engine;
  final BuildContext snackContext;

  const BrowserTorSocksEndpointForm({
    super.key,
    required this.engine,
    required this.snackContext,
  });

  @override
  State<BrowserTorSocksEndpointForm> createState() => _BrowserTorSocksEndpointFormState();
}

class _BrowserTorSocksEndpointFormState extends State<BrowserTorSocksEndpointForm> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.engine.torSocksHost);
    _portCtrl = TextEditingController(text: '${widget.engine.torSocksPort}');
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Matched to `--proxy-server=socks5://host:port` on Chromium WebView2. '
            'Default Tor SOCKS is often 9050 (Expert Bundle) or 9150 (Tor Browser).',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hostCtrl,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'SOCKS host',
              labelStyle: TextStyle(color: AppTheme.textSecondary),
              enabledBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
              focusedBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _portCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'SOCKS port',
              labelStyle: TextStyle(color: AppTheme.textSecondary),
              enabledBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
              focusedBorder:
                  OutlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                final p = int.tryParse(_portCtrl.text.trim()) ?? 9050;
                await widget.engine.setTorSocksEndpoint(
                  host: _hostCtrl.text,
                  port: p,
                );
                if (!mounted) return;
                if (widget.snackContext.mounted &&
                    widget.engine.shellBackend ==
                        BrowserShellBackend.torEmbeddedSocks) {
                  ScaffoldMessenger.of(widget.snackContext).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'Quit and relaunch KrdOS so WebView picks up the new SOCKS endpoint.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save SOCKS endpoint'),
            ),
          ),
        ],
      ),
    );
  }
}

