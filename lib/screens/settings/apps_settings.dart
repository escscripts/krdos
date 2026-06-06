import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/settings_state.dart';
import '../../theme/app_theme.dart';

class AppsSettingsScreen extends StatefulWidget {
  final int initialTab;

  const AppsSettingsScreen({super.key, this.initialTab = 0});

  @override
  State<AppsSettingsScreen> createState() => _AppsSettingsScreenState();
}

class _AppsSettingsScreenState extends State<AppsSettingsScreen> {
  late int _selectedTab = widget.initialTab.clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 720;
        if (narrow) {
          return Column(
            children: [
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  children: [
                    _buildSidebarChip(0, Icons.apps_rounded, 'Installed'),
                    _buildSidebarChip(1, Icons.star_rounded, 'Defaults'),
                    _buildSidebarChip(2, Icons.rocket_launch_rounded, 'Startup'),
                  ],
                ),
              ),
              Container(height: 1, color: AppTheme.border.withValues(alpha: 0.45)),
              Expanded(child: _buildContent()),
            ],
          );
        }
        return Row(
          children: [
            _buildSidebar(),
            Expanded(child: _buildContent()),
          ],
        );
      },
    );
  }

  Widget _buildSidebarChip(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppTheme.accent.withValues(alpha: 0.12) : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _selectedTab = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: isSelected ? AppTheme.accent : AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          _buildSidebarItem(0, Icons.apps_rounded, 'Installed Apps'),
          _buildSidebarItem(1, Icons.star_rounded, 'Default Apps'),
          _buildSidebarItem(2, Icons.rocket_launch_rounded, 'Startup'),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accent : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.accent : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildInstalledAppsTab();
      case 1:
        return _buildDefaultAppsTab();
      case 2:
        return _buildStartupTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildInstalledAppsTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        final installedApps = settings.installedApps.where((app) => app['installed'] == true).toList();
        
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Text(
                  'Installed Apps',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${installedApps.length} apps',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your installed applications',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ...installedApps.asMap().entries.map((entry) {
              final index = settings.installedApps.indexOf(entry.value);
              return _buildAppCard(entry.value, index, settings);
            }),
          ],
        );
      },
    );
  }

  Widget _buildAppCard(Map<String, dynamic> app, int index, SettingsState settings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accent, AppTheme.accent.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getAppIcon(app['icon']),
              color: Colors.black,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app['name'],
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  app['size'],
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => _UninstallDialog(
                  appName: app['name'],
                  onConfirm: () {
                    settings.uninstallApp(index);
                    Navigator.pop(context);
                  },
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.danger),
              ),
              child: Text(
                'Uninstall',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAppIcon(String icon) {
    switch (icon) {
      case 'folder':
        return Icons.folder_rounded;
      case 'terminal':
        return Icons.terminal_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'web':
        return Icons.language_rounded;
      case 'calculate':
        return Icons.calculate_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  Widget _buildDefaultAppsTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Default Apps',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose which apps to use by default',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ...settings.defaultApps.entries.map((entry) {
              return _buildDefaultAppCard(entry.key, entry.value, settings);
            }),
          ],
        );
      },
    );
  }

  Widget _buildDefaultAppCard(String category, String currentApp, SettingsState settings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(category),
              color: AppTheme.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentApp,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => _DefaultAppDialog(
                  category: category,
                  currentApp: currentApp,
                  onSelect: (app) {
                    settings.setDefaultApp(category, app);
                    Navigator.pop(context);
                  },
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Change',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Browser':
        return Icons.language_rounded;
      case 'Email':
        return Icons.email_rounded;
      case 'Music':
        return Icons.music_note_rounded;
      case 'Video':
        return Icons.video_library_rounded;
      case 'Photos':
        return Icons.photo_library_rounded;
      case 'Files':
        return Icons.folder_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  Widget _buildStartupTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Startup Apps',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose which apps start automatically when you sign in',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ...settings.startupApps.asMap().entries.map((entry) {
              return _buildStartupAppCard(entry.value, entry.key, settings);
            }),
          ],
        );
      },
    );
  }

  Widget _buildStartupAppCard(Map<String, dynamic> app, int index, SettingsState settings) {
    final enabled = app['enabled'] as bool;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: enabled ? AppTheme.surface : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: enabled 
                  ? AppTheme.accent.withOpacity(0.15)
                  : AppTheme.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              color: enabled ? AppTheme.accent : AppTheme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app['name'],
                  style: TextStyle(
                    color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enabled ? 'Starts automatically' : 'Disabled',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (_) => settings.toggleStartupApp(index),
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }
}

class _UninstallDialog extends StatelessWidget {
  final String appName;
  final VoidCallback onConfirm;

  const _UninstallDialog({required this.appName, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded, color: AppTheme.danger, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'Uninstall App?',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to uninstall $appName? This action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Uninstall',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultAppDialog extends StatelessWidget {
  final String category;
  final String currentApp;
  final Function(String) onSelect;

  const _DefaultAppDialog({
    required this.category,
    required this.currentApp,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final apps = _getAppsForCategory(category);
    
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Default $category',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...apps.map((app) {
              final isSelected = app == currentApp;
              return GestureDetector(
                onTap: () => onSelect(app),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.accent : AppTheme.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          app,
                          style: TextStyle(
                            color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: AppTheme.accent, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<String> _getAppsForCategory(String category) {
    switch (category) {
      case 'Browser':
        return ['KrdOS Browser', 'Chrome', 'Firefox', 'Edge'];
      case 'Email':
        return ['Mail', 'Outlook', 'Thunderbird'];
      case 'Music':
        return ['Music Player', 'Spotify', 'VLC'];
      case 'Video':
        return ['Video Player', 'VLC', 'Media Player'];
      case 'Photos':
        return ['Photos', 'GIMP', 'Image Viewer'];
      case 'Files':
        return ['File Manager', 'Explorer', 'Nautilus'];
      default:
        return [];
    }
  }
}

