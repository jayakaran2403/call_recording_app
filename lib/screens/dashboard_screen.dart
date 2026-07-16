import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/status_card.dart';
import 'folder_selection_screen.dart';
import 'login_screen.dart';
import 'permissions_screen.dart';
import 'recording_history_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final employee = ref.read(authProvider).employee;
      if (employee != null) {
        ref.read(recordingRepositoryProvider).startListening(
              employeeId: employee.employeeId,
              employeeName: employee.employeeName,
            );
      }
    });
  }

  Future<void> _handleToggle(bool value) async {
    final settingsState = ref.read(settingsProvider);

    if (value && settingsState.folderPath == null) {
      final chosen = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const FolderSelectionScreen()),
      );
      if (chosen != true) return;
    }

    if (value && !settingsState.allPermissionsGranted) {
      final granted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PermissionsScreen()),
      );
      if (granted != true) return;
    }

    final ok = await ref.read(settingsProvider.notifier).toggleRecording(value);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grant all required permissions to enable recording.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(authProvider).employee;
    final settings = ref.watch(settingsProvider);
    final activeRecording = ref.watch(activeRecordingProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(settingsProvider.notifier).refreshPermissionStatus();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: AppTheme.primaryBlue,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      child: Text(
                        (employee?.employeeName.isNotEmpty ?? false)
                            ? employee!.employeeName.substring(0, 1).toUpperCase()
                            : 'E',
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee?.employeeName ?? '—',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${employee?.employeeId ?? '—'}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Call Recording',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              settings.recordingEnabled
                                  ? 'Active — listening for calls'
                                  : 'Turned off',
                              style: TextStyle(
                                fontSize: 13,
                                color: settings.recordingEnabled
                                    ? AppTheme.successGreen
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: settings.recordingEnabled,
                          onChanged: _handleToggle,
                        ),
                      ],
                    ),
                    if (activeRecording != null) ...[
                      const Divider(height: 28),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppTheme.errorRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Recording call with ${activeRecording.phoneNumber ?? "unknown number"}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            StatusCard(
              icon: Icons.folder_outlined,
              label: 'Selected Folder',
              value: settings.folderPath ?? 'Not selected',
            ),
            const SizedBox(height: 12),
            StatusCard(
              icon: Icons.verified_user_outlined,
              label: 'Permission Status',
              value: settings.allPermissionsGranted
                  ? 'All permissions granted'
                  : 'Action required',
              valueColor:
                  settings.allPermissionsGranted ? AppTheme.successGreen : AppTheme.errorRed,
            ),
            const SizedBox(height: 12),
            StatusCard(
              icon: Icons.my_location_outlined,
              label: 'Location Status',
              value: settings.allPermissionsGranted ? 'Ready' : 'Permission required',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecordingHistoryScreen()),
              ),
              icon: const Icon(Icons.history_outlined),
              label: const Text('View Recording History'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout, color: AppTheme.errorRed),
              label: const Text('Logout', style: TextStyle(color: AppTheme.errorRed)),
            ),
          ],
        ),
      ),
    );
  }
}
