/// App-wide constants shared across layers.
class AppConstants {
  AppConstants._();

  static const String appName = 'Employee Call Recorder';

  // Method channel names — must match the native Kotlin side exactly.
  static const String callChannel = 'com.hab.callrecorder/call_events';
  static const String recordingChannel = 'com.hab.callrecorder/recording';
  static const String serviceChannel = 'com.hab.callrecorder/service';

  // Secure storage keys
  static const String keyEmployeeId = 'employee_id';
  static const String keyEmployeeName = 'employee_name';
  static const String keyAuthToken = 'auth_token';

  // Shared preferences keys
  static const String prefRecordingFolder = 'recording_folder_path';
  static const String prefRecordingEnabled = 'recording_enabled';
  static const String prefLoggedInEmployeeId = 'logged_in_employee_id';

  // Database
  static const String dbName = 'call_recorder.db';
  static const int dbVersion = 1;
  static const String tableEmployee = 'employee';
  static const String tableRecordings = 'recordings';

  // Default folder (relative to app-scoped external storage)
  static const String defaultFolderName = 'CallRecordings';

  // Recording file name pattern: EmployeeID_YYYYMMDD_HHMMSS.mp3
  static String buildFileName(String employeeId, DateTime start) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date =
        '${start.year}${two(start.month)}${two(start.day)}';
    final time = '${two(start.hour)}${two(start.minute)}${two(start.second)}';
    return '${employeeId}_${date}_$time.mp3';
  }
}

enum CallType { incoming, outgoing }

enum UploadStatus { pending, uploading, uploaded, failed }
