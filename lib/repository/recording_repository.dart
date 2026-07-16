import 'dart:async';

import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../database/database_helper.dart';
import '../models/recording_metadata.dart';
import '../services/location_service.dart';
import '../services/native_bridge_service.dart';
import '../services/storage_service.dart';
import '../services/upload_service.dart';

/// Central orchestrator that reacts to native call events, captures
/// location, and persists recording metadata. This is the Flutter-side
/// counterpart to the native PhoneStateReceiver + CallRecordingService:
/// native owns the actual audio capture (it must run even if the Dart
/// isolate is suspended), while this repository keeps the local
/// database and UI state in sync whenever the app is in the foreground.
class RecordingRepository {
  RecordingRepository({
    NativeBridgeService? bridge,
    LocationService? locationService,
    StorageService? storageService,
    UploadService? uploadService,
  })  : _bridge = bridge ?? NativeBridgeService(),
        _locationService = locationService ?? LocationService(),
        _storageService = storageService ?? StorageService(),
        _uploadService = uploadService ?? UploadService();

  final NativeBridgeService _bridge;
  final LocationService _locationService;
  final StorageService _storageService;
  final UploadService _uploadService;
  final _uuid = const Uuid();

  StreamSubscription<CallEvent>? _subscription;
  RecordingMetadata? _activeRecording;

  final _activeRecordingController =
      StreamController<RecordingMetadata?>.broadcast();
  Stream<RecordingMetadata?> get activeRecordingStream =>
      _activeRecordingController.stream;

  /// Starts listening to native call events. Call once, after the
  /// foreground service has been started and permissions granted.
  void startListening({
    required String employeeId,
    required String employeeName,
  }) {
    _subscription?.cancel();
    _subscription = _bridge.callEvents.listen((event) async {
      if (event.type == 'call_started') {
        await _onCallStarted(event, employeeId, employeeName);
      } else if (event.type == 'call_ended') {
        await _onCallEnded(event);
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _onCallStarted(
    CallEvent event,
    String employeeId,
    String employeeName,
  ) async {
    final startTime =
        DateTime.fromMillisecondsSinceEpoch(event.timestampMillis);

    // Capture GPS immediately, per spec. If unavailable, proceed without
    // it — recording must not be blocked by a location failure.
    final location = await _locationService.captureCurrentLocation();

    final rootFolder = await _storageService.getSavedFolderPath() ??
        await _storageService.defaultFolderPath();
    final dateFolder = await _storageService.resolveDatedSubfolder(
      rootFolder: rootFolder,
      employeeId: employeeId,
      date: startTime,
    );

    final fileName = AppConstants.buildFileName(employeeId, startTime);
    final filePath = '$dateFolder/$fileName';

    final metadata = RecordingMetadata(
      id: _uuid.v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      phoneNumber: event.phoneNumber,
      callType: event.direction == 'incoming'
          ? CallType.incoming
          : CallType.outgoing,
      startTime: startTime,
      latitude: location?.latitude,
      longitude: location?.longitude,
      address: location?.address,
      fileName: fileName,
      filePath: filePath,
    );

    _activeRecording = metadata;
    _activeRecordingController.add(metadata);
    await DatabaseHelper.instance.insertRecording(metadata);

    // Actual audio capture start/stop is driven natively by
    // CallRecordingService using this same file path convention; the
    // native side already began recording on PHONE_STATE OFFHOOK. This
    // insert just guarantees metadata exists even if the app is killed
    // before call end.
  }

  Future<void> _onCallEnded(CallEvent event) async {
    final active = _activeRecording;
    if (active == null) return;

    final endTime = DateTime.fromMillisecondsSinceEpoch(event.timestampMillis);
    final duration = endTime.difference(active.startTime).inSeconds;

    final updated = active.copyWith(
      endTime: endTime,
      durationSeconds: duration < 0 ? 0 : duration,
    );

    await DatabaseHelper.instance.updateRecording(updated);
    _activeRecording = null;
    _activeRecordingController.add(null);

    // Best-effort immediate upload attempt; falls back to retry queue.
    unawaited(_uploadService.uploadRecording(updated));
  }

  Future<List<RecordingMetadata>> getRecordings({
    String? employeeId,
    DateTime? fromDate,
    DateTime? toDate,
    UploadStatus? uploadStatus,
    String? searchQuery,
  }) {
    return DatabaseHelper.instance.getRecordings(
      employeeId: employeeId,
      fromDate: fromDate,
      toDate: toDate,
      uploadStatus: uploadStatus,
      searchQuery: searchQuery,
    );
  }

  Future<bool> deleteRecording(RecordingMetadata metadata) async {
    await _storageService.deleteFile(metadata.filePath);
    final rows = await DatabaseHelper.instance.deleteRecording(metadata.id);
    return rows > 0;
  }

  Future<bool> retryUpload(RecordingMetadata metadata) {
    return _uploadService.uploadRecording(metadata);
  }

  Future<bool> startService(String folderPath) {
    return _bridge.startForegroundService(folderPath: folderPath);
  }

  Future<bool> stopService() => _bridge.stopForegroundService();

  Future<bool> isServiceRunning() => _bridge.isServiceRunning();
}

void unawaited(Future<void> future) {}
