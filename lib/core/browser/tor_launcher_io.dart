import 'dart:io';

/// Best-effort launch of Tor Browser with [url]; never throws to callers.
Future<bool> openUrlInTorBrowser(String url, {String? executablePath}) async {
  final normalized = url.trim();
  if (normalized.isEmpty || normalized == 'about:blank') return false;

  String? exe;
  final custom = executablePath?.trim();
  if (custom != null && custom.isNotEmpty) exe = custom;
  exe ??= await _guessTorFirefoxPath();
  if (exe == null) return false;
  try {
    final file = File(exe);
    if (!await file.exists()) return false;
    await Process.start(exe, [normalized], mode: ProcessStartMode.detached);
    return true;
  } catch (_) {
    return false;
  }
}

Future<String?> pickDefaultTorExecutable() async {
  final guessed = await _guessTorFirefoxPath();
  return guessed;
}

Future<String?> _guessTorFirefoxPath() async {
  if (!Platform.isWindows) return null;
  const candidates = <String>[
    r'C:\Program Files\Tor Browser\Browser\firefox.exe',
    r'C:\Program Files (x86)\Tor Browser\Browser\firefox.exe',
  ];
  for (final p in candidates) {
    if (await File(p).exists()) return p;
  }
  final home = Platform.environment['LOCALAPPDATA'];
  if (home != null) {
    final alt = '$home\\Tor Browser\\Browser\\firefox.exe';
    if (await File(alt).exists()) return alt;
  }
  return null;
}
