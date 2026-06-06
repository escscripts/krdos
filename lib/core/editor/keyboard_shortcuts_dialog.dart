import 'package:flutter/material.dart';

class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const KeyboardShortcutsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF252526),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.keyboard, color: Color(0xFF007ACC), size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Keyboard Shortcuts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildSection('File Operations', [
                    _ShortcutItem('Ctrl+N', 'New File'),
                    _ShortcutItem('Ctrl+O', 'Open File'),
                    _ShortcutItem('Ctrl+S', 'Save'),
                    _ShortcutItem('Ctrl+Shift+S', 'Save As'),
                    _ShortcutItem('Ctrl+W', 'Close Tab'),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('Editing', [
                    _ShortcutItem('Ctrl+Z', 'Undo'),
                    _ShortcutItem('Ctrl+Y', 'Redo'),
                    _ShortcutItem('Ctrl+X', 'Cut'),
                    _ShortcutItem('Ctrl+C', 'Copy'),
                    _ShortcutItem('Ctrl+V', 'Paste'),
                    _ShortcutItem('Ctrl+A', 'Select All'),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('Search & Replace', [
                    _ShortcutItem('Ctrl+F', 'Find'),
                    _ShortcutItem('Ctrl+H', 'Replace'),
                    _ShortcutItem('F3', 'Find Next'),
                    _ShortcutItem('Shift+F3', 'Find Previous'),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('View', [
                    _ShortcutItem('Ctrl+B', 'Toggle Sidebar'),
                    _ShortcutItem('Ctrl+`', 'Toggle Terminal'),
                    _ShortcutItem('Ctrl+Shift+P', 'Command Palette'),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<_ShortcutItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF007ACC),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3C3C3C),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  item.shortcut,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                item.description,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

class _ShortcutItem {
  final String shortcut;
  final String description;

  _ShortcutItem(this.shortcut, this.description);
}
