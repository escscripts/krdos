import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/os_state.dart';
import 'core/settings_state.dart';
import 'core/dock_settings.dart';
import 'core/filesystem/vfs.dart';
import 'core/clipboard_manager.dart';
import 'core/auth/auth_manager.dart';
import 'core/vpn/vpn_engine.dart';
import 'core/vpn_state.dart';
import 'core/devices/device_registry.dart';
import 'apps/meshcommand/core/mesh_engine.dart';
import 'core/first_boot/first_boot_service.dart';
import 'core/update_state.dart';
import 'screens/first_boot_screen.dart';
import 'screens/system_init_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final vfs = VirtualFileSystem(skipDefaultSeed: true);
  await vfs.hydratePersisted();

  final firstBoot = await FirstBootService.isFirstBoot();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final o = OsState();
            o.load();
            return o;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final s = SettingsState();
            s.load();
            return s;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final d = DockSettings();
            d.load();
            return d;
          },
        ),
        ChangeNotifierProvider.value(value: vfs),
        ChangeNotifierProvider(create: (_) => ClipboardManager()),
        ChangeNotifierProvider(create: (_) => AuthManager()),
        ChangeNotifierProvider(create: (_) => VpnEngine()),
        ChangeNotifierProvider(create: (_) => VPNState()),
        ChangeNotifierProvider(create: (_) => DeviceRegistry()),
        ChangeNotifierProvider(create: (_) => MeshEngine()),
        ChangeNotifierProvider(
          create: (_) {
            final u = UpdateState();
            u.load(); // checks GitHub 4 s after boot if autoCheck is on
            return u;
          },
        ),
      ],
      child: KrdOSApp(vfs: vfs, isFirstBoot: firstBoot),
    ),
  );
}

TextTheme _textThemeFor(SettingsState settings, Brightness brightness) {
  final base = brightness == Brightness.light
      ? ThemeData.light().textTheme
      : ThemeData.dark().textTheme;
  switch (settings.fontFamily) {
    case 'Roboto':
      return GoogleFonts.robotoTextTheme(base);
    case 'Open Sans':
      return GoogleFonts.openSansTextTheme(base);
    case 'Lato':
      return GoogleFonts.latoTextTheme(base);
    case 'Montserrat':
      return GoogleFonts.montserratTextTheme(base);
    case 'Source Sans Pro':
      return GoogleFonts.sourceSans3TextTheme(base);
    default:
      return GoogleFonts.interTextTheme(base);
  }
}

/// Simulated HDR (contrast punch) applied as a GPU color matrix.
List<double> _hdrSimMatrix() => [
  1.12,
  0,
  0,
  0,
  6,
  0,
  1.1,
  0,
  0,
  4,
  0,
  0,
  1.08,
  0,
  2,
  0,
  0,
  0,
  1,
  0,
];

/// Warms the display for night-light (Kelvin-derived strength 0?1).
List<double> _warmNightMatrix(double t) {
  final w = t.clamp(0.0, 1.0);
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

Widget _wrapGlobalDisplayEffects(SettingsState settings, Widget child) {
  Widget w = child;
  if (settings.hdrEnabled) {
    w = ColorFiltered(
      colorFilter: ColorFilter.matrix(_hdrSimMatrix()),
      child: w,
    );
  }
  if (settings.effectiveNightLightNow()) {
    final warm = ((6500 - settings.nightLightTemp) / 2600).clamp(0.0, 1.0);
    w = ColorFiltered(
      colorFilter: ColorFilter.matrix(_warmNightMatrix(warm)),
      child: w,
    );
  }
  return w;
}

class KrdOSApp extends StatefulWidget {
  const KrdOSApp({super.key, required this.vfs, this.isFirstBoot = false});

  final VirtualFileSystem vfs;
  final bool isFirstBoot;

  @override
  State<KrdOSApp> createState() => _KrdOSAppState();
}

class _KrdOSAppState extends State<KrdOSApp> with WidgetsBindingObserver {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  // Night-light schedule crosses clock boundaries ? refresh periodically without busy loops.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.vfs.flushPersistence());
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.vfs.flushPersistence());
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    AppTheme.syncAccentFrom(settings.accentColor);

    final lightTheme = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: settings.accentColor,
        surface: const Color(0xFFF4F5F7),
        onSurface: const Color(0xFF1B1F24),
      ),
      textTheme: _textThemeFor(settings, Brightness.light),
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: settings.accentColor,
        surface: const Color(0xFF0D1117),
        onSurface: const Color(0xFFE6EDF3),
      ),
      textTheme: _textThemeFor(settings, Brightness.dark),
    );

  // Guard against corrupted prefs / bad math producing NaN or Infinity (breaks TextScaler / layout).
    final fs = settings.fontSize;
    final sc = settings.scaling;
    final safeFs = (fs.isFinite ? fs : 14.0).clamp(8.0, 40.0);
    final safeSc = (sc.isFinite ? sc : 100.0).clamp(50.0, 300.0);
    final fontScale = (safeFs / 14.0).clamp(0.85, 1.55);
    final displayScale = (safeSc / 100).clamp(0.75, 2.25);
    var combinedTextScale = fontScale * displayScale;
    if (!combinedTextScale.isFinite || combinedTextScale <= 0) {
      combinedTextScale = 1.0;
    } else {
      combinedTextScale = combinedTextScale.clamp(0.5, 4.0);
    }

    ThemeMode themeMode;
    switch (settings.themeMode) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      default:
        themeMode = ThemeMode.system;
    }

    return MaterialApp(
      title: 'KrdOS',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final mqA11y = mq.copyWith(
          disableAnimations: settings.a11yReduceMotion || settings.a11yAccessibleNavigation,
          highContrast: settings.a11yHighContrast,
          boldText: settings.a11yBoldText,
          accessibleNavigation: settings.a11yAccessibleNavigation,
        );
        return MediaQuery(
          data: mqA11y.copyWith(textScaler: TextScaler.linear(combinedTextScale)),
          child: _wrapGlobalDisplayEffects(
            settings,
            child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: widget.isFirstBoot ? const FirstBootScreen() : const SystemInitScreen(),
    );
  }
}