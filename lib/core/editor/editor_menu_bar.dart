import 'package:flutter/material.dart';
import 'keyboard_shortcuts_dialog.dart';

class EditorMenuItem {
  final String label;
  final String? shortcut;
  final IconData? icon;
  final VoidCallback? onTap;
  final List<EditorMenuItem>? submenu;
  final bool isDivider;

  EditorMenuItem({
    this.label = '',
    this.shortcut,
    this.icon,
    this.onTap,
    this.submenu,
    this.isDivider = false,
  });

  static EditorMenuItem divider() => EditorMenuItem(isDivider: true);
}

class EditorMenuBar extends StatefulWidget {
  final Function()? onNewFile;
  final Function()? onOpenFile;
  final Function()? onSave;
  final Function()? onSaveAs;
  final Function()? onUndo;
  final Function()? onRedo;
  final Function()? onCut;
  final Function()? onCopy;
  final Function()? onPaste;
  final Function()? onFind;
  final Function()? onReplace;
  final Function()? onToggleSidebar;
  final Function()? onToggleTerminal;
  final Function()? onToggleMinimap;
  final Function()? onCommandPalette;

  const EditorMenuBar({
    super.key,
    this.onNewFile,
    this.onOpenFile,
    this.onSave,
    this.onSaveAs,
    this.onUndo,
    this.onRedo,
    this.onCut,
    this.onCopy,
    this.onPaste,
    this.onFind,
    this.onReplace,
    this.onToggleSidebar,
    this.onToggleTerminal,
    this.onToggleMinimap,
    this.onCommandPalette,
  });

  @override
  State<EditorMenuBar> createState() => _EditorMenuBarState();
}

