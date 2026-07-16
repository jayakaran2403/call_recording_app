import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/settings_provider.dart';

class FolderSelectionScreen extends ConsumerStatefulWidget {
  const FolderSelectionScreen({super.key});

  @override
  ConsumerState<FolderSelectionScreen> createState() =>
      _FolderSelectionScreenState();
}

class _FolderSelectionScreenState
    extends ConsumerState<FolderSelectionScreen> {
  bool _picking = false;

  Future<void> _pickFolder() async {
    setState(() => _picking = true);
    final storage = ref.read(storageServiceProvider);
    final path = await storage.pickFolder();
    if (path != null) {
      await ref.read(settingsProvider.notifier).setFolder(path);
    }
    if (mounted) setState(() => _picking = false);
  }

  Future<void> _useDefault() async {
    final storage = ref.read(storageServiceProvider);
    final path = await storage.defaultFolderPath();
    await ref.read(settingsProvider.notifier).setFolder(path);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Recording Folder')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose where call recordings should be saved on this device. '
              'Recordings are automatically organized into '
              'EmployeeID / Year / Month subfolders.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.folder_outlined, color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        settings.folderPath ?? 'No folder selected',
                        style: const TextStyle(fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _picking ? null : _pickFolder,
              icon: const Icon(Icons.drive_folder_upload_outlined),
              label: const Text('Choose Custom Folder'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _useDefault,
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Use Default (Documents/CallRecordings)'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: settings.folderPath == null
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
