import 'package:flutter/material.dart';

enum SuggestionType {
  keyword,
  variable,
  function,
  classType,
  snippet,
  property,
}

class CodeSuggestion {
  final String label;
  final String? detail;
  final String? documentation;
  final SuggestionType type;
  final String insertText;
  final IconData icon;

  CodeSuggestion({
    required this.label,
    this.detail,
    this.documentation,
    required this.type,
    required this.insertText,
    required this.icon,
  });
}

class AutocompleteEngine {
  static final Map<String, List<CodeSuggestion>> _languageSuggestions = {
    'dart': [
      CodeSuggestion(label: 'class', detail: 'Class declaration', type: SuggestionType.keyword, insertText: 'class ', icon: Icons.class_),
      CodeSuggestion(label: 'void', detail: 'Void type', type: SuggestionType.keyword, insertText: 'void ', icon: Icons.code),
      CodeSuggestion(label: 'String', detail: 'String type', type: SuggestionType.classType, insertText: 'String', icon: Icons.text_fields),
      CodeSuggestion(label: 'int', detail: 'Integer type', type: SuggestionType.classType, insertText: 'int', icon: Icons.numbers),
      CodeSuggestion(label: 'bool', detail: 'Boolean type', type: SuggestionType.classType, insertText: 'bool', icon: Icons.toggle_on),
      CodeSuggestion(label: 'List', detail: 'List collection', type: SuggestionType.classType, insertText: 'List', icon: Icons.list),
      CodeSuggestion(label: 'Map', detail: 'Map collection', type: SuggestionType.classType, insertText: 'Map', icon: Icons.map),
      CodeSuggestion(label: 'if', detail: 'If statement', type: SuggestionType.keyword, insertText: 'if ()', icon: Icons.call_split),
      CodeSuggestion(label: 'for', detail: 'For loop', type: SuggestionType.keyword, insertText: 'for ()', icon: Icons.loop),
      CodeSuggestion(label: 'while', detail: 'While loop', type: SuggestionType.keyword, insertText: 'while ()', icon: Icons.loop),
      CodeSuggestion(label: 'return', detail: 'Return statement', type: SuggestionType.keyword, insertText: 'return ', icon: Icons.keyboard_return),
      CodeSuggestion(label: 'async', detail: 'Async modifier', type: SuggestionType.keyword, insertText: 'async ', icon: Icons.sync),
      CodeSuggestion(label: 'await', detail: 'Await expression', type: SuggestionType.keyword, insertText: 'await ', icon: Icons.hourglass_empty),
      CodeSuggestion(label: 'final', detail: 'Final variable', type: SuggestionType.keyword, insertText: 'final ', icon: Icons.lock),
      CodeSuggestion(label: 'const', detail: 'Const variable', type: SuggestionType.keyword, insertText: 'const ', icon: Icons.lock_outline),
    ],
    'python': [
      CodeSuggestion(label: 'def', detail: 'Function definition', type: SuggestionType.keyword, insertText: 'def ', icon: Icons.functions),
      CodeSuggestion(label: 'class', detail: 'Class definition', type: SuggestionType.keyword, insertText: 'class ', icon: Icons.class_),
      CodeSuggestion(label: 'if', detail: 'If statement', type: SuggestionType.keyword, insertText: 'if :', icon: Icons.call_split),
      CodeSuggestion(label: 'for', detail: 'For loop', type: SuggestionType.keyword, insertText: 'for ', icon: Icons.loop),
      CodeSuggestion(label: 'while', detail: 'While loop', type: SuggestionType.keyword, insertText: 'while :', icon: Icons.loop),
      CodeSuggestion(label: 'return', detail: 'Return statement', type: SuggestionType.keyword, insertText: 'return ', icon: Icons.keyboard_return),
      CodeSuggestion(label: 'import', detail: 'Import module', type: SuggestionType.keyword, insertText: 'import ', icon: Icons.input),
      CodeSuggestion(label: 'from', detail: 'From import', type: SuggestionType.keyword, insertText: 'from ', icon: Icons.input),
      CodeSuggestion(label: 'try', detail: 'Try block', type: SuggestionType.keyword, insertText: 'try:', icon: Icons.error_outline),
      CodeSuggestion(label: 'except', detail: 'Except block', type: SuggestionType.keyword, insertText: 'except:', icon: Icons.error),
    ],
    'javascript': [
      CodeSuggestion(label: 'function', detail: 'Function declaration', type: SuggestionType.keyword, insertText: 'function ', icon: Icons.functions),
      CodeSuggestion(label: 'const', detail: 'Const variable', type: SuggestionType.keyword, insertText: 'const ', icon: Icons.lock),
      CodeSuggestion(label: 'let', detail: 'Let variable', type: SuggestionType.keyword, insertText: 'let ', icon: Icons.code),
      CodeSuggestion(label: 'var', detail: 'Var variable', type: SuggestionType.keyword, insertText: 'var ', icon: Icons.code),
      CodeSuggestion(label: 'if', detail: 'If statement', type: SuggestionType.keyword, insertText: 'if ()', icon: Icons.call_split),
      CodeSuggestion(label: 'for', detail: 'For loop', type: SuggestionType.keyword, insertText: 'for ()', icon: Icons.loop),
      CodeSuggestion(label: 'while', detail: 'While loop', type: SuggestionType.keyword, insertText: 'while ()', icon: Icons.loop),
      CodeSuggestion(label: 'return', detail: 'Return statement', type: SuggestionType.keyword, insertText: 'return ', icon: Icons.keyboard_return),
      CodeSuggestion(label: 'async', detail: 'Async function', type: SuggestionType.keyword, insertText: 'async ', icon: Icons.sync),
      CodeSuggestion(label: 'await', detail: 'Await expression', type: SuggestionType.keyword, insertText: 'await ', icon: Icons.hourglass_empty),
    ],
  };

