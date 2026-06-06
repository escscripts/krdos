import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as host_fp;
import 'package:flutter/material.dart';
import 'vfs.dart';

enum FilePickerMode { open, save }

class FilePicker extends StatefulWidget {
  final VirtualFileSystem vfs;
  final FilePickerMode mode;
  final String? initialPath;
  final String? initialFileName;

  /// When set (lowercase, no dot: `png`, `jpg`), only those file types are listed and accepted.
  final Set<String>? allowedExtensions;

  const FilePicker({
    super.key,
    required this.vfs,
    required this.mode,
    this.initialPath,
    this.initialFileName,
    this.allowedExtensions,
  });

  static Future<String?> open(
    BuildContext context,
    VirtualFileSystem vfs, {
    String? initialPath,
    Set<String>? allowedExtensions,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => FilePicker(
        vfs: vfs,
        mode: FilePickerMode.open,
        initialPath: initialPath,
        allowedExtensions: allowedExtensions,
      ),
    );
  }

  /// Host OS file dialog ? PNG / JPEG only. Returns raw bytes or `null` if cancelled.
  static Future<Uint8List?> pickHostImageBytes() async {
    final result = await host_fp.FilePicker.platform.pickFiles(
      type: host_fp.FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    if (f.bytes != null && f.bytes!.isNotEmpty) return f.bytes;
    return null;
  }

  static Future<String?> save(BuildContext context, VirtualFileSystem vfs, {String? initialPath, String? initialFileName}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => FilePicker(
        vfs: vfs,
        mode: FilePickerMode.save,
        initialPath: initialPath,
        initialFileName: initialFileName,
      ),
    );
  }

  @override
  State<FilePicker> createState() => _FilePickerState();
}

