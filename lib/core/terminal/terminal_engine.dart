import 'dart:io';
import 'package:flutter/foundation.dart';
import '../filesystem/vfs.dart';
import '../platform/system_bridge.dart';

enum OutputType { normal, success, error, warning, info, command, system }

class TerminalLine {
  final String text;
  final OutputType type;
  final DateTime time;
  TerminalLine(this.text, this.type) : time = DateTime.now();
}

class TerminalEngine extends ChangeNotifier {
  final VirtualFileSystem vfs;
  final Future<void> Function()? onFactoryReset;

  TerminalEngine(this.vfs, {this.onFactoryReset});

  final List<TerminalLine> _output = [];
  final List<String> _history = [];
  int _historyIndex = -1;
  String _cwd = '/home/admin';
  bool _busy = false;
  int _bannerEndIndex = 0; // Track where banner ends
  final Map<String, String> _env = {
    'HOME': '/home/admin',
    'USER': 'admin',
    'SHELL': '/bin/customsh',
    'PATH': '/usr/local/bin:/usr/bin:/bin:/home/admin/.local/bin',
    'TERM': 'xterm-256color',
    'LANG': 'en_US.UTF-8',
    'OS': 'KrdOS',
    'ROLE': 'ADMIN',
    'PWD': '/home/admin',
  };
  final Map<String, String> _aliases = {
    'll': 'ls -la',
    'la': 'ls -a',
    '..': 'cd ..',
    '...': 'cd ../..',
  };

  List<TerminalLine> get output => List.unmodifiable(_output);
  String get cwd => _cwd;
  bool get busy => _busy;
  String get prompt => 'admin@KrdOS:${_cwd.replaceAll('/home/admin', '~')}\$ ';

  void _write(String text, OutputType type) {
    _output.add(TerminalLine(text, type));
    notifyListeners();
  }

  void clear() { 
  // Keep only the banner (neofetch output)
    if (_bannerEndIndex > 0 && _bannerEndIndex < _output.length) {
      final banner = _output.sublist(0, _bannerEndIndex);
      _output.clear();
      _output.addAll(banner);
    } else {
      _output.clear();
    }
    notifyListeners(); 
  }

  String historyUp(String current) {
    if (_history.isEmpty) return current;
    if (_historyIndex == -1) _historyIndex = _history.length;
    if (_historyIndex > 0) _historyIndex--;
    return _history[_historyIndex];
  }

  String historyDown() {
    if (_historyIndex == -1) return '';
    _historyIndex++;
    if (_historyIndex >= _history.length) { _historyIndex = -1; return ''; }
    return _history[_historyIndex];
  }

  List<String> autocomplete(String partial) {
    final parts = partial.trimLeft().split(' ');
    if (parts.length == 1) {
      return _allCommands.where((c) => c.startsWith(parts[0])).toList();
    }
    final path = parts.last;
    final node = vfs.resolve(_cwd);
    if (node is VfsDir) {
      return node.children.keys
        .where((k) => k.startsWith(path.split('/').last))
        .map((k) => '${parts.sublist(0, parts.length - 1).join(' ')} $k')
        .toList();
    }
    return [];
  }

  static const _allCommands = [
    'ls', 'cd', 'pwd', 'cat', 'mkdir', 'touch', 'rm', 'cp', 'mv',
    'echo', 'clear', 'help', 'whoami', 'hostname', 'uname', 'uptime',
    'ps', 'kill', 'top', 'df', 'du', 'free', 'ifconfig', 'ping',
    'chmod', 'chown', 'find', 'grep', 'history', 'date', 'env',
    'export', 'alias', 'nano', 'hexdump', 'stat', 'tree', 'neofetch',
    'sudo', 'systemctl', 'journalctl', 'netstat', 'ss', 'curl', 'wget',
    'tar', 'zip', 'unzip', 'git', 'vim', 'head', 'tail', 'wc', 'sort',
    'uniq', 'diff', 'awk', 'sed', 'which', 'whereis', 'man', 'info',
    'ln', 'readlink', 'file', 'strings', 'base64', 'md5sum', 'sha256sum',
    'factory-reset',
  ];

  // Commands that manipulate the virtual filesystem stay simulated.
  // Everything else is passed to the real shell when running on Linux.
  static const _vfsCmds = {
    'ls', 'cd', 'pwd', 'cat', 'mkdir', 'touch', 'rm', 'cp', 'mv',
    'tree', 'find', 'grep', 'stat', 'hexdump', 'du', 'head', 'tail',
    'wc', 'sort', 'uniq', 'ln', 'file', 'echo', 'help', 'history',
    'clear', 'alias', 'export', 'env', 'neofetch', 'factory-reset',
  };

  Future<void> execute(String raw) async {
    final input = raw.trim();
    if (input.isEmpty) return;
    _history.add(input);
    _historyIndex = -1;
    _write('${prompt}$input', OutputType.command);

  // Handle aliases
    var processedInput = input;
    for (final alias in _aliases.entries) {
      if (input.startsWith(alias.key)) {
        processedInput = input.replaceFirst(alias.key, alias.value);
        break;
      }
    }

    final parts = _tokenize(processedInput);
    if (parts.isEmpty) return;
    final cmd   = parts[0];
    final args  = parts.sublist(1);

  // On real Linux hardware, route non-VFS commands through the system bridge
  // so the terminal talks to the actual kernel instead of the simulation.
    if (!kIsWeb && Platform.isLinux && !_vfsCmds.contains(cmd)) {
      _busy = true;
      notifyListeners();
      await _realExecute(processedInput);
      _busy = false;
      notifyListeners();
      return;
    }

    _busy = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 40));

  // Update PWD env variable
    _env['PWD'] = _cwd;

    switch (cmd) {
      case 'clear':     clear(); break;
      case 'help':      _help(); break;
      case 'ls':        _ls(args); break;
      case 'cd':        _cd(args); break;
      case 'pwd':       _write(_cwd, OutputType.normal); break;
      case 'cat':       _cat(args); break;
      case 'mkdir':     _mkdir(args); break;
      case 'touch':     _touch(args); break;
      case 'rm':        _rm(args); break;
      case 'echo':      _echo(args); break;
      case 'whoami':    _write('admin', OutputType.normal); break;
      case 'hostname':  _write('KrdOS-device', OutputType.normal); break;
      case 'uname':     _uname(args); break;
      case 'uptime':    _uptime(); break;
      case 'date':      _date(args); break;
      case 'ps':        _ps(args); break;
      case 'top':       _top(); break;
      case 'df':        _df(args); break;
      case 'free':      _free(args); break;
      case 'ifconfig':  _ifconfig(); break;
      case 'ping':      await _ping(args); break;
      case 'history':   _showHistory(); break;
      case 'neofetch':  _neofetch(); break;
      case 'tree':      _tree(args); break;
      case 'find':      _find(args); break;
      case 'grep':      _grep(args); break;
      case 'stat':      _stat(args); break;
      case 'hexdump':   _hexdump(args); break;
      case 'chmod':     _chmod(args); break;
      case 'chown':     _chown(args); break;
      case 'env':       _envCmd(); break;
      case 'export':    _export(args); break;
      case 'alias':     _aliasCmd(args); break;
      case 'cp':        _cp(args); break;
      case 'mv':        _mv(args); break;
      case 'du':        _du(args); break;
      case 'sudo':      _sudo(args); break;
      case 'systemctl': _systemctl(args); break;
      case 'journalctl':_journalctl(args); break;
      case 'netstat':   _netstat(args); break;
      case 'ss':        _ss(args); break;
      case 'curl':      await _curl(args); break;
      case 'wget':      await _wget(args); break;
      case 'tar':       _tar(args); break;
      case 'zip':       _zip(args); break;
      case 'unzip':     _unzip(args); break;
      case 'git':       _git(args); break;
      case 'vim':       _vim(args); break;
      case 'nano':      _nano(args); break;
      case 'head':      _head(args); break;
      case 'tail':      _tail(args); break;
      case 'wc':        _wc(args); break;
      case 'sort':      _sort(args); break;
      case 'uniq':      _uniq(args); break;
      case 'which':     _which(args); break;
      case 'whereis':   _whereis(args); break;
      case 'man':       _man(args); break;
      case 'file':      _file(args); break;
      case 'ln':        _ln(args); break;
      case 'base64':    _base64(args); break;
      case 'md5sum':    _md5sum(args); break;
      case 'sha256sum': _sha256sum(args); break;
      case 'kill':      _kill(args); break;
      case 'factory-reset':
        await _factoryReset(args);
        break;
      default:
        _write('$cmd: command not found. Type \'help\' for available commands.', OutputType.error);
    }

    _busy = false;
    notifyListeners();
  }

  // Execute a command on the real Linux system and stream output to the terminal.
  Future<void> _realExecute(String command) async {
    final output = await SystemBridge.terminalExecute(command, cwd: _cwd);
    if (output.isEmpty) return;
    for (final line in output.split('\n')) {
      _write(line, OutputType.normal);
    }
  }

  // - Commands -

  void _help() {
    _write('KrdOS Shell v2.0 ? Available Commands:', OutputType.info);
    _write('', OutputType.normal);
    final groups = {
      'FILESYSTEM': ['ls', 'cd', 'pwd', 'cat', 'mkdir', 'touch', 'rm', 'cp', 'mv', 'tree', 'find', 'stat', 'du', 'ln', 'file'],
      'TEXT':       ['echo', 'grep', 'head', 'tail', 'wc', 'sort', 'uniq', 'hexdump', 'nano', 'vim'],
      'SYSTEM':     ['ps', 'top', 'kill', 'df', 'free', 'uptime', 'uname', 'date', 'env', 'neofetch', 'sudo', 'systemctl', 'journalctl'],
      'NETWORK':    ['ifconfig', 'ping', 'netstat', 'ss', 'curl', 'wget'],
      'ARCHIVE':    ['tar', 'zip', 'unzip'],
      'SECURITY':   ['chmod', 'chown', 'base64', 'md5sum', 'sha256sum'],
      'DEV':        ['git', 'which', 'whereis', 'man'],
      'MISC':       ['whoami', 'hostname', 'history', 'alias', 'export', 'clear', 'help', 'factory-reset'],
    };
    for (final g in groups.entries) {
      _write('  ${g.key}:', OutputType.warning);
      _write('    ${g.value.join('  ')}', OutputType.normal);
    }
    _write('', OutputType.normal);
    _write('TIP: Use Tab for autocomplete, ?? for history', OutputType.info);
    _write('DANGER: factory-reset --yes wipes saved users, settings, and resets the virtual disk.', OutputType.warning);
  }

  Future<void> _factoryReset(List<String> args) async {
    if (!args.contains('--yes')) {
      _write('factory-reset: This erases all user accounts, device registration, saved OS settings, and the in-memory virtual disk.', OutputType.warning);
      _write('         Run: factory-reset --yes', OutputType.info);
      return;
    }
    final run = onFactoryReset;
    if (run == null) {
      _write('factory-reset: full reset with restart is not wired in this terminal.', OutputType.error);
      return;
    }
    _write('Erasing persisted OS data?', OutputType.warning);
    try {
      await run();
    } catch (e) {
      _write('factory-reset failed: $e', OutputType.error);
    }
  }

  void _ls(List<String> args) {
    final showHidden = args.contains('-a') || args.contains('-la') || args.contains('-al');
    final longFormat = args.contains('-l') || args.contains('-la') || args.contains('-al');
    final pathArgs = args.where((a) => !a.startsWith('-')).toList();
    final target = pathArgs.isNotEmpty ? pathArgs.first : _cwd;
    final path = _resolvePath(target);
    final node = vfs.resolve(path);

    if (node == null) { _write('ls: $target: No such file or directory', OutputType.error); return; }
    if (node is VfsFile) { _write(node.name, OutputType.normal); return; }
    if (node is VfsDir) {
      final entries = node.children.values
        .where((e) => showHidden || !e.name.startsWith('.'))
        .toList()
        ..sort((a, b) {
          if (a is VfsDir && b is VfsFile) return -1;
          if (a is VfsFile && b is VfsDir) return 1;
          return a.name.compareTo(b.name);
        });

      if (longFormat) {
        _write('total ${entries.length}', OutputType.normal);
        for (final e in entries) {
          final isDir = e is VfsDir;
          final perms = isDir ? 'drwxr-xr-x' : '-rw-r--r--';
          final size  = isDir ? '4096' : '${(e as VfsFile).content.length}';
          final date  = 'Jan 01 00:00';
          final color = isDir ? OutputType.info : OutputType.normal;
          _write('$perms  1 admin admin  ${size.padLeft(6)}  $date  ${e.name}${isDir ? '/' : ''}', color);
        }
      } else {
        final names = entries.map((e) {
          final isDir = e is VfsDir;
          return '${e.name}${isDir ? '/' : ''}';
        }).toList();
        _write(names.join('  '), OutputType.normal);
      }
    }
  }

  void _cd(List<String> args) {
    if (args.isEmpty || args[0] == '~') { _cwd = '/home/admin'; notifyListeners(); return; }
    if (args[0] == '-') { _write('cd: OLDPWD not set', OutputType.error); return; }
    final path = _resolvePath(args[0]);
    final node = vfs.resolve(path);
    if (node == null)    { _write('cd: ${args[0]}: No such file or directory', OutputType.error); return; }
    if (node is VfsFile) { _write('cd: ${args[0]}: Not a directory', OutputType.error); return; }
    _cwd = path;
    notifyListeners();
  }

  void _cat(List<String> args) {
    if (args.isEmpty) { _write('cat: missing operand', OutputType.error); return; }
    for (final arg in args.where((a) => !a.startsWith('-'))) {
      final path = _resolvePath(arg);
      final node = vfs.resolve(path);
      if (node == null)   { _write('cat: $arg: No such file or directory', OutputType.error); continue; }
      if (node is VfsDir) { _write('cat: $arg: Is a directory', OutputType.error); continue; }
      final lines = (node as VfsFile).content.split('\n');
      if (args.contains('-n')) {
        for (int i = 0; i < lines.length; i++) {
          _write('${(i+1).toString().padLeft(6)}  ${lines[i]}', OutputType.normal);
        }
      } else {
        for (final l in lines) _write(l, OutputType.normal);
      }
    }
  }

  void _mkdir(List<String> args) {
    if (args.isEmpty) { _write('mkdir: missing operand', OutputType.error); return; }
    for (final arg in args.where((a) => !a.startsWith('-'))) {
      final path = _resolvePath(arg);
      if (vfs.resolve(path) != null) { _write('mkdir: $arg: File exists', OutputType.error); continue; }
      vfs.mkdir(path);
      _write('', OutputType.normal);
    }
  }

  void _touch(List<String> args) {
    if (args.isEmpty) { _write('touch: missing operand', OutputType.error); return; }
    for (final arg in args) {
      final path = _resolvePath(arg);
      vfs.touch(path);
    }
  }

  void _rm(List<String> args) {
    if (args.isEmpty) { _write('rm: missing operand', OutputType.error); return; }
    final recursive = args.contains('-r') || args.contains('-rf') || args.contains('-fr');
    for (final arg in args.where((a) => !a.startsWith('-'))) {
      final path = _resolvePath(arg);
      final node = vfs.resolve(path);
      if (node == null) { _write('rm: $arg: No such file or directory', OutputType.error); continue; }
      if (node is VfsDir && !recursive) { _write('rm: $arg: Is a directory (use -r)', OutputType.error); continue; }
      vfs.remove(path);
      _write('', OutputType.normal);
    }
  }

  void _cp(List<String> args) {
    final paths = args.where((a) => !a.startsWith('-')).toList();
    if (paths.length < 2) { _write('cp: missing destination', OutputType.error); return; }
    final src = vfs.resolve(_resolvePath(paths[0]));
    if (src == null) { _write('cp: ${paths[0]}: No such file', OutputType.error); return; }
    if (src is VfsFile) vfs.touch(_resolvePath(paths[1]), content: src.content);
    _write('', OutputType.normal);
  }

  void _mv(List<String> args) {
    final paths = args.where((a) => !a.startsWith('-')).toList();
    if (paths.length < 2) { _write('mv: missing destination', OutputType.error); return; }
    final srcPath = _resolvePath(paths[0]);
    final src = vfs.resolve(srcPath);
    if (src == null) { _write('mv: ${paths[0]}: No such file', OutputType.error); return; }
    if (src is VfsFile) {
      vfs.touch(_resolvePath(paths[1]), content: src.content);
      vfs.remove(srcPath);
    }
    _write('', OutputType.normal);
  }

  void _uname(List<String> args) {
    if (args.contains('-a')) {
      _write('KrdOS 6.1.0-custom #1 SMP PREEMPT aarch64 GNU/Linux', OutputType.normal);
    } else {
      _write('KrdOS', OutputType.normal);
    }
  }

  void _ps(List<String> args) {
    final showAll = args.contains('-a') || args.contains('aux');
    _write('  PID  TTY     STAT   TIME  COMMAND', OutputType.info);
    final procs = [
      ['1',    'pts/0', 'S',    '0:00', 'init'],
      ['42',   'pts/0', 'S',    '0:01', 'systemd'],
      ['88',   'pts/0', 'S',    '0:00', 'firewalld'],
      ['102',  'pts/0', 'S',    '0:00', 'networkd'],
      ['156',  'pts/0', 'S',    '0:00', 'sshd'],
      ['201',  'pts/0', 'S',    '0:02', 'KrdOS-shell'],
      ['334',  'pts/0', 'R',    '0:00', 'ps'],
    ];
    final toShow = showAll ? procs : procs.sublist(procs.length - 3);
    for (final p in toShow) {
      _write('${p[0].padLeft(5)}  ${p[1].padRight(7)} ${p[2].padRight(6)} ${p[3].padRight(5)} ${p[4]}', OutputType.normal);
    }
  }

  void _kill(List<String> args) {
    if (args.isEmpty) { _write('kill: missing operand', OutputType.error); return; }
    final pid = args.last;
    _write('kill: sending SIGTERM to process $pid', OutputType.success);
  }

  void _top() {
    _write('KrdOS top ? ${DateTime.now().toString().substring(11, 19)}', OutputType.info);
    _write('Tasks: 6 total, 1 running, 5 sleeping', OutputType.normal);
    _write('CPU:  12.3% user,  2.1% sys,  85.6% idle', OutputType.normal);
    _write('Mem:  2048MB total, 712MB used, 1336MB free', OutputType.normal);
    _write('', OutputType.normal);
    _write('  PID  USER   %CPU  %MEM  COMMAND', OutputType.info);
    _write('  201  admin   4.2   1.1  KrdOS-shell', OutputType.normal);
    _write('   88  root    2.1   0.4  firewalld', OutputType.normal);
    _write('  102  root    1.8   0.3  networkd', OutputType.normal);
  }

  void _df(List<String> args) {
    final human = args.contains('-h');
    _write('Filesystem      Size   Used  Avail  Use%  Mounted on', OutputType.info);
    if (human) {
      _write('/dev/mmcblk0p2  128G   14G   114G   11%   /', OutputType.normal);
      _write('/dev/mmcblk0p1  512M   45M   467M    9%   /boot', OutputType.normal);
      _write('tmpfs           1.0G    0B   1.0G    0%   /tmp', OutputType.normal);
    } else {
      _write('/dev/mmcblk0p2  134217728  14680064  119537664  11%   /', OutputType.normal);
      _write('/dev/mmcblk0p1  524288     46080     478208     9%   /boot', OutputType.normal);
      _write('tmpfs           1048576    0         1048576    0%   /tmp', OutputType.normal);
    }
  }

  void _free(List<String> args) {
    final human = args.contains('-h');
    _write('              total    used    free   shared  buff/cache  available', OutputType.info);
    if (human) {
      _write('Mem:           2.0G    712M   1.0G    12M        312M       1.3G', OutputType.normal);
      _write('Swap:          1.0G      0B   1.0G     0B          0B       1.0G', OutputType.normal);
    } else {
      _write('Mem:           2048     712    1024       12         312       1336', OutputType.normal);
      _write('Swap:          1024       0    1024        0           0       1024', OutputType.normal);
    }
  }

  void _ifconfig() {
    _write('eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500', OutputType.info);
    _write('      inet 192.168.1.100  netmask 255.255.255.0  broadcast 192.168.1.255', OutputType.normal);
    _write('      ether aa:bb:cc:dd:ee:ff  txqueuelen 1000', OutputType.normal);
    _write('      RX packets 12043  bytes 14MB', OutputType.normal);
    _write('      TX packets 8821   bytes 9MB', OutputType.normal);
    _write('', OutputType.normal);
    _write('wlan0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500', OutputType.info);
    _write('      inet 192.168.1.101  netmask 255.255.255.0', OutputType.normal);
    _write('      ether ff:ee:dd:cc:bb:aa  txqueuelen 1000', OutputType.normal);
    _write('      RX packets 4421   bytes 5MB', OutputType.normal);
    _write('', OutputType.normal);
    _write('lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536', OutputType.info);
    _write('      inet 127.0.0.1  netmask 255.0.0.0', OutputType.normal);
  }

  Future<void> _ping(List<String> args) async {
    if (args.isEmpty) { _write('ping: missing host', OutputType.error); return; }
    final host = args.where((a) => !a.startsWith('-')).first;
    final count = int.tryParse(args.contains('-c')
      ? args[args.indexOf('-c') + 1] : '4') ?? 4;
    _write('PING $host: 56 data bytes', OutputType.info);
    for (int i = 0; i < count; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      final ms = 12 + (i * 3);
      _write('64 bytes from $host: icmp_seq=$i ttl=64 time=$ms ms', OutputType.success);
      notifyListeners();
    }
    _write('--- $host ping statistics ---', OutputType.info);
    _write('$count packets transmitted, $count received, 0% packet loss', OutputType.success);
  }

  void _showHistory() {
    for (int i = 0; i < _history.length; i++) {
      _write('${(i + 1).toString().padLeft(4)}  ${_history[i]}', OutputType.normal);
    }
  }

  void _neofetch() {
    _write('', OutputType.normal);
    _write('   ??????????   ???????????????????? ??????? ????   ????', OutputType.info);
    _write('  ???????????   ?????????????????????????????????? ?????', OutputType.info);
    _write('  ???     ???   ???????????   ???   ???   ??????????????', OutputType.info);
    _write('  ???     ???   ???????????   ???   ???   ??????????????', OutputType.info);
    _write('  ?????????????????????????   ???   ???????????? ??? ???', OutputType.info);
    _write('   ??????? ??????? ????????   ???    ??????? ???     ???', OutputType.info);
    _write('', OutputType.normal);
    _write('  OS:       KrdOS v0.1.0', OutputType.normal);
    _write('  Kernel:   6.1.0-custom-aarch64', OutputType.normal);
    _write('  Shell:    customsh 2.0', OutputType.normal);
    _write('  CPU:      ARM Cortex-A78 @ 3.0GHz', OutputType.normal);
    _write('  Memory:   712MB / 2048MB', OutputType.normal);
    _write('  Uptime:   3 days, 4 hours', OutputType.normal);
    _write('  User:     admin', OutputType.normal);
    _write('  Role:     ADMINISTRATOR', OutputType.normal);
    _write('  Security: FIREWALL ON | VPN ON | IP MASKED', OutputType.success);
    _write('', OutputType.normal);
  // Mark the end of banner for clear command
    _bannerEndIndex = _output.length;
  }

  void _tree(List<String> args) {
    final paths = args.where((a) => !a.startsWith('-')).toList();
    final target = paths.isNotEmpty ? paths.first : _cwd;
    final path = _resolvePath(target);
    final node = vfs.resolve(path);
    if (node == null) { _write('tree: $target: No such file or directory', OutputType.error); return; }
    _write(target, OutputType.info);
    _treeRecurse(node, '', true);
  }

  void _treeRecurse(VfsNode node, String prefix, bool isLast) {
    if (node is VfsDir) {
      final children = node.children.values.toList();
      for (int i = 0; i < children.length; i++) {
        final child = children[i];
        final last = i == children.length - 1;
        final connector = last ? '??? ' : '??? ';
        final isDir = child is VfsDir;
        _write('$prefix$connector${child.name}${isDir ? '/' : ''}',
          isDir ? OutputType.info : OutputType.normal);
        if (isDir) {
          _treeRecurse(child, '$prefix${last ? '    ' : '?   '}', last);
        }
      }
    }
  }

  void _find(List<String> args) {
    final nameIdx = args.indexOf('-name');
    final pattern = nameIdx >= 0 && nameIdx + 1 < args.length ? args[nameIdx + 1] : null;
    final pathArgs = args.where((a) => !a.startsWith('-') && a != (pattern ?? '')).toList();
    final startPath = pathArgs.isNotEmpty ? pathArgs.first : _cwd;
    final results = <String>[];
    _findRecurse(vfs.resolve(_resolvePath(startPath)), _resolvePath(startPath), pattern, results);
    for (final r in results) _write(r, OutputType.normal);
    if (results.isEmpty) _write('(no results)', OutputType.warning);
  }

  void _findRecurse(VfsNode? node, String path, String? pattern, List<String> results) {
    if (node == null) return;
    final match = pattern == null || node.name.contains(pattern.replaceAll('*', ''));
    if (match) results.add(path);
    if (node is VfsDir) {
      for (final child in node.children.values) {
        _findRecurse(child, '$path/${child.name}', pattern, results);
      }
    }
  }

  void _grep(List<String> args) {
    if (args.length < 2) { _write('grep: usage: grep [pattern] [file]', OutputType.error); return; }
    final pattern = args[0];
    final filePath = _resolvePath(args[1]);
    final node = vfs.resolve(filePath);
    if (node == null)   { _write('grep: ${args[1]}: No such file', OutputType.error); return; }
    if (node is VfsDir) { _write('grep: ${args[1]}: Is a directory', OutputType.error); return; }
    final lines = (node as VfsFile).content.split('\n');
    bool found = false;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains(pattern)) {
        _write('${(i+1).toString().padLeft(3)}: ${lines[i]}', OutputType.success);
        found = true;
      }
    }
    if (!found) _write('(no matches)', OutputType.warning);
  }

  void _stat(List<String> args) {
    if (args.isEmpty) { _write('stat: missing operand', OutputType.error); return; }
    final path = _resolvePath(args[0]);
    final node = vfs.resolve(path);
    if (node == null) { _write('stat: ${args[0]}: No such file', OutputType.error); return; }
    final isDir = node is VfsDir;
    _write('  File: $path', OutputType.normal);
    _write('  Type: ${isDir ? 'directory' : 'regular file'}', OutputType.normal);
    _write('  Size: ${isDir ? '4096' : (node as VfsFile).content.length} bytes', OutputType.normal);
    _write('  Mode: ${isDir ? 'drwxr-xr-x' : '-rw-r--r--'}', OutputType.normal);
    _write('  Owner: admin', OutputType.normal);
    _write('  Modified: ${DateTime.now()}', OutputType.normal);
  }

  void _hexdump(List<String> args) {
    if (args.isEmpty) { _write('hexdump: missing operand', OutputType.error); return; }
    final path = _resolvePath(args[0]);
    final node = vfs.resolve(path);
    if (node == null)   { _write('hexdump: ${args[0]}: No such file', OutputType.error); return; }
    if (node is VfsDir) { _write('hexdump: ${args[0]}: Is a directory', OutputType.error); return; }
    final content = (node as VfsFile).content;
    final bytes = content.codeUnits.take(128).toList();
    for (int i = 0; i < bytes.length; i += 16) {
      final chunk = bytes.sublist(i, i + 16 > bytes.length ? bytes.length : i + 16);
      final hex = chunk.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      final ascii = chunk.map((b) => b >= 32 && b < 127 ? String.fromCharCode(b) : '.').join();
      _write('${i.toRadixString(16).padLeft(8, '0')}  ${hex.padRight(47)}  |$ascii|', OutputType.normal);
    }
  }

  void _chmod(List<String> args) {
    if (args.length < 2) { _write('chmod: missing operand', OutputType.error); return; }
    final path = _resolvePath(args[1]);
    final node = vfs.resolve(path);
    if (node == null) { _write('chmod: ${args[1]}: No such file or directory', OutputType.error); return; }
    node.permissions = args[0];
    _write('mode of \'${args[1]}\' changed to ${args[0]}', OutputType.success);
  }

  void _chown(List<String> args) {
    if (args.length < 2) { _write('chown: missing operand', OutputType.error); return; }
    final path = _resolvePath(args[1]);
    final node = vfs.resolve(path);
    if (node == null) { _write('chown: ${args[1]}: No such file or directory', OutputType.error); return; }
    node.owner = args[0];
    _write('owner of \'${args[1]}\' changed to ${args[0]}', OutputType.success);
  }

  void _envCmd() {
    for (final e in _env.entries) _write('${e.key}=${e.value}', OutputType.normal);
  }

  void _export(List<String> args) {
    if (args.isEmpty) { _envCmd(); return; }
    for (final arg in args) {
      final parts = arg.split('=');
      if (parts.length == 2) {
        _env[parts[0]] = parts[1];
        _write('${parts[0]}=${parts[1]}', OutputType.success);
      }
    }
  }

  void _aliasCmd(List<String> args) {
    if (args.isEmpty) {
      for (final a in _aliases.entries) _write('${a.key}=\'${a.value}\'', OutputType.normal);
      return;
    }
    final parts = args.join(' ').split('=');
    if (parts.length == 2) {
      _aliases[parts[0]] = parts[1].replaceAll("'", '').replaceAll('"', '');
      _write('alias ${parts[0]}=\'${_aliases[parts[0]]}\'', OutputType.success);
    }
  }

  void _echo(List<String> args) {
    var text = args.join(' ');
  // Replace environment variables
    for (final env in _env.entries) {
      text = text.replaceAll('\$${env.key}', env.value);
      text = text.replaceAll('\${${env.key}}', env.value);
    }
    _write(text, OutputType.normal);
  }

  void _uptime() {
    final now = DateTime.now();
    _write('${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} up 3 days, 4:22, 1 user, load average: 0.12, 0.08, 0.05', OutputType.normal);
  }

  void _date(List<String> args) {
    if (args.contains('-u')) {
      _write(DateTime.now().toUtc().toString(), OutputType.normal);
    } else if (args.contains('-R')) {
      _write(DateTime.now().toIso8601String(), OutputType.normal);
    } else {
      _write(DateTime.now().toString(), OutputType.normal);
    }
  }

  void _du(List<String> args) {
    final paths = args.where((a) => !a.startsWith('-')).toList();
    final target = paths.isNotEmpty ? paths.first : _cwd;
    final human = args.contains('-h');
    if (human) {
      _write('4.0K\t$target', OutputType.normal);
    } else {
      _write('4096\t$target', OutputType.normal);
    }
  }

  // - New Advanced Commands -

  void _sudo(List<String> args) {
    if (args.isEmpty) { _write('sudo: missing command', OutputType.error); return; }
    _write('[sudo] password for admin: ', OutputType.warning);
    _write('Executing as root...', OutputType.success);
  // Execute the command (simplified - just show it would run)
    execute(args.join(' '));
  }

  void _systemctl(List<String> args) {
    if (args.isEmpty) { _write('systemctl: missing command', OutputType.error); return; }
    final action = args[0];
    final service = args.length > 1 ? args[1] : '';
    
    switch (action) {
      case 'status':
        if (service.isEmpty) {
          _write('System is running', OutputType.success);
        } else {
          _write('? $service.service - $service daemon', OutputType.success);
          _write('   Loaded: loaded (/lib/systemd/system/$service.service; enabled)', OutputType.normal);
          _write('   Active: active (running) since ${DateTime.now()}', OutputType.success);
          _write('   Main PID: 88 ($service)', OutputType.normal);
        }
        break;
      case 'start':
        _write('Starting $service.service...', OutputType.normal);
        _write('Started $service.service', OutputType.success);
        break;
      case 'stop':
        _write('Stopping $service.service...', OutputType.normal);
        _write('Stopped $service.service', OutputType.success);
        break;
      case 'restart':
        _write('Restarting $service.service...', OutputType.normal);
        _write('Restarted $service.service', OutputType.success);
        break;
      case 'enable':
        _write('Created symlink /etc/systemd/system/multi-user.target.wants/$service.service', OutputType.success);
        break;
      case 'disable':
        _write('Removed /etc/systemd/system/multi-user.target.wants/$service.service', OutputType.success);
        break;
      case 'list-units':
        _write('UNIT                    LOAD   ACTIVE SUB     DESCRIPTION', OutputType.info);
        _write('firewalld.service       loaded active running Firewall daemon', OutputType.normal);
        _write('networkd.service        loaded active running Network daemon', OutputType.normal);
        _write('sshd.service            loaded active running OpenSSH server', OutputType.normal);
        break;
      default:
        _write('systemctl: unknown command $action', OutputType.error);
    }
  }

  void _journalctl(List<String> args) {
    final lines = args.contains('-n') 
      ? int.tryParse(args[args.indexOf('-n') + 1]) ?? 10
      : 10;
    _write('-- Logs begin at ${DateTime.now().subtract(const Duration(days: 3))} --', OutputType.info);
    final logs = [
      'Jan 01 00:00:01 KrdOS kernel: KrdOS 6.1.0-custom booting',
      'Jan 01 00:00:02 KrdOS systemd: Started firewalld.service',
      'Jan 01 00:00:03 KrdOS networkd: Interface eth0 up',
      'Jan 01 00:00:04 KrdOS sshd: Server listening on 0.0.0.0 port 22',
      'Jan 01 00:00:05 KrdOS systemd: Reached target Multi-User System',
      'Jan 01 00:01:00 KrdOS sshd: Accepted publickey for admin',
      'Jan 01 00:01:01 KrdOS sudo: admin : TTY=pts/0 ; COMMAND=/bin/bash',
      'Jan 01 00:02:00 KrdOS firewalld: Blocked connection from 192.168.1.50',
      'Jan 01 00:03:00 KrdOS networkd: DHCP lease renewed',
      'Jan 01 00:04:00 KrdOS systemd: Started KrdOS-shell.service',
    ];
    for (final log in logs.take(lines)) {
      _write(log, OutputType.normal);
    }
  }

  void _netstat(List<String> args) {
    final listening = args.contains('-l');
    final numeric = args.contains('-n');
    _write('Active Internet connections', OutputType.info);
    _write('Proto Recv-Q Send-Q Local Address           Foreign Address         State', OutputType.info);
    final connections = [
      ['tcp', '0', '0', '0.0.0.0:22', '0.0.0.0:*', 'LISTEN'],
      ['tcp', '0', '0', '127.0.0.1:631', '0.0.0.0:*', 'LISTEN'],
      ['tcp', '0', '52', '192.168.1.100:22', '192.168.1.50:54321', 'ESTABLISHED'],
      ['udp', '0', '0', '0.0.0.0:68', '0.0.0.0:*', ''],
    ];
    for (final conn in connections) {
      if (listening && conn[5] != 'LISTEN') continue;
      _write('${conn[0].padRight(5)} ${conn[1].padLeft(6)} ${conn[2].padLeft(6)} ${conn[3].padRight(23)} ${conn[4].padRight(23)} ${conn[5]}', OutputType.normal);
    }
  }

  void _ss(List<String> args) {
    _write('Netid  State      Recv-Q Send-Q Local Address:Port   Peer Address:Port', OutputType.info);
    _write('tcp    LISTEN     0      128    0.0.0.0:22            0.0.0.0:*', OutputType.normal);
    _write('tcp    ESTAB      0      52     192.168.1.100:22      192.168.1.50:54321', OutputType.success);
    _write('udp    UNCONN     0      0      0.0.0.0:68            0.0.0.0:*', OutputType.normal);
  }

  Future<void> _curl(List<String> args) async {
    if (args.isEmpty) { _write('curl: missing URL', OutputType.error); return; }
    final url = args.where((a) => !a.startsWith('-')).first;
    _write('Connecting to $url...', OutputType.info);
    await Future.delayed(const Duration(milliseconds: 500));
    _write('HTTP/1.1 200 OK', OutputType.success);
    _write('Content-Type: text/html; charset=UTF-8', OutputType.normal);
    _write('', OutputType.normal);
    _write('<!DOCTYPE html>', OutputType.normal);
    _write('<html><head><title>KrdOS</title></head>', OutputType.normal);
    _write('<body><h1>Welcome to KrdOS</h1></body></html>', OutputType.normal);
  }

  Future<void> _wget(List<String> args) async {
    if (args.isEmpty) { _write('wget: missing URL', OutputType.error); return; }
    final url = args.where((a) => !a.startsWith('-')).first;
    final filename = url.split('/').last.isEmpty ? 'index.html' : url.split('/').last;
    _write('--${DateTime.now()}--  $url', OutputType.info);
    _write('Resolving host...', OutputType.normal);
    await Future.delayed(const Duration(milliseconds: 300));
    _write('Connecting to host... connected.', OutputType.success);
    await Future.delayed(const Duration(milliseconds: 400));
    _write('HTTP request sent, awaiting response... 200 OK', OutputType.success);
    _write('Length: 2048 (2.0K) [text/html]', OutputType.normal);
    _write('Saving to: \'$filename\'', OutputType.normal);
    await Future.delayed(const Duration(milliseconds: 300));
    _write('', OutputType.normal);
    _write('100%[===================>] 2,048       --.-K/s   in 0s', OutputType.success);
    _write('', OutputType.normal);
    _write('\'$filename\' saved [2048/2048]', OutputType.success);
    vfs.touch('$_cwd/$filename', content: '<html><body>Downloaded content</body></html>');
  }

  void _tar(List<String> args) {
    if (args.isEmpty) { _write('tar: missing operand', OutputType.error); return; }
    final hasCreate = args.contains('-c') || args.contains('czf') || args.contains('czvf');
    final hasExtract = args.contains('-x') || args.contains('xzf') || args.contains('xzvf');
    final hasList = args.contains('-t') || args.contains('tzf');
    
    if (hasCreate) {
      final archive = args.last;
      _write('Creating archive $archive...', OutputType.normal);
      _write('Archive created successfully', OutputType.success);
      vfs.touch('$_cwd/$archive', content: 'TAR_ARCHIVE_DATA');
    } else if (hasExtract) {
      final archive = args.last;
      _write('Extracting $archive...', OutputType.normal);
      _write('Extracted successfully', OutputType.success);
    } else if (hasList) {
      _write('file1.txt', OutputType.normal);
      _write('file2.txt', OutputType.normal);
      _write('directory/', OutputType.normal);
    }
  }

  void _zip(List<String> args) {
    if (args.length < 2) { _write('zip: missing operand', OutputType.error); return; }
    final archive = args[0];
    final files = args.sublist(1);
    _write('  adding: ${files.join(', ')} (deflated 65%)', OutputType.normal);
    _write('Archive $archive created', OutputType.success);
    vfs.touch('$_cwd/$archive', content: 'ZIP_ARCHIVE_DATA');
  }

  void _unzip(List<String> args) {
    if (args.isEmpty) { _write('unzip: missing operand', OutputType.error); return; }
    final archive = args[0];
    _write('Archive:  $archive', OutputType.info);
    _write('  inflating: file1.txt', OutputType.normal);
    _write('  inflating: file2.txt', OutputType.normal);
    _write('Extraction complete', OutputType.success);
  }

  void _git(List<String> args) {
    if (args.isEmpty) { _write('git: missing command', OutputType.error); return; }
    final cmd = args[0];
    
    switch (cmd) {
      case 'init':
        _write('Initialized empty Git repository in $_cwd/.git/', OutputType.success);
        vfs.mkdir('$_cwd/.git');
        break;
      case 'status':
        _write('On branch main', OutputType.info);
        _write('Your branch is up to date with \'origin/main\'.', OutputType.normal);
        _write('', OutputType.normal);
        _write('nothing to commit, working tree clean', OutputType.success);
        break;
      case 'log':
        _write('commit a1b2c3d4e5f6 (HEAD -> main, origin/main)', OutputType.warning);
        _write('Author: admin <admin@KrdOS>', OutputType.normal);
        _write('Date:   ${DateTime.now()}', OutputType.normal);
        _write('', OutputType.normal);
        _write('    Initial commit', OutputType.normal);
        break;
      case 'clone':
        if (args.length < 2) { _write('git clone: missing repository', OutputType.error); return; }
        final repo = args[1];
        _write('Cloning into \'${repo.split('/').last}\'...', OutputType.info);
        _write('remote: Enumerating objects: 100, done.', OutputType.normal);
        _write('remote: Counting objects: 100% (100/100), done.', OutputType.normal);
        _write('Receiving objects: 100% (100/100), done.', OutputType.success);
        break;
      case 'pull':
        _write('Already up to date.', OutputType.success);
        break;
      case 'push':
        _write('Everything up-to-date', OutputType.success);
        break;
      case 'branch':
        _write('* main', OutputType.success);
        _write('  develop', OutputType.normal);
        break;
      default:
        _write('git: \'$cmd\' is not a git command. See \'git --help\'.', OutputType.error);
    }
  }

  void _vim(List<String> args) {
    if (args.isEmpty) {
      _write('Vim - Vi IMproved 9.0', OutputType.info);
      _write('', OutputType.normal);
      _write('Usage: vim [file]', OutputType.normal);
      _write('Note: Full vim editor not available in this terminal', OutputType.warning);
    } else {
      _write('Opening ${args[0]} in vim...', OutputType.info);
      _write('(Vim editor simulation - file opened)', OutputType.warning);
    }
  }

  void _nano(List<String> args) {
    if (args.isEmpty) {
      _write('Usage: nano [file]', OutputType.normal);
    } else {
      _write('Opening ${args[0]} in nano...', OutputType.info);
      _write('(Nano editor simulation - file opened)', OutputType.warning);
    }
  }

  void _head(List<String> args) {
    if (args.isEmpty) { _write('head: missing operand', OutputType.error); return; }
    final lines = args.contains('-n') 
      ? int.tryParse(args[args.indexOf('-n') + 1]) ?? 10
      : 10;
    final file = args.where((a) => !a.startsWith('-') && a != lines.toString()).first;
    final path = _resolvePath(file);
    final node = vfs.resolve(path);
    if (node == null) { _write('head: $file: No such file', OutputType.error); return; }
    if (node is VfsDir) { _write('head: $file: Is a directory', OutputType.error); return; }
    final content = (node as VfsFile).content.split('\n');
    for (final line in content.take(lines)) {
      _write(line, OutputType.normal);
    }
  }

  void _tail(List<String> args) {
    if (args.isEmpty) { _write('tail: missing operand', OutputType.error); return; }
    final lines = args.contains('-n') 
      ? int.tryParse(args[args.indexOf('-n') + 1]) ?? 10
      : 10;
    final file = args.where((a) => !a.startsWith('-') && a != lines.toString()).first;
    final path = _resolvePath(file);
    final node = vfs.resolve(path);
    if (node == null) { _write('tail: $file: No such file', OutputType.error); return; }
    if (node is VfsDir) { _write('tail: $file: Is a directory', OutputType.error); return; }
    final content = (node as VfsFile).content.split('\n');
    final start = content.length > lines ? content.length - lines : 0;
    for (final line in content.sublist(start)) {
      _write(line, OutputType.normal);
    }
  }

  void _wc(List<String> args) {
    if (args.isEmpty) { _write('wc: missing operand', OutputType.error); return; }
    final file = args.where((a) => !a.startsWith('-')).first;
    final path = _resolvePath(file);
    final node = vfs.resolve(path);
    if (node == null) { _write('wc: $file: No such file', OutputType.error); return; }
    if (node is VfsDir) { _write('wc: $file: Is a directory', OutputType.error); return; }
    final content = (node as VfsFile).content;
    final lines = content.split('\n').length;
    final words = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final bytes = content.length;
    _write('  ${lines.toString().padLeft(7)} ${words.toString().padLeft(7)} ${bytes.toString().padLeft(7)} $file', OutputType.normal);
  }

  void _sort(List<String> args) {
    if (args.isEmpty) { _write('sort: missing operand', OutputType.error); return; }
    final file = args.where((a) => !a.startsWith('-')).first;
    final path = _resolvePath(file);
    final node = vfs.resolve(path);
    if (node == null) { _write('sort: $file: No such file', OutputType.error); return; }
    if (node is VfsDir) { _write('sort: $file: Is a directory', OutputType.error); return; }
    final lines = (node as VfsFile).content.split('\n');
    final sorted = List<String>.from(lines)..sort();
    for (final line in sorted) {
      if (line.isNotEmpty) _write(line, OutputType.normal);
    }
  }

  void _uniq(List<String> args) {
    if (args.isEmpty) { _write('uniq: missing operand', OutputType.error); return; }
    final file = args.where((a) => !a.startsWith('-')).first;
    final path = _resolvePath(file);
    final node = vfs.resolve(path);
    if (node == null) { _write('uniq: $file: No such file', OutputType.error); return; }
    if (node is VfsDir) { _write('uniq: $file: Is a directory', OutputType.error); return; }
    final lines = (node as VfsFile).content.split('\n');
    String? prev;
    for (final line in lines) {
      if (line != prev && line.isNotEmpty) {
        _write(line, OutputType.normal);
        prev = line;
      }
    }
  }

  void _which(List<String> args) {
    if (args.isEmpty) { _write('which: missing operand', OutputType.error); return; }
    final cmd = args[0];
    if (_allCommands.contains(cmd)) {
      _write('/usr/bin/$cmd', OutputType.normal);
    } else {
      _write('which: no $cmd in (\$PATH)', OutputType.error);
    }
  }

  void _whereis(List<String> args) {
    if (args.isEmpty) { _write('whereis: missing operand', OutputType.error); return; }
    final cmd = args[0];
    if (_allCommands.contains(cmd)) {
      _write('$cmd: /usr/bin/$cmd /usr/share/man/man1/$cmd.1.gz', OutputType.normal);
    } else {
      _write('$cmd:', OutputType.normal);
    }
  }

  void _man(List<String> args) {
    if (args.isEmpty) { _write('What manual page do you want?', OutputType.error); return; }
    final cmd = args[0];
    _write('$cmd(1)                    User Commands                    $cmd(1)', OutputType.info);
    _write('', OutputType.normal);
    _write('NAME', OutputType.warning);
    _write('       $cmd - ${_getCommandDescription(cmd)}', OutputType.normal);
    _write('', OutputType.normal);
    _write('SYNOPSIS', OutputType.warning);
    _write('       $cmd [OPTIONS]', OutputType.normal);
    _write('', OutputType.normal);
    _write('DESCRIPTION', OutputType.warning);
    _write('       This is a simulated man page for $cmd command.', OutputType.normal);
  }

  String _getCommandDescription(String cmd) {
    final descriptions = {
      'ls': 'list directory contents',
      'cd': 'change directory',
      'cat': 'concatenate files and print',
      'grep': 'search for patterns in files',
      'find': 'search for files in directory hierarchy',
      'ps': 'report process status',
      'top': 'display system processes',
      'git': 'distributed version control system',
      'factory-reset': 'erase saved users, settings, and restore defaults',
    };
    return descriptions[cmd] ?? 'command utility';
  }

  void _file(List<String> args) {
    if (args.isEmpty) { _write('file: missing operand', OutputType.error); return; }
    for (final arg in args) {
      final path = _resolvePath(arg);
      final node = vfs.resolve(path);
      if (node == null) {
        _write('$arg: cannot open (No such file or directory)', OutputType.error);
        continue;
      }
      if (node is VfsDir) {
        _write('$arg: directory', OutputType.normal);
      } else {
        final content = (node as VfsFile).content;
        if (content.startsWith('#!/')) {
          _write('$arg: shell script, ASCII text executable', OutputType.normal);
        } else if (content.contains('<html')) {
          _write('$arg: HTML document, ASCII text', OutputType.normal);
        } else {
          _write('$arg: ASCII text', OutputType.normal);
        }
      }
    }
  }

  void _ln(List<String> args) {
    if (args.length < 2) { _write('ln: missing operand', OutputType.error); return; }
    final target = args[args.length - 2];
    final link = args[args.length - 1];
    _write('Created link $link -> $target', OutputType.success);
  }

  void _base64(List<String> args) {
    if (args.isEmpty) { _write('base64: missing operand', OutputType.error); return; }
    final decode = args.contains('-d');
    final input = args.where((a) => !a.startsWith('-')).join(' ');
    if (decode) {
      _write('Decoded: $input', OutputType.normal);
    } else {
      _write('Encoded: ${input.codeUnits.map((c) => c.toRadixString(16)).join()}', OutputType.normal);
    }
  }

  void _md5sum(List<String> args) {
    if (args.isEmpty) { _write('md5sum: missing operand', OutputType.error); return; }
    for (final arg in args) {
      final path = _resolvePath(arg);
      final node = vfs.resolve(path);
      if (node == null) {
        _write('md5sum: $arg: No such file', OutputType.error);
        continue;
      }
      if (node is VfsDir) {
        _write('md5sum: $arg: Is a directory', OutputType.error);
        continue;
      }
      _write('5d41402abc4b2a76b9719d911017c592  $arg', OutputType.normal);
    }
  }

  void _sha256sum(List<String> args) {
    if (args.isEmpty) { _write('sha256sum: missing operand', OutputType.error); return; }
    for (final arg in args) {
      final path = _resolvePath(arg);
      final node = vfs.resolve(path);
      if (node == null) {
        _write('sha256sum: $arg: No such file', OutputType.error);
        continue;
      }
      if (node is VfsDir) {
        _write('sha256sum: $arg: Is a directory', OutputType.error);
        continue;
      }
      _write('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  $arg', OutputType.normal);
    }
  }

  // - Helpers -
  String _resolvePath(String path) {
    if (path.startsWith('/')) return _normalize(path);
    if (path == '..') {
      final parts = _cwd.split('/')..removeLast();
      return parts.isEmpty ? '/' : parts.join('/');
    }
    if (path == '.') return _cwd;
    return _normalize('$_cwd/$path');
  }

  String _normalize(String path) {
    final parts = <String>[];
    for (final p in path.split('/')) {
      if (p == '' || p == '.') continue;
      if (p == '..') { if (parts.isNotEmpty) parts.removeLast(); }
      else parts.add(p);
    }
    return '/${parts.join('/')}';
  }

  List<String> _tokenize(String input) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuote = false;
    for (final ch in input.split('')) {
      if (ch == '"') { inQuote = !inQuote; continue; }
      if (ch == ' ' && !inQuote) {
        if (buf.isNotEmpty) { result.add(buf.toString()); buf.clear(); }
      } else { buf.write(ch); }
    }
    if (buf.isNotEmpty) result.add(buf.toString());
    return result;
  }
}