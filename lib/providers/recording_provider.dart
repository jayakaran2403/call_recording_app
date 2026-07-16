import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/recording_metadata.dart';
import '../repository/recording_repository.dart';

final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  final repo = RecordingRepository();
  ref.onDispose(repo.stopListening);
  return repo;
});

/// Emits the currently in-progress recording, or null when idle.
final activeRecordingProvider = StreamProvider<RecordingMetadata?>((ref) {
  final repo = ref.watch(recordingRepositoryProvider);
  return repo.activeRecordingStream;
});

class RecordingFilter {
  final String? employeeId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final UploadStatus? uploadStatus;
  final String? searchQuery;

  const RecordingFilter({
    this.employeeId,
    this.fromDate,
    this.toDate,
    this.uploadStatus,
    this.searchQuery,
  });

  RecordingFilter copyWith({
    String? employeeId,
    DateTime? fromDate,
    DateTime? toDate,
    UploadStatus? uploadStatus,
    String? searchQuery,
    bool clearUploadStatus = false,
    bool clearDates = false,
  }) {
    return RecordingFilter(
      employeeId: employeeId ?? this.employeeId,
      fromDate: clearDates ? null : fromDate ?? this.fromDate,
      toDate: clearDates ? null : toDate ?? this.toDate,
      uploadStatus:
          clearUploadStatus ? null : uploadStatus ?? this.uploadStatus,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final recordingFilterProvider =
    StateProvider<RecordingFilter>((ref) => const RecordingFilter());

final recordingHistoryProvider =
    FutureProvider.autoDispose<List<RecordingMetadata>>((ref) async {
  final repo = ref.watch(recordingRepositoryProvider);
  final filter = ref.watch(recordingFilterProvider);
  return repo.getRecordings(
    employeeId: filter.employeeId,
    fromDate: filter.fromDate,
    toDate: filter.toDate,
    uploadStatus: filter.uploadStatus,
    searchQuery: filter.searchQuery,
  );
});
