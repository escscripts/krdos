import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/filesystem/file_picker.dart';
import '../../core/filesystem/vfs.dart';
import '../../core/settings_state.dart' show SettingsState, accentColorArgb32;
import '../../core/os_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/shell_accent.dart';

class PersonalizationSettingsScreen extends StatefulWidget {
  final int initialTab;

  const PersonalizationSettingsScreen({super.key, this.initialTab = 0});

  @override
  State<PersonalizationSettingsScreen> createState() => _PersonalizationSettingsScreenState();
}

class _PersonalizationSettingsScreenState extends State<PersonalizationSettingsScreen> {
  late int _selectedTab = widget.initialTab.clamp(0, 3);

  static const Set<String> _imageExtensions = {'png', 'jpg', 'jpeg'};

  final List<Map<String, dynamic>> _wallpapers = [
    {'id': 'gradient_1', 'name': 'Ocean Breeze', 'colors': [Color(0xFF667eea), Color(0xFF764ba2)]},
    {'id': 'gradient_2', 'name': 'Sunset', 'colors': [Color(0xFFf093fb), Color(0xFFf5576c)]},
    {'id': 'gradient_3', 'name': 'Forest', 'colors': [Color(0xFF11998e), Color(0xFF38ef7d)]},
    {'id': 'gradient_4', 'name': 'Night Sky', 'colors': [Color(0xFF2c3e50), Color(0xFF3498db)]},
    {'id': 'gradient_5', 'name': 'Aurora', 'colors': [Color(0xFF00c6ff), Color(0xFF0072ff)]},
    {'id': 'gradient_6', 'name': 'Fire', 'colors': [Color(0xFFff6b6b), Color(0xFFfeca57)]},
    {'id': 'solid_dark', 'name': 'Dark', 'colors': [Color(0xFF1a1a1a), Color(0xFF1a1a1a)]},
    {'id': 'solid_light', 'name': 'Light', 'colors': [Color(0xFFf5f5f5), Color(0xFFf5f5f5)]},
  ];

