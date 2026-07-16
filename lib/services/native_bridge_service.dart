import 'dart:async';
import 'package:flutter/services.dart';

import '../core/constants.dart';

/// Event emitted from native Android when a call starts or ends.
class CallEvent {
  final String type; // 'call_started' | 'call_ended'
  final String? phoneNumber;
  final String direction; // 'incoming' | 'outgoing'
  final int timestampMillis;

  CallEvent({
    required this.type,
    required this.phoneNumber,
    required this.direction,
    required this.timestampMillis,
  });

  factory CallEvent.fromMap(Map<dynamic, dynamic> map) {
    return CallEvent(
      type: map['type'] as String,
      phoneNumber: map['phoneNumber'] as String?,
      direction: map['direction'] as String? ?? 'outgoing',
      timestampMillis: map['timestamp'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Bridges Flutter and the native Kotlin foreground service.
///
/// - `serviceChannel`   (method channel): start/stop the foreground service,
///   query its running state, and push the configured save folder to it.
/// - `recordingChannel` (method channel): imperative recorder calls used
///   for testing / manual control (native normally drives this itself
///   from PhoneStateReceiver, but Flutter can query status/duration).
/// - `callChannel`      (event channel): stream of CallEvent objects fired
///   by PhoneStateReceiver as calls start and end.
class NativeBridgeService {
  static const MethodChannel _serviceChannel =
      MethodChannel(AppConstants.serviceChannel);
  static const MethodChannel _recordingChannel =
      MethodChannel(AppConstants.recordingChannel);
  static const EventChannel _callEventChannel =
      EventChannel(AppConstants.callChannel);

  Stream<CallEvent>? _callEventStream;

  /// Stream of call start/end events pushed from PhoneStateReceiver.
  Stream<CallEvent> get callEvents {
    _callEventStream ??= _callEventChannel
        .receiveBroadcastStream()
        .map((event) => CallEvent.fromMap(event as Map));
    return _callEventStream!;
  }

  Future<bool> startForegroundService({required String folderPath}) async {
    try {
      final result = await _serviceChannel.invokeMethod<bool>(
        'startService',
        {'folderPath': folderPath},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> stopForegroundService() async {
    try {
      final result =
          await _serviceChannel.invokeMethod<bool>('stopService');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isServiceRunning() async {
    try {
      final result =
          await _serviceChannel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> updateFolderPath(String folderPath) async {
    try {
      await _serviceChannel
          .invokeMethod('updateFolderPath', {'folderPath': folderPath});
    } on PlatformException {
      // Non-fatal — the service will keep using the previous folder.
    }
  }

  /// Queries whether native reports a recording currently in progress
  /// (useful after an app restart to reconcile UI state).
  Future<bool> isRecordingInProgress() async {
    try {
      final result =
          await _recordingChannel.invokeMethod<bool>('isRecording');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
