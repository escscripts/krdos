import 'package:flutter/material.dart';

class EditorBreadcrumb extends StatelessWidget {
  final String filePath;
  final Function(String)? onPathClick;

  const EditorBreadcrumb({
    super.key,
    required this.filePath,
    this.onPathClick,
  });

  @override
  Widget build(BuildContext context) {
    if (filePath.isEmpty) {
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: const Color(0xFF252526),
        alignment: Alignment.centerLeft,
        child: const Text(
          'Untitled',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
    }

    final parts = filePath.split('/').where((p) => p.isNotEmpty).toList();
    
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF252526),
      child: Row(
        children: [
          const Icon(Icons.folder_open, size: 14, color: Color(0xFFDCB67A)),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: parts.length,
              separatorBuilder: (ctx, i) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right, size: 14, color: Colors.white38),
              ),
              itemBuilder: (ctx, i) {
                final isLast = i == parts.length - 1;
                final path = '/${parts.sublist(0, i + 1).join('/')}';
                
                return InkWell(
                  onTap: () => onPathClick?.call(path),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      parts[i],
                      style: TextStyle(
                        color: isLast ? Colors.white : Colors.white60,
                        fontSize: 12,
                        fontWeight: isLast ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