class _EditorMenuBarState extends State<EditorMenuBar> {
  String? _hoveredMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      color: const Color(0xFF3C3C3C),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _buildMenuButton('File', _getFileMenu()),
          _buildMenuButton('Edit', _getEditMenu()),
          _buildMenuButton('Selection', _getSelectionMenu()),
          _buildMenuButton('View', _getViewMenu()),
          _buildMenuButton('Go', _getGoMenu()),
          _buildMenuButton('Run', _getRunMenu()),
          _buildMenuButton('Help', _getHelpMenu()),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, size: 16),
            color: Colors.white70,
            onPressed: widget.onFind,
            tooltip: 'Search (Ctrl+F)',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(String label, List<EditorMenuItem> items) {
    final isHovered = _hoveredMenu == label;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredMenu = label),
      onExit: (_) => setState(() => _hoveredMenu = null),
      child: PopupMenuButton<VoidCallback>(
        offset: const Offset(0, 35),
        color: const Color(0xFF252526),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isHovered ? const Color(0xFF505050) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        itemBuilder: (ctx) => items.map((item) {
          if (item.isDivider) {
            return const PopupMenuDivider() as PopupMenuEntry<VoidCallback>;
          }
          return PopupMenuItem<VoidCallback>(
            value: item.onTap,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 16, color: Colors.white70),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                if (item.shortcut != null)
                  Text(
                    item.shortcut!,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
              ],
            ),
          );
        }).toList(),
        onSelected: (callback) => callback?.call(),
      ),
    );
  }

  List<EditorMenuItem> _getFileMenu() {
    return [
      EditorMenuItem(label: 'New File', shortcut: 'Ctrl+N', icon: Icons.insert_drive_file, onTap: widget.onNewFile),
      EditorMenuItem(label: 'Open File...', shortcut: 'Ctrl+O', icon: Icons.folder_open, onTap: widget.onOpenFile),
      EditorMenuItem.divider(),
      EditorMenuItem(label: 'Save', shortcut: 'Ctrl+S', icon: Icons.save, onTap: widget.onSave),
      EditorMenuItem(label: 'Save As...', shortcut: 'Ctrl+Shift+S', icon: Icons.save_as, onTap: widget.onSaveAs),
      EditorMenuItem.divider(),
      EditorMenuItem(label: 'Close Editor', shortcut: 'Ctrl+W', icon: Icons.close),
    ];
  }

  List<EditorMenuItem> _getEditMenu() {
    return [
      EditorMenuItem(label: 'Undo', shortcut: 'Ctrl+Z', icon: Icons.undo, onTap: widget.onUndo),
      EditorMenuItem(label: 'Redo', shortcut: 'Ctrl+Y', icon: Icons.redo, onTap: widget.onRedo),
      EditorMenuItem.divider(),
      EditorMenuItem(label: 'Cut', shortcut: 'Ctrl+X', icon: Icons.content_cut, onTap: widget.onCut),
      EditorMenuItem(label: 'Copy', shortcut: 'Ctrl+C', icon: Icons.content_copy, onTap: widget.onCopy),
      EditorMenuItem(label: 'Paste', shortcut: 'Ctrl+V', icon: Icons.content_paste, onTap: widget.onPaste),
      EditorMenuItem.divider(),
      EditorMenuItem(label: 'Find', shortcut: 'Ctrl+F', icon: Icons.search, onTap: widget.onFind),
      EditorMenuItem(label: 'Replace', shortcut: 'Ctrl+H', icon: Icons.find_replace, onTap: widget.onReplace),
    ];
  }

  List<EditorMenuItem> _getSelectionMenu() {
    return [
      EditorMenuItem(label: 'Select All', shortcut: 'Ctrl+A', icon: Icons.select_all),
      EditorMenuItem(label: 'Expand Selection', shortcut: 'Shift+Alt+?'),
      EditorMenuItem(label: 'Shrink Selection', shortcut: 'Shift+Alt+?'),
      EditorMenuItem.divider(),
      EditorMenuItem(label: 'Add Cursor Above', shortcut: 'Ctrl+Alt+?'),
      EditorMenuItem(label: 'Add Cursor Below', shortcut: 'Ctrl+Alt+?'),
    ];
  }

  List<EditorMenuItem> _getViewMenu() {
    return [
      EditorMenuItem(label: 'Command Palette...', shortcut: 'Ctrl+Shift+P', icon: Icons.search, onTap: widget.onCommandPalette),
      EditorMenuItem.divider(),
      EditorMenuItem(label: 'Explorer', shortcut: 'Ctrl+Shift+E', icon: Icons.folder),
      EditorMenuItem(label: 'Search', shortcut: 'Ctrl+Shift+F', icon: Icons.search),
      EditorMenuItem(label: 'Source Control', shortcut: 'Ctrl+Shift+G', icon: Icons.source),
      EditorMenuItem.divider(),
      EditorMenuItem(label: 'Toggle Sidebar', shortcut: 'Ctrl+B', icon: Icons.view_sidebar, onTap: widget.onToggleSidebar),
      EditorMenuItem(label: 'Toggle Terminal', shortcut: 'Ctrl+`', icon: Icons.terminal, onTap: widget.onToggleTerminal),
      EditorMenuItem(label: 'Toggle Minimap', icon: Icons.map, onTap: widget.onToggleMinimap),
    ];
  }

  List<EditorMenuItem> _getGoMenu() {
    return [
      EditorMenuItem(label: 'Go to File...', shortcut: 'Ctrl+P', icon: Icons.file_open),
      EditorMenuItem(label: 'Go to Line...', shortcut: 'Ctrl+G', icon: Icons.format_list_numbered),
      EditorMenuItem.divider(),
      EditorMenuItem(label: 'Back', shortcut: 'Alt+?', icon: Icons.arrow_back),
      EditorMenuItem(label: 'Forward', shortcut: 'Alt+?', icon: Icons.arrow_forward),
    ];
  }

  List<EditorMenuItem> _getRunMenu() {
    return [
      EditorMenuItem(label: 'Start Debugging', shortcut: 'F5', icon: Icons.play_arrow),
      EditorMenuItem(label: 'Run Without Debugging', shortcut: 'Ctrl+F5', icon: Icons.play_circle_outline),
      EditorMenuItem.divider(),
      EditorMenuItem(label: 'Stop', shortcut: 'Shift+F5', icon: Icons.stop),
      EditorMenuItem(label: 'Restart', shortcut: 'Ctrl+Shift+F5', icon: Icons.restart_alt),
    ];
  }

  List<EditorMenuItem> _getHelpMenu() {
    return [
      EditorMenuItem(label: 'Welcome', icon: Icons.home),
      EditorMenuItem(label: 'Documentation', icon: Icons.book),
      EditorMenuItem.divider(),
      EditorMenuItem(
        label: 'Keyboard Shortcuts',
        shortcut: 'Ctrl+K Ctrl+S',
        icon: Icons.keyboard,
        onTap: () => KeyboardShortcutsDialog.show(context),
      ),
      EditorMenuItem(label: 'About', icon: Icons.info),
    ];
  }
}