class _FilePickerState extends State<FilePicker> {
  late String _currentPath;
  final _fileNameCtrl = TextEditingController();
  String? _selectedFile;
  final List<String> _pathHistory = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath ?? '/C:/Users/Admin';
    if (widget.initialFileName != null) {
      _fileNameCtrl.text = widget.initialFileName!;
    }
  }

  @override
  void dispose() {
    _fileNameCtrl.dispose();
    super.dispose();
  }

  void _navigateTo(String path) {
    if (_historyIndex < _pathHistory.length - 1) {
      _pathHistory.removeRange(_historyIndex + 1, _pathHistory.length);
    }
    _pathHistory.add(_currentPath);
    _historyIndex++;
    setState(() {
      _currentPath = path;
      _selectedFile = null;
    });
  }

  void _goBack() {
    if (_historyIndex > 0) {
      _historyIndex--;
      setState(() {
        _currentPath = _pathHistory[_historyIndex];
        _selectedFile = null;
      });
    }
  }

  void _goForward() {
    if (_historyIndex < _pathHistory.length - 1) {
      _historyIndex++;
      setState(() {
        _currentPath = _pathHistory[_historyIndex];
        _selectedFile = null;
      });
    }
  }

  void _goUp() {
    if (_currentPath == '/' || _currentPath == '/C:' || _currentPath == '/D:') return;
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return;
    final parentPath = parts.length == 1 ? '/' : '/${parts.sublist(0, parts.length - 1).join('/')}';
    _navigateTo(parentPath);
  }

  List<VfsNode> _getCurrentItems() {
    final node = widget.vfs.resolve(_currentPath);
    if (node is! VfsDir) return [];
    final items = node.children.values.toList();
    items.sort((a, b) {
      if (a is VfsDir && b is VfsFile) return -1;
      if (a is VfsFile && b is VfsDir) return 1;
      return a.name.compareTo(b.name);
    });
    final allowed = widget.allowedExtensions;
    if (allowed == null || allowed.isEmpty) return items;
    return items.where((n) {
      if (n is VfsDir) return true;
      final ext = n.name.split('.').last.toLowerCase();
      return allowed.contains(ext);
    }).toList();
  }

  void _selectFile(String fileName) {
    setState(() {
      _selectedFile = fileName;
      _fileNameCtrl.text = fileName;
    });
  }

  void _openFolder(String folderName) {
    final newPath = _currentPath == '/' ? '/$folderName' : '$_currentPath/$folderName';
    _navigateTo(newPath);
  }

  void _confirm() {
    if (widget.mode == FilePickerMode.open) {
      if (_selectedFile != null) {
        final ext = _selectedFile!.split('.').last.toLowerCase();
        if (widget.allowedExtensions != null &&
            widget.allowedExtensions!.isNotEmpty &&
            !widget.allowedExtensions!.contains(ext)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This dialog accepts: ${widget.allowedExtensions!.join(', ')}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          );
          return;
        }
        final fullPath = _currentPath == '/' ? '/$_selectedFile' : '$_currentPath/$_selectedFile';
        Navigator.pop(context, fullPath);
      }
    } else {
      if (_fileNameCtrl.text.isNotEmpty) {
        final fullPath = _currentPath == '/' ? '/${_fileNameCtrl.text}' : '$_currentPath/${_fileNameCtrl.text}';
        Navigator.pop(context, fullPath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2D2D30),
      child: Container(
        width: 700,
        height: 500,
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildAddressBar(),
            Expanded(child: _buildFileList()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_open, color: Color(0xFF007ACC), size: 20),
          const SizedBox(width: 8),
          Text(
            widget.mode == FilePickerMode.open
                ? (widget.allowedExtensions != null ? 'Open Image' : 'Open File')
                : 'Save File',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.white70,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            color: _historyIndex > 0 ? Colors.white70 : Colors.white24,
            onPressed: _historyIndex > 0 ? _goBack : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 18),
            color: _historyIndex < _pathHistory.length - 1 ? Colors.white70 : Colors.white24,
            onPressed: _historyIndex < _pathHistory.length - 1 ? _goForward : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            color: Colors.white70,
            onPressed: _goUp,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3C3C3C),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 16, color: Color(0xFFDCB67A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentPath,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    final items = _getCurrentItems();
    
    return Container(
      color: const Color(0xFF1E1E1E),
      child: items.isEmpty
          ? const Center(
              child: Text(
                'Empty folder',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                final isDir = item is VfsDir;
                final isSelected = _selectedFile == item.name;

                return InkWell(
                  onTap: () {
                    if (isDir) {
                      _openFolder(item.name);
                    } else {
                      _selectFile(item.name);
                    }
                  },
                  onDoubleTap: () {
                    if (isDir) {
                      _openFolder(item.name);
                    } else if (widget.mode == FilePickerMode.open) {
                      _selectFile(item.name);
                      _confirm();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: isSelected ? const Color(0xFF094771) : Colors.transparent,
                    child: Row(
                      children: [
                        Icon(
                          isDir ? Icons.folder : Icons.insert_drive_file,
                          size: 18,
                          color: isDir ? const Color(0xFFDCB67A) : _getFileColor(item.name),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        if (!isDir && item is VfsFile) ...[
                          Text(
                            _formatSize(item.size),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _formatDate(item.modified),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('File name:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _fileNameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF3C3C3C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  readOnly: widget.mode == FilePickerMode.open,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007ACC),
                  foregroundColor: Colors.white,
                ),
                child: Text(widget.mode == FilePickerMode.open ? 'Open' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getFileColor(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart': return const Color(0xFF00D2B8);
      case 'py': return const Color(0xFF3776AB);
      case 'js': return const Color(0xFFF7DF1E);
      case 'ts': return const Color(0xFF3178C6);
      case 'html': return const Color(0xFFE34C26);
      case 'css': return const Color(0xFF1572B6);
      case 'json': return const Color(0xFFFFA500);
      case 'md': return const Color(0xFF083FA1);
      case 'txt': return Colors.white70;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return const Color(0xFF7BC96F);
      default: return Colors.white60;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
