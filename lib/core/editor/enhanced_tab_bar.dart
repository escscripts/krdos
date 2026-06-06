import 'package:flutter/material.dart';

class EditorTabData {
  final String tabId;
  final String fileName;
  final String filePath;
  final bool isDirty;
  final IconData icon;
  final Color iconColor;

  EditorTabData({
    required this.tabId,
    required this.fileName,
    required this.filePath,
    required this.isDirty,
    required this.icon,
    required this.iconColor,
  });
}

class EnhancedTabBar extends StatefulWidget {
  final List<EditorTabData> tabs;
  final String? activeTabId;
  final Function(String) onTabSelected;
  final Function(String) onTabClose;
  final Function(String)? onTabContextMenu;

  const EnhancedTabBar({
    super.key,
    required this.tabs,
    this.activeTabId,
    required this.onTabSelected,
    required this.onTabClose,
    this.onTabContextMenu,
  });

  @override
  State<EnhancedTabBar> createState() => _EnhancedTabBarState();
}

class _EnhancedTabBarState extends State<EnhancedTabBar> {
  String? _hoveredTabId;

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 35,
      color: const Color(0xFF2D2D30),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.tabs.length,
              itemBuilder: (ctx, i) => _buildTab(widget.tabs[i]),
            ),
          ),
          _buildTabActions(),
        ],
      ),
    );
  }

  Widget _buildTab(EditorTabData tab) {
    final isActive = tab.tabId == widget.activeTabId;
    final isHovered = tab.tabId == _hoveredTabId;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTabId = tab.tabId),
      onExit: (_) => setState(() => _hoveredTabId = null),
      child: GestureDetector(
        onSecondaryTap: () => _showContextMenu(tab),
        child: InkWell(
          onTap: () => widget.onTabSelected(tab.tabId),
          child: Container(
            constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF1E1E1E)
                  : isHovered
                      ? const Color(0xFF2A2D2E)
                      : Colors.transparent,
              border: Border(
                top: BorderSide(
                  color: isActive ? const Color(0xFF007ACC) : Colors.transparent,
                  width: 2,
                ),
                right: const BorderSide(color: Color(0xFF252526), width: 1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tab.icon, size: 16, color: tab.iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tab.fileName + (tab.isDirty ? ' ?' : ''),
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                if (isHovered || isActive)
                  InkWell(
                    onTap: () => widget.onTabClose(tab.tabId),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: isActive ? Colors.white70 : Colors.white54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 16),
            color: Colors.white70,
            onPressed: _showTabListMenu,
            tooltip: 'Show Opened Editors',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.splitscreen, size: 16),
            color: Colors.white70,
            onPressed: () {},
            tooltip: 'Split Editor',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(EditorTabData tab) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 100, 100),
      color: const Color(0xFF252526),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      items: <PopupMenuEntry>[
        _buildContextMenuItem('Close', Icons.close, () => widget.onTabClose(tab.tabId)),
        _buildContextMenuItem('Close Others', Icons.close_fullscreen, () {}),
        _buildContextMenuItem('Close All', Icons.clear_all, () {}),
        const PopupMenuDivider(),
        _buildContextMenuItem('Split Right', Icons.vertical_split, () {}),
        _buildContextMenuItem('Split Down', Icons.horizontal_split, () {}),
        const PopupMenuDivider(),
        _buildContextMenuItem('Copy Path', Icons.content_copy, () {}),
        _buildContextMenuItem('Reveal in Explorer', Icons.folder_open, () {}),
      ],
    );
  }

  PopupMenuEntry _buildContextMenuItem(String label, IconData icon, VoidCallback onTap) {
    return PopupMenuItem(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  void _showTabListMenu() {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        35,
        0,
        0,
      ),
      color: const Color(0xFF252526),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      items: widget.tabs.map<PopupMenuEntry>((tab) {
        return PopupMenuItem(
          onTap: () => widget.onTabSelected(tab.tabId),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(tab.icon, size: 16, color: tab.iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tab.fileName,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tab.isDirty)
                const Icon(Icons.circle, size: 8, color: Colors.white70),
            ],
          ),
        );
      }).toList(),
    );
  }
}
