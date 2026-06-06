import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../core/settings_state.dart';

/// Central map for desktop / lock wallpapers (IDs must match [SettingsState] & personalization UI).
class WallpaperCatalog {
  WallpaperCatalog._();

  static const List<String> slideshowIds = [
    'gradient_1',
    'gradient_2',
    'gradient_3',
    'gradient_4',
    'gradient_5',
    'gradient_6',
  ];

  static List<Color> colorsForId(String id) {
    switch (id) {
      case 'gradient_1':
        return const [Color(0xFF667eea), Color(0xFF764ba2)];
      case 'gradient_2':
        return const [Color(0xFFf093fb), Color(0xFFf5576c)];
      case 'gradient_3':
        return const [Color(0xFF11998e), Color(0xFF38ef7d)];
      case 'gradient_4':
        return const [Color(0xFF2c3e50), Color(0xFF3498db)];
      case 'gradient_5':
        return const [Color(0xFF00c6ff), Color(0xFF0072ff)];
      case 'gradient_6':
        return const [Color(0xFFff6b6b), Color(0xFFfeca57)];
      case 'solid_dark':
        return const [Color(0xFF1a1a1a), Color(0xFF1a1a1a)];
      case 'solid_light':
        return const [Color(0xFFe8eaef), Color(0xFFdde1e8)];
      default:
        return const [Color(0xFF050A0E), Color(0xFF0A1628), Color(0xFF050E1A)];
    }
  }

  /// Desktop / mobile home background.
  static BoxDecoration desktopDecoration(SettingsState s, {String? wallpaperOverride}) {
    final id = wallpaperOverride ?? s.wallpaper;
    final colors = colorsForId(id);
    final fit = s.wallpaperFit;

    Alignment begin = Alignment.topLeft;
    Alignment end = Alignment.bottomRight;
    if (fit == 'center') {
      begin = const Alignment(-0.5, -0.5);
      end = const Alignment(0.5, 0.5);
    }

    if (colors.length >= 3) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: colors,
          stops: const [0.0, 0.5, 1.0],
        ),
      );
    }

    return BoxDecoration(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: colors,
      ),
    );
  }

  static BoxFit _boxFitForWallpaper(String fit) {
    switch (fit) {
      case 'fit':
        return BoxFit.contain;
      case 'stretch':
        return BoxFit.fill;
      case 'tile':
        return BoxFit.none;
      case 'center':
        return BoxFit.none;
      case 'fill':
      default:
        return BoxFit.cover;
    }
  }

  /// Raster wallpaper from memory (PNG / JPEG). Uses [SettingsState.wallpaperFit].
  static BoxDecoration imageBytesDecoration(SettingsState s, Uint8List bytes) {
    final fit = _boxFitForWallpaper(s.wallpaperFit);
    final tile = s.wallpaperFit == 'tile';
    return BoxDecoration(
      image: DecorationImage(
        image: MemoryImage(bytes),
        fit: fit,
        repeat: tile ? ImageRepeat.repeat : ImageRepeat.noRepeat,
        alignment: Alignment.center,
      ),
    );
  }

  static BoxDecoration lockDecoration(SettingsState s) {
    if (s.hasCustomLockWallpaper && s.lockWallpaperBytes != null) {
      return imageBytesDecoration(s, s.lockWallpaperBytes!);
    }
    return desktopDecoration(s, wallpaperOverride: s.lockScreenWallpaper);
  }
}
