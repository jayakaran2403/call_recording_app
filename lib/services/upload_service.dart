import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../core/constants.dart';
import '../database/database_helper.dart';
import '../models/recording_metadata.dart';

/// Handles uploading recordings + metadata to the backend once it is
/// available. Designed so the rest of the app (repository/UI) never
/// needs to change when the real endpoint is wired in — only
/// [_baseUrl] and [_uploadEndpoint] need updating.
class UploadService {
  UploadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  static const String _baseUrl = 'https://api.hab-solutions.example.com';
  static const String _uploadEndpoint = '/v1/call-recordings';
  static const int _maxRetries = 5;

  Future<bool> hasConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Uploads a single recording (audio + metadata JSON) as multipart.
  /// Returns true on success. On failure, increments the attempt count
  /// and marks the recording as failed so it can be retried later.
  Future<bool> uploadRecording(RecordingMetadata metadata) async {
    if (metadata.uploadAttempts >= _maxRetries) return false;
    if (!await hasConnectivity()) return false;

    final file = File(metadata.filePath);
    if (!await file.exists()) return false;

    try {
      final formData = FormData.fromMap({
        'metadata': MultipartFile.fromString(
          _jsonEncode(metadata.toUploadJson()),
          filename: '${metadata.id}.json',
        ),
        'audio': await MultipartFile.fromFile(
          metadata.filePath,
          filename: metadata.fileName,
        ),
      });

      final response = await _dio.post(
        '$_baseUrl$_uploadEndpoint',
        data: formData,
        options: Options(
          headers: {'X-Employee-Id': metadata.employeeId},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final success = response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;

      final updated = metadata.copyWith(
        uploadStatus:
            success ? UploadStatus.uploaded : UploadStatus.failed,
        uploadAttempts: metadata.uploadAttempts + 1,
      );
      await DatabaseHelper.instance.updateRecording(updated);
      return success;
    } catch (_) {
      final updated = metadata.copyWith(
        uploadStatus: UploadStatus.failed,
        uploadAttempts: metadata.uploadAttempts + 1,
      );
      await DatabaseHelper.instance.updateRecording(updated);
      return false;
    }
  }

  /// Iterates all pending/failed recordings and retries them when
  /// connectivity is available. Call this from a connectivity listener
  /// or a periodic background task (e.g. WorkManager via a future
  /// native integration).
  Future<void> retryPendingUploads() async {
    if (!await hasConnectivity()) return;
    final pending = await DatabaseHelper.instance.getPendingUploads();
    for (final recording in pending) {
      await uploadRecording(recording);
    }
  }

  String _jsonEncode(Map<String, dynamic> map) {
    // Local minimal encoder avoids importing dart:convert twice across
    // the file; dio also accepts a raw string body here.
    final buffer = StringBuffer('{');
    var first = true;
    map.forEach((key, value) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write('"$key":');
      if (value == null) {
        buffer.write('null');
      } else if (value is num || value is bool) {
        buffer.write(value.toString());
      } else {
        buffer.write('"${value.toString().replaceAll('"', '\\"')}"');
      }
    });
    buffer.write('}');
    return buffer.toString();
  }
}
