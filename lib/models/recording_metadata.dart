import '../core/constants.dart';

/// Metadata for a single call recording. Mirrors the JSON schema used
/// for local persistence and the future upload payload.
class RecordingMetadata {
  final String id; // uuid, primary key locally
  final String employeeId;
  final String employeeName;
  final String? phoneNumber;
  final CallType callType;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String fileName;
  final String filePath;
  final UploadStatus uploadStatus;
  final int uploadAttempts;

  const RecordingMetadata({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.phoneNumber,
    required this.callType,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.latitude,
    this.longitude,
    this.address,
    required this.fileName,
    required this.filePath,
    this.uploadStatus = UploadStatus.pending,
    this.uploadAttempts = 0,
  });

  RecordingMetadata copyWith({
    String? phoneNumber,
    DateTime? endTime,
    int? durationSeconds,
    double? latitude,
    double? longitude,
    String? address,
    UploadStatus? uploadStatus,
    int? uploadAttempts,
  }) {
    return RecordingMetadata(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      callType: callType,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      fileName: fileName,
      filePath: filePath,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      uploadAttempts: uploadAttempts ?? this.uploadAttempts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'phoneNumber': phoneNumber,
      'callType': callType == CallType.incoming ? 'Incoming' : 'Outgoing',
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': durationSeconds,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'recordingPath': filePath,
      'fileName': fileName,
      'uploaded': uploadStatus == UploadStatus.uploaded ? 1 : 0,
      'uploadStatus': uploadStatus.name,
      'uploadAttempts': uploadAttempts,
    };
  }

  factory RecordingMetadata.fromMap(Map<String, dynamic> map) {
    return RecordingMetadata(
      id: map['id'] as String,
      employeeId: map['employeeId'] as String,
      employeeName: map['employeeName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String?,
      callType:
          (map['callType'] as String?) == 'Incoming'
              ? CallType.incoming
              : CallType.outgoing,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null
          ? DateTime.tryParse(map['endTime'] as String)
          : null,
      durationSeconds: map['duration'] as int? ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      address: map['address'] as String?,
      fileName: map['fileName'] as String,
      filePath: map['recordingPath'] as String,
      uploadStatus: UploadStatus.values.firstWhere(
        (e) => e.name == (map['uploadStatus'] as String? ?? 'pending'),
        orElse: () => UploadStatus.pending,
      ),
      uploadAttempts: map['uploadAttempts'] as int? ?? 0,
    );
  }

  /// JSON payload shape matching the spec exactly, for future upload.
  Map<String, dynamic> toUploadJson() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'phoneNumber': phoneNumber,
      'callType': callType == CallType.incoming ? 'Incoming' : 'Outgoing',
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': durationSeconds,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'fileName': fileName,
      'filePath': filePath,
      'uploaded': uploadStatus == UploadStatus.uploaded,
    };
  }
}
