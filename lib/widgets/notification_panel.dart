import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/os_state.dart';
import '../theme/app_theme.dart';

class NotificationPanel extends StatelessWidget {
  final VoidCallback onClose;
  const NotificationPanel({super.key, required this.onClose});

  Color _typeColor(NotifType t) {
    switch (t) {
      case NotifType.security: return AppTheme.danger;
      case NotifType.network:  return AppTheme.accent;
      case NotifType.warning:  return AppTheme.warning;
      case NotifType.system:   return AppTheme.textSecondary;
    }
  }

  String _typeLabel(NotifType t) {
    switch (t) {
      case NotifType.security: return 'SEC';
      case NotifType.network:  return 'NET';
      case NotifType.warning:  return 'WARN';
      case NotifType.system:   return 'SYS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final os = context.watch<OsState>();
    return Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.97),
        border: Border.all(color: AppTheme.border),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Text('NOTIFICATIONS',
                  style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                const SizedBox(width: 8),
                if (os.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(10)),
                    child: Text('${os.unreadCount}', style: TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: os.markAllRead,
                  child: Text('CLEAR ALL', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 1)),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.keyboard_arrow_up, color: AppTheme.textSecondary, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          if (os.notifications.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Text('No notifications', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: os.notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final n = os.notifications[i];
                  final c = _typeColor(n.type);
                  return Dismissible(
                    key: Key(n.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => os.dismissNotif(n.id),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: AppTheme.danger.withOpacity(0.2),
                      child: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: n.read ? AppTheme.surfaceAlt : c.withOpacity(0.05),
                        border: Border.all(color: n.read ? AppTheme.border : c.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(_typeLabel(n.type),
                              style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(n.body, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                              ],
                            ),
                          ),
                          if (!n.read)
                            Container(width: 6, height: 6,
                              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 200.ms),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
