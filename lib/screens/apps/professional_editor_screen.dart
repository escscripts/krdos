import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/editor/editor_engine.dart';
import '../../core/filesystem/vfs.dart';
import '../../core/filesystem/file_picker.dart';
import '../../core/terminal/terminal_engine.dart';
import '../../core/os_factory_reset.dart';
import '../../core/editor/activity_bar.dart';
import '../../core/editor/sidebar_panel.dart';
import '../../core/editor/editor_menu_bar.dart';
import '../../core/editor/enhanced_tab_bar.dart';
import '../../core/editor/editor_status_bar.dart';
import '../../core/editor/editor_breadcrumb.dart';
import '../../core/editor/command_palette.dart';
import '../../core/editor/editor_preferences.dart';
import '../../core/editor/keyboard_shortcuts_dialog.dart';

class ProfessionalEditorScreen extends StatefulWidget {
  final VirtualFileSystem vfs;
  final String? initialFilePath;
  final String? rootFolder;

  const ProfessionalEditorScreen({
    super.key,
    required this.vfs,
    this.initialFilePath,
    this.rootFolder,
  });

  @override
  State<ProfessionalEditorScreen> createState() => _ProfessionalEditorScreenState();
}

class _ProfessionalEditorScreenState extends State<ProfessionalEditorScreen> {
  late EditorEngine _engine;
  final _prefs = EditorPreferences();
  String? _activeTabId;
  
  // UI State
  ActivityBarView _currentView = ActivityBarView.explorer;
  bool _showSidebar = true;
  bool _showTerminal = false;
  bool _showMinimap = false;
  double _terminalHeight = 200;
  
  // Search/Replace
  bool _showSearch = false;
  bool _showReplace = false;
  final _searchCtrl = TextEditingController();
  final _replaceCtrl = TextEditingController();
  int _currentSearchIndex = -1;
  List<int> _searchMatches = [];
  
  // File explorer
  final Set<String> _expandedFolders = {'/C:', '/C:/Users', '/C:/Users/Admin'};
  
  // Terminal
  TerminalEngine? _terminalEngine;
  final _terminalCtrl = TextEditingController();
  final _terminalScrollCtrl = ScrollController();
  
  // Editor
  final _editorScrollCtrl = ScrollController();
  final _editorFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _engine = EditorEngine(widget.vfs);
    _engine.onChange.listen((_) => setState(() {}));
    
