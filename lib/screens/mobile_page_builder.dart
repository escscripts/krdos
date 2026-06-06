import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/os_state.dart';
import '../core/mobile_home_manager.dart';
import '../core/filesystem/vfs.dart';
import '../theme/app_theme.dart';

class MobilePageBuilder {
  static Widget buildPage({
    required BuildContext context,
    required int pageIndex,
    required bool isTablet,
    required int totalPages,
    required String time,
    required String date,
    required MobileHomeManager manager,
    required bool editMode,
    required VoidCallback onToggleEditMode,
    required Function(int) onRemovePage,
    required VoidCallback onAddPage,
    required Function(int fromPage, int fromIndex, int toPage, int toIndex)
    onMoveItem,
    required Function(int pageIndex, int itemIndex) onRemoveItem,
    required Function(MobileHomeItem, int) buildDraggableItem,
  }) {
    final clockSize = isTablet ? 38.0 : 32.0;
    final cols = isTablet ? 5 : 4;
    final rows = isTablet ? 6 : 6;
    final maxItems = cols * rows;
    final pageItems = manager.getPage(pageIndex);
    final isFirstPage = pageIndex == 0;

    return Column(
      children: [
  // Clock and status chips - ONLY on first page
        if (isFirstPage) ...[
          const SizedBox(height: 12),
          Text(
            time,
            style: TextStyle(
              color: Colors.white,
              fontSize: clockSize,
              fontWeight: FontWeight.w200,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 6),
          Consumer<OsState>(
            builder: (_, os, __) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MiniChip(
                  'NET',
                  os.wifiEnabled ? 'ON' : 'OFF',
                  os.wifiEnabled ? AppTheme.accent : AppTheme.danger,
                ),
                const SizedBox(width: 4),
                _MiniChip(
                  'FW',
                  os.firewallEnabled ? 'ON' : 'OFF',
                  os.firewallEnabled ? AppTheme.accent : AppTheme.danger,
                ),
                const SizedBox(width: 4),
                _MiniChip(
                  'VPN',
                  os.vpnEnabled ? 'ON' : 'OFF',
                  os.vpnEnabled ? AppTheme.accent : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ] else ...[
          const SizedBox(height: 20),
        ],

  // Edit mode banner
        if (editMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            margin: const EdgeInsets.only(bottom: 8, left: 20, right: 20),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              border: Border.all(color: AppTheme.accent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, color: AppTheme.accent, size: 11),
                const SizedBox(width: 5),
                Text(
                  'Hold at edge to switch pages',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

  // App grid - FREE POSITIONING (wrap each item in Positioned)
        Expanded(
          child: GestureDetector(
            onLongPress: () => onToggleEditMode(),
            behavior: HitTestBehavior.translucent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / cols;
                  final cellHeight = constraints.maxHeight / rows;

                  return Stack(
                    children: [
  // Show grid in edit mode
                      if (editMode)
                        ...List.generate(maxItems, (i) {
                          final col = i % cols;
                          final row = i ~/ cols;
                          return Positioned(
                            left: col * cellWidth,
                            top: row * cellHeight,
                            width: cellWidth,
                            height: cellHeight,
                            child: DragTarget<Map<String, dynamic>>(
                              onWillAcceptWithDetails: (details) => true,
                              onAcceptWithDetails: (details) {
                                final data = details.data;
                                final fromIndex = data['index'] as int;
                                final fromPage = data['pageIndex'] as int;
                                onMoveItem(fromPage, fromIndex, pageIndex, i);
                              },
                              builder: (context, candidateData, rejectedData) {
                                final isHovering = candidateData.isNotEmpty;
                                return Container(
                                  margin: const EdgeInsets.all(1),
                                  decoration: BoxDecoration(
                                    color: isHovering
                                        ? AppTheme.accent.withValues(
                                            alpha: 0.15,
                                          )
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isHovering
                                          ? AppTheme.accent.withValues(
                                              alpha: 0.6,
                                            )
                                          : AppTheme.border.withValues(
                                              alpha: 0.1,
                                            ),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: isHovering
                                      ? Center(
                                          child: Icon(
                                            Icons.add_circle_outline,
                                            color: AppTheme.accent.withValues(
                                              alpha: 0.6,
                                            ),
                                            size: 20,
                                          ),
                                        )
                                      : null,
                                );
                              },
                            ),
                          );
                        }),

  // Actual apps - positioned freely
                      ...pageItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final col = index % cols;
                        final row = index ~/ cols;

                        return Positioned(
                          left: col * cellWidth,
                          top: row * cellHeight,
                          width: cellWidth,
                          height: cellHeight,
                          child: Center(
                            child: SizedBox(
                              width: cellWidth * 0.85,
                              height: cellHeight * 0.85,
                              child: buildDraggableItem(item, index),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

  // Page management - ONLY in edit mode
        if (editMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (totalPages > 1)
                  GestureDetector(
                    onTap: () => onRemovePage(pageIndex),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.15),
                        border: Border.all(color: AppTheme.danger),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.remove_circle_outline,
                            color: AppTheme.danger,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Remove Page',
                            style: TextStyle(
                              color: AppTheme.danger,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onAddPage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      border: Border.all(color: AppTheme.accent),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: AppTheme.accent,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Add Page',
                          style: TextStyle(color: AppTheme.accent, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

  // Done button - ONLY in edit mode
        if (editMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: onToggleEditMode,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

        if (!editMode) const SizedBox(height: 8),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.surfaceAlt,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 7),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 7,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}