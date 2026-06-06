import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/mobile_home_manager.dart';
import '../core/shell/app_catalog.dart';
import '../theme/app_theme.dart';
import '../theme/grid_painter.dart';
import '../widgets/status_bar.dart';

class AppDrawer extends StatefulWidget {
  final MobileHomeManager? mobileHomeManager;
  final int? currentPage;
  final Function(String message)? onAppAdded;
  const AppDrawer({
    super.key,
    this.mobileHomeManager,
    this.currentPage,
    this.onAppAdded,
  });
  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _search = '';
  int _category = 0;

  static const _categories = ['ALL', 'SYSTEM', 'SECURITY', 'TOOLS'];

  List<Map<String, dynamic>> get _filtered {
    final cat = _categories[_category];
    return ShellAppRegistry.forDrawerCategory(cat)
        .where((d) => d.matchesQuery(_search))
        .map(
          (d) => {
            'icon': d.icon,
            'label': d.title,
            'color': d.colorArgb32,
            'cat': d.category,
            'appId': d.id,
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(painter: GridPainter(), child: const SizedBox.expand()),
          Column(
            children: [
              const StatusBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back_ios,
                        color: AppTheme.accent,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _searchBar()),
                  ],
                ),
              ),
              _categoryTabs(),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 110,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) =>
                      _AppTile(
                            app: _filtered[i],
                            mobileHomeManager: widget.mobileHomeManager,
                            currentPage: widget.currentPage ?? 0,
                            onAppAdded: widget.onAppAdded,
                          )
                          .animate(delay: Duration(milliseconds: i * 30))
                          .fadeIn(duration: 200.ms)
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1, 1),
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchBar() => Container(
    height: 36,
    decoration: BoxDecoration(
      color: AppTheme.surfaceAlt,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: TextField(
      onChanged: (v) => setState(() => _search = v),
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: const InputDecoration(
        hintText: '> search apps...',
        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary, size: 16),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );

  Widget _categoryTabs() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: _categories.asMap().entries.map((e) {
        final selected = e.key == _category;
        return GestureDetector(
          onTap: () => setState(() => _category = e.key),
          child: AnimatedContainer(
            duration: 150.ms,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppTheme.accentDim : AppTheme.surfaceAlt,
              border: Border.all(
                color: selected ? AppTheme.accent : AppTheme.border,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                color: selected ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class _AppTile extends StatefulWidget {
  final Map<String, dynamic> app;
  final MobileHomeManager? mobileHomeManager;
  final int currentPage;
  final Function(String message)? onAppAdded;
  const _AppTile({
    required this.app,
    this.mobileHomeManager,
    required this.currentPage,
    this.onAppAdded,
  });
  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  bool _hovered = false;

  void _launch(BuildContext context) {
    final appId = widget.app['appId'] as String?;
    if (appId == null) return;
    if (ShellAppRegistry.lookup(appId) == null) return;
    final dest = ShellAppRegistry.buildShellApp(context, appId);
    Navigator.push(
      context,
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
    final color = Color(widget.app['color'] as int);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _launch(context),
        onLongPress: widget.mobileHomeManager != null
            ? () {
                showMenu<String>(
                  context: context,
                  position: RelativeRect.fromLTRB(100, 300, 100, 300),
                  color: const Color(0xFF1C1C1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  items: [
                    PopupMenuItem<String>(
                      value: 'open',
                      height: 36,
                      child: Row(
                        children: [
                          Icon(
                            Icons.open_in_new,
                            size: 14,
                            color: AppTheme.accent,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Open',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                            ),
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
                          Icon(
                            Icons.add_circle_outline,
                            size: 14,
                            color: AppTheme.accent,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Add to Home Screen',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).then((value) {
                  if (value == 'open') {
                    _launch(context);
                  } else if (value == 'add' &&
                      widget.mobileHomeManager != null) {
                    final appId = widget.app['appId'] as String?;
                    final label = widget.app['label'] as String;
                    final icon = widget.app['icon'] as IconData;
                    final color = Color(widget.app['color'] as int);

                    if (appId != null) {
                      widget.mobileHomeManager!.addItem(
                        widget.currentPage,
                        MobileHomeItem(
                          type: MobileItemType.app,
                          id: 'app_$appId',
                          label: label,
                          icon: icon,
                          color: color,
                          appId: appId,
                        ),
                      );

                      if (widget.onAppAdded != null) {
                        widget.onAppAdded!(
                          '$label added to page ${widget.currentPage + 1}',
                        );
                      }
                    }
                  }
                });
              }
            : null,
        child: AnimatedContainer(
          duration: 150.ms,
          decoration: BoxDecoration(
            color: _hovered ? color.withOpacity(0.1) : AppTheme.surfaceAlt,
            border: Border.all(color: _hovered ? color : AppTheme.border),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hovered
                ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12)]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.app['icon'] as IconData, color: color, size: 30),
              const SizedBox(height: 8),
              Text(
                widget.app['label'] as String,
                style: TextStyle(
                  color: _hovered ? color : AppTheme.textSecondary,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