  static List<CodeSuggestion> getSuggestions(String language, String prefix) {
    final suggestions = _languageSuggestions[language] ?? [];
    if (prefix.isEmpty) return suggestions;
    
    return suggestions.where((s) => s.label.toLowerCase().startsWith(prefix.toLowerCase())).toList();
  }
}

class AutocompleteOverlay extends StatefulWidget {
  final List<CodeSuggestion> suggestions;
  final Offset position;
  final Function(CodeSuggestion) onSelect;

  const AutocompleteOverlay({
    super.key,
    required this.suggestions,
    required this.position,
    required this.onSelect,
  });

  @override
  State<AutocompleteOverlay> createState() => _AutocompleteOverlayState();
}

class _AutocompleteOverlayState extends State<AutocompleteOverlay> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(4),
        color: const Color(0xFF252526),
        child: Container(
          width: 300,
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF3C3C3C)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.suggestions.length,
            itemBuilder: (ctx, i) {
              final suggestion = widget.suggestions[i];
              final isSelected = i == _selectedIndex;

              return InkWell(
                onTap: () => widget.onSelect(suggestion),
                onHover: (hovering) {
                  if (hovering) setState(() => _selectedIndex = i);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: isSelected ? const Color(0xFF094771) : Colors.transparent,
                  child: Row(
                    children: [
                      Icon(suggestion.icon, size: 16, color: _getTypeColor(suggestion.type)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion.label,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            if (suggestion.detail != null)
                              Text(
                                suggestion.detail!,
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _getTypeLabel(suggestion.type),
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(SuggestionType type) {
    switch (type) {
      case SuggestionType.keyword: return const Color(0xFFC586C0);
      case SuggestionType.classType: return const Color(0xFF4EC9B0);
      case SuggestionType.function: return const Color(0xFFDCDCAA);
      case SuggestionType.variable: return const Color(0xFF9CDCFE);
      case SuggestionType.property: return const Color(0xFF9CDCFE);
      case SuggestionType.snippet: return const Color(0xFFCE9178);
    }
  }

  String _getTypeLabel(SuggestionType type) {
    switch (type) {
      case SuggestionType.keyword: return 'keyword';
      case SuggestionType.classType: return 'class';
      case SuggestionType.function: return 'function';
      case SuggestionType.variable: return 'variable';
      case SuggestionType.property: return 'property';
      case SuggestionType.snippet: return 'snippet';
    }
  }
}
