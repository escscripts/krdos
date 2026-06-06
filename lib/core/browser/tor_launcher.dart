import 'tor_launcher_stub.dart' if (dart.library.io) 'tor_launcher_io.dart' as tor_impl;

Future<bool> openUrlInTorBrowser(String url, {String? executablePath}) =>
    tor_impl.openUrlInTorBrowser(url, executablePath: executablePath);

Future<String?> pickDefaultTorExecutable() => tor_impl.pickDefaultTorExecutable();
