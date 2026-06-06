import 'package:flutter/material.dart';

class EditorCommand {
  final String id;
  final String label;
  final String? description;
  final IconData? icon;
  final String? shortcut;
  final VoidCallback action;

  EditorCommand({
    required this.id,
    required this.label,
    this.description,
    this.icon,
    this.shortcut,
    required this.action,
  });
}

class CommandPalette extends StatefulWidget {
  final List<EditorCommand> commands;

  const CommandPalette({
    super.key,
    required this.commands,
  });

  static Future<void> show(BuildContext context, List<EditorCommand> commands) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => CommandPalette(commands: commands),
    );
  }

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<EditorCommand> _filteredCommands = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _filteredCommands = widget.commands;
    _searchCtrl.addListener(_filterCommands);
    Future.delayed(Duration.zero, () => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _filterCommands() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCommands = widget.commands;
      } else {
        _filteredCommands = widget.commands.where((cmd) {
          return cmd.label.toLowerCase().contains(query) ||
                 (cmd.description?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
      _selectedIndex = 0;
    });
  }

  void _executeCommand(EditorCommand command) {
    Navigator.pop(context);
    command.action();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF252526),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF007ACC), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchBar(),
            if (_filteredCommands.isNotEmpty) _buildCommandList(),
            if (_filteredCommands.isEmpty) _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF3C3C3C))),
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _focusNode,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Type a command or search...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF3C3C3C)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF3C3C3C)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFF007ACC)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildCommandList() {
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredCommands.length,
        itemBuilder: (ctx, i) {
          final command = _filteredCommands[i];
          final isSelected = i == _selectedIndex;

          return InkWell(
            onTap: () => _executeCommand(command),
            onHover: (hovering) {
              if (hovering) setState(() => _selectedIndex = i);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isSelected ? const Color(0xFF094771) : Colors.transparent,
              child: Row(
                children: [
                  if (command.icon != null) ...[
                    Icon(command.icon, size: 18, color: Colors.white70),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          command.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (command.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            command.description!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (command.shortcut != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3C3C3C),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        command.shortcut!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(
            'No commands found',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
