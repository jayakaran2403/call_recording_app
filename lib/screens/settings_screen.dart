import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'folder_selection_screen.dart';
import 'login_screen.dart';
import 'permissions_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _storageUsage;

  @override
  void initState() {
    super.initState();
    _loadStorageUsage();
  }

  Future<void> _loadStorageUsage() async {
    final settings = ref.read(settingsProvider);
    final storage = ref.read(storageServiceProvider);
    if (settings.folderPath == null) return;
    final bytes = await storage.folderSizeInBytes(settings.folderPath!);
    if (mounted) {
      setState(() => _storageUsage = storage.formatBytes(bytes));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final employee = ref.watch(authProvider).employee;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(employee?.employeeName ?? '—'),
            subtitle: Text('ID: ${employee?.employeeId ?? '—'}'),
          ),
          const Divider(),
          _SectionHeader('Recording'),
          SwitchListTile(
            secondary: const Icon(Icons.fiber_manual_record_outlined),
            title: const Text('Recording ON/OFF'),
            value: settings.recordingEnabled,
            onChanged: (value) async {
              final ok = await ref.read(settingsProvider.notifier).toggleRecording(value);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Grant all permissions first.'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Recording Folder'),
            subtitle: Text(settings.folderPath ?? 'Not selected'),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FolderSelectionScreen()),
              );
              _loadStorageUsage();
            },
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: const Text('Storage Usage'),
            subtitle: Text(_storageUsage ?? 'Calculating…'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadStorageUsage,
            ),
          ),
          const Divider(),
          _SectionHeader('Permissions'),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('View Granted Permissions'),
            subtitle: Text(
              settings.allPermissionsGranted ? 'All permissions granted' : 'Action required',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PermissionsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Open Android Settings'),
            onTap: () => ref.read(permissionServiceProvider).openSettings(),
          ),
          const Divider(),
          _SectionHeader('Session'),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorRed),
            title: const Text('Logout', style: TextStyle(color: AppTheme.errorRed)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
