import 'dart:io';

Future<void> restartApplication() async {
  try {
    await Process.start(
      Platform.resolvedExecutable,
      const [],
      mode: ProcessStartMode.detached,
    );
  } catch (_) {
  /* ignore */
  }
  exit(0);
}

void exitApplication() => exit(0);