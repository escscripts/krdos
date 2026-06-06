import 'package:flutter/material.dart';

class EditorGutter extends StatelessWidget {
  final int lineCount;
  final double lineHeight;
  final Set<int> breakpoints;
  final int? currentLine;
  final Function(int)? onLineClick;

  const EditorGutter({
    super.key,
    required this.lineCount,
    this.lineHeight = 21.0,
    this.breakpoints = const {},
    this.currentLine,
    this.onLineClick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      color: const Color(0xFF1E1E1E),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: lineCount,
        itemBuilder: (context, index) {
          final lineNumber = index + 1;
          final isBreakpoint = breakpoints.contains(lineNumber);
          final isCurrent = currentLine == lineNumber;

          return InkWell(
            onTap: () => onLineClick?.call(lineNumber),
            child: Container(
              height: lineHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: isCurrent ? const Color(0xFF2A2D2E) : null,
              child: Row(
                children: [
                  if (isBreakpoint)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE51400),
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lineNumber.toString(),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFF858585),
                        fontSize: 13,
                        fontFamily: 'monospace',
                        height: 1.5,
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
}
