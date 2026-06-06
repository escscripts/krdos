import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/os_state.dart';
import '../core/settings_state.dart';
import '../core/update_state.dart';
import '../theme/app_theme.dart';
import 'settings/dock_customization_screen.dart';
import 'settings/display_settings.dart';
import 'settings/network_settings.dart';
import 'settings/security_settings.dart';
import 'settings/about_screen.dart';
import 'settings/personalization_settings.dart';
import 'settings/apps_settings.dart';
import 'settings/change_password_screen.dart';
import 'settings/accessibility_settings.dart';
import 'settings/software_update_screen.dart';
import 'user_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String? initialPage;
  /// Sidebar page sub-tab when [initialPage] is set (e.g. personalization wallpaper = 0).
  final int initialSubTab;

  const SettingsScreen({super.key, this.initialPage, this.initialSubTab = 0});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _selectedId;
  int _subTab = 0;

  final GlobalKey<ScaffoldState> _settingsScaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const double _sideWidth = 272;

  late final List<_SettingsGroup> _groups = [
    _SettingsGroup(
      title: 'System',
      items: [
        _NavItem(
          id: 'display',
          title: 'Display',
          subtitle: 'Brightness, HDR, night light, fonts',
          icon: Icons.monitor_rounded,
          color: const Color(0xFF58A6FF),
          keywords: const ['screen', 'brightness', 'resolution', 'monitor', 'night', 'hdr', 'scaling', 'font', 'text'],
        ),
        _NavItem(
          id: 'network',
          title: 'Network',
          subtitle: 'WiFi, firewall, DNS, proxy',
          icon: Icons.wifi_rounded,
          color: AppTheme.accent,
          keywords: const ['internet', 'wifi', 'ethernet', 'dns', 'proxy', 'firewall', 'connection'],
        ),
        _NavItem(
          id: 'security',
          title: 'Privacy & Security',
          subtitle: 'Telemetry, permissions, encryption',
          icon: Icons.shield_rounded,
          color: AppTheme.danger,
          keywords: const ['privacy', 'permissions', 'encryption', 'camera', 'microphone', 'telemetry', 'location'],
        ),
        _NavItem(
          id: 'about',
          title: 'System Information',
          subtitle: 'Hardware, storage, OS build',
          icon: Icons.info_rounded,
          color: AppTheme.textSecondary,
          keywords: const ['about', 'version', 'cpu', 'ram', 'storage', 'device', 'build', 'kernel'],
        ),
        _NavItem(
          id: 'software_update',
          title: 'Software Update',
          subtitle: 'Check for updates, update history',
          icon: Icons.system_update_alt_rounded,
          color: const Color(0xFF34D399),
          keywords: const ['update', 'upgrade', 'version', 'ota', 'download', 'install', 'release'],
          badge: _UpdateBadge(),
        ),
        _NavItem(
          id: 'accessibility',
          title: 'Accessibility',
          subtitle: 'Contrast, reduce motion, navigation',
          icon: Icons.accessibility_new_rounded,
          color: const Color(0xFF00D4FF),
          keywords: const ['accessibility', 'a11y', 'contrast', 'motion', 'keyboard', 'bold text'],
        ),
      ],
    ),
    _SettingsGroup(
      title: 'Personalization',
      items: [
        _NavItem(
          id: 'personalization',
          title: 'Personalization',
          subtitle: 'Wallpaper, accent, themes, lock screen',
          icon: Icons.palette_rounded,
          color: const Color(0xFF9B59B6),
          keywords: const ['wallpaper', 'background', 'theme', 'accent', 'color', 'lock', 'blur'],
        ),
        _NavItem(
          id: 'taskbar',
          title: 'Taskbar & Dock',
          subtitle: 'Pins, size, behavior',
          icon: Icons.view_agenda_rounded,
          color: const Color(0xFF3498DB),
          keywords: const ['dock', 'taskbar', 'panel', 'launcher', 'pinned'],
        ),
      ],
    ),
    _SettingsGroup(
      title: 'Apps',
      items: [
        _NavItem(
          id: 'apps',
          title: 'Apps',
          subtitle: 'Installed, defaults, startup',
          icon: Icons.apps_rounded,
          color: const Color(0xFF2ECC71),
          keywords: const ['applications', 'defaults', 'startup', 'uninstall', 'programs'],
        ),
      ],
    ),
    _SettingsGroup(
      title: 'Accounts',
      items: [
        _NavItem(
          id: 'signin',
          title: 'Sign-in & Password',
          subtitle: 'Password, strength, recovery',
          icon: Icons.key_rounded,
          color: const Color(0xFFFFB86C),
          keywords: const ['password', 'signin', 'login', 'credential', 'pin', 'passphrase', 'change'],
        ),
        _NavItem(
          id: 'users',
          title: 'Users & Accounts',
          subtitle: 'Family, roles, devices',
          icon: Icons.people_rounded,
          color: AppTheme.warning,
          keywords: const ['users', 'accounts', 'admin', 'profile', 'family', 'multiuser'],
        ),
      ],
    ),
  ];

  late final List<_DeepSetting> _deep = [
    _DeepSetting('Night Light', 'Warm tint, schedule, automation', 'display', 1,
        const ['sleep', 'blue', 'evening', 'flux', 'eye', 'circadian']),
    _DeepSetting('Fonts & legibility', 'Type size, family, rendering', 'display', 2,
        const ['text', 'typeface', 'dpi', 'readable', 'scaling']),
    _DeepSetting('HDR & refresh', 'High dynamic range, motion clarity', 'display', 0,
        const ['hdr', 'hz', 'refresh', 'gaming', 'smooth']),

    _DeepSetting('Firewall rules', 'Inbound, outbound, hardening', 'network', 2, const ['firewall', 'rules', 'block']),
    _DeepSetting('DNS & DoH', 'Resolvers, secure DNS, overrides', 'network', 3, const ['dns', 'doh', 'resolver', 'adguard']),
    _DeepSetting('Proxy', 'HTTP proxy, PAC, corporate', 'network', 4, const ['proxy', 'pac', 'corporate']),
    _DeepSetting('Wallpaper studio', 'Gradients, fit, slideshow', 'personalization', 0,
        const ['wallpaper', 'background', 'slideshow']),
    _DeepSetting('Accent & materials', 'Colors, transparency, blur', 'personalization', 1,
        const ['accent', 'material', 'blur', 'glass']),
    _DeepSetting('Themes', 'Light, dark, scheduled', 'personalization', 2, const ['dark', 'light', 'schedule']),
    _DeepSetting('Lock screen', 'Wallpaper, blur, notifications', 'personalization', 3,
        const ['lock', 'login', 'notifications']),
    _DeepSetting('Default handlers', 'Browser, mail, media', 'apps', 1, const ['default', 'handler', 'mailto', 'http']),
    _DeepSetting('Startup items', 'Login helpers, launch agents', 'apps', 2, const ['startup', 'login', 'boot']),
    _DeepSetting('Privacy toggles', 'Telemetry, location, clipboard', 'security', 1,
        const ['telemetry', 'location', 'clipboard', 'ads']),
    _DeepSetting('App permissions', 'Camera, mic, files', 'security', 2, const ['permissions', 'camera', 'mic']),
    _DeepSetting('Device trust', 'TPM, biometrics, secure boot', 'security', 3, const ['tpm', 'biometric', 'secure boot']),
    _DeepSetting('Change password', 'Rotate credentials safely', 'signin', 0, const ['password', 'rotate', 'update']),
    _DeepSetting('High contrast', 'Increase separation and readability', 'accessibility', 0,
        const ['contrast', 'readability', 'vision']),
    _DeepSetting('Reduce motion', 'Disable animations and transitions', 'accessibility', 1,
        const ['motion', 'animations', 'vestibular']),
    _DeepSetting('Accessible navigation', 'Keyboard-first interaction hints', 'accessibility', 2,
        const ['keyboard', 'tab', 'navigation']),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    if (widget.initialPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _select(widget.initialPage!, widget.initialSubTab);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _select(String id, int subTab) {
    setState(() {
      _selectedId = id;
      _subTab = subTab;
      _searchController.clear();
    });
  }

  void _goHome() {
    setState(() {
      _selectedId = null;
      _subTab = 0;
      _searchController.clear();
    });
  }

  _NavItem? _findNav(String id) {
    for (final g in _groups) {
      for (final i in g.items) {
        if (i.id == id) return i;
      }
    }
    return null;
  }

  List<_SearchHit> _runSearch() {
    final q = _searchQuery;
    if (q.isEmpty) return [];

    final hits = <_SearchHit>[];

    void addHit(String title, String subtitle, String category, String pageId, int sub, double score) {
      if (score <= 0) return;
      hits.add(_SearchHit(
        title: title,
        subtitle: subtitle,
        category: category,
        pageId: pageId,
        subTab: sub,
        score: score,
      ));
    }

    for (final g in _groups) {
      for (final i in g.items) {
        final s = _score(q, i.title, i.subtitle, i.keywords);
        addHit(i.title, i.subtitle, g.title, i.id, 0, s);
      }
    }

    for (final d in _deep) {
      final s = _score(q, d.title, d.subtitle, d.keywords);
      addHit(d.title, d.subtitle, _groupLabelFor(d.pageId), d.pageId, d.subTab, s + 2);
    }

    hits.sort((a, b) => b.score.compareTo(a.score));

    final seen = <String>{};
    final deduped = <_SearchHit>[];
    for (final h in hits) {
      final k = '${h.pageId}|${h.subTab}|${h.title}';
      if (seen.add(k)) deduped.add(h);
    }
    return deduped.take(48).toList();
  }

  String _groupLabelFor(String pageId) {
    for (final g in _groups) {
      if (g.items.any((e) => e.id == pageId)) return g.title;
    }
    return 'Settings';
  }

  double _score(String query, String title, String subtitle, List<String> keywords) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return 0;

    final t = title.toLowerCase();
    final s = subtitle.toLowerCase();
    final blob = '$t $s ${keywords.join(' ')}'.toLowerCase();

    if (t == q || s == q) return 120;
    if (blob.contains(q)) return 95;

    final tokens = q.split(RegExp(r'\s+')).where((x) => x.length > 1).toList();
    if (tokens.isEmpty) return blob.contains(q) ? 80 : 0;

    var score = 0.0;
    for (final tok in tokens) {
      if (t.contains(tok)) score += 42;
      if (s.contains(tok)) score += 26;
      for (final k in keywords) {
        final lk = k.toLowerCase();
        if (lk.contains(tok) || tok.contains(lk)) score += 16;
      }
    }
    return score;
  }

  void _closeDrawer() => _settingsScaffoldKey.currentState?.closeDrawer();

  Widget _buildDetailPane(OsState os, {VoidCallback? onOpenDrawer}) {
    return Column(
      children: [
        _DetailHeader(
          selectedId: _selectedId,
          title: _selectedId == null ? 'System Control' : (_findNav(_selectedId!)?.title ?? 'Settings'),
          subtitle: _selectedId == null ? 'Configuration' : (_findNav(_selectedId!)?.subtitle ?? ''),
          onBack: _selectedId == null ? null : _goHome,
          os: os,
          onAccount: () => _select('users', 0),
          onOpenDrawer: onOpenDrawer,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _selectedId == null
                ? _HomeDashboard(
                    key: const ValueKey('home'),
                    groups: _groups,
                    onOpen: _select,
                  )
                : ColoredBox(
                    key: ValueKey('page-$_selectedId-$_subTab'),
                    color: const Color(0xFF050A0E),
                    child: _buildPage(_selectedId!, _subTab),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage(String id, int sub) {
    switch (id) {
      case 'display':
        return DisplaySettingsScreen(initialTab: sub);
      case 'network':
        return NetworkSettingsScreen(initialTab: sub);
      case 'security':
        return SecuritySettingsScreen(initialTab: sub);
      case 'about':
        return const AboutScreen();
      case 'accessibility':
        return AccessibilitySettingsScreen(initialTab: sub);
      case 'personalization':
        return PersonalizationSettingsScreen(initialTab: sub);
      case 'taskbar':
        return const DockCustomizationScreen();
      case 'apps':
        return AppsSettingsScreen(initialTab: sub);
      case 'signin':
        return const ChangePasswordScreen();
      case 'users':
        return const UserManagementScreen(embedded: true);
      case 'software_update':
        return const SoftwareUpdateScreen();
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final os = context.watch<OsState>();
    final searching = _searchQuery.isNotEmpty;
    final results = searching ? _runSearch() : const <_SearchHit>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 880;

        if (wide) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF03070C), Color(0xFF060D14)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _sideWidth,
                  child: _Sidebar(
                    groups: _groups,
                    selectedId: _selectedId,
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    searchResults: results,
                    onPickHit: (h) => _select(h.pageId, h.subTab),
                    onPickNav: (id) => _select(id, 0),
                    onHome: _goHome,
                  ),
                ),
                Container(width: 1, color: AppTheme.border.withValues(alpha: 0.28)),
                Expanded(child: _buildDetailPane(os)),
              ],
            ),
          );
        }

        return Scaffold(
          key: _settingsScaffoldKey,
          backgroundColor: const Color(0xFF03070C),
          drawer: Drawer(
            backgroundColor: AppTheme.surface,
            child: SafeArea(
              child: _Sidebar(
                groups: _groups,
                selectedId: _selectedId,
                searchController: _searchController,
                searchQuery: _searchQuery,
                searchResults: results,
                onPickHit: (h) {
                  _select(h.pageId, h.subTab);
                  _closeDrawer();
                },
                onPickNav: (id) {
                  _select(id, 0);
                  _closeDrawer();
                },
                onHome: () {
                  _goHome();
                  _closeDrawer();
                },
              ),
            ),
          ),
          body: SafeArea(
            child: _buildDetailPane(
              os,
              onOpenDrawer: () => _settingsScaffoldKey.currentState?.openDrawer(),
            ),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<_SettingsGroup> groups;
  final String? selectedId;
  final TextEditingController searchController;
  final String searchQuery;
  final List<_SearchHit> searchResults;
  final void Function(_SearchHit) onPickHit;
  final void Function(String id) onPickNav;
  final VoidCallback onHome;

  const _Sidebar({
    required this.groups,
    required this.selectedId,
    required this.searchController,
    required this.searchQuery,
    required this.searchResults,
    required this.onPickHit,
    required this.onPickNav,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final searching = searchQuery.isNotEmpty;

    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.72),
            border: Border(right: BorderSide(color: AppTheme.border.withValues(alpha: 0.35))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [settings.accentColor, settings.accentColor.withValues(alpha: 0.65)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.tune_rounded, color: Colors.black, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'System Control',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: searchController,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: searchController.clear,
                            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 18),
                          ),
                    hintText: 'search',
                    hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.75), fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: settings.accentColor, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (!searching)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextButton.icon(
                    onPressed: onHome,
                    icon: Icon(Icons.home_rounded, size: 18, color: settings.accentColor),
                    label: Text('Overview', style: TextStyle(color: settings.accentColor, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      backgroundColor: settings.accentColor.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              Expanded(
                child: searching
                    ? _SearchList(results: searchResults, onPick: onPickHit)
                    : _NavList(
                        groups: groups,
                        selectedId: selectedId,
                        onPick: onPickNav,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchList extends StatelessWidget {
  final List<_SearchHit> results;
  final void Function(_SearchHit) onPick;

  const _SearchList({required this.results, required this.onPick});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No matches ‚¬ try ‚¬Å“firewall‚¬, ‚¬Å“wallpaper‚¬, or ‚¬Å“startup‚¬.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.9), fontSize: 12, height: 1.35),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final h = results[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onPick(h),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.title,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      h.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.label_important_outline_rounded,
                            size: 12, color: AppTheme.accent.withValues(alpha: 0.85)),
                        const SizedBox(width: 4),
                        Text(
                          h.category,
                          style: TextStyle(
                            color: AppTheme.textSecondary.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          h.subTab == 0 ? 'Section' : 'Open link',
                          style: TextStyle(color: AppTheme.accent.withValues(alpha: 0.75), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavList extends StatelessWidget {
  final List<_SettingsGroup> groups;
  final String? selectedId;
  final void Function(String id) onPick;

  const _NavList({required this.groups, required this.selectedId, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
      children: [
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
            child: Text(
              g.title.toUpperCase(),
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.85),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          for (final item in g.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _NavTile(
                item: item,
                selected: selectedId == item.id,
                onTap: () => onPick(item.id),
              ),
            ),
        ],
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? settings.accentColor.withValues(alpha: 0.12) : AppTheme.surfaceAlt.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? settings.accentColor.withValues(alpha: 0.55) : AppTheme.border.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (item.badge != null) ...[
                            const SizedBox(width: 8),
                            item.badge!,
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.65), size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final String? selectedId;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final OsState os;
  final VoidCallback onAccount;
  final VoidCallback? onOpenDrawer;

  const _DetailHeader({
    required this.selectedId,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.os,
    required this.onAccount,
    this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: onOpenDrawer != null ? 4 : 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F14),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              if (onOpenDrawer != null)
                IconButton(
                  onPressed: onOpenDrawer,
                  icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary, size: 22),
                  tooltip: 'Navigation',
                ),
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textSecondary, size: 18),
                  tooltip: 'Overview',
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedId != null)
                      Text(
                        'SYSTEM CONTROL',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.75),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.25,
                        ),
                      ),
                    if (selectedId != null) const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.35,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.9),
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onAccount,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.65)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: settings.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.person_rounded, color: settings.accentColor, size: 15),
                      ),
                  if (onOpenDrawer == null) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'admin',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          os.role == UserRole.admin ? 'Administrator' : 'User',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  final List<_SettingsGroup> groups;
  final void Function(String id, int sub) onOpen;

  const _HomeDashboard({super.key, required this.groups, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final picks = [
      for (final g in groups) ...g.items,
    ];

    return Container(
      color: const Color(0xFF050A0E),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF0C1218),
              border: Border.all(
                width: 0.85,
                color: AppTheme.border.withValues(alpha: 0.32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OVERVIEW',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withValues(alpha: 0.75),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Operational parameters',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.25,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the sidebar search for precise targets ‚¬ wallpaper, DNS, startup agents, password rotation. '
                  'Below are high-traffic modules.',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.88),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip('Indexed search'),
                    _chip('Persisted state'),
                    _chip('Cross-form-factor'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'MODULES',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.85,
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cols = w > 1000 ? 3 : w > 560 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: cols == 1 ? 2.35 : 1.95,
                ),
                itemCount: picks.length.clamp(0, 9),
                itemBuilder: (context, i) {
                  final p = picks[i];
                  return _BigTile(
                    item: p,
                    onTap: () => onOpen(p.id, 0),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget _chip(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF080D12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          width: 0.85,
          color: AppTheme.border.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        t,
        style: TextStyle(
          color: AppTheme.textSecondary.withValues(alpha: 0.9),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BigTile extends StatelessWidget {
  final _NavItem item;
  final VoidCallback onTap;

  const _BigTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1218),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              width: 0.85,
              color: AppTheme.border.withValues(alpha: 0.32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(item.icon, color: item.color.withValues(alpha: 0.9), size: 17),
                if (item.badge != null) ...[
                  const SizedBox(width: 6),
                  item.badge!,
                ],
              ]),
              const Spacer(),
              Text(
                item.title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  letterSpacing: -0.15,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.85),
                  fontSize: 10,
                  height: 1.22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup {
  final String title;
  final List<_NavItem> items;

  _SettingsGroup({required this.title, required this.items});
}

class _NavItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> keywords;
  /// Optional badge widget shown next to the title (e.g. update dot).
  final Widget? badge;

  _NavItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.keywords,
    this.badge,
  });
}

class _DeepSetting {
  final String title;
  final String subtitle;
  final String pageId;
  final int subTab;
  final List<String> keywords;

  _DeepSetting(this.title, this.subtitle, this.pageId, this.subTab, this.keywords);
}

class _SearchHit {
  final String title;
  final String subtitle;
  final String category;
  final String pageId;
  final int subTab;
  final double score;

  _SearchHit({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.pageId,
    required this.subTab,
    required this.score,
  });
}

// ── Update available badge ────────────────────────────────────────────────────
/// Small green dot shown on the Software Update settings row when an update
/// is available. Reads UpdateState from the widget tree.
class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge();

  @override
  Widget build(BuildContext context) {
    final us = context.watch<UpdateState>();
    if (us.status != UpdateStatus.available) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF34D399),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '1',
        style: TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

