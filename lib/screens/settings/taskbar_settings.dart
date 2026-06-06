import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/taskbar_settings.dart';
import '../../theme/app_theme.dart';

class TaskbarSettingsScreen extends StatefulWidget {
  const TaskbarSettingsScreen({super.key});

  @override
  State<TaskbarSettingsScreen> createState() => _TaskbarSettingsScreenState();
}

class _TaskbarSettingsScreenState extends State<TaskbarSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<TaskbarSettings>();

    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
  // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.view_agenda_rounded, color: AppTheme.accent, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Taskbar',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Customize your taskbar appearance and behavior',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

  // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
  // Position Section
                _buildSection(
                  'Position',
                  'Choose where the taskbar appears on your screen',
                  [
                    _buildPositionSelector(settings),
                  ],
                ),

                const SizedBox(height: 24),

  // Alignment Section
                _buildSection(
                  'Alignment',
                  'Align taskbar items to left, center, or right',
                  [
                    _buildAlignmentSelector(settings),
                  ],
                ),

                const SizedBox(height: 24),

  // Size Section
                _buildSection(
                  'Size',
                  'Adjust the taskbar size',
                  [
                    _buildSizeSelector(settings),
                  ],
                ),

                const SizedBox(height: 24),

  // Behavior Section
                _buildSection(
                  'Behavior',
                  'Control how the taskbar behaves',
                  [
                    _buildToggle(
                      'Auto-hide taskbar',
                      'Automatically hide the taskbar when not in use',
                      settings.autoHide,
                      settings.toggleAutoHide,
                    ),
                    const SizedBox(height: 12),
                    _buildToggle(
                      'Show window previews',
                      'Display thumbnail previews when hovering over taskbar buttons',
                      settings.showWindowPreviews,
                      settings.toggleWindowPreviews,
                    ),
                    const SizedBox(height: 12),
                    _buildToggle(
                      'Combine taskbar buttons',
                      'Group multiple windows of the same app into one button',
                      settings.combineButtons,
                      settings.toggleCombineButtons,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

  // Appearance Section
                _buildSection(
                  'Appearance',
                  'Customize how taskbar items look',
                  [
                    _buildToggle(
                      'Show app labels',
                      'Display text labels below app icons',
                      settings.showLabels,
                      settings.toggleShowLabels,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

  // Pinned Apps Section
                _buildSection(
                  'Pinned Apps',
                  'Manage apps pinned to your taskbar',
                  [
                    _buildPinnedAppsManager(settings),
                  ],
                ),

                const SizedBox(height: 24),

  // Reset Section
                _buildSection(
                  'Reset',
                  'Restore taskbar to default settings',
                  [
                    ElevatedButton.icon(
                      onPressed: () => _showResetDialog(context, settings),
                      icon: const Icon(Icons.restore, size: 16),
                      label: Text('Reset to Defaults'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger.withValues(alpha: 0.15),
                        foregroundColor: AppTheme.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppTheme.danger),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String description, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPositionSelector(TaskbarSettings settings) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildPositionOption(
          'Bottom',
          Icons.vertical_align_bottom,
          TaskbarPosition.bottom,
          settings.position,
          settings.setPosition,
        ),
        _buildPositionOption(
          'Top',
          Icons.vertical_align_top,
          TaskbarPosition.top,
          settings.position,
          settings.setPosition,
        ),
        _buildPositionOption(
          'Left',
          Icons.align_horizontal_left,
          TaskbarPosition.left,
          settings.position,
          settings.setPosition,
        ),
        _buildPositionOption(
          'Right',
          Icons.align_horizontal_right,
          TaskbarPosition.right,
          settings.position,
          settings.setPosition,
        ),
      ],
    );
  }

  Widget _buildPositionOption(
    String label,
    IconData icon,
    TaskbarPosition position,
    TaskbarPosition current,
    Function(TaskbarPosition) onSelect,
  ) {
    final isSelected = position == current;
    return GestureDetector(
      onTap: () => onSelect(position),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentDim : AppTheme.surfaceAlt,
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentSelector(TaskbarSettings settings) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildAlignmentOption(
          'Left',
          Icons.align_horizontal_left,
          TaskbarAlignment.left,
          settings.alignment,
          settings.setAlignment,
        ),
        _buildAlignmentOption(
          'Center',
          Icons.align_horizontal_center,
          TaskbarAlignment.center,
          settings.alignment,
          settings.setAlignment,
        ),
        _buildAlignmentOption(
          'Right',
          Icons.align_horizontal_right,
          TaskbarAlignment.right,
          settings.alignment,
          settings.setAlignment,
        ),
      ],
    );
  }

  Widget _buildAlignmentOption(
    String label,
    IconData icon,
    TaskbarAlignment alignment,
    TaskbarAlignment current,
    Function(TaskbarAlignment) onSelect,
  ) {
    final isSelected = alignment == current;
    return GestureDetector(
      onTap: () => onSelect(alignment),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentDim : AppTheme.surfaceAlt,
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSelector(TaskbarSettings settings) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSizeOption(
          'Small',
          TaskbarSize.small,
          settings.size,
          settings.setSize,
        ),
        _buildSizeOption(
          'Medium',
          TaskbarSize.medium,
          settings.size,
          settings.setSize,
        ),
        _buildSizeOption(
          'Large',
          TaskbarSize.large,
          settings.size,
          settings.setSize,
        ),
      ],
    );
  }

  Widget _buildSizeOption(
    String label,
    TaskbarSize size,
    TaskbarSize current,
    Function(TaskbarSize) onSelect,
  ) {
    final isSelected = size == current;
    return GestureDetector(
      onTap: () => onSelect(size),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentDim : AppTheme.surfaceAlt,
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Container(
              width: size == TaskbarSize.small ? 16 : size == TaskbarSize.medium ? 20 : 24,
              height: size == TaskbarSize.small ? 16 : size == TaskbarSize.medium ? 20 : 24,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String title, String description, bool value, VoidCallback onToggle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
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
                  description,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: value ? AppTheme.accent : AppTheme.border,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedAppsManager(TaskbarSettings settings) {
    final pinnedApps = settings.pinnedApps;
    final allApps = _getAllApps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
  // Current pinned apps
        if (pinnedApps.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No apps pinned. Add apps from the list below.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pinnedApps.length,
            onReorder: (oldIndex, newIndex) {
              settings.reorderPinnedApps(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final appId = pinnedApps[index];
              final appInfo = _getAppInfo(appId, allApps);
              if (appInfo == null) return const SizedBox.shrink();

              return Container(
                key: ValueKey(appId),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.drag_handle, color: AppTheme.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Icon(appInfo['icon'] as IconData, color: appInfo['color'] as Color, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        appInfo['label'] as String,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.danger, size: 18),
                      onPressed: () => settings.removePinnedApp(appId),
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 16),

  // Available apps to pin
        Text(
          'Available Apps',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allApps.where((app) => !pinnedApps.contains(app['id'])).map((app) {
            return GestureDetector(
              onTap: () => settings.addPinnedApp(app['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(app['icon'] as IconData, color: app['color'] as Color, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      app['label'] as String,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.add, color: AppTheme.accent, size: 14),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showResetDialog(BuildContext context, TaskbarSettings settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.warning, size: 24),
            SizedBox(width: 12),
            Text('Reset Taskbar Settings?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'This will restore all taskbar settings to their default values. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              settings.setPosition(TaskbarPosition.bottom);
              settings.setAlignment(TaskbarAlignment.center);
              settings.setSize(TaskbarSize.medium);
  // Reset other settings as needed
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Taskbar settings reset to defaults'),
                  backgroundColor: AppTheme.accent,
                ),
              );
            },
            child: Text('Reset', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _getAppInfo(String appId, List<Map<String, dynamic>> apps) {
    try {
      return apps.firstWhere((app) => app['id'] == appId);
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> _getAllApps() {
    return [
      {'id': 'terminal', 'label': 'Terminal', 'icon': Icons.terminal, 'color': AppTheme.accent},
      {'id': 'files', 'label': 'Files', 'icon': Icons.folder_open, 'color': AppTheme.warning},
      {'id': 'devices', 'label': 'Devices', 'icon': Icons.devices_other, 'color': const Color(0xFF58A6FF)},
      {'id': 'settings', 'label': 'Settings', 'icon': Icons.settings, 'color': AppTheme.textSecondary},
      {'id': 'users', 'label': 'Users', 'icon': Icons.manage_accounts, 'color': AppTheme.warning},
      {'id': 'security', 'label': 'Security', 'icon': Icons.security, 'color': AppTheme.danger},
      {'id': 'network', 'label': 'Network', 'icon': Icons.wifi, 'color': AppTheme.accent},
      {'id': 'monitor', 'label': 'Monitor', 'icon': Icons.monitor_heart, 'color': AppTheme.accent},
    ];
  }
}
