import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/os_state.dart';
import '../core/shell/app_catalog.dart';
import '../theme/app_theme.dart';
import '../screens/apps/file_manager_screen.dart';
import '../screens/lock_screen.dart';

class StartMenu extends StatefulWidget {
  final VoidCallback onClose;
  const StartMenu({super.key, required this.onClose});
  @override
  State<StartMenu> createState() => _StartMenuState();
}

class _StartMenuState extends State<StartMenu> {
  String _search = '';
  final _ctrl = TextEditingController();

  static const _recent = [
    {'icon': Icons.description, 'label': 'readme.txt',       'path': '/home/admin/documents'},
    {'icon': Icons.description, 'label': 'KrdOS.conf',    'path': '/home/admin/.config'},
    {'icon': Icons.description, 'label': 'authorized_keys',  'path': '/home/admin/.ssh'},
    {'icon': Icons.description, 'label': 'syslog',           'path': '/var/log'},
  ];

  List<ShellAppDef> get _launchableApps =>
      ShellAppRegistry.all.where((a) => a.id != 'allapps').toList();

  List<Map<String, dynamic>> get _filtered {
    final apps = _search.isEmpty
        ? _launchableApps
        : _launchableApps.where((d) => d.matchesQuery(_search)).toList();
    final sorted = [...apps]..sort((a, b) => a.title.compareTo(b.title));
    return sorted
        .map(
          (d) => {
            'icon': d.icon,
            'label': d.title,
            'color': d.colorArgb32,
            'appId': d.id,
          },
        )
        .toList();
  }

  void _launch(BuildContext ctx, String appId) {
    widget.onClose();
    if (ShellAppRegistry.lookup(appId) == null) return;
    final dest = ShellAppRegistry.buildShellApp(ctx, appId);
    Navigator.push(
      ctx,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => dest,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: 200.ms,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final os = context.watch<OsState>();
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.97),
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 32)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
  // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: AppTheme.textSecondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        onChanged: (v) => setState(() => _search = v),
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        cursorColor: AppTheme.accent,
                        decoration: const InputDecoration(
                          hintText: 'Search apps, files, settings...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
  // Pinned apps
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Text(_search.isEmpty ? 'PINNED' : 'RESULTS',
                    style: TextStyle(color: AppTheme.textSecondary,
                      fontSize: 10, letterSpacing: 2)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 6,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.9,
                children: _filtered.map((a) => _StartAppTile(
                  icon: a['icon'] as IconData,
                  label: a['label'] as String,
                  color: Color(a['color'] as int),
                  onTap: () => _launch(context, a['appId'] as String),
                )).toList(),
              ),
            ),
            if (_search.isEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Text('RECENT', style: TextStyle(color: AppTheme.textSecondary,
                    fontSize: 10, letterSpacing: 2)),
                ]),
              ),
              ...(_recent.map((r) => _RecentTile(
                icon: r['icon'] as IconData,
                label: r['label'] as String,
                path: r['path'] as String,
                onTap: () { widget.onClose(); Navigator.push(context, PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const FileManagerScreen(),
                  transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                  transitionDuration: 200.ms,
                )); },
              ))),
            ],
  // Bottom bar
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
  // User info
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.accentDim,
                      border: Border.all(color: AppTheme.accent),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, color: AppTheme.accent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('admin', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                      Text(
                        os.role == UserRole.admin ? 'Administrator' : 'User',
                        style: TextStyle(
                          color: os.role == UserRole.admin ? AppTheme.accent : AppTheme.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
  // Power options
                  _PowerBtn(Icons.lock_outline, 'Lock', () {
                    widget.onClose();
                    Navigator.pushReplacement(context, PageRouteBuilder(
                      pageBuilder: (_, __, ___) => const LockScreen(),
                      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                      transitionDuration: 300.ms,
                    ));
                  }),
                  const SizedBox(width: 8),
                  _PowerBtn(Icons.restart_alt, 'Restart', () => widget.onClose()),
                  const SizedBox(width: 8),
                  _PowerBtn(Icons.power_settings_new, 'Shutdown', () => widget.onClose(),
                    color: AppTheme.danger),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 150.ms).scale(
        begin: const Offset(0.97, 0.97), end: const Offset(1, 1),
        duration: 150.ms, curve: Curves.easeOut,
      ),
    );
  }
}

class _StartAppTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _StartAppTile({required this.icon, required this.label,
    required this.color, required this.onTap});
  @override
  State<_StartAppTile> createState() => _StartAppTileState();
}

class _StartAppTileState extends State<_StartAppTile> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: 120.ms,
        decoration: BoxDecoration(
          color: _hovered ? widget.color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: widget.color, size: 26),
            const SizedBox(height: 4),
            Text(widget.label,
              style: TextStyle(
                color: _hovered ? widget.color : AppTheme.textSecondary,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecentTile extends StatefulWidget {
  final IconData icon;
  final String label, path;
  final VoidCallback onTap;
  const _RecentTile({required this.icon, required this.label,
    required this.path, required this.onTap});
  @override
  State<_RecentTile> createState() => _RecentTileState();
}

class _RecentTileState extends State<_RecentTile> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit:  (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: 100.ms,
        color: _hovered ? AppTheme.accentDim : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(widget.icon, color: AppTheme.textSecondary, size: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: TextStyle(
                    color: _hovered ? AppTheme.accent : AppTheme.textPrimary, fontSize: 12)),
                  Text(widget.path, style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 9)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
              color: _hovered ? AppTheme.accent : AppTheme.textSecondary, size: 14),
          ],
        ),
      ),
    ),
  );
}

class _PowerBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _PowerBtn(this.icon, this.label, this.onTap, {this.color = AppTheme.textSecondary});
  @override
  State<_PowerBtn> createState() => _PowerBtnState();
}

class _PowerBtnState extends State<_PowerBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.label,
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: 100.ms,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withOpacity(0.15) : Colors.transparent,
            border: Border.all(color: _hovered ? widget.color : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, color: _hovered ? widget.color : AppTheme.textSecondary, size: 18),
        ),
      ),
    ),
  );
}
