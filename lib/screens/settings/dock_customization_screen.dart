import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/dock_settings.dart';
import '../../core/shell/app_catalog.dart';
import '../../theme/app_theme.dart';

class DockCustomizationScreen extends StatefulWidget {
  const DockCustomizationScreen({super.key});

  @override
  State<DockCustomizationScreen> createState() => _DockCustomizationScreenState();
}

class _DockCustomizationScreenState extends State<DockCustomizationScreen> {
  List<Map<String, dynamic>> get _allApps => ShellAppRegistry.all
      .where((d) => d.allowTaskbarPin)
      .map(
        (d) => {
          'icon': d.icon,
          'label': d.title,
          'appId': d.id,
        },
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final dockSettings = context.watch<DockSettings>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1C1C1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    title: Text(
                      'Reset to Defaults?',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                    ),
                    content: Text(
                      'This will reset all dock settings to their default values.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () {
                          dockSettings.resetToDefaults();
                          Navigator.pop(context);
                        },
                        child: Text('Reset', style: TextStyle(color: AppTheme.danger)),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  border: Border.all(color: AppTheme.danger),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Reset to Defaults',
                  style: TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          'Position',
          Icons.location_on,
          Column(
            children: [
              _buildPositionGrid(dockSettings),
              const SizedBox(height: 16),
              _buildAlignmentSelector(dockSettings),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSection(
          'Appearance',
          Icons.palette,
          Column(
            children: [
              _buildSlider(
                'Size',
                dockSettings.size,
                50.0,
                100.0,
                (v) => dockSettings.setSize(v),
                '${dockSettings.size.round()}px',
              ),
              const SizedBox(height: 16),
              _buildSlider(
                'Icon Size',
                dockSettings.iconSize,
                18.0,
                40.0,
                (v) => dockSettings.setIconSize(v),
                '${dockSettings.iconSize.round()}px',
              ),
              const SizedBox(height: 16),
              _buildSlider(
                'Opacity',
                dockSettings.opacity,
                0.3,
                1.0,
                (v) => dockSettings.setOpacity(v),
                '${(dockSettings.opacity * 100).round()}%',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSection(
          'Behavior',
          Icons.settings,
          Column(
            children: [
              _buildToggle(
                'Auto Hide',
                dockSettings.autoHide,
                () => dockSettings.toggleAutoHide(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSection(
          'Pinned Apps',
          Icons.push_pin,
          Column(
            children: [
              _buildPinnedApps(dockSettings),
              const SizedBox(height: 16),
              _buildAvailableApps(dockSettings),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.accent, size: 18),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildPositionGrid(DockSettings settings) {
    return Column(
      children: [
        Text(
          'Dock Position',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPositionButton(
              'Top',
              Icons.vertical_align_top,
              DockPosition.top,
              settings,
            ),
            _buildPositionButton(
              'Bottom',
              Icons.vertical_align_bottom,
              DockPosition.bottom,
              settings,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPositionButton(
              'Left',
              Icons.align_horizontal_left,
              DockPosition.left,
              settings,
            ),
            _buildPositionButton(
              'Right',
              Icons.align_horizontal_right,
              DockPosition.right,
              settings,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPositionButton(
    String label,
    IconData icon,
    DockPosition position,
    DockSettings settings,
  ) {
    final isSelected = settings.position == position;
    return GestureDetector(
      onTap: () => settings.setPosition(position),
      child: AnimatedContainer(
        duration: 150.ms,
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentDim : AppTheme.surface,
          border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.accent : AppTheme.textSecondary, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentSelector(DockSettings settings) {
    return Column(
      children: [
        Text(
          'Alignment',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAlignmentButton('Start', DockAlignment.start, settings),
            _buildAlignmentButton('Center', DockAlignment.center, settings),
            _buildAlignmentButton('End', DockAlignment.end, settings),
          ],
        ),
      ],
    );
  }

  Widget _buildAlignmentButton(String label, DockAlignment alignment, DockSettings settings) {
    final isSelected = settings.alignment == alignment;
    return GestureDetector(
      onTap: () => settings.setAlignment(alignment),
      child: AnimatedContainer(
        duration: 150.ms,
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentDim : AppTheme.surface,
          border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    String displayValue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            Text(displayValue, style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppTheme.accent,
            inactiveTrackColor: AppTheme.border,
            thumbColor: AppTheme.accent,
            overlayColor: AppTheme.accent.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(String label, bool value, VoidCallback onToggle) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            AnimatedContainer(
              duration: 200.ms,
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppTheme.accent : AppTheme.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: 200.ms,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _dockPinRow(String appId) {
    try {
      return _allApps.firstWhere((a) => a['appId'] == appId);
    } catch (_) {
      final d = ShellAppRegistry.lookup(appId);
      if (d != null) {
        return {'icon': d.icon, 'label': d.title, 'appId': d.id};
      }
      return {
        'icon': Icons.help_outline,
        'label': appId,
        'appId': appId,
      };
    }
  }

  Widget _buildPinnedApps(DockSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Currently Pinned (Drag to reorder)',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: settings.pinnedApps.length,
          onReorder: (oldIndex, newIndex) => settings.reorderPinnedApps(oldIndex, newIndex),
          itemBuilder: (_, i) {
            final appId = settings.pinnedApps[i];
            return _buildPinnedAppItem(appId, _dockPinRow(appId), settings, i);
          },
        ),
      ],
    );
  }

  Widget _buildPinnedAppItem(String appId, Map<String, dynamic> appData, DockSettings settings, int index) {
    return Container(
      key: ValueKey(appId),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_handle, color: AppTheme.textSecondary, size: 18),
          const SizedBox(width: 12),
          Icon(appData['icon'] as IconData, color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appData['label'] as String,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            ),
          ),
          if (appId != 'allapps')
            GestureDetector(
              onTap: () => settings.removePinnedApp(appId),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.close, color: AppTheme.danger, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailableApps(DockSettings settings) {
    final availableApps = _allApps.where((a) => !settings.pinnedApps.contains(a['appId'])).toList();

    if (availableApps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Apps (Tap to pin)',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableApps.map((app) {
            return GestureDetector(
              onTap: () => settings.addPinnedApp(app['appId'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(app['icon'] as IconData, color: AppTheme.textSecondary, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      app['label'] as String,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.add_circle_outline, color: AppTheme.accent, size: 14),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