    if (widget.initialFilePath != null) {
      final tab = _engine.openFile(widget.initialFilePath!);
      _activeTabId = tab.tabId;
    }
  // One-time focus for editor shortcuts; never call requestFocus from build
  // (that would steal focus from TextFields on every setState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editorFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _engine.dispose();
    _searchCtrl.dispose();
    _replaceCtrl.dispose();
    _terminalEngine?.dispose();
    _terminalCtrl.dispose();
    _terminalScrollCtrl.dispose();
    _editorScrollCtrl.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  EditorTab? get _activeTab => _activeTabId != null ? _engine.getTab(_activeTabId!) : null;

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    
    if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyP) {
      _showCommandPalette();
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyS) {
      _saveCurrentFile();
    } else if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyS) {
      _saveAsCurrentFile();
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyN) {
      _createNewFile();
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyO) {
      _showOpenFileDialog();
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyF) {
      setState(() {
        _showSearch = !_showSearch;
        _showReplace = false;
      });
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyH) {
      setState(() {
        _showSearch = true;
        _showReplace = true;
      });
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyW) {
      if (_activeTabId != null) _closeTab(_activeTabId!);
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.backquote) {
      _toggleTerminal();
    } else if (ctrl && event.logicalKey == LogicalKeyboardKey.keyB) {
      setState(() => _showSidebar = !_showSidebar);
    }
  }

  void _showCommandPalette() {
    CommandPalette.show(context, _getCommands());
  }

  List<EditorCommand> _getCommands() {
    return [
      EditorCommand(
        id: 'new-file',
        label: 'File: New File',
        shortcut: 'Ctrl+N',
        icon: Icons.insert_drive_file,
        action: _createNewFile,
      ),
      EditorCommand(
        id: 'open-file',
        label: 'File: Open File',
        shortcut: 'Ctrl+O',
        icon: Icons.folder_open,
        action: _showOpenFileDialog,
      ),
      EditorCommand(
        id: 'save',
        label: 'File: Save',
        shortcut: 'Ctrl+S',
        icon: Icons.save,
        action: _saveCurrentFile,
      ),
      EditorCommand(
        id: 'save-as',
        label: 'File: Save As',
        shortcut: 'Ctrl+Shift+S',
        icon: Icons.save_as,
        action: _saveAsCurrentFile,
      ),
      EditorCommand(
        id: 'toggle-sidebar',
        label: 'View: Toggle Sidebar',
        shortcut: 'Ctrl+B',
        icon: Icons.view_sidebar,
        action: () => setState(() => _showSidebar = !_showSidebar),
      ),
      EditorCommand(
        id: 'toggle-terminal',
        label: 'View: Toggle Terminal',
        shortcut: 'Ctrl+`',
        icon: Icons.terminal,
        action: _toggleTerminal,
      ),
      EditorCommand(
        id: 'toggle-minimap',
        label: 'View: Toggle Minimap',
        icon: Icons.map,
        action: () => setState(() => _showMinimap = !_showMinimap),
      ),
      EditorCommand(
        id: 'find',
        label: 'Edit: Find',
        shortcut: 'Ctrl+F',
        icon: Icons.search,
        action: () => setState(() {
          _showSearch = true;
          _showReplace = false;
        }),
      ),
      EditorCommand(
        id: 'replace',
        label: 'Edit: Replace',
        shortcut: 'Ctrl+H',
        icon: Icons.find_replace,
        action: () => setState(() {
          _showSearch = true;
          _showReplace = true;
        }),
      ),
    ];
  }

  void _createNewFile() {
    final tab = _engine.createNewFile();
    setState(() => _activeTabId = tab.tabId);
  }

  void _saveCurrentFile() {
    if (_activeTab == null) return;
    if (_activeTab!.filePath.isEmpty) {
      _saveAsCurrentFile();
    } else {
      _activeTab!.save();
      setState(() {});
    }
  }

  void _saveAsCurrentFile() async {
    if (_activeTab == null) return;
    final path = await FilePicker.save(
      context,
      widget.vfs,
      initialPath: _prefs.lastSavePath,
      initialFileName: _activeTab!.fileName,
    );
    if (path != null) {
      _activeTab!.saveAs(path);
      _prefs.setLastSavePath(path);
      setState(() {});
    }
  }

  void _showOpenFileDialog() async {
    final path = await FilePicker.open(
      context,
      widget.vfs,
      initialPath: _prefs.lastOpenPath,
    );
    if (path != null) {
      try {
        final tab = _engine.openFile(path);
        _prefs.setLastOpenPath(path);
        setState(() => _activeTabId = tab.tabId);
      } catch (e) {
  // Handle error
      }
    }
  }

  void _closeTab(String tabId) {
    final tab = _engine.getTab(tabId);
    if (tab != null && tab.isDirty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF252526),
          title: const Text('Unsaved Changes', style: TextStyle(color: Colors.white)),
          content: Text(
            'Do you want to save changes to ${tab.fileName}?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _engine.closeTab(tabId);
                if (_activeTabId == tabId) {
                  _activeTabId = _engine.tabs.isNotEmpty ? _engine.tabs.first.tabId : null;
                }
                setState(() {});
              },
              child: const Text('Don\'t Save'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                tab.save();
                _engine.closeTab(tabId);
                if (_activeTabId == tabId) {
                  _activeTabId = _engine.tabs.isNotEmpty ? _engine.tabs.first.tabId : null;
                }
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } else {
      _engine.closeTab(tabId);
      if (_activeTabId == tabId) {
        _activeTabId = _engine.tabs.isNotEmpty ? _engine.tabs.first.tabId : null;
      }
      setState(() {});
    }
  }

  void _toggleTerminal() {
    setState(() {
      _showTerminal = !_showTerminal;
      if (_showTerminal && _terminalEngine == null) {
        _terminalEngine = TerminalEngine(
          widget.vfs,
          onFactoryReset: () => OsFactoryReset.run(context),
        );
        _terminalEngine!.addListener(() {
          setState(() {});
          Future.delayed(const Duration(milliseconds: 50), () {
            if (_terminalScrollCtrl.hasClients) {
              _terminalScrollCtrl.jumpTo(_terminalScrollCtrl.position.maxScrollExtent);
            }
          });
        });
      }
    });
  }

  void _openFileFromExplorer(String path) {
    try {
      final tab = _engine.openFile(path);
      setState(() => _activeTabId = tab.tabId);
    } catch (e) {
  // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _editorFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            EditorMenuBar(
              onNewFile: _createNewFile,
              onOpenFile: _showOpenFileDialog,
              onSave: _saveCurrentFile,
              onSaveAs: _saveAsCurrentFile,
              onFind: () => setState(() {
                _showSearch = true;
                _showReplace = false;
              }),
              onReplace: () => setState(() {
                _showSearch = true;
                _showReplace = true;
              }),
              onToggleSidebar: () => setState(() => _showSidebar = !_showSidebar),
              onToggleTerminal: _toggleTerminal,
              onToggleMinimap: () => setState(() => _showMinimap = !_showMinimap),
              onCommandPalette: _showCommandPalette,
            ),
            Expanded(
              child: Row(
                children: [
                  ActivityBar(
                    selectedView: _currentView,
                    onViewChanged: (view) => setState(() => _currentView = view),
                  ),
                  if (_showSidebar)
                    SidebarPanel(
                      currentView: _currentView,
                      vfs: widget.vfs,
                      onFileOpen: _openFileFromExplorer,
                      currentPath: widget.rootFolder ?? '/C:/Users/Admin',
                      expandedFolders: _expandedFolders,
                      onFolderToggle: (path) {
                        setState(() {
                          if (_expandedFolders.contains(path)) {
                            _expandedFolders.remove(path);
                          } else {
                            _expandedFolders.add(path);
                          }
                        });
                      },
                      rootFolder: widget.rootFolder,
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        EnhancedTabBar(
                          tabs: _engine.tabs.map((tab) {
                            return EditorTabData(
                              tabId: tab.tabId,
                              fileName: tab.fileName,
                              filePath: tab.filePath,
                              isDirty: tab.isDirty,
                              icon: _getFileIcon(tab.fileExtension),
                              iconColor: _getFileColor(tab.fileExtension),
                            );
                          }).toList(),
                          activeTabId: _activeTabId,
                          onTabSelected: (tabId) => setState(() => _activeTabId = tabId),
                          onTabClose: _closeTab,
                        ),
                        if (_activeTab != null)
                          EditorBreadcrumb(filePath: _activeTab!.filePath),
                        if (_activeTab != null) _buildQuickToolbar(),
                        if (_showSearch) _buildSearchBar(),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(child: _buildEditorArea()),
                              if (_showTerminal) _buildTerminal(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            EditorStatusBar(
              language: _activeTab?.language.name,
              encoding: 'UTF-8',
              lineEnding: 'LF',
              currentLine: 1,
              currentColumn: 1,
              totalLines: _activeTab?.controller.text.split('\n').length,
              isDirty: _activeTab?.isDirty,
              gitBranch: 'main',
              autoSaveEnabled: _engine.autoSaveEnabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickToolbar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF2D2D30),
      child: Row(
        children: [
          _buildQuickButton(Icons.save, 'Save (Ctrl+S)', _saveCurrentFile),
          _buildQuickButton(Icons.undo, 'Undo (Ctrl+Z)', () {}),
          _buildQuickButton(Icons.redo, 'Redo (Ctrl+Y)', () {}),
          const VerticalDivider(color: Colors.white24, width: 16),
          _buildQuickButton(Icons.content_cut, 'Cut (Ctrl+X)', () {}),
          _buildQuickButton(Icons.content_copy, 'Copy (Ctrl+C)', () {}),
          _buildQuickButton(Icons.content_paste, 'Paste (Ctrl+V)', () {}),
          const VerticalDivider(color: Colors.white24, width: 16),
          _buildQuickButton(Icons.search, 'Find (Ctrl+F)', () {
            setState(() {
              _showSearch = true;
              _showReplace = false;
            });
          }),
          _buildQuickButton(Icons.find_replace, 'Replace (Ctrl+H)', () {
            setState(() {
              _showSearch = true;
              _showReplace = true;
            });
          }),
          const Spacer(),
          Text(
            'Lines: ${_activeTab?.controller.text.split('\n').length ?? 0}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(width: 16),
          Text(
            'Chars: ${_activeTab?.controller.text.length ?? 0}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white70, size: 16),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF252526),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Find',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF3C3C3C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (value) => _performSearch(),
                  onSubmitted: (value) => _findNext(),
                ),
              ),
              const SizedBox(width: 4),
              if (_searchMatches.isNotEmpty)
                Text(
                  '${_currentSearchIndex + 1}/${_searchMatches.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 16),
                color: Colors.white70,
                onPressed: _findPrevious,
                tooltip: 'Previous Match',
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 16),
                color: Colors.white70,
                onPressed: _findNext,
                tooltip: 'Next Match',
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.white70,
                onPressed: () => setState(() {
                  _showSearch = false;
                  _searchMatches.clear();
                  _currentSearchIndex = -1;
                }),
              ),
            ],
          ),
          if (_showReplace) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replaceCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Replace',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF3C3C3C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _replaceOne,
                  child: const Text('Replace', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: _replaceAll,
                  child: const Text('Replace All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _performSearch() {
    if (_activeTab == null || _searchCtrl.text.isEmpty) {
      setState(() {
        _searchMatches.clear();
        _currentSearchIndex = -1;
      });
      return;
    }

    final text = _activeTab!.controller.text;
    final query = _searchCtrl.text;
    final matches = <int>[];

    int index = 0;
    while (index < text.length) {
      index = text.indexOf(query, index);
      if (index == -1) break;
      matches.add(index);
      index += query.length;
    }

    setState(() {
      _searchMatches = matches;
      _currentSearchIndex = matches.isNotEmpty ? 0 : -1;
    });

    if (matches.isNotEmpty) {
      _highlightMatch(matches[0]);
    }
  }

  void _findNext() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchMatches.length;
    });
    _highlightMatch(_searchMatches[_currentSearchIndex]);
  }

  void _findPrevious() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentSearchIndex = (_currentSearchIndex - 1 + _searchMatches.length) % _searchMatches.length;
    });
    _highlightMatch(_searchMatches[_currentSearchIndex]);
  }

  void _highlightMatch(int position) {
    if (_activeTab == null) return;
    _activeTab!.controller.selection = TextSelection(
      baseOffset: position,
      extentOffset: position + _searchCtrl.text.length,
    );
  }

  void _replaceOne() {
    if (_activeTab == null || _searchCtrl.text.isEmpty || _searchMatches.isEmpty) return;
    
    final text = _activeTab!.controller.text;
    final search = _searchCtrl.text;
    final replace = _replaceCtrl.text;
    final position = _searchMatches[_currentSearchIndex];
    
    final newText = text.substring(0, position) + replace + text.substring(position + search.length);
    _activeTab!.controller.text = newText;
    _activeTab!.controller.selection = TextSelection.collapsed(offset: position + replace.length);
    
    _performSearch();
  }

  void _replaceAll() {
    if (_activeTab == null || _searchCtrl.text.isEmpty) return;
    final text = _activeTab!.controller.text;
    final search = _searchCtrl.text;
    final replace = _replaceCtrl.text;
    _activeTab!.controller.text = text.replaceAll(search, replace);
    _performSearch();
  }

  Widget _buildEditorArea() {
    if (_activeTab == null) {
      return _buildWelcomeScreen();
    }

    return _buildEditor();
  }

  Widget _buildWelcomeScreen() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.code, size: 80, color: Color(0xFF007ACC)),
            const SizedBox(height: 24),
            const Text(
              'Professional Code Editor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start by opening a file or creating a new one',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _createNewFile,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007ACC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _showOpenFileDialog,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Open File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF007ACC)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        controller: _editorScrollCtrl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _activeTab!.controller,
            maxLines: null,
            style: TextStyle(
              color: const Color(0xFFD4D4D4),
              fontSize: _prefs.fontSize.toDouble(),
              fontFamily: 'monospace',
              height: 1.5,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTerminal() {
    return Container(
      height: _terminalHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFF252526),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                const Text(
                  'TERMINAL',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: Colors.white70,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _showTerminal = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              child: ListView(
                controller: _terminalScrollCtrl,
                children: [
                  SelectableText(
                    _terminalEngine?.output.map((line) => line.text).join('\n') ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Text(
                  '${_terminalEngine?.cwd ?? '/C:/Users/Admin'} \$ ',
                  style: const TextStyle(
                    color: Color(0xFF4EC9B0),
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _terminalCtrl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (cmd) {
                      _terminalEngine?.execute(cmd);
                      _terminalCtrl.clear();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'dart': return Icons.code;
      case 'py': return Icons.code;
      case 'js': case 'ts': return Icons.javascript;
      case 'html': return Icons.html;
      case 'css': return Icons.css;
      case 'json': return Icons.data_object;
      case 'md': return Icons.description;
      default: return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext) {
      case 'dart': return const Color(0xFF00D2B8);
      case 'py': return const Color(0xFF3776AB);
      case 'js': return const Color(0xFFF7DF1E);
      case 'ts': return const Color(0xFF3178C6);
      case 'html': return const Color(0xFFE34C26);
      case 'css': return const Color(0xFF1572B6);
      case 'json': return const Color(0xFFFFA500);
      case 'md': return const Color(0xFF083FA1);
      default: return Colors.white60;
    }
  }
}