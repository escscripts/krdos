import 'dart:convert';
import 'dart:io';
import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
// SavedPassword  — one stored credential
// ─────────────────────────────────────────────────────────────────────────────
class SavedPassword {
  final String   id;
  final String   site;      // host, e.g. "google.com"
  final String   username;
  final String   password;
  final DateTime created;

  SavedPassword({
    required this.id,
    required this.site,
    required this.username,
    required this.password,
    DateTime? created,
  }) : created = created ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id':       id,
    'site':     site,
    'username': username,
    'password': password,
    'created':  created.toIso8601String(),
  };

  factory SavedPassword.fromJson(Map<String, dynamic> j) => SavedPassword(
    id:       j['id']       as String? ?? '',
    site:     j['site']     as String? ?? '',
    username: j['username'] as String? ?? '',
    password: j['password'] as String? ?? '',
    created:  DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.now(),
  );

  SavedPassword copyWith({String? username, String? password}) => SavedPassword(
    id:       id,
    site:     site,
    username: username ?? this.username,
    password: password ?? this.password,
    created:  created,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PasswordManager — load / save / find / generate
// ─────────────────────────────────────────────────────────────────────────────
class PasswordManager {
  static const _file = '/root/.krdos/passwords.json';
  static List<SavedPassword> _cache = [];
  static bool _loaded = false;

  // ── Persistence ─────────────────────────────────────────────────────────

  static Future<List<SavedPassword>> load() async {
    if (_loaded) return List.of(_cache);
    try {
      final f = File(_file);
      if (await f.exists()) {
        final raw  = await f.readAsString();
        final list = jsonDecode(raw) as List<dynamic>;
        _cache = list
            .map((e) => SavedPassword.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    _loaded = true;
    return List.of(_cache);
  }

  static Future<void> _persist() async {
    try {
      final f = File(_file);
      await f.parent.create(recursive: true);
      await f.writeAsString(
        jsonEncode(_cache.map((p) => p.toJson()).toList()),
      );
    } catch (_) {}
  }

  // ── CRUD ────────────────────────────────────────────────────────────────

  static Future<void> add(SavedPassword p) async {
    await load();
    // Replace any existing entry for the same site + username
    _cache.removeWhere((e) => e.site == p.site && e.username == p.username);
    _cache.insert(0, p);
    await _persist();
  }

  static Future<void> remove(String id) async {
    await load();
    _cache.removeWhere((e) => e.id == id);
    await _persist();
  }

  static Future<void> update(
      String id, {String? username, String? password}) async {
    await load();
    final i = _cache.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _cache[i] = _cache[i].copyWith(username: username, password: password);
    await _persist();
  }

  /// Returns the first saved password whose site matches the URL host.
  static Future<SavedPassword?> findForSite(String url) async {
    await load();
    final host = _hostOf(url);
    if (host.isEmpty) return null;
    try {
      return _cache.firstWhere(
          (e) => host.contains(e.site) || e.site.contains(host));
    } catch (_) {
      return null;
    }
  }

  static String _hostOf(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return '';
    }
  }

  // ── Generator ────────────────────────────────────────────────────────────

  /// Generate a cryptographically random password.
  static String generate({
    int    length  = 16,
    bool   upper   = true,
    bool   lower   = true,
    bool   digits  = true,
    bool   symbols = true,
  }) {
    const u = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const l = 'abcdefghijklmnopqrstuvwxyz';
    const d = '0123456789';
    const s = r'!@#$%^&*()-_=+[]{}|;:,.<>?';

    final pool = StringBuffer();
    if (upper)   pool.write(u);
    if (lower)   pool.write(l);
    if (digits)  pool.write(d);
    if (symbols) pool.write(s);
    if (pool.isEmpty) pool.write(l + d);

    final rng   = Random.secure();
    final chars = pool.toString();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Generate a memorable username (adjective + noun + number).
  static String generateUsername() {
    const adj  = ['swift', 'dark', 'red', 'blue', 'fast', 'cool', 'bold', 'smart'];
    const noun = ['fox', 'wolf', 'eagle', 'tiger', 'hawk', 'bear', 'shark', 'lion'];
    final rng  = Random.secure();
    final num  = rng.nextInt(999);
    return '${adj[rng.nextInt(adj.length)]}'
        '${noun[rng.nextInt(noun.length)]}'
        '$num';
  }
}
