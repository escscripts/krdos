import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/settings_state.dart';
import '../theme/wallpaper_catalog.dart';

/// Live desktop / home background driven by [SettingsState] (wallpaper, fit, slideshow).
class DesktopWallpaperLayer extends StatefulWidget {
  final bool forLockScreen;

  const DesktopWallpaperLayer({super.key, this.forLockScreen = false});

  @override
  State<DesktopWallpaperLayer> createState() => _DesktopWallpaperLayerState();
}

class _DesktopWallpaperLayerState extends State<DesktopWallpaperLayer> {
  Timer? _timer;
  int _slideIndex = 0;
  int _lastInterval = 0;
  bool _lastSlideshow = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _ensureTimer(SettingsState s) {
    if (widget.forLockScreen || !s.wallpaperSlideshow || s.hasCustomDesktopWallpaper) {
      _timer?.cancel();
      _timer = null;
      _lastSlideshow = false;
      return;
    }

    final interval = s.slideshowInterval.clamp(5, 3600);
    if (_timer != null && _lastInterval == interval && _lastSlideshow) return;

    _timer?.cancel();
    _lastInterval = interval;
    _lastSlideshow = true;
    _timer = Timer.periodic(Duration(seconds: interval), (_) {
      if (!mounted) return;
      setState(() {
        _slideIndex = (_slideIndex + 1) % WallpaperCatalog.slideshowIds.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsState>();

    if (!widget.forLockScreen && s.wallpaperSlideshow && !s.hasCustomDesktopWallpaper) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureTimer(s);
      });
    } else {
      _timer?.cancel();
      _timer = null;
      _lastSlideshow = false;
    }

    final id = widget.forLockScreen
        ? s.lockScreenWallpaper
        : (s.wallpaperSlideshow && !s.hasCustomDesktopWallpaper
            ? WallpaperCatalog.slideshowIds[_slideIndex % WallpaperCatalog.slideshowIds.length]
            : s.wallpaper);

    final BoxDecoration deco;
    if (widget.forLockScreen) {
      deco = WallpaperCatalog.lockDecoration(s);
    } else if (s.hasCustomDesktopWallpaper && s.desktopWallpaperBytes != null) {
      deco = WallpaperCatalog.imageBytesDecoration(s, s.desktopWallpaperBytes!);
    } else {
      deco = WallpaperCatalog.desktopDecoration(s, wallpaperOverride: id);
    }

    Widget layer = DecoratedBox(decoration: deco, child: const SizedBox.expand());

    if (widget.forLockScreen && s.lockScreenBlur) {
      layer = ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            layer,
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withValues(alpha: 0.15)),
            ),
          ],
        ),
      );
    }

    return layer;
  }
}
