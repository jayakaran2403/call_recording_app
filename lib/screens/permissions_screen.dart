import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/settings_provider.dart';
import '../services/permission_service.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  List<PermissionResult>? _results;
  bool _requesting = false;

  Future<void> _requestPermissions() async {
    setState(() => _requesting = true);
    final results = await ref.read(permissionServiceProvider).requestAll();
    await ref.read(settingsProvider.notifier).refreshPermissionStatus();
    if (!mounted) return;
    setState(() {
      _results = results;
      _requesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final permissionService = ref.watch(permissionServiceProvider);
    final allGranted =
        _results != null && _results!.every((r) => r.isGranted);

    return Scaffold(
      appBar: AppBar(title: const Text('Required Permissions')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'To record business calls and tag them with location, the app needs the following permissions.',
            style: TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          for (final (permission, label, rationale)
              in permissionService.requiredPermissions)
            _PermissionTile(
              label: label,
              rationale: rationale,
              result: _results == null
                  ? null
                  : _results!.where((r) => r.permission == permission).isEmpty
                      ? null
                      : _results!.firstWhere((r) => r.permission == permission),
            ),
          const SizedBox(height: 12),
          if (_results != null && !allGranted)
            Card(
              color: AppTheme.warningAmber.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Some permissions were denied',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Call recording cannot run without these. Open Settings to grant them manually.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => permissionService.openSettings(),
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Open App Settings'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _requesting ? null : _requestPermissions,
            child: _requesting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(_results == null ? 'Grant Permissions' : 'Re-check Permissions'),
          ),
          const SizedBox(height: 12),
          if (allGranted)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String label;
  final String rationale;
  final PermissionResult? result;

  const _PermissionTile({
    required this.label,
    required this.rationale,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    final granted = result?.isGranted ?? false;
    final requested = result != null;

    return Card(
      child: ListTile(
        leading: Icon(
          granted
              ? Icons.check_circle
              : requested
                  ? Icons.cancel
                  : Icons.radio_button_unchecked,
          color: granted
              ? AppTheme.successGreen
              : requested
                  ? AppTheme.errorRed
                  : Colors.grey,
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(rationale, style: const TextStyle(fontSize: 12.5)),
        isThreeLine: true,
      ),
    );
  }
}

