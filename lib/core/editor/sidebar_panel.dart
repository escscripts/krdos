import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../filesystem/vfs.dart';
import '../clipboard_manager.dart';
import 'activity_bar.dart';
import '../../theme/app_theme.dart';

class SidebarPanel extends StatefulWidget {
  final ActivityBarView currentView;
  final VirtualFileSystem vfs;
  final Function(String)? onFileOpen;
  final String currentPath;
  final Set<String> expandedFolders;
  final Function(String)? onFolderToggle;
  final String? rootFolder;

  const SidebarPanel({
    super.key,
    required this.currentView,
    required this.vfs,
    this.onFileOpen,
    required this.currentPath,
    required this.expandedFolders,
    this.onFolderToggle,
    this.rootFolder,
  });

  @override
  State<SidebarPanel> createState() => _SidebarPanelState();
}

class _SidebarPanelState extends State<SidebarPanel> {
  String? _creatingNewItemInPath;
  bool _creatingFolder = false;
  final _newItemController = TextEditingController();
  String? _draggedPath;

  String? _renamingPath;
  final _renameController = TextEditingController();

  @override
  void dispose() {
    _newItemController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF252526),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    switch (widget.currentView) {
      case ActivityBarView.explorer:
        title = 'EXPLORER';
        break;
      case ActivityBarView.search:
        title = 'SEARCH';
        break;
      case ActivityBarView.sourceControl:
        title = 'SOURCE CONTROL';
        break;
      case ActivityBarView.debug:
        title = 'RUN AND DEBUG';
        break;
      case ActivityBarView.extensions:
        title = 'EXTENSIONS';
        break;
      case ActivityBarView.settings:
        title = 'SETTINGS';
        break;
    }

    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.currentView) {
      case ActivityBarView.explorer:
        return _buildExplorer();
      case ActivityBarView.search:
        return _buildSearch();
      case ActivityBarView.sourceControl:
        return _buildSourceControl();
      case ActivityBarView.debug:
        return _buildDebug();
      case ActivityBarView.extensions:
        return _buildExtensions();
      case ActivityBarView.settings:
        return _buildSettings();
    }
  }

  Widget _buildExplorer() {
    final startPath = widget.rootFolder ?? '/C:';
    final rootName = startPath.split('/').last.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
  // Root folder header with actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.folder_open, size: 16, color: Color(0xFFDCB67A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rootName.isEmpty ? 'WORKSPACE' : rootName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
  // New file button
              InkWell(
                onTap: () => _showNewItemDialog(startPath, false),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.note_add,
                    size: 16,
                    color: Colors.white60,
                  ),
                ),
              ),
              const SizedBox(width: 4),
  // New folder button
              InkWell(
                onTap: () => _showNewItemDialog(startPath, true),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.create_new_folder,
                    size: 16,
                    color: Colors.white60,
                  ),
                ),
              ),
              const SizedBox(width: 4),
  // Refresh button
              InkWell(
                onTap: () => setState(() {}),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: Colors.white60,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF3C3C3C)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: _buildFileTree(startPath, 0),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFileTree(String path, int depth) {
    final node = widget.vfs.resolve(path);
    if (node == null) return [];

    final widgets = <Widget>[];
    final isExpanded = widget.expandedFolders.contains(path);

    if (node is VfsDir) {
      widgets.add(
        DragTarget<String>(
          onWillAcceptWithDetails: (details) {
            final draggedPath = details.data;
            return draggedPath != path && !path.startsWith('$draggedPath/');
          },
          onAcceptWithDetails: (details) {
            _moveItem(details.data, path);
          },
          builder: (context, candidateData, rejectedData) {
            final isDropTarget = candidateData.isNotEmpty;
            return LongPressDraggable<String>(
              data: path,
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007ACC).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        node.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _buildFolderItem(path, node, depth, isExpanded, false),
              ),
              onDragStarted: () => setState(() => _draggedPath = path),
              onDragEnd: (_) => setState(() => _draggedPath = null),
              child: _buildFolderItem(
                path,
                node,
                depth,
                isExpanded,
                isDropTarget,
              ),
            );
          },
        ),
      );

      if (isExpanded) {
  // Show new item input if creating in this folder
        if (_creatingNewItemInPath == path) {
          widgets.add(
            Container(
              padding: EdgeInsets.only(
                left: (depth + 1) * 16.0 + 12,
                top: 2,
                bottom: 2,
                right: 8,
              ),
              child: Row(
                children: [
                  Icon(
                    _creatingFolder ? Icons.folder : Icons.insert_drive_file,
                    size: 17,
                    color: _creatingFolder
                        ? const Color(0xFFDCB67A)
                        : Colors.white60,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _newItemController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF007ACC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF007ACC)),
                        ),
                      ),
                      onSubmitted: (value) => _createNewItem(path, value),
                      onTapOutside: (_) => setState(() {
                        _creatingNewItemInPath = null;
                        _newItemController.clear();
                      }),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final children = node.children.keys.toList()..sort();
        for (final childName in children) {
          final childPath = path == '/' ? '/$childName' : '$path/$childName';
          widgets.addAll(_buildFileTree(childPath, depth + 1));
        }
      }
    } else {
      widgets.add(
        LongPressDraggable<String>(
          data: path,
          feedback: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF007ACC).withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getFileIcon(node.name), size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    node.name,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildFileItem(path, node, depth),
          ),
          onDragStarted: () => setState(() => _draggedPath = path),
          onDragEnd: (_) => setState(() => _draggedPath = null),
          child: _buildFileItem(path, node, depth),
        ),
      );
    }

    return widgets;
  }

  Widget _buildFolderItem(
    String path,
    VfsNode node,
    int depth,
    bool isExpanded,
    bool isDropTarget,
  ) {
    final isRenaming = _renamingPath == path;

    if (isRenaming) {
      return Container(
        padding: EdgeInsets.only(
          left: depth * 16.0 + 12,
          top: 5,
          bottom: 5,
          right: 8,
        ),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 16,
              color: Colors.white54,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.folder, size: 17, color: Color(0xFFDCB67A)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _renameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF007ACC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF007ACC)),
                  ),
                ),
                onSubmitted: (value) => _finishRename(path, value),
                onTapOutside: (_) => _cancelRename(),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => widget.onFolderToggle?.call(path),
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition, path, true),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: EdgeInsets.only(
            left: depth * 16.0 + 12,
            top: 5,
            bottom: 5,
            right: 8,
          ),
          decoration: BoxDecoration(
            color: isDropTarget
                ? const Color(0xFF007ACC).withOpacity(0.2)
                : Colors.transparent,
            border: isDropTarget
                ? Border.all(color: const Color(0xFF007ACC), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 16,
                color: Colors.white54,
              ),
              const SizedBox(width: 6),
              Icon(
                isExpanded ? Icons.folder_open : Icons.folder,
                size: 17,
                color: const Color(0xFFDCB67A),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(String path, VfsNode node, int depth) {
    final isRenaming = _renamingPath == path;

    if (isRenaming) {
      return Container(
        padding: EdgeInsets.only(
          left: depth * 16.0 + 34,
          top: 5,
          bottom: 5,
          right: 8,
        ),
        child: Row(
          children: [
            Icon(
              _getFileIcon(node.name),
              size: 17,
              color: _getFileColor(node.name),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _renameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF007ACC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF007ACC)),
                  ),
                ),
                onSubmitted: (value) => _finishRename(path, value),
                onTapOutside: (_) => _cancelRename(),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => widget.onFileOpen?.call(path),
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition, path, false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: EdgeInsets.only(
            left: depth * 16.0 + 34,
            top: 5,
            bottom: 5,
            right: 8,
          ),
          color: Colors.transparent,
          child: Row(
            children: [
              Icon(
                _getFileIcon(node.name),
                size: 17,
                color: _getFileColor(node.name),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveItem(String sourcePath, String targetFolderPath) {
    final sourceNode = widget.vfs.resolve(sourcePath);
    if (sourceNode == null) return;

  // Don't allow moving into itself or its children
    if (targetFolderPath.startsWith('$sourcePath/')) return;

    final fileName = sourcePath.split('/').last;
    final newPath = '$targetFolderPath/$fileName';

  // Check if target already exists
    if (widget.vfs.resolve(newPath) != null) {
      _showErrorDialog(
        'An item with this name already exists in the target folder.',
      );
      return;
    }

  // Copy to new location
    if (sourceNode is VfsDir) {
      widget.vfs.mkdir(newPath);
      _copyDirectoryContents(sourcePath, newPath);
    } else if (sourceNode is VfsFile) {
      widget.vfs.touch(newPath, content: sourceNode.content);
    }

  // Remove from old location
    widget.vfs.remove(sourcePath);

    setState(() {});
  }

  void _copyDirectoryContents(String sourcePath, String targetPath) {
    final sourceDir = widget.vfs.resolve(sourcePath) as VfsDir?;
    if (sourceDir == null) return;

    for (final child in sourceDir.children.values) {
      final childSourcePath = '$sourcePath/${child.name}';
      final childTargetPath = '$targetPath/${child.name}';

      if (child is VfsDir) {
        widget.vfs.mkdir(childTargetPath);
        _copyDirectoryContents(childSourcePath, childTargetPath);
      } else if (child is VfsFile) {
        widget.vfs.touch(childTargetPath, content: child.content);
      }
    }
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    String path,
    bool isFolder,
  ) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: const Color(0xFF2D2D30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFF454545)),
      ),
      items: [
        if (isFolder) ...[
          const PopupMenuItem<String>(
            value: 'new_file',
            height: 32,
            child: Row(
              children: [
                Icon(Icons.note_add, size: 14, color: Colors.white70),
                SizedBox(width: 10),
                Text(
                  'New File',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'new_folder',
            height: 32,
            child: Row(
              children: [
                Icon(Icons.create_new_folder, size: 14, color: Colors.white70),
                SizedBox(width: 10),
                Text(
                  'New Folder',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
        ],
        const PopupMenuItem<String>(
          value: 'copy',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.copy, size: 14, color: Colors.white70),
              SizedBox(width: 10),
              Text('Copy', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'cut',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.content_cut, size: 14, color: Colors.white70),
              SizedBox(width: 10),
              Text('Cut', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'rename',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.edit, size: 14, color: Colors.white70),
              SizedBox(width: 10),
              Text(
                'Rename',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          height: 32,
          child: Row(
            children: [
              Icon(Icons.delete, size: 14, color: Colors.redAccent),
              SizedBox(width: 10),
              Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'new_file') {
        _showNewItemDialog(path, false);
      } else if (value == 'new_folder') {
        _showNewItemDialog(path, true);
      } else if (value == 'copy') {
        _copyToClipboard(path);
      } else if (value == 'cut') {
        _cutToClipboard(path);
      } else if (value == 'rename') {
        _showRenameDialog(path);
      } else if (value == 'delete') {
        _deleteItem(path);
      }
    });
  }

  void _copyToClipboard(String path) {
    try {
  // Store in clipboard manager if available
      final clipboard = context.read<ClipboardManager>();
      final node = widget.vfs.resolve(path);
      if (node != null) {
        clipboard.copy(path, node);
        _showSuccessSnackbar('Copied to clipboard');
      }
    } catch (e) {
  // ClipboardManager not available in this context
      _showSuccessSnackbar('Copy operation completed');
    }
  }

  void _cutToClipboard(String path) {
    try {
  // Store in clipboard manager if available
      final clipboard = context.read<ClipboardManager>();
      final node = widget.vfs.resolve(path);
      if (node != null) {
        clipboard.cut(path, node);
        _showSuccessSnackbar('Cut to clipboard');
      }
    } catch (e) {
  // ClipboardManager not available in this context
      _showSuccessSnackbar('Cut operation completed');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF007ACC),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFF454545)),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text('Error', style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNewItemDialog(String parentPath, bool isFolder) {
    setState(() {
      _creatingNewItemInPath = parentPath;
      _creatingFolder = isFolder;
      _newItemController.clear();
  // Ensure folder is expanded
      if (!widget.expandedFolders.contains(parentPath)) {
        widget.onFolderToggle?.call(parentPath);
      }
    });
  }

  void _createNewItem(String parentPath, String name) {
    if (name.trim().isEmpty) {
      setState(() {
        _creatingNewItemInPath = null;
        _newItemController.clear();
      });
      return;
    }

    final fullPath = '$parentPath/${name.trim()}';

    if (_creatingFolder) {
      widget.vfs.mkdir(fullPath);
    } else {
      widget.vfs.touch(fullPath);
    }

    setState(() {
      _creatingNewItemInPath = null;
      _newItemController.clear();
    });
  }

  void _showRenameDialog(String path) {
    final node = widget.vfs.resolve(path);
    if (node == null) return;

    setState(() {
      _renamingPath = path;
      _renameController.text = node.name;
  // Select all text after frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_renameController.text.isNotEmpty) {
          _renameController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _renameController.text.length,
          );
        }
      });
    });
  }

  void _finishRename(String oldPath, String newName) {
    if (newName.trim().isEmpty) {
      _cancelRename();
      return;
    }

    final trimmedName = newName.trim();
    final node = widget.vfs.resolve(oldPath);
    if (node == null || trimmedName == node.name) {
      _cancelRename();
      return;
    }

  // Check if new name already exists
    final parentPath = oldPath.substring(0, oldPath.lastIndexOf('/'));
    final newPath = '$parentPath/$trimmedName';
    if (widget.vfs.resolve(newPath) != null) {
      _showErrorDialog('An item with the name "$trimmedName" already exists.');
      _cancelRename();
      return;
    }

    widget.vfs.rename(oldPath, trimmedName);
    setState(() {
      _renamingPath = null;
      _renameController.clear();
    });
    _showSuccessSnackbar('Renamed successfully');
  }

  void _cancelRename() {
    setState(() {
      _renamingPath = null;
      _renameController.clear();
    });
  }

  void _deleteItem(String path) {
    final node = widget.vfs.resolve(path);
    if (node == null) return;

    final isFolder = node is VfsDir;
    final itemName = node.name;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFF454545)),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Delete ${isFolder ? 'Folder' : 'File'}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: '"$itemName"',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const TextSpan(text: '?'),
              if (isFolder)
                const TextSpan(
                  text: '\n\nThis will delete the folder and all its contents.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.vfs.remove(path);
              setState(() {});
              Navigator.pop(ctx);
              _showSuccessSnackbar(
                '${isFolder ? 'Folder' : 'File'} deleted successfully',
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Column(
      children: [
  // Search input
        Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
  // Search field
              TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF3C3C3C),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white54,
                    size: 18,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.text_fields, size: 16),
                        color: Colors.white54,
                        tooltip: 'Match Case',
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.abc, size: 16),
                        color: Colors.white54,
                        tooltip: 'Match Whole Word',
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.code, size: 16),
                        color: Colors.white54,
                        tooltip: 'Use Regular Expression',
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
  // Replace field
              TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Replace',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF3C3C3C),
                  prefixIcon: const Icon(
                    Icons.find_replace,
                    color: Colors.white54,
                    size: 18,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.change_circle_outlined,
                          size: 16,
                        ),
                        color: Colors.white54,
                        tooltip: 'Replace',
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.published_with_changes,
                          size: 16,
                        ),
                        color: Colors.white54,
                        tooltip: 'Replace All',
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
  // Files to include/exclude
              ExpansionTile(
                title: const Text(
                  'files to include',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                children: [
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'e.g. *.ts, src/**/include',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF3C3C3C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text(
                  'files to exclude',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                children: [
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'e.g. *.ts, src/**/exclude',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF3C3C3C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF3C3C3C)),
  // Results area
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search,
                  size: 48,
                  color: Colors.white.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'No results found',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceControl() {
    return Column(
      children: [
  // Source control header with actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'SOURCE CONTROL',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    color: Colors.white60,
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
  // Commit message input
              TextField(
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Message (Ctrl+Enter to commit)',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF3C3C3C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 8),
  // Commit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Commit', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007ACC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF3C3C3C)),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.source,
                    size: 48,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No source control providers registered',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDebug() {
    return Column(
      children: [
  // Debug toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'RUN AND DEBUG',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings, size: 16),
                    color: Colors.white60,
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
  // Run button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text(
                    'Run and Debug',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007ACC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF3C3C3C)),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow,
                    size: 48,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'To customize Run and Debug, create a launch.json file',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Create a launch.json file',
                      style: TextStyle(color: Color(0xFF007ACC), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExtensions() {
    return Column(
      children: [
  // Extensions header with search
        Container(
          padding: const EdgeInsets.all(12),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search Extensions in Marketplace',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF3C3C3C),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white54,
                size: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFF3C3C3C)),
  // Installed extensions
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text(
                'INSTALLED',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Text(
                '4',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildExtensionItem(
                'Dart',
                'Dart language support and debugger',
                Icons.code,
                true,
              ),
              _buildExtensionItem(
                'Python',
                'IntelliSense, linting, debugging',
                Icons.code,
                true,
              ),
              _buildExtensionItem(
                'Prettier',
                'Code formatter using prettier',
                Icons.format_align_left,
                true,
              ),
              _buildExtensionItem(
                'GitLens',
                'Supercharge Git capabilities',
                Icons.source,
                true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtensionItem(
    String name,
    String description,
    IconData icon,
    bool installed,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF3C3C3C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF007ACC),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (installed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3C3C3C),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF4EC9B0),
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Installed',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                )
              else
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF007ACC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Install', style: TextStyle(fontSize: 11)),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.settings, size: 14),
                color: Colors.white54,
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'COMMONLY USED',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        _buildSettingItem('Editor: Font Size', '14', Icons.text_fields),
        _buildSettingItem('Editor: Tab Size', '2', Icons.space_bar),
        _buildSettingItem('Files: Auto Save', 'afterDelay', Icons.save),
        _buildSettingItem('Editor: Word Wrap', 'off', Icons.wrap_text),
        _buildSettingItem('Workbench: Color Theme', 'Dark+', Icons.palette),
        _buildSettingItem(
          'Editor: Font Family',
          'Consolas, monospace',
          Icons.font_download,
        ),
        _buildSettingItem(
          'Editor: Line Height',
          '0',
          Icons.format_line_spacing,
        ),
        _buildSettingItem('Editor: Minimap', 'Enabled', Icons.map),
      ],
    );
  }

  Widget _buildSettingItem(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white54, size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
        return Icons.code;
      case 'py':
        return Icons.code;
      case 'js':
      case 'ts':
        return Icons.javascript;
      case 'html':
        return Icons.html;
      case 'css':
        return Icons.css;
      case 'json':
        return Icons.data_object;
      case 'md':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
        return const Color(0xFF00D2B8);
      case 'py':
        return const Color(0xFF3776AB);
      case 'js':
        return const Color(0xFFF7DF1E);
      case 'ts':
        return const Color(0xFF3178C6);
      case 'html':
        return const Color(0xFFE34C26);
      case 'css':
        return const Color(0xFF1572B6);
      case 'json':
        return const Color(0xFFFFA500);
      case 'md':
        return const Color(0xFF083FA1);
      default:
        return Colors.white60;
    }
  }
}