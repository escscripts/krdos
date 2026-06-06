import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/settings_state.dart';
import '../../theme/app_theme.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  final int initialTab;
  const AccessibilitySettingsScreen({super.key, this.initialTab = 0});

  @override
  State<AccessibilitySettingsScreen> createState() =>
      _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  late int _tab = widget.initialTab.clamp(0, 2);

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
                    _chip(0, Icons.visibility_rounded, 'Vision'),
                    _chip(1, Icons.motion_photos_off_rounded, 'Motion'),
                    _chip(2, Icons.keyboard_alt_rounded, 'Navigation'),
                  ],
                ),
              ),
              Container(height: 1, color: AppTheme.border.withValues(alpha: 0.45)),
              Expanded(child: _content()),
            ],
          );
        }

        return Row(
          children: [
            _sidebar(),
            Expanded(child: _content()),
          ],
        );
      },
    );
  }

  Widget _chip(int i, IconData icon, String label) {
    final on = _tab == i;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? AppTheme.accent.withValues(alpha: 0.12) : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _tab = i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: on ? AppTheme.accent : AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: on ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          _sideItem(0, Icons.visibility_rounded, 'Vision'),
          _sideItem(1, Icons.motion_photos_off_rounded, 'Motion'),
          _sideItem(2, Icons.keyboard_alt_rounded, 'Navigation'),
        ],
      ),
    );
  }

  Widget _sideItem(int i, IconData icon, String label) {
    final on = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: on ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? AppTheme.accent.withValues(alpha: 0.55) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: on ? AppTheme.accent : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: on ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    switch (_tab) {
      case 0:
        return _vision();
      case 1:
        return _motion();
      case 2:
        return _nav();
      default:
        return const SizedBox();
    }
  }

  Widget _vision() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _header('Vision', 'High-clarity controls for reading, contrast, and focus.'),
            const SizedBox(height: 14),
            _toggleCard(
              title: 'High contrast',
              sub: 'Increase separation between surfaces and text (MediaQuery highContrast).',
              value: settings.a11yHighContrast,
              onChanged: settings.setA11yHighContrast,
            ),
            _toggleCard(
              title: 'Bold text',
              sub: 'Request thicker font strokes across the UI (MediaQuery boldText).',
              value: settings.a11yBoldText,
              onChanged: settings.setA11yBoldText,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.tips_and_updates_rounded, color: AppTheme.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Tip: For maximum readability combine Bold text with a larger Font Size under Display ? Fonts.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.35),
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

  Widget _motion() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _header('Motion', 'Control animations and transitions to reduce discomfort.'),
            const SizedBox(height: 14),
            _toggleCard(
              title: 'Reduce motion',
              sub: 'Disables animations for the shell (MediaQuery disableAnimations).',
              value: settings.a11yReduceMotion,
              onChanged: settings.setA11yReduceMotion,
            ),
            _toggleCard(
              title: 'Cosmetic animations',
              sub: 'Allow UI micro-animations when Reduce motion is off.',
              value: settings.animations,
              onChanged: (v) {
                if (settings.a11yReduceMotion) return;
                if (v != settings.animations) settings.toggleAnimations();
              },
              disabled: settings.a11yReduceMotion,
            ),
          ],
        );
      },
    );
  }

  Widget _nav() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _header('Navigation', 'Keyboard-first and assistive navigation hints.'),
            const SizedBox(height: 14),
            _toggleCard(
              title: 'Accessible navigation',
              sub: 'Signals assistive navigation is enabled (MediaQuery accessibleNavigation). Also reduces motion.',
              value: settings.a11yAccessibleNavigation,
              onChanged: settings.setA11yAccessibleNavigation,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                'Keyboard focus rings are handled by Flutter focusable widgets. Next upgrade: a global focus overlay that matches your shell accent.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.35),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(sub, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.35)),
      ],
    );
  }

  Widget _toggleCard({
    required String title,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(sub, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: disabled ? null : onChanged,
              activeThumbColor: Colors.black,
              activeTrackColor: AppTheme.accent,
            ),
          ],
        ),
      ),
    );
  }
}

