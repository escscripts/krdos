import 'package:flutter/material.dart';

enum ActivityBarView {
  explorer,
  search,
  sourceControl,
  debug,
  extensions,
  settings,
}

class ActivityBarItem {
  final ActivityBarView view;
  final IconData icon;
  final String label;
  final String? badge;

  ActivityBarItem({
    required this.view,
    required this.icon,
    required this.label,
    this.badge,
  });
}

class ActivityBar extends StatelessWidget {
  final ActivityBarView selectedView;
  final Function(ActivityBarView) onViewChanged;
  final Map<ActivityBarView, String>? badges;

  const ActivityBar({
    super.key,
    required this.selectedView,
    required this.onViewChanged,
    this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ActivityBarItem(
        view: ActivityBarView.explorer,
        icon: Icons.folder_copy_outlined,
        label: 'Explorer',
      ),
      ActivityBarItem(
        view: ActivityBarView.search,
        icon: Icons.search,
        label: 'Search',
      ),
      ActivityBarItem(
        view: ActivityBarView.sourceControl,
        icon: Icons.source,
        label: 'Source Control',
        badge: badges?[ActivityBarView.sourceControl],
      ),
      ActivityBarItem(
        view: ActivityBarView.debug,
        icon: Icons.bug_report_outlined,
        label: 'Run and Debug',
      ),
      ActivityBarItem(
        view: ActivityBarView.extensions,
        icon: Icons.extension_outlined,
        label: 'Extensions',
      ),
    ];

    return Container(
      width: 48,
      color: const Color(0xFF333333),
      child: Column(
        children: [
          ...items.map((item) => _buildActivityBarItem(item)),
          const Spacer(),
          _buildActivityBarItem(
            ActivityBarItem(
              view: ActivityBarView.settings,
              icon: Icons.settings_outlined,
              label: 'Settings',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBarItem(ActivityBarItem item) {
    final isSelected = selectedView == item.view;

    return Tooltip(
      message: item.label,
      preferBelow: false,
      child: InkWell(
        onTap: () => onViewChanged(item.view),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2D2D30) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? const Color(0xFF007ACC) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                item.icon,
                color: isSelected ? Colors.white : const Color(0xFFCCCCCC),
                size: 24,
              ),
              if (item.badge != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF007ACC),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      item.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
