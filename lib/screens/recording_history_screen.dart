import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/recording_metadata.dart';
import '../providers/recording_provider.dart';
import '../widgets/recording_tile.dart';

class RecordingHistoryScreen extends ConsumerStatefulWidget {
  const RecordingHistoryScreen({super.key});

  @override
  ConsumerState<RecordingHistoryScreen> createState() =>
      _RecordingHistoryScreenState();
}

class _RecordingHistoryScreenState
    extends ConsumerState<RecordingHistoryScreen> {
  final _searchController = TextEditingController();
  final _player = AudioPlayer();

  @override
  void dispose() {
    _searchController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(RecordingMetadata recording) async {
    try {
      await _player.setFilePath(recording.filePath);
      await _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to play this recording. The file may be missing.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _share(RecordingMetadata recording) async {
    await Share.shareXFiles(
      [XFile(recording.filePath)],
      text: recording.fileName,
    );
  }

  Future<void> _delete(RecordingMetadata recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recording?'),
        content: const Text('This will permanently remove the audio file and its metadata.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recordingRepositoryProvider).deleteRecording(recording);
    ref.invalidate(recordingHistoryProvider);
  }

  Future<void> _upload(RecordingMetadata recording) async {
    final success = await ref.read(recordingRepositoryProvider).retryUpload(recording);
    ref.invalidate(recordingHistoryProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Upload started successfully.' : 'Upload failed. Will retry automatically.'),
          backgroundColor: success ? AppTheme.successGreen : AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordingsAsync = ref.watch(recordingHistoryProvider);
    final filter = ref.watch(recordingFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recording History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by number, file, or address',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(recordingFilterProvider.notifier).state =
                              filter.copyWith(searchQuery: '');
                        },
                      )
                    : null,
              ),
              onSubmitted: (value) {
                ref.read(recordingFilterProvider.notifier).state =
                    filter.copyWith(searchQuery: value);
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: filter.uploadStatus == null,
                  onSelected: () => ref.read(recordingFilterProvider.notifier).state =
                      filter.copyWith(clearUploadStatus: true),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Pending',
                  selected: filter.uploadStatus == UploadStatus.pending,
                  onSelected: () => ref.read(recordingFilterProvider.notifier).state =
                      filter.copyWith(uploadStatus: UploadStatus.pending),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Uploaded',
                  selected: filter.uploadStatus == UploadStatus.uploaded,
                  onSelected: () => ref.read(recordingFilterProvider.notifier).state =
                      filter.copyWith(uploadStatus: UploadStatus.uploaded),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Failed',
                  selected: filter.uploadStatus == UploadStatus.failed,
                  onSelected: () => ref.read(recordingFilterProvider.notifier).state =
                      filter.copyWith(uploadStatus: UploadStatus.failed),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.date_range_outlined, size: 16),
                  label: const Text('Date'),
                  onPressed: () async {
                    final now = DateTime.now();
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 2),
                      lastDate: now,
                    );
                    if (range != null) {
                      ref.read(recordingFilterProvider.notifier).state = filter.copyWith(
                        fromDate: range.start,
                        toDate: range.end,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: recordingsAsync.when(
              data: (recordings) {
                if (recordings.isEmpty) {
                  return Center(
                    child: Text(
                      'No recordings yet',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: recordings.length,
                  itemBuilder: (context, index) {
                    final recording = recordings[index];
                    return RecordingTile(
                      recording: recording,
                      onPlay: () => _play(recording),
                      onDelete: () => _delete(recording),
                      onShare: () => _share(recording),
                      onUpload: () => _upload(recording),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Failed to load recordings: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.accentBlue,
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryBlue : Colors.black87,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
