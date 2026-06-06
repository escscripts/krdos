import 'package:flutter/material.dart';

class EditorMinimap extends StatelessWidget {
  final String content;
  final ScrollController scrollController;
  final double viewportHeight;

  const EditorMinimap({
    super.key,
    required this.content,
    required this.scrollController,
    required this.viewportHeight,
  });

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final totalLines = lines.length;
    
    return Container(
      width: 80,
      color: const Color(0xFF1E1E1E).withOpacity(0.5),
      child: GestureDetector(
        onTapDown: (details) => _handleTap(details, totalLines),
        onVerticalDragUpdate: (details) => _handleDrag(details, totalLines),
        child: CustomPaint(
          painter: MinimapPainter(
            lines: lines,
            scrollController: scrollController,
            viewportHeight: viewportHeight,
          ),
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details, int totalLines) {
    if (!scrollController.hasClients) return;
    final ratio = details.localPosition.dy / viewportHeight;
    final targetOffset = ratio * scrollController.position.maxScrollExtent;
    scrollController.jumpTo(targetOffset.clamp(0.0, scrollController.position.maxScrollExtent));
  }

  void _handleDrag(DragUpdateDetails details, int totalLines) {
    if (!scrollController.hasClients) return;
    final delta = details.delta.dy;
    final ratio = delta / viewportHeight;
    final targetOffset = scrollController.offset + (ratio * scrollController.position.maxScrollExtent);
    scrollController.jumpTo(targetOffset.clamp(0.0, scrollController.position.maxScrollExtent));
  }
}

class MinimapPainter extends CustomPainter {
  final List<String> lines;
  final ScrollController scrollController;
  final double viewportHeight;

  MinimapPainter({
    required this.lines,
    required this.scrollController,
    required this.viewportHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lineHeight = size.height / lines.length;
    
  // Draw code lines
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      
      final y = i * lineHeight;
      final paint = Paint()
        ..color = _getLineColor(line)
        ..strokeWidth = 1;
      
      canvas.drawLine(
        Offset(10, y),
        Offset(size.width - 10, y),
        paint,
      );
    }
    
  // Draw viewport indicator
    if (scrollController.hasClients) {
      final scrollRatio = scrollController.offset / scrollController.position.maxScrollExtent;
      final viewportRatio = viewportHeight / (lines.length * 21);
      final indicatorTop = scrollRatio * size.height;
      final indicatorHeight = viewportRatio * size.height;
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, indicatorTop, size.width, indicatorHeight),
        const Radius.circular(4),
      );
      
      canvas.drawRRect(
        rect,
        Paint()..color = const Color(0xFF007ACC).withOpacity(0.3),
      );
    }
  }

  Color _getLineColor(String line) {
    final trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('#')) {
      return const Color(0xFF6A9955).withOpacity(0.6);
    }
    if (trimmed.contains('class ') || trimmed.contains('def ') || trimmed.contains('function ')) {
      return const Color(0xFF4EC9B0).withOpacity(0.8);
    }
    return const Color(0xFFD4D4D4).withOpacity(0.5);
  }

  @override
  bool shouldRepaint(MinimapPainter oldDelegate) => true;
}