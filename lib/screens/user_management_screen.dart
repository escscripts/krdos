import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_manager.dart';
import '../core/auth/user_account.dart';
import '../theme/app_theme.dart';
import '../widgets/add_user_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  /// When true, hides the app bar back button  for embedding inside Settings.
  final bool embedded;

  const UserManagementScreen({super.key, this.embedded = false});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  UserAccount? _selectedUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: AppTheme.surface,
              elevation: 0,
              title: Text('Users & Accounts', style: TextStyle(color: AppTheme.textPrimary)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: Consumer<AuthManager>(
        builder: (context, authManager, _) {
          return Row(
            children: [
              _buildUserList(authManager),
              Expanded(child: _buildUserDetails(authManager)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserList(AuthManager authManager) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddUserDialog(authManager),
              icon: const Icon(Icons.add),
              label: Text('Add User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: authManager.accounts.length,
              itemBuilder: (context, index) {
                final user = authManager.accounts[index];
                final isSelected = _selectedUser?.id == user.id;
                final isCurrent = authManager.currentUser?.id == user.id;
                
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: AppTheme.surfaceAlt,
                  leading: _buildAvatar(user),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.fullName,
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Current',
                            style: TextStyle(fontSize: 10, color: AppTheme.accent),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    user.accountType.name,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  onTap: () => setState(() => _selectedUser = user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserAccount user) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accent.withValues(alpha: 0.2),
      ),
      child: Icon(
        user.accountType == UserAccountType.administrator
            ? Icons.admin_panel_settings
            : user.accountType == UserAccountType.guest
                ? Icons.person_outline
                : Icons.person,
        color: AppTheme.accent,
        size: 20,
      ),
    );
  }

  Widget _buildUserDetails(AuthManager authManager) {
    if (_selectedUser == null) {
      return const Center(
        child: Text(
          'Select a user to view details',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final isCurrent = authManager.currentUser?.id == _selectedUser!.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.2),
                ),
                child: Icon(
                  _selectedUser!.accountType == UserAccountType.administrator
                      ? Icons.admin_panel_settings
                      : _selectedUser!.accountType == UserAccountType.guest
                          ? Icons.person_outline
                          : Icons.person,
                  color: AppTheme.accent,
                  size: 40,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedUser!.fullName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedUser!.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildInfoSection('Account Information', [
            _buildInfoRow('Username', _selectedUser!.username),
            _buildInfoRow('Account Type', _selectedUser!.accountType.name.toUpperCase()),
            _buildInfoRow('Created', _formatDate(_selectedUser!.createdAt)),
            _buildInfoRow('Last Login', _formatDate(_selectedUser!.lastLogin)),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('Security', [
            _buildSwitchRow(
              'Biometric Authentication',
              _selectedUser!.biometricEnabled,
              (value) => _updateBiometric(authManager, value),
            ),
            _buildSwitchRow(
              'PIN Enabled',
              _selectedUser!.pin != null,
              null,
            ),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('Registered Devices', [
            ..._selectedUser!.devices.map((device) => _buildDeviceCard(device)),
          ]),
          const SizedBox(height: 32),
          if (!isCurrent) ...[
            ElevatedButton.icon(
              onPressed: () => _showDeleteConfirmation(authManager),
              icon: const Icon(Icons.delete),
              label: Text('Delete User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, Function(bool)? onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(RegisteredDevice device) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Icon(_getDeviceIcon(device.deviceType), color: AppTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.deviceName, style: TextStyle(color: AppTheme.textPrimary)),
                Text(
                  'Last seen: ${_formatDate(device.lastSeen)}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (device.isTrusted)
            const Icon(Icons.verified, color: AppTheme.success, size: 20),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.desktop:
        return Icons.computer;
      case DeviceType.laptop:
        return Icons.laptop;
      case DeviceType.mobile:
        return Icons.phone_android;
      case DeviceType.tablet:
        return Icons.tablet;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _updateBiometric(AuthManager authManager, bool value) async {
    await authManager.enableBiometric(value);
    setState(() => _selectedUser = authManager.accounts.firstWhere((u) => u.id == _selectedUser!.id));
  }

  void _showDeleteConfirmation(AuthManager authManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete User', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete ${_selectedUser!.fullName}? This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              authManager.deleteAccount(_selectedUser!.id);
              Navigator.pop(context);
              setState(() => _selectedUser = null);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(AuthManager authManager) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddUserDialog(authManager: authManager),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User created successfully')),
      );
    }
  }
}