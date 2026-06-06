import 'package:flutter/material.dart';

class EditorStatusBar extends StatelessWidget {
  final String? language;
  final String? encoding;
  final String? lineEnding;
  final int? currentLine;
  final int? currentColumn;
  final int? totalLines;
  final bool? isDirty;
  final String? gitBranch;
  final int? gitChanges;
  final int? errors;
  final int? warnings;
  final bool autoSaveEnabled;

  const EditorStatusBar({
    super.key,
    this.language,
    this.encoding,
    this.lineEnding,
    this.currentLine,
    this.currentColumn,
    this.totalLines,
    this.isDirty,
    this.gitBranch,
    this.gitChanges,
    this.errors,
    this.warnings,
    this.autoSaveEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      color: const Color(0xFF007ACC),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
  // Left side
          if (gitBranch != null) ...[
            const Icon(Icons.source, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              gitBranch!,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            if (gitChanges != null && gitChanges! > 0) ...[
              const SizedBox(width: 4),
              Text(
                '($gitChanges)',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
            const SizedBox(width: 16),
          ],
          
          if (errors != null && errors! > 0) ...[
            const Icon(Icons.error, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              errors.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            const SizedBox(width: 12),
          ],
          
          if (warnings != null && warnings! > 0) ...[
            const Icon(Icons.warning, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              warnings.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            const SizedBox(width: 12),
          ],

          const Spacer(),

  // Right side
          if (currentLine != null && currentColumn != null) ...[
            InkWell(
              onTap: () {},
              child: Text(
                'Ln $currentLine, Col $currentColumn',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            const SizedBox(width: 16),
          ],

          if (totalLines != null) ...[
            Text(
              '$totalLines lines',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            const SizedBox(width: 16),
          ],

          if (language != null) ...[
            InkWell(
              onTap: () {},
              child: Text(
                language!.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            const SizedBox(width: 16),
          ],

          if (encoding != null) ...[
            InkWell(
              onTap: () {},
              child: Text(
                encoding!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            const SizedBox(width: 16),
          ],

          if (lineEnding != null) ...[
            InkWell(
              onTap: () {},
              child: Text(
                lineEnding!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            const SizedBox(width: 16),
          ],

          InkWell(
            onTap: () {},
            child: Row(
              children: [
                Icon(
                  autoSaveEnabled ? Icons.check_circle : Icons.cancel,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Auto Save',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          InkWell(
            onTap: () {},
            child: const Icon(Icons.notifications_none, size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}