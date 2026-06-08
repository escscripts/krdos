import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/os_state.dart';
import '../core/dock_settings.dart';
import '../core/settings_state.dart';
import '../core/shell/app_catalog.dart';
import '../core/shell/power_actions.dart';
import '../theme/app_theme.dart';

/// Advanced Taskbar - Part 1: Core Structure
class NewTaskbar extends StatefulWidget {
  final Function(String) onAppTap;
  final List<dynamic> openWindows;
  final void Function(String)? onWindowTap;
  final void Function(String)? onWindowClose;

  const NewTaskbar({
    super.key,
    required this.onAppTap,
    this.openWindows = const [],
    this.onWindowTap,
    this.onWindowClose,
  });

  @override
  State<NewTaskbar> createState() => _NewTaskbarState();
}

class _NewTaskbarState extends State<NewTaskbar> with SingleTickerProviderStateMixin {
  // State management
  bool _isHovered = false;
  bool _showAllApps = false;
  bool _showControlCenter = false;
  String? _hoveredItem;
  final TextEditingController _searchController = TextEditingController();
  int _quickSettingsPage = 0; // For pagination
  int _ccTab = 0; // 0=main, 1=wifi, 2=bluetooth
  String _allAppsCategory = 'ALL'; // Category filter for all-apps overlay
  late PageController _pageController;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Clock state
  Timer? _clockTimer;
  String _clockTime = '';
  String _clockDate = '';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
  }

  void _updateClock() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    setState(() {
      _clockTime = '$h:$m';
      _clockDate = '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchController.dispose();
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _getApp(String id) {
    final d = ShellAppRegistry.lookup(id);
    return d?.toTaskbarMap();
  }

  @override
  Widget build(BuildContext context) {
    final dockSettings = context.watch<DockSettings>();
    final os = context.watch<OsState>();
    final shell = context.watch<SettingsState>();

    return Stack(
      children: [
  // Control Center Overlay
        if (_showControlCenter) _buildControlCenter(dockSettings, os),
        
  // All Apps Menu Overlay
        if (_showAllApps) _buildAllAppsOverlay(dockSettings),
        
  // Main Taskbar
        _buildMainTaskbar(dockSettings, os, shell),
      ],
    );
  }

  Widget _buildMainTaskbar(DockSettings settings, OsState os, SettingsState shell) {
    final isVertical = settings.position == DockPosition.left || settings.position == DockPosition.right;
    final shouldHide = settings.autoHide && !_isHovered && !_showAllApps && !_showControlCenter;

    return Positioned(
      left: settings.position == DockPosition.left ? 0 : 
            settings.position == DockPosition.right ? null : 0,
      right: settings.position == DockPosition.right ? 0 : 
             settings.position == DockPosition.left ? null : 0,
      top: settings.position == DockPosition.top ? 0 : 
           settings.position == DockPosition.bottom ? null : 0,
      bottom: settings.position == DockPosition.bottom ? 0 : 
              settings.position == DockPosition.top ? null : 0,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: isVertical ? settings.size : double.infinity,
          height: isVertical ? double.infinity : settings.size,
          transform: Matrix4.translationValues(
            settings.position == DockPosition.left && shouldHide ? -settings.size : 
            settings.position == DockPosition.right && shouldHide ? settings.size : 0,
            settings.position == DockPosition.top && shouldHide ? -settings.size : 
            settings.position == DockPosition.bottom && shouldHide ? settings.size : 0,
            0,
          ),
          decoration: BoxDecoration(
            color: Color(0xFF1A1A1A).withValues(
              alpha: (settings.opacity * shell.taskbarTransparency).clamp(0.35, 1.0),
            ),
            border: _getBorder(settings.position),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: _getShadowOffset(settings.position),
              ),
            ],
          ),
          child: isVertical
              ? Column(children: _buildTaskbarContent(settings, os, isVertical))
              : Row(children: _buildTaskbarContent(settings, os, isVertical)),
        ),
      ),
    );
  }

  List<Widget> _buildTaskbarContent(DockSettings settings, OsState os, bool isVertical) {
    final items = <Widget>[];

  // Start Apps Button
    items.add(_buildStartButton(settings));
    items.add(_buildDivider(isVertical));

  // Apply alignment for pinned apps and windows
    if (settings.alignment == DockAlignment.start) {
  // Start alignment - items at start
      items.addAll(_buildPinnedAndWindows(settings, isVertical));
      items.add(const Spacer());
    } else if (settings.alignment == DockAlignment.center) {
  // Center alignment - center the pinned apps and windows
      items.add(const Spacer());
      items.addAll(_buildPinnedAndWindows(settings, isVertical));
      items.add(const Spacer());
    } else {
  // End alignment - items at end (before system tray)
      items.add(const Spacer());
      items.addAll(_buildPinnedAndWindows(settings, isVertical));
      items.add(const SizedBox(width: 8, height: 8));
    }

  // System Tray always at the absolute end
    items.add(_buildSystemTray(os, settings, isVertical));

    return items;
  }

  List<Widget> _buildPinnedAndWindows(DockSettings settings, bool isVertical) {
    final items = <Widget>[];

  // Pinned Apps
    for (final appId in settings.pinnedApps) {
      if (appId == 'allapps') continue;
      final app = _getApp(appId);
      if (app != null) {
        items.add(_buildAppIcon(app, settings, false));
      }
    }

  // Running Windows
    if (widget.openWindows.isNotEmpty) {
      items.add(_buildDivider(isVertical));
      for (final window in widget.openWindows) {
        items.add(_buildWindowButton(window, isVertical));
      }
    }

    return items;
  }

  Widget _buildStartButton(DockSettings settings) {
    final isActive = _showAllApps;
    final isHovered = _hoveredItem == 'start';

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredItem = 'start'),
      onExit: (_) => setState(() => _hoveredItem = null),
      child: GestureDetector(
        onTap: () => setState(() => _showAllApps = !_showAllApps),
        child: Tooltip(
          message: 'All Apps',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.accent.withOpacity(0.2) : 
                     isHovered ? AppTheme.surfaceAlt : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive ? Border.all(color: AppTheme.accent, width: 1.5) : null,
            ),
            child: Icon(
              Icons.apps_rounded,
              color: isActive || isHovered ? AppTheme.accent : AppTheme.textSecondary,
              size: settings.iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon(Map<String, dynamic> app, DockSettings settings, bool isRunning) {
    final appId = app['id'] as String;
    final isHovered = _hoveredItem == appId;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredItem = appId),
      onExit: (_) => setState(() => _hoveredItem = null),
      child: GestureDetector(
        onTap: () => widget.onAppTap(appId),
        onSecondaryTapDown: (_) => _showAppContextMenu(app, settings),
        child: Tooltip(
          message: app['label'] as String,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHovered ? AppTheme.surfaceAlt : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  app['icon'] as IconData,
                  color: isHovered ? AppTheme.accent : AppTheme.textSecondary,
                  size: settings.iconSize,
                ),
                if (isRunning)
                  Positioned(
                    bottom: -4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWindowButton(dynamic window, bool isVertical) {
    final id = window.id as String;
    final title = window.title as String;
    final icon = window.icon as IconData;
    final color = window.color as Color;
    final minimized = window.minimized as bool;
    final isHovered = _hoveredItem == 'window_$id';

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredItem = 'window_$id'),
      onExit: (_) => setState(() => _hoveredItem = null),
      child: GestureDetector(
        onTap: () => widget.onWindowTap?.call(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(maxWidth: isVertical ? double.infinity : 200),
          decoration: BoxDecoration(
            color: isHovered ? color.withOpacity(0.2) : 
                   minimized ? AppTheme.surface : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: minimized ? AppTheme.border : color,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              if (!isVertical) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: minimized ? AppTheme.textSecondary : AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (isHovered) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => widget.onWindowClose?.call(id),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(Icons.close, size: 10, color: AppTheme.danger),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemTray(OsState os, DockSettings settings, bool isVertical) {
    return GestureDetector(
      onTap: () => setState(() => _showControlCenter = !_showControlCenter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            left: !isVertical ? const BorderSide(color: AppTheme.border) : BorderSide.none,
            top: isVertical ? const BorderSide(color: AppTheme.border) : BorderSide.none,
          ),
        ),
        child: isVertical ? _buildVerticalTray(os) : _buildHorizontalTray(os),
      ),
    );
  }

  Widget _buildHorizontalTray(OsState os) {
    final battColor = os.batteryCharging
        ? const Color(0xFF00FF88)
        : os.batteryLevel <= 15
            ? const Color(0xFFFF4444)
            : AppTheme.textSecondary;
    final battIcon = os.batteryCharging
        ? Icons.battery_charging_full_rounded
        : os.batteryLevel >= 90
            ? Icons.battery_full_rounded
            : os.batteryLevel >= 60
                ? Icons.battery_4_bar_rounded
                : os.batteryLevel >= 30
                    ? Icons.battery_2_bar_rounded
                    : Icons.battery_alert_rounded;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (os.hasBattery) ...[
          Icon(battIcon, size: 13, color: battColor),
          const SizedBox(width: 3),
          Text('${os.batteryLevel}%',
              style: TextStyle(color: battColor, fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
        ],
        Icon(Icons.wifi, size: 14, color: os.wifiEnabled ? AppTheme.accent : AppTheme.textSecondary),
        const SizedBox(width: 6),
        Icon(Icons.shield, size: 14, color: os.firewallEnabled ? AppTheme.accent : AppTheme.danger),
        const SizedBox(width: 6),
        Icon(Icons.vpn_lock, size: 14, color: os.vpnEnabled ? AppTheme.accent : AppTheme.textSecondary),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_clockTime,
                style: const TextStyle(
                    color: Color(0xFFE0E0F0), fontSize: 11, fontWeight: FontWeight.w600)),
            Text(_clockDate,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
          ],
        ),
        const SizedBox(width: 6),
        const Icon(Icons.expand_less, size: 16, color: AppTheme.textSecondary),
      ],
    );
  }

  Widget _buildVerticalTray(OsState os) {
    final battColor = os.batteryCharging
        ? const Color(0xFF00FF88)
        : os.batteryLevel <= 15
            ? const Color(0xFFFF4444)
            : AppTheme.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Clock time (compact)
        Text(_clockTime,
            style: const TextStyle(
                color: Color(0xFFE0E0F0), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (os.hasBattery) ...[
          Icon(
            os.batteryCharging
                ? Icons.battery_charging_full_rounded
                : os.batteryLevel >= 50
                    ? Icons.battery_full_rounded
                    : Icons.battery_2_bar_rounded,
            size: 13,
            color: battColor,
          ),
          const SizedBox(height: 6),
        ],
        Icon(Icons.wifi, size: 14, color: os.wifiEnabled ? AppTheme.accent : AppTheme.textSecondary),
        const SizedBox(height: 6),
        Icon(Icons.shield, size: 14, color: os.firewallEnabled ? AppTheme.accent : AppTheme.danger),
        const SizedBox(height: 6),
        Icon(Icons.vpn_lock, size: 14, color: os.vpnEnabled ? AppTheme.accent : AppTheme.textSecondary),
        const SizedBox(height: 10),
        const Icon(Icons.expand_less, size: 16, color: AppTheme.textSecondary),
      ],
    );
  }

  Widget _buildDivider(bool isVertical) {
    return Container(
      width: isVertical ? null : 1,
      height: isVertical ? 1 : 28,
      margin: EdgeInsets.symmetric(
        horizontal: isVertical ? 8 : 4,
        vertical: isVertical ? 4 : 0,
      ),
      color: AppTheme.border.withOpacity(0.5),
    );
  }

  Border _getBorder(DockPosition position) {
    switch (position) {
      case DockPosition.bottom:
        return const Border(top: BorderSide(color: AppTheme.border));
      case DockPosition.top:
        return const Border(bottom: BorderSide(color: AppTheme.border));
      case DockPosition.left:
        return const Border(right: BorderSide(color: AppTheme.border));
      case DockPosition.right:
        return const Border(left: BorderSide(color: AppTheme.border));
    }
  }

  String _catLabel(String cat) {
    switch (cat.toUpperCase()) {
      case 'SECURITY': return 'Security';
      case 'SYSTEM':   return 'System';
      case 'TOOLS':    return 'Tools';
      case 'NETWORK':  return 'Network';
      case 'MEDIA':    return 'Media';
      case 'DEV':      return 'Dev';
      default:         return cat[0].toUpperCase() + cat.substring(1).toLowerCase();
    }
  }

  Offset _getShadowOffset(DockPosition position) {
    switch (position) {
      case DockPosition.bottom:
        return const Offset(0, -5);
      case DockPosition.top:
        return const Offset(0, 5);
      case DockPosition.left:
        return const Offset(5, 0);
      case DockPosition.right:
        return const Offset(-5, 0);
    }
  }

  void _showAppContextMenu(Map<String, dynamic> app, DockSettings settings) {
    final appId = app['id'] as String;
    final isPinned = settings.pinnedApps.contains(appId);

    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(200, 300, 200, 300),
      color: const Color(0xFF1C1C1E),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'open',
          height: 40,
          child: Row(children: [
            Icon(Icons.open_in_new, size: 16, color: AppTheme.accent),
            const SizedBox(width: 12),
            Text('Open', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: isPinned ? 'unpin' : 'pin',
          height: 40,
          child: Row(children: [
            Icon(
              isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              size: 16,
              color: isPinned ? AppTheme.danger : AppTheme.accent,
            ),
            const SizedBox(width: 12),
            Text(
              isPinned ? 'Unpin from Taskbar' : 'Pin to Taskbar',
              style: TextStyle(
                color: isPinned ? AppTheme.danger : AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
          ]),
        ),
      ],
    ).then((value) {
      if (value == 'open') {
        widget.onAppTap(app['id'] as String);
      } else if (value == 'pin') {
        settings.addPinnedApp(appId);
      } else if (value == 'unpin') {
        settings.removePinnedApp(appId);
      }
    });
  }

  Widget _buildAllAppsOverlay(DockSettings settings) {
    final screenSize = MediaQuery.of(context).size;
    final position = settings.position;
    // ignore: unused_local_variable
    final isVertical = position == DockPosition.left || position == DockPosition.right;

    // All pinnable apps
    final all = ShellAppRegistry.all.where((a) => a.allowTaskbarPin).toList();

    // Collect categories
    final categories = <String>['ALL',
      ...all.map((a) => a.category).toSet().toList()..sort()];

    // Filter apps: category + search
    final searchQuery = _searchController.text.toLowerCase();
    final filteredDefs = all.where((a) {
      final catMatch = _allAppsCategory == 'ALL' || a.category == _allAppsCategory;
      final searchMatch = searchQuery.isEmpty || a.matchesQuery(searchQuery);
      return catMatch && searchMatch;
    }).toList();
    filteredDefs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final filteredApps = filteredDefs.map((a) => a.toTaskbarMap()).toList();

  // Calculate menu dimensions
    final menuWidth = 700.0;
    final menuHeight = (screenSize.height * 0.7).clamp(400.0, 700.0);

  // Calculate position based on taskbar position and alignment
    double? left, right, top, bottom;
    
    if (position == DockPosition.bottom) {
      bottom = settings.size + 12;
  // Center horizontally regardless of alignment
      left = (screenSize.width - menuWidth) / 2;
    } else if (position == DockPosition.top) {
      top = settings.size + 12;
  // Center horizontally regardless of alignment
      left = (screenSize.width - menuWidth) / 2;
    } else if (position == DockPosition.left) {
      left = settings.size + 12;
      bottom = 12;
    } else {
      right = settings.size + 12;
      bottom = 12;
    }

    return GestureDetector(
      onTap: () => setState(() {
        _showAllApps = false;
        _searchController.clear();
        _allAppsCategory = 'ALL';
      }),
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Stack(
          children: [
            Positioned(
              left: left,
              right: right,
              top: top,
              bottom: bottom,
              child: GestureDetector(
                onTap: () {},
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.95 + (0.05 * value),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: menuWidth,
                    height: menuHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
  // Search Bar
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: AppTheme.accent, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                                  decoration: const InputDecoration(
                                    hintText: 'Search apps...',
                                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (value) => setState(() {}),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () => setState(() => _searchController.clear()),
                                  child: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                                ),
                            ],
                          ),
                        ),

  // Category filter chips
                        if (searchQuery.isEmpty)
                          SizedBox(
                            height: 36,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: categories.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 6),
                              itemBuilder: (_, i) {
                                final cat = categories[i];
                                final active = _allAppsCategory == cat;
                                return GestureDetector(
                                  onTap: () => setState(() => _allAppsCategory = cat),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: active ? AppTheme.accentDim : AppTheme.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: active ? AppTheme.accent : AppTheme.border.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      cat == 'ALL' ? 'All Apps' : _catLabel(cat),
                                      style: TextStyle(
                                        color: active ? AppTheme.accent : AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 8),

  // Apps Grid
                        Expanded(
                          child: filteredApps.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No apps found',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 6,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 0.85,
                                  ),
                                  itemCount: filteredApps.length,
                                  itemBuilder: (context, index) {
                                    return _AllAppItem(
                                      app: filteredApps[index],
                                      onTap: () {
                                        final appId = filteredApps[index]['id'] as String;
                                        setState(() {
                                          _showAllApps = false;
                                          _searchController.clear();
                                        });
                                        widget.onAppTap(appId);
                                      },
                                      onLongPress: () => _showAppContextMenu(filteredApps[index], settings),
                                      delay: index * 15,
                                    );
                                  },
                                ),
                        ),
                        
  // Footer
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: AppTheme.border)),
                          ),
                          child: Row(
                            children: [
  // User Profile
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _showAllApps = false);
                                    widget.onAppTap('users');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppTheme.accent.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: AppTheme.accent, width: 2),
                                          ),
                                          child: Icon(Icons.person, color: AppTheme.accent, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Admin User',
                                                style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                'Administrator',
                                                style: TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
  // Power Menu
                              GestureDetector(
                                onTap: _showPowerMenu,
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppTheme.danger.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.danger.withOpacity(0.3), width: 1.5),
                                  ),
                                  child: const Icon(Icons.power_settings_new, color: AppTheme.danger, size: 24),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPowerMenu() {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(300, 400, 300, 200),
      color: const Color(0xFF1C1C1E),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'lock',
          height: 44,
          child: Row(children: [
            Icon(Icons.lock_outline, size: 18, color: AppTheme.accent),
            const SizedBox(width: 12),
            Text('Lock', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'sleep',
          height: 44,
          child: Row(children: [
            Icon(Icons.bedtime_outlined, size: 18, color: AppTheme.warning),
            const SizedBox(width: 12),
            Text('Sleep', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'restart',
          height: 44,
          child: Row(children: [
            Icon(Icons.restart_alt, size: 18, color: AppTheme.accent),
            const SizedBox(width: 12),
            Text('Restart', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
          ]),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'shutdown',
          height: 44,
          child: Row(children: [
            Icon(Icons.power_settings_new, size: 18, color: AppTheme.danger),
            const SizedBox(width: 12),
            Text('Shut Down', style: TextStyle(color: AppTheme.danger, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    ).then((value) {
      if (value != null) {
        setState(() => _showAllApps = false);
        _handlePowerAction(value);
      }
    });
  }

  Future<void> _handlePowerAction(String action) async {
    final os = context.read<OsState>();
    switch (action) {
      case 'lock':
        os.lock();
        break;
      case 'sleep':
        os.enterDisplaySleep();
        break;
      case 'restart':
        final go = await _confirmPowerAction(
          title: 'Restart KrdOS?',
          body: 'The application will close and launch again.',
        );
        if (go == true && mounted) {
          await restartApplication();
        }
        break;
      case 'shutdown':
        final go = await _confirmPowerAction(
          title: 'Shut down?',
          body: kIsWeb
              ? 'This will close the app tab or window.'
              : 'The application will exit.',
        );
        if (go == true && mounted) {
          exitApplication();
        }
        break;
    }
  }

  Future<bool?> _confirmPowerAction({
    required String title,
    required String body,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text(body, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Continue',
              style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCenter(DockSettings settings, OsState os) {
    final screenSize = MediaQuery.of(context).size;
    final position = settings.position;
    
  // Calculate dimensions
    final panelWidth = 420.0;
    final panelHeight = (screenSize.height * 0.75).clamp(500.0, 750.0);

  // Calculate position based on taskbar location
    double? left, right, top, bottom;
    
    if (position == DockPosition.bottom) {
      bottom = settings.size + 12;
      right = 12;
    } else if (position == DockPosition.top) {
      top = settings.size + 12;
      right = 12;
    } else if (position == DockPosition.left) {
      left = settings.size + 12;
      top = 12;
    } else {
      right = settings.size + 12;
      top = 12;
    }

    return GestureDetector(
      onTap: () => setState(() => _showControlCenter = false),
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Stack(
          children: [
            Positioned(
              left: left,
              right: right,
              top: top,
              bottom: bottom,
              child: GestureDetector(
                onTap: () {},
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(20 * (1 - value), 0),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: panelWidth,
                    height: panelHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A).withOpacity(0.98),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 50,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
  // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppTheme.border)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Control Center',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(() => _showControlCenter = false),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
  // Content
                        Expanded(
                          child: _ccTab == 0 ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
  // Quick Settings
                              _buildQuickSettings(os),
                              const SizedBox(height: 16),
                              
  // Brightness & Volume - Compact
                              Row(children: [
                                Expanded(child: _CompactSlider(
                                  icon: Icons.brightness_6,
                                  value: os.brightness,
                                  color: AppTheme.warning,
                                  onChanged: (v) => os.setBrightness(v),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _CompactSlider(
                                  icon: Icons.volume_up,
                                  value: os.volume,
                                  color: AppTheme.accent,
                                  onChanged: (v) => os.setVolume(v),
                                )),
                              ]),
                              const SizedBox(height: 16),
                              
  // Notifications Section
                              _buildNotificationsSection(os),
                            ],
                          ) : _ccTab == 1 ? _buildWifiPanel(os) : _buildBluetoothPanel(os),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSettings(OsState os) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
  // WiFi & Bluetooth - Windows 11 Style
        Row(children: [
          Expanded(child: _ConnectionTile(
            icon: Icons.wifi,
            label: 'Wi-Fi',
            subtitle: os.wifiEnabled ? os.connectedWifi : 'Off',
            isActive: os.wifiEnabled,
            onToggle: () => os.toggleWifi(),
            onSettings: () => setState(() => _ccTab = 1),
          )),
          const SizedBox(width: 12),
          Expanded(child: _ConnectionTile(
            icon: Icons.bluetooth,
            label: 'Bluetooth',
            subtitle: os.bluetoothEnabled ? 'On' : 'Off',
            isActive: os.bluetoothEnabled,
            onToggle: () => os.toggleBluetooth(),
            onSettings: () => setState(() => _ccTab = 2),
          )),
        ]),
        const SizedBox(height: 16),
  // Paginated Quick Settings
        Container(
          height: 130,
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border.withOpacity(0.5)),
          ),
          child: Column(children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _quickSettingsPage = page),
                children: [
                  _buildQuickSettingsPage1(os),
                  _buildQuickSettingsPage2(os),
                ],
              ),
            ),
  // Page Indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _quickSettingsPage > 0 ? () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } : null,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.chevron_left,
                        color: _quickSettingsPage == 0 ? AppTheme.border : AppTheme.accent,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PageDot(active: _quickSettingsPage == 0),
                  const SizedBox(width: 6),
                  _PageDot(active: _quickSettingsPage == 1),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _quickSettingsPage < 1 ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } : null,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.chevron_right,
                        color: _quickSettingsPage == 1 ? AppTheme.border : AppTheme.accent,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildQuickSettingsPage1(OsState os) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: Row(children: [
              Expanded(child: _MiniTile(icon: Icons.vpn_lock, label: 'VPN', active: os.vpnEnabled, onTap: os.toggleVpn)),
              const SizedBox(width: 8),
              Expanded(child: _MiniTile(icon: Icons.shield, label: 'Firewall', active: os.firewallEnabled, onTap: os.toggleFirewall)),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(children: [
              Expanded(child: _MiniTile(icon: Icons.visibility_off, label: 'IP Mask', active: os.ipMasked, onTap: os.toggleIpMask)),
              const SizedBox(width: 8),
              Expanded(
                child: Consumer<SettingsState>(
                  builder: (context, settings, _) {
                    final plat = MediaQuery.platformBrightnessOf(context);
                    final dark = settings.isEffectivelyDark(plat);
                    return _MiniTile(
                      icon: Icons.dark_mode,
                      label: 'Dark',
                      active: dark,
                      onTap: () => settings.toggleLightDarkTheme(plat),
                    );
                  },
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSettingsPage2(OsState os) {
    return Consumer<SettingsState>(
      builder: (context, settings, _) => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: Row(children: [
                Expanded(child: _MiniTile(
                  icon: Icons.nightlight_rounded,
                  label: 'Night',
                  active: settings.nightLightEnabled,
                  onTap: settings.toggleNightLight,
                )),
                const SizedBox(width: 8),
                Expanded(child: _MiniTile(
                  icon: Icons.do_not_disturb_rounded,
                  label: 'DND',
                  active: os.doNotDisturb,
                  onTap: os.toggleDoNotDisturb,
                )),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(children: [
                Expanded(child: _MiniTile(
                  icon: os.hasBattery
                      ? (os.batteryCharging
                          ? Icons.battery_charging_full
                          : os.batteryLevel >= 75
                              ? Icons.battery_full
                              : os.batteryLevel >= 40
                                  ? Icons.battery_3_bar
                                  : os.batteryLevel >= 15
                                      ? Icons.battery_1_bar
                                      : Icons.battery_alert)
                      : Icons.battery_saver,
                  label: os.hasBattery ? '${os.batteryLevel}%' : 'Battery',
                  active: false,
                  onTap: () {},
                )),
                const SizedBox(width: 8),
                Expanded(child: _MiniTile(
                  icon: Icons.airplanemode_active,
                  label: 'Airplane',
                  active: false,
                  onTap: () {},
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessControl(OsState os) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.brightness_6, color: AppTheme.warning, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Brightness',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(os.brightness * 100).round()}%',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppTheme.warning,
              inactiveTrackColor: AppTheme.surfaceAlt,
              thumbColor: AppTheme.warning,
              overlayColor: AppTheme.warning.withOpacity(0.2),
            ),
            child: Slider(
              value: os.brightness,
              onChanged: (value) => os.setBrightness(value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl(OsState os) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  os.volume == 0 ? Icons.volume_off : 
                  os.volume < 0.5 ? Icons.volume_down : Icons.volume_up,
                  color: AppTheme.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Volume',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(os.volume * 100).round()}%',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.surfaceAlt,
              thumbColor: AppTheme.accent,
              overlayColor: AppTheme.accent.withOpacity(0.2),
            ),
            child: Slider(
              value: os.volume,
              onChanged: (value) => os.setVolume(value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(OsState os) {
    final notifications = os.notifications;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
          child: Row(
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (notifications.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      for (var i = notifications.length - 1; i >= 0; i--) {
                        os.dismissNotif(notifications[i].id);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Clear All',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (notifications.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 48,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...notifications.map((notif) => _NotificationCard(
            notification: notif,
            onDismiss: () {
              setState(() {
                os.dismissNotif(notif.id);
              });
            },
          )),
      ],
    );
  }

  Widget _buildWifiPanel(OsState os) {
    return Column(children: [
  // Header
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => _ccTab = 0),
            child: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.accent, size: 16),
          ),
          const SizedBox(width: 12),
          Text('Wi-Fi Settings',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(
            onTap: os.scanWifi,
            child: os.scanningWifi
              ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
              : Icon(Icons.refresh_rounded, color: AppTheme.accent, size: 18),
          ),
        ]),
      ),
  // Networks List
      Expanded(
        child: !os.wifiEnabled
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 48, color: AppTheme.textSecondary),
                  const SizedBox(height: 12),
                  Text('Wi-Fi is off', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: os.toggleWifi,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentDim,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accent),
                      ),
                      child: Text('Turn On Wi-Fi',
                        style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: os.wifiNetworks.map((n) => _WifiNetworkTile(
                ssid: n['ssid'],
                signal: n['signal'],
                secured: n['secured'],
                connected: n['connected'],
                onTap: () => _connectToWifi(context, os, n),
              )).toList(),
            ),
      ),
    ]);
  }

  Widget _buildBluetoothPanel(OsState os) {
    return Column(children: [
  // Header
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => _ccTab = 0),
            child: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.accent, size: 16),
          ),
          const SizedBox(width: 12),
          Text('Bluetooth Settings',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
  // Devices List
      Expanded(
        child: !os.bluetoothEnabled
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth_disabled, size: 48, color: AppTheme.textSecondary),
                  const SizedBox(height: 12),
                  Text('Bluetooth is off', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: os.toggleBluetooth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentDim,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.accent),
                      ),
                      child: Text('Turn On Bluetooth',
                        style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: os.btDevices.map((d) => _BluetoothDeviceTile(
                name: d['name'],
                type: d['type'],
                paired: d['paired'],
                connected: d['connected'],
                onTap: () {
                  final mac = (d['mac'] as String?) ?? (d['name'] as String);
                  if (d['connected'] == true) {
                    os.disconnectBluetooth(mac);
                  } else {
                    os.connectBluetooth(mac);
                  }
                },
              )).toList(),
            ),
      ),
    ]);
  }

  void _connectToWifi(BuildContext context, OsState os, Map<String, dynamic> network) {
    if (network['connected']) return;
    if (!network['secured']) {
      os.connectWifi(network['ssid']);
      return;
    }
    
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 440, bottom: 100),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Icon(Icons.wifi_lock_rounded, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(network['ssid'],
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 16),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  key: ValueKey('wifi_password_${network['ssid']}'),
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.accent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      os.connectWifi(network['ssid'], password: value);
                      Navigator.pop(dialogContext);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text('Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (passwordController.text.isNotEmpty) {
                          os.connectWifi(network['ssid'], password: passwordController.text);
                          Navigator.pop(dialogContext);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentDim,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.accent),
                        ),
                        child: Text('Connect',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}


// All Apps Grid Item Widget
class _AllAppItem extends StatefulWidget {
  final Map<String, dynamic> app;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int delay;

  const _AllAppItem({
    required this.app,
    required this.onTap,
    required this.onLongPress,
    this.delay = 0,
  });

  @override
  State<_AllAppItem> createState() => _AllAppItemState();
}

class _AllAppItemState extends State<_AllAppItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 150 + widget.delay),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTapDown: (_) => widget.onLongPress(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _hovered ? AppTheme.surfaceAlt : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: _hovered ? Border.all(color: AppTheme.border) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _hovered 
                        ? Color(widget.app['color'] as int).withOpacity(0.2)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: _hovered 
                        ? Border.all(color: Color(widget.app['color'] as int), width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    widget.app['icon'] as IconData,
                    color: _hovered 
                        ? Color(widget.app['color'] as int)
                        : AppTheme.textSecondary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.app['label'] as String,
                  style: TextStyle(
                    color: _hovered ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: _hovered ? FontWeight.w600 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// Quick Setting Tile Widget
class _QuickSettingTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _QuickSettingTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickSettingTile> createState() => _QuickSettingTileState();
}

class _QuickSettingTileState extends State<_QuickSettingTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive 
                ? widget.color.withOpacity(0.15)
                : _hovered 
                    ? AppTheme.surfaceAlt 
                    : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isActive 
                  ? widget.color.withOpacity(0.4)
                  : AppTheme.border,
              width: widget.isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    widget.icon,
                    color: widget.isActive ? widget.color : AppTheme.textSecondary,
                    size: 18,
                  ),
                  const Spacer(),
                  if (widget.isActive)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Notification Card Widget
class _NotificationCard extends StatefulWidget {
  final dynamic notification;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final notif = widget.notification;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hovered ? AppTheme.surfaceAlt : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getNotificationColor(notif.type).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getNotificationIcon(notif.type),
                color: _getNotificationColor(notif.type),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(notif.time),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_hovered) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.close, size: 14, color: AppTheme.danger),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotifType type) {
    switch (type) {
      case NotifType.system:
        return Icons.info_outline;
      case NotifType.security:
        return Icons.security;
      case NotifType.network:
        return Icons.wifi;
      case NotifType.warning:
        return Icons.warning_amber_outlined;
    }
  }

  Color _getNotificationColor(NotifType type) {
    switch (type) {
      case NotifType.system:
        return AppTheme.accent;
      case NotifType.security:
        return const Color(0xFFFF9800);
      case NotifType.network:
        return const Color(0xFF00BCD4);
      case NotifType.warning:
        return AppTheme.warning;
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// Connection Tile - Windows 11 Style
class _ConnectionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isActive;
  final VoidCallback onToggle;
  final VoidCallback onSettings;

  const _ConnectionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.onToggle,
    required this.onSettings,
  });

  @override
  State<_ConnectionTile> createState() => _ConnectionTileState();
}

class _ConnectionTileState extends State<_ConnectionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 70,
        decoration: BoxDecoration(
          color: widget.isActive ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isActive ? AppTheme.accent.withOpacity(0.4) : AppTheme.border,
            width: widget.isActive ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
  // Left: Toggle
          Expanded(
            child: GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.isActive ? AppTheme.accent.withOpacity(0.2) : AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.isActive ? AppTheme.accent : AppTheme.textSecondary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
  // Right: Settings Arrow
          GestureDetector(
            onTap: widget.onSettings,
            child: Container(
              width: 40,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: AppTheme.border.withOpacity(0.5))),
              ),
              child: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}

// Compact Slider Widget
class _CompactSlider extends StatelessWidget {
  final IconData icon;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  const _CompactSlider({
    required this.icon,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const Spacer(),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: color,
              inactiveTrackColor: AppTheme.surfaceAlt,
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

// Mini Tile for Quick Settings
class _MiniTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MiniTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_MiniTile> createState() => _MiniTileState();
}

class _MiniTileState extends State<_MiniTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.active ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.active ? AppTheme.accent.withOpacity(0.4) : AppTheme.border,
              width: widget.active ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.active ? AppTheme.accent : AppTheme.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.active ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Page Dot Indicator
class _PageDot extends StatelessWidget {
  final bool active;
  const _PageDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? AppTheme.accent : AppTheme.border,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// WiFi Network Tile
class _WifiNetworkTile extends StatefulWidget {
  final String ssid;
  final int signal;
  final bool secured;
  final bool connected;
  final VoidCallback onTap;

  const _WifiNetworkTile({
    required this.ssid,
    required this.signal,
    required this.secured,
    required this.connected,
    required this.onTap,
  });

  @override
  State<_WifiNetworkTile> createState() => _WifiNetworkTileState();
}

class _WifiNetworkTileState extends State<_WifiNetworkTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.connected ? AppTheme.accentDim : _hovered ? AppTheme.surfaceAlt : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.connected ? AppTheme.accent : AppTheme.border,
              width: widget.connected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Icon(
              Icons.wifi_rounded,
              color: widget.connected ? AppTheme.accent : AppTheme.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.ssid,
                style: TextStyle(
                  color: widget.connected ? AppTheme.accent : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: widget.connected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (widget.secured)
              const Icon(Icons.lock_rounded, color: AppTheme.textSecondary, size: 12),
            const SizedBox(width: 8),
            Text(
              '${widget.signal}%',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            if (widget.connected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: AppTheme.accent, size: 16),
            ],
          ]),
        ),
      ),
    );
  }
}

// Bluetooth Device Tile
class _BluetoothDeviceTile extends StatefulWidget {
  final String name;
  final String type;
  final bool paired;
  final bool connected;
  final VoidCallback onTap;

  const _BluetoothDeviceTile({
    required this.name,
    required this.type,
    required this.paired,
    required this.connected,
    required this.onTap,
  });

  @override
  State<_BluetoothDeviceTile> createState() => _BluetoothDeviceTileState();
}

class _BluetoothDeviceTileState extends State<_BluetoothDeviceTile> {
  bool _hovered = false;

  IconData get _icon {
    switch (widget.type) {
      case 'audio': return Icons.headphones_rounded;
      case 'input': return Icons.keyboard_rounded;
      case 'device': return Icons.devices_rounded;
      default: return Icons.bluetooth_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.connected ? AppTheme.accentDim : _hovered ? AppTheme.surfaceAlt : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.connected ? AppTheme.accent : AppTheme.border,
              width: widget.connected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Icon(
              _icon,
              color: widget.connected ? AppTheme.accent : AppTheme.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      color: widget.connected ? AppTheme.accent : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: widget.connected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  Text(
                    widget.paired ? 'Paired' : 'Not paired',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.connected ? AppTheme.danger.withOpacity(0.15) : AppTheme.accentDim,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.connected ? AppTheme.danger : AppTheme.accent,
                ),
              ),
              child: Text(
                widget.connected ? 'Disconnect' : 'Connect',
                style: TextStyle(
                  color: widget.connected ? AppTheme.danger : AppTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
