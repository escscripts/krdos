import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/settings_state.dart';
import '../../core/os_state.dart';
import '../../theme/app_theme.dart';

class DisplaySettingsScreen extends StatefulWidget {
  final int initialTab;

  const DisplaySettingsScreen({super.key, this.initialTab = 0});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

List<double> _warmNightPreviewMatrix(SettingsState settings) {
  final warm = ((6500 - settings.nightLightTemp) / 2600).clamp(0.0, 1.0);
  final w = warm;
  return [
    1.0 + 0.2 * w,
    0,
    0,
    0,
    18 * w,
    0,
    1.0 + 0.08 * w,
    0,
    0,
    6 * w,
    0,
    0,
    1.0 - 0.32 * w,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

TextStyle _fontPreview(SettingsState settings) {
  final size = settings.fontSize;
  switch (settings.fontFamily) {
    case 'Roboto':
      return GoogleFonts.roboto(fontSize: size, fontWeight: FontWeight.w500, color: AppTheme.textPrimary);
    case 'Open Sans':
      return GoogleFonts.openSans(fontSize: size, fontWeight: FontWeight.w500, color: AppTheme.textPrimary);
    case 'Lato':
      return GoogleFonts.lato(fontSize: size, fontWeight: FontWeight.w500, color: AppTheme.textPrimary);
    case 'Montserrat':
      return GoogleFonts.montserrat(fontSize: size, fontWeight: FontWeight.w500, color: AppTheme.textPrimary);
    case 'Source Sans Pro':
      return GoogleFonts.sourceSans3(fontSize: size, fontWeight: FontWeight.w500, color: AppTheme.textPrimary);
    default:
      return GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w500, color: AppTheme.textPrimary);
  }
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {
  late int _selectedTab = widget.initialTab.clamp(0, 2);

  final List<String> _resolutions = [
    '1920x1080',
    '2560x1440',
    '3840x2160',
    '1680x1050',
    '1440x900',
  ];

  final List<int> _refreshRates = [60, 75, 120, 144, 165, 240];

  final List<String> _fontFamilies = [
    'System Default',
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat',
    'Source Sans Pro',
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
                    _buildSidebarChip(0, Icons.monitor_rounded, 'Display'),
                    _buildSidebarChip(1, Icons.nightlight_rounded, 'Night'),
                    _buildSidebarChip(2, Icons.text_fields_rounded, 'Fonts'),
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
          _buildSidebarItem(0, Icons.monitor_rounded, 'Display'),
          _buildSidebarItem(1, Icons.nightlight_rounded, 'Night Light'),
          _buildSidebarItem(2, Icons.text_fields_rounded, 'Fonts'),
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
        return _buildDisplayTab();
      case 1:
        return _buildNightLightTab();
      case 2:
        return _buildFontsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildDisplayTab() {
    return Consumer2<SettingsState, OsState>(
      builder: (context, settings, os, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.28)),
              ),
              child: Text(
                'These controls update KrdOS visuals and saved preferences. Resolution and Hz are simulated profiles; '
                'the Flutter window follows your OS. Scaling and brightness still affect shell rendering inside the demo.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.38),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Display Settings',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adjust your screen resolution, refresh rate, and scaling',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildCard(
              'Resolution',
              Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _resolutions.map((res) {
                      final isSelected = settings.resolution == res;
                      return GestureDetector(
                        onTap: () => settings.setResolution(res),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppTheme.accent : AppTheme.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            res,
                            style: TextStyle(
                              color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Saved profile: ${settings.resolution}. Active window bounds follow the host desktop.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              'Refresh Rate',
              Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _refreshRates.map((rate) {
                      final isSelected = settings.refreshRate == rate;
                      return GestureDetector(
                        onTap: () => settings.setRefreshRate(rate),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppTheme.accent : AppTheme.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            '${rate}Hz',
                            style: TextStyle(
                              color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              'Display Scaling',
              Column(
                children: [
                  _buildSlider(
                    'Scale: ${settings.scaling.toInt()}%',
                    settings.scaling,
                    75,
                    200,
                    (value) => settings.setScaling(value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adjust the size of text, apps, and other items',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              'Brightness',
              Column(
                children: [
                  _buildSlider(
                    'Brightness: ${(os.brightness * 100).toInt()}%',
                    os.brightness,
                    0.1,
                    1.0,
                    (value) => os.setBrightness(value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.brightness_low, color: AppTheme.textSecondary, size: 20),
                      Expanded(
                        child: Slider(
                          value: os.brightness,
                          min: 0.1,
                          max: 1.0,
                          activeColor: AppTheme.accent,
                          onChanged: (value) => os.setBrightness(value),
                        ),
                      ),
                      Icon(Icons.brightness_high, color: AppTheme.accent, size: 20),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              'Advanced',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildToggle(
                    'HDR simulation',
                    'Boosts vividness globally (KrdOS HDR preview)',
                    settings.hdrEnabled,
                    (_) => settings.toggleHDR(),
                  ),
                  if (settings.hdrEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Tone lift active, mirrored on the shell compositor.',
                        style: TextStyle(color: AppTheme.accent.withValues(alpha: 0.85), fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNightLightTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Night Light',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reduce blue light to help you sleep better',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildCard(
              'Night Light',
              Column(
                children: [
                  _buildToggle(
                    'Enable Night Light',
                    'Warm screen colors at night',
                    settings.nightLightEnabled,
                    (_) => settings.toggleNightLight(),
                  ),
                  if (settings.nightLightEnabled) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 86,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFB9D4FF), Color(0xFF5B7CFB)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            ColorFiltered(
                              colorFilter: ColorFilter.matrix(_warmNightPreviewMatrix(settings)),
                              child: Container(color: Colors.white.withValues(alpha: 0.001)),
                            ),
                            Center(
                              child: Text(
                                settings.effectiveNightLightNow()
                                    ? 'Live tint active inside schedule'
                                    : 'Schedule saved ‚¬ tint shows when clocks match',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      blurRadius: 6,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSlider(
                      'Color Temperature: ${settings.nightLightTemp}K',
                      settings.nightLightTemp.toDouble(),
                      3000,
                      6500,
                      (value) => settings.setNightLightTemp(value.toInt()),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Warmer',
                          style: TextStyle(
                            color: Colors.orange.shade300,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Cooler',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Turn on',
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () async {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: settings.nightLightStart,
                                        );
                                        if (time != null) {
                                          settings.setNightLightStart(time);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              settings.nightLightStart.format(context),
                                              style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Icon(Icons.access_time, color: AppTheme.accent, size: 18),
                                          ],
                                        ),
                                      ),
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
                                      'Turn off',
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () async {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: settings.nightLightEnd,
                                        );
                                        if (time != null) {
                                          settings.setNightLightEnd(time);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              settings.nightLightEnd.format(context),
                                              style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Icon(Icons.access_time, color: AppTheme.accent, size: 18),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
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
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About Night Light',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Night light reduces blue light emission to help reduce eye strain and improve sleep quality.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFontsTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Font Settings',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customize system fonts and text size',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildCard(
              'Font Size',
              Column(
                children: [
                  _buildSlider(
                    'Size: ${settings.fontSize.toInt()}px',
                    settings.fontSize,
                    10,
                    24,
                    (value) => settings.setFontSize(value),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preview (${settings.fontFamily})', style: _fontPreview(settings)),
                        const SizedBox(height: 10),
                        Text(
                          'The live shell uses the font family picked here through Google Fonts routing.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: (settings.fontSize * 0.78).clamp(10.0, 16.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              'Font Family',
              Column(
                children: _fontFamilies.map((font) {
                  final isSelected = settings.fontFamily == font;
                  return GestureDetector(
                    onTap: () => settings.setFontFamily(font),
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
                              font,
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
                }).toList(),
              ),
            ),
          ],
        );
      },
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
          activeColor: AppTheme.accent,
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
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
          activeColor: AppTheme.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

