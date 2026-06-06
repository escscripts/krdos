import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_manager.dart';
import 'dock_settings.dart';
import 'filesystem/vfs.dart';
import 'os_state.dart';
import 'settings_state.dart';
import '../screens/system_init_screen.dart';

/// Full factory reset: persisted settings, users, VFS session state, then boot.
class OsFactoryReset {
  OsFactoryReset._();

  static Future<void> run(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthManager>();
    final vfs = context.read<VirtualFileSystem>();
    final osState = context.read<OsState>();
    final settingsState = context.read<SettingsState>();
    final dockSettings = context.read<DockSettings>();

    await auth.factoryResetOs();
    vfs.reset();
    await osState.load();
    await settingsState.load();
    await dockSettings.load();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SystemInitScreen()),
      (_) => false,
    );
  }
}