  final List<Color> _accentColors = [
    const Color(0xFFC1C1C1), // Default Silver (Main)
    const Color(0xFF0078D4), // Blue
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFEC4899), // Pink
    const Color(0xFFEF4444), // Red
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEAB308), // Yellow
    const Color(0xFF84CC16), // Lime
    const Color(0xFF10B981), // Green
    const Color(0xFF14B8A6), // Teal
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF3B82F6), // Sky Blue
    const Color(0xFF6366F1), // Indigo
    const Color(0xFFA855F7), // Violet
    const Color(0xFFDB2777), // Rose
    const Color(0xFFF97316), // Orange
    const Color(0xFF64748B), // Slate
  ];

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
                    _buildSidebarChip(0, Icons.wallpaper_rounded, 'Wallpaper'),
                    _buildSidebarChip(1, Icons.palette_rounded, 'Colors'),
                    _buildSidebarChip(2, Icons.brightness_6_rounded, 'Themes'),
                    _buildSidebarChip(3, Icons.lock_rounded, 'Lock'),
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
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: isSelected ? settings.accentColor.withValues(alpha: 0.12) : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _selectedTab = index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: isSelected ? settings.accentColor : AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? settings.accentColor : AppTheme.textPrimary,
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
      },
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
          _buildSidebarItem(0, Icons.wallpaper_rounded, 'Wallpaper'),
          _buildSidebarItem(1, Icons.palette_rounded, 'Colors'),
          _buildSidebarItem(2, Icons.brightness_6_rounded, 'Themes'),
          _buildSidebarItem(3, Icons.lock_rounded, 'Lock Screen'),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return GestureDetector(
          onTap: () => setState(() => _selectedTab = index),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? settings.accentColor.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? settings.accentColor : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? settings.accentColor : AppTheme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? settings.accentColor : AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildWallpaperTab();
      case 1:
        return _buildColorsTab();
      case 2:
        return _buildThemesTab();
      case 3:
        return _buildLockScreenTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildWallpaperTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Choose Your Wallpaper',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a wallpaper to personalize your desktop',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildCustomImageBanner(settings, forLock: false),
            _buildImagePickRow(context, settings, forLock: false),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 16 / 9,
              ),
              itemCount: _wallpapers.length,
              itemBuilder: (context, index) {
                final wallpaper = _wallpapers[index];
                final isSelected =
                    !settings.hasCustomDesktopWallpaper && settings.wallpaper == wallpaper['id'];
                final acc = settings.accentColor;
                return GestureDetector(
                  onTap: () => settings.setWallpaper(wallpaper['id']),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: wallpaper['colors'],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? acc : AppTheme.border,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: acc,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.black, size: 16),
                            ),
                          ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              wallpaper['name'],
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            _buildCard(
              'Wallpaper Settings',
              Column(
                children: [
                  _buildDropdown(
                    'Fit',
                    settings.wallpaperFit,
                    ['fill', 'fit', 'stretch', 'tile', 'center'],
                    (value) => settings.setWallpaperFit(value!),
                  ),
                  const SizedBox(height: 16),
                  _buildToggle(
                    'Slideshow',
                    'Automatically change wallpaper',
                    settings.wallpaperSlideshow,
                    (_) => settings.toggleWallpaperSlideshow(),
                  ),
                  if (settings.wallpaperSlideshow) ...[
                    const SizedBox(height: 16),
                    _buildSlider(
                      'Change every ${settings.slideshowInterval} minutes',
                      settings.slideshowInterval.toDouble(),
                      5,
                      120,
                      (value) => settings.setSlideshowInterval(value.toInt()),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDesktopIconSizeCard(settings),
          ],
        );
      },
    );
  }

  Widget _buildDesktopIconSizeCard(SettingsState settings) {
    return _buildCard(
      'Desktop shortcuts',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explorer icon size (right‚¬-click desktop " - ™ View mirrors this)',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _desktopIconChip('Large', 72.0, settings),
              const SizedBox(width: 10),
              _desktopIconChip('Medium', 56.0, settings),
              const SizedBox(width: 10),
              _desktopIconChip('Small', 40.0, settings),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopIconChip(String label, double size, SettingsState settings) {
    final sel = (settings.desktopIconSize - size).abs() < 0.5;
    final acc = settings.accentColor;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11)),
      selected: sel,
      selectedColor: acc.withValues(alpha: 0.16),
      onSelected: (_) => settings.setDesktopIconSize(size),
    );
  }

  Widget _buildColorsTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Accent Color',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an accent color for buttons, links, and highlights',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildCustomColorPicker(settings),
            const SizedBox(height: 32),
            _buildCard(
              'Transparency',
              Column(
                children: [
                  _buildSlider(
                    'Window Transparency: ${(settings.windowTransparency * 100).toInt()}%',
                    settings.windowTransparency,
                    0.5,
                    1.0,
                    (value) => settings.setWindowTransparency(value),
                  ),
                  const SizedBox(height: 16),
                  _buildSlider(
                    'Taskbar Transparency: ${(settings.taskbarTransparency * 100).toInt()}%',
                    settings.taskbarTransparency,
                    0.5,
                    1.0,
                    (value) => settings.setTaskbarTransparency(value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              'Effects',
              Column(
                children: [
                  _buildToggle(
                    'Blur Effects',
                    'Apply blur to transparent surfaces',
                    settings.blurEffects,
                    (_) => settings.toggleBlurEffects(),
                  ),
                  const SizedBox(height: 16),
                  _buildToggle(
                    'Animations',
                    'Enable smooth animations',
                    settings.animations,
                    (_) => settings.toggleAnimations(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemesTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Theme Mode',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how KrdOS looks',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final cards = [
                  _buildThemeCard('Light', 'light', Icons.light_mode_rounded, settings),
                  _buildThemeCard('Dark', 'dark', Icons.dark_mode_rounded, settings),
                  _buildThemeCard('Auto', 'auto', Icons.brightness_auto_rounded, settings),
                ];
                if (c.maxWidth < 520) {
                  return Column(
                    children: [
                      cards[0],
                      const SizedBox(height: 12),
                      cards[1],
                      const SizedBox(height: 12),
                      cards[2],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[2]),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            _buildCard(
              'Theme Preview',
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: settings.themeMode == 'light'
                        ? [const Color(0xFFf5f5f5), const Color(0xFFe0e0e0)]
                        : [const Color(0xFF1a1a1a), const Color(0xFF0a0a0a)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: settings.accentColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Preview Button',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This is how your theme looks',
                        style: TextStyle(
                          color: settings.themeMode == 'light'
                              ? Colors.black87
                              : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLockScreenTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Lock Screen',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customize your lock screen appearance',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildCustomImageBanner(settings, forLock: true),
            _buildImagePickRow(context, settings, forLock: true),
            const SizedBox(height: 24),
            _buildCard(
              'Lock Screen Wallpaper',
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: _wallpapers.length,
                itemBuilder: (context, index) {
                  final wallpaper = _wallpapers[index];
                  final isSelected = !settings.hasCustomLockWallpaper &&
                      settings.lockScreenWallpaper == wallpaper['id'];
                  return GestureDetector(
                    onTap: () => settings.setLockScreenWallpaper(wallpaper['id']),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: wallpaper['colors'],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppTheme.accent : AppTheme.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: settings.accentColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.black, size: 14),
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              'Lock Screen Effects',
              _buildToggle(
                'Blur Effect',
                'Apply blur to lock screen wallpaper',
                settings.lockScreenBlur,
                (_) => settings.toggleLockScreenBlur(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomImageBanner(SettingsState settings, {required bool forLock}) {
    final active = forLock ? settings.hasCustomLockWallpaper : settings.hasCustomDesktopWallpaper;
    if (!active) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: settings.accentColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: settings.accentColor.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.image_rounded, color: settings.accentColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Using a custom photo (PNG or JPEG)',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () {
                if (forLock) {
                  settings.clearCustomLockWallpaper();
                } else {
                  settings.clearCustomDesktopWallpaper();
                }
              },
              child: Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickRow(BuildContext context, SettingsState settings, {required bool forLock}) {
    final vfs = context.read<VirtualFileSystem>();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final bytes = await FilePicker.pickHostImageBytes();
            if (!context.mounted) return;
            if (bytes == null || bytes.isEmpty) return;
            if (!SettingsState.isValidPngOrJpeg(bytes)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Choose a valid PNG or JPEG image.')),
              );
              return;
            }
            if (forLock) {
              settings.setLockWallpaperCustomBytes(bytes);
            } else {
              settings.setDesktopWallpaperCustomBytes(bytes);
            }
          },
          icon: const Icon(Icons.folder_open, size: 18),
          label: Text('This device'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final path = await FilePicker.open(
              context,
              vfs,
              allowedExtensions: _imageExtensions,
            );
            if (!context.mounted) return;
            if (path == null) return;
            final node = vfs.resolve(path);
            if (node is! VfsFile) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not read that file.')),
              );
              return;
            }
            final bytes = node.rawBytes;
            if (bytes == null || bytes.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'No image bytes in that file. In KrdOS, pick a PNG or JPG (e.g. under Pictures).',
                  ),
                ),
              );
              return;
            }
            if (!SettingsState.isValidPngOrJpeg(bytes)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Choose a PNG or JPEG file.')),
              );
              return;
            }
            if (forLock) {
              settings.setLockWallpaperCustomBytes(bytes);
            } else {
              settings.setDesktopWallpaperCustomBytes(bytes);
            }
          },
          icon: const Icon(Icons.storage_rounded, size: 18),
          label: Text('KrdOS files'),
        ),
      ],
    );
  }

  Widget _buildThemeCard(String label, String value, IconData icon, SettingsState settings) {
    final isSelected = settings.themeMode == value;
    final acc = settings.accentColor;
    return GestureDetector(
      onTap: () {
        settings.setThemeMode(value);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? acc.withOpacity(0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? acc : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? acc : AppTheme.textSecondary, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? acc : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: settings.accentColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              activeColor: settings.accentColor,
              onChanged: onChanged,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            dropdownColor: AppTheme.surface,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomColorPicker(SettingsState settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: settings.accentColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: settings.accentColor.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(Icons.palette_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Accent',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${settings.accentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: settings.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: settings.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Color Palette',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 9,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: _accentColors.length,
            itemBuilder: (context, index) {
              final color = _accentColors[index];
              final isSelected = accentColorArgb32(settings.accentColor) == accentColorArgb32(color);
              return GestureDetector(
                onTap: () => settings.setAccentColor(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: isSelected ? 0.6 : 0.3),
                        blurRadius: isSelected ? 16 : 8,
                        spreadRadius: isSelected ? 2 : 0,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 16),
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showCustomColorDialog(context, settings),
            icon: const Icon(Icons.colorize_rounded, size: 18),
            label: const Text('Custom Color Picker'),
            style: OutlinedButton.styleFrom(
              foregroundColor: settings.accentColor,
              side: BorderSide(color: settings.accentColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Accent color affects buttons, highlights, and interactive elements throughout the OS',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomColorDialog(BuildContext context, SettingsState settings) {
    Color selectedColor = settings.accentColor;
    double hue = HSVColor.fromColor(selectedColor).hue;
    double saturation = HSVColor.fromColor(selectedColor).saturation;
    double value = HSVColor.fromColor(selectedColor).value;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.colorize_rounded, color: settings.accentColor, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Custom Color',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
  // Color preview and hex input
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: selectedColor.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HEX',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
  // Hue gradient bar
                  Text(
                    'HUE',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanUpdate: (details) {
                          final localX = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                          final newHue = (localX / constraints.maxWidth * 360).clamp(0.0, 360.0);
                          dialogSetState(() {
                            hue = newHue;
                            selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
                          });
                        },
                        onTapDown: (details) {
                          final localX = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                          final newHue = (localX / constraints.maxWidth * 360).clamp(0.0, 360.0);
                          dialogSetState(() {
                            hue = newHue;
                            selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
                          });
                        },
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFF0000),
                                const Color(0xFFFFFF00),
                                const Color(0xFF00FF00),
                                const Color(0xFF00FFFF),
                                const Color(0xFF0000FF),
                                const Color(0xFFFF00FF),
                                const Color(0xFFFF0000),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: (hue / 360) * constraints.maxWidth - 12,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black.withValues(alpha: 0.2), width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
  // Saturation/Value 2D picker
                  Text(
                    'SATURATION & BRIGHTNESS',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanUpdate: (details) {
                          final localX = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                          final localY = details.localPosition.dy.clamp(0.0, 200.0);
                          dialogSetState(() {
                            saturation = (localX / constraints.maxWidth).clamp(0.0, 1.0);
                            value = (1 - (localY / 200)).clamp(0.0, 1.0);
                            selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
                          });
                        },
                        onTapDown: (details) {
                          final localX = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                          final localY = details.localPosition.dy.clamp(0.0, 200.0);
                          dialogSetState(() {
                            saturation = (localX / constraints.maxWidth).clamp(0.0, 1.0);
                            value = (1 - (localY / 200)).clamp(0.0, 1.0);
                            selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
                          });
                        },
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
  // Base hue color
                                Container(
                                  decoration: BoxDecoration(
                                    color: HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor(),
                                  ),
                                ),
  // White to transparent (saturation)
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white,
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
  // Black to transparent (value)
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black,
                                        Colors.black.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
  // Cursor
                                Positioned(
                                  left: saturation * constraints.maxWidth - 12,
                                  top: (1 - value) * 200 - 12,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: BorderSide(color: AppTheme.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            settings.setAccentColor(selectedColor);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            shadowColor: selectedColor.withValues(alpha: 0.5),
                          ),
                          child: const Text('Apply Color', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}