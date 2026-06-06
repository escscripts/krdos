import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/terminal/terminal_engine.dart';
import '../../core/filesystem/vfs.dart';
import '../../core/os_factory_reset.dart';
import '../../theme/app_theme.dart';
import '../../theme/grid_painter.dart';
import '../../widgets/status_bar.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> with TickerProviderStateMixin {
  final List<TerminalEngine> _engines = [];
  final List<TextEditingController> _controllers = [];
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  late TabController _tabCtrl;
  int _currentTab = 0;
  double _fontSize = 12.0;

  TerminalEngine get _engine => _engines[_currentTab];
  TextEditingController get _controller => _controllers[_currentTab];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 1, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) {
        setState(() {
          _currentTab = _tabCtrl.index;
          _suggestions.clear();
          _showSuggestions = false;
        });
      }
    });
    final vfs = context.read<VirtualFileSystem>();
    _addNewTab(vfs);
  }

  void _addNewTab(VirtualFileSystem vfs) {
    final engine = TerminalEngine(
      vfs,
      onFactoryReset: () => OsFactoryReset.run(context),
    );
    engine.addListener(_onEngineUpdate);
    engine.execute('neofetch');
    _engines.add(engine);
    _controllers.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final engine in _engines) {
      engine.removeListener(_onEngineUpdate);
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onEngineUpdate() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: 80.ms, curve: Curves.easeOut,
        );
      }
    });
  }

  void _submit() {
    final text = _controller.text;
    _controller.clear();
    setState(() { _suggestions = []; _showSuggestions = false; });
    _engine.execute(text);
    _focusNode.requestFocus();
  }

  void _onChanged(String val) {
    final sugg = _engine.autocomplete(val);
    setState(() {
      _suggestions = sugg;
      _showSuggestions = sugg.isNotEmpty && val.isNotEmpty;
    });
  }

  void _applySuggestion(String s) {
    _controller.text = s;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: s.length),
    );
    setState(() { _showSuggestions = false; });
    _focusNode.requestFocus();
  }

  void _newTab() {
    final vfs = context.read<VirtualFileSystem>();
    setState(() {
      _addNewTab(vfs);
      _tabCtrl.dispose();
      _tabCtrl = TabController(length: _engines.length, vsync: this, initialIndex: _engines.length - 1);
      _tabCtrl.addListener(() {
        if (_tabCtrl.indexIsChanging) {
          setState(() {
            _currentTab = _tabCtrl.index;
            _suggestions.clear();
            _showSuggestions = false;
          });
        }
      });
      _currentTab = _engines.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(painter: GridPainter(), child: const SizedBox.expand()),
          Column(
            children: [
              const StatusBar(),
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: Stack(
                  children: [
                    _buildOutput(),
                    if (_showSuggestions) _buildSuggestions(),
                  ],
                ),
              ),
              _buildInput(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('TERMINAL', style: TextStyle(color: AppTheme.accent, fontSize: 13,
            fontWeight: FontWeight.bold, letterSpacing: 3)),
          const Spacer(),
          Tooltip(
            message: 'Decrease font size',
            child: GestureDetector(
              onTap: () => setState(() => _fontSize = (_fontSize - 1).clamp(8, 20)),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.remove, color: AppTheme.textSecondary, size: 12),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text('${_fontSize.toInt()}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Increase font size',
            child: GestureDetector(
              onTap: () => setState(() => _fontSize = (_fontSize + 1).clamp(8, 20)),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.add, color: AppTheme.textSecondary, size: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: AppTheme.border),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Clear terminal',
            child: GestureDetector(
              onTap: () => _engine.clear(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.clear_all, color: AppTheme.textSecondary, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 36,
      color: AppTheme.surface,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_back_ios, color: AppTheme.accent, size: 14),
            ),
          ),
          Expanded(
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              indicatorColor: AppTheme.accent,
              indicatorWeight: 1,
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: TextStyle(fontSize: 11),
              tabs: List.generate(_engines.length, (i) => Tab(text: 'terminal ${i + 1}')),
            ),
          ),
          GestureDetector(
            onTap: _newTab,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const Icon(Icons.add, color: AppTheme.textSecondary, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutput() {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        itemCount: _engine.output.length,
        itemBuilder: (_, i) => _TerminalLine(line: _engine.output[i]),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Positioned(
      bottom: 0, left: 12,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 160),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ListView(
          shrinkWrap: true,
          children: _suggestions.map((s) => GestureDetector(
            onTap: () => _applySuggestion(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(s, style: TextStyle(color: AppTheme.accent, fontSize: 12)),
            ),
          )).toList(),
        ),
      ).animate().fadeIn(duration: 100.ms),
    );
  }

  Widget _buildInput() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Flexible(
            child: Text(_engine.prompt,
              style: TextStyle(color: AppTheme.accent, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _controller.text = _engine.historyUp(_controller.text);
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: _controller.text.length));
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _controller.text = _engine.historyDown();
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: _controller.text.length));
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.tab) {
                    if (_suggestions.isNotEmpty) _applySuggestion(_suggestions.first);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: (_) => _submit(),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                cursorColor: AppTheme.accent,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          if (_engine.busy)
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accent),
            ),
        ],
      ),
    );
  }
}

class _TerminalLine extends StatelessWidget {
  final TerminalLine line;
  const _TerminalLine({required this.line});

  Color get _color {
    switch (line.type) {
      case OutputType.command:  return AppTheme.accent;
      case OutputType.success:  return const Color(0xFF00FF88);
      case OutputType.error:    return AppTheme.danger;
      case OutputType.warning:  return AppTheme.warning;
      case OutputType.info:     return const Color(0xFF58A6FF);
      case OutputType.system:   return AppTheme.textSecondary;
      case OutputType.normal:   return AppTheme.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (line.text.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SelectableText(
        line.text,
        style: TextStyle(color: _color, fontSize: 12, height: 1.5, fontFamily: 'monospace'),
      ),
    );
  }
}

