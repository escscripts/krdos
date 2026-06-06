import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/os_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/grid_painter.dart';
import '../../widgets/status_bar.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final List<Map<String, dynamic>> _users = [
    {'name': 'admin',   'role': 'Administrator', 'status': 'active',   'lastSeen': 'Now',        'devices': 3},
    {'name': 'user01',  'role': 'User',          'status': 'active',   'lastSeen': '2 min ago',  'devices': 1},
    {'name': 'user02',  'role': 'User',          'status': 'inactive', 'lastSeen': '1 hour ago', 'devices': 1},
    {'name': 'powerusr','role': 'Power User',    'status': 'active',   'lastSeen': '5 min ago',  'devices': 2},
  ];

  @override
  Widget build(BuildContext context) {
    final os = context.watch<OsState>();
    final isAdmin = os.role == UserRole.admin;

    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(painter: GridPainter(), child: const SizedBox.expand()),
          Column(
            children: [
              const StatusBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.arrow_back_ios, color: AppTheme.accent, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text('USER MANAGEMENT',
                      style: TextStyle(color: AppTheme.accent, fontSize: 14,
                        fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const Spacer(),
                    if (isAdmin)
                      GestureDetector(
                        onTap: () => _showAddUser(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.accentDim,
                            border: Border.all(color: AppTheme.accent),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: AppTheme.accent, size: 14),
                              SizedBox(width: 4),
                              Text('ADD USER', style: TextStyle(color: AppTheme.accent,
                                fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!isAdmin)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    border: Border.all(color: AppTheme.warning),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: AppTheme.warning, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Read-only access. Connect to admin device via USB to manage users.',
                          style: TextStyle(color: AppTheme.warning, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (_, i) => _UserCard(
                    user: _users[i],
                    isAdmin: isAdmin,
                    onRoleChange: (role) => setState(() => _users[i]['role'] = role),
                    onDelete: () => setState(() => _users.removeAt(i)),
                  ).animate(delay: Duration(milliseconds: i * 60))
                    .fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddUser(BuildContext context) {
    final nameCtrl = TextEditingController();
    String role = 'User';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: AppTheme.surfaceAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ADD USER', style: TextStyle(color: AppTheme.accent,
                  fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 16),
                _inputField('Username', nameCtrl),
                const SizedBox(height: 12),
                Text('Role', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                ...['User', 'Power User'].map((r) => GestureDetector(
                  onTap: () => setS(() => role = r),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: role == r ? AppTheme.accentDim : AppTheme.surface,
                      border: Border.all(color: role == r ? AppTheme.accent : AppTheme.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(r, style: TextStyle(
                      color: role == r ? AppTheme.accent : AppTheme.textPrimary, fontSize: 12)),
                  ),
                )),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: _dialogBtn('CANCEL', AppTheme.textSecondary, false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setState(() => _users.add({
                            'name': nameCtrl.text.trim(),
                            'role': role,
                            'status': 'inactive',
                            'lastSeen': 'Never',
                            'devices': 0,
                          }));
                          Navigator.pop(context);
                        },
                        child: _dialogBtn('CREATE', AppTheme.accent, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(String hint, TextEditingController ctrl) => Container(
    decoration: BoxDecoration(
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: TextField(
      controller: ctrl,
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      cursorColor: AppTheme.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textSecondary),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  );

  Widget _dialogBtn(String label, Color color, bool filled) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: filled ? color.withOpacity(0.15) : Colors.transparent,
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
  );
}

class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isAdmin;
  final ValueChanged<String> onRoleChange;
  final VoidCallback onDelete;
  const _UserCard({required this.user, required this.isAdmin,
    required this.onRoleChange, required this.onDelete});
  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _expanded = false;

  Color get _statusColor => widget.user['status'] == 'active' ? AppTheme.accent : AppTheme.textSecondary;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      border: Border.all(color: _statusColor.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person, color: _statusColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u['name'], style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('${u['role']} Ãƒ - šÃ‚ |  ${u['devices']} device(s)',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(u['status'].toUpperCase(),
                      style: TextStyle(color: _statusColor, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary, size: 16),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppTheme.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row('Last Seen', u['lastSeen']),
                  _row('Devices', '${u['devices']}'),
                  _row('Role', u['role']),
                  if (widget.isAdmin && u['name'] != 'admin') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _actionBtn('SET POWER USER', AppTheme.warning,
                          () => widget.onRoleChange('Power User'))),
                        const SizedBox(width: 8),
                        Expanded(child: _actionBtn('SET USER', AppTheme.accent,
                          () => widget.onRoleChange('User'))),
                        const SizedBox(width: 8),
                        Expanded(child: _actionBtn('REMOVE', AppTheme.danger, widget.onDelete)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text('$label: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
      ],
    ),
  );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    ),
  );
}

