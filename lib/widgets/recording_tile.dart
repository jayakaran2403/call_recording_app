import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/recording_metadata.dart';
import '../utils/formatters.dart';

class RecordingTile extends StatelessWidget {
  final RecordingMetadata recording;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onUpload;

  const RecordingTile({
    super.key,
    required this.recording,
    required this.onPlay,
    required this.onDelete,
    required this.onShare,
    required this.onUpload,
  });

  Color _statusColor() {
    switch (recording.uploadStatus) {
      case UploadStatus.uploaded:
        return AppTheme.successGreen;
      case UploadStatus.uploading:
        return AppTheme.secondaryBlue;
      case UploadStatus.failed:
        return AppTheme.errorRed;
      case UploadStatus.pending:
        return AppTheme.warningAmber;
    }
  }

  String _statusLabel() {
    switch (recording.uploadStatus) {
      case UploadStatus.uploaded:
        return 'Uploaded';
      case UploadStatus.uploading:
        return 'Uploading';
      case UploadStatus.failed:
        return 'Failed';
      case UploadStatus.pending:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  recording.callType == CallType.incoming
                      ? Icons.call_received
                      : Icons.call_made,
                  size: 18,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recording.phoneNumber ?? 'Unknown number',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                        fontSize: 11, color: _statusColor(), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${Formatters.date(recording.startTime)} • ${Formatters.time(recording.startTime)} • ${Formatters.duration(recording.durationSeconds)}',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            if (recording.address != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      recording.address!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_circle_outline, size: 22),
                  color: AppTheme.primaryBlue,
                  onPressed: onPlay,
                  tooltip: 'Play',
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share_outlined, size: 20),
                  onPressed: onShare,
                  tooltip: 'Share',
                ),
                if (recording.uploadStatus != UploadStatus.uploaded)
                  IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                    onPressed: onUpload,
                    tooltip: 'Upload',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppTheme.errorRed,
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
