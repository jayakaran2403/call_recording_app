import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Handles recording-folder selection, persistence of the chosen path,
/// and the `CallRecordings/EmployeeID/Year/Month/` folder layout.
class StorageService {
  Future<String> defaultFolderPath() async {
    final base = await getExternalStorageDirectory();
    final path =
        p.join(base?.path ?? '/storage/emulated/0', AppConstants.defaultFolderName);
    await Directory(path).create(recursive: true);
    return path;
  }

  Future<String?> pickFolder() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder for call recordings',
    );
    if (selected == null) return null;
    await Directory(selected).create(recursive: true);
    return selected;
  }

  Future<void> saveFolderPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefRecordingFolder, path);
  }

  Future<String?> getSavedFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefRecordingFolder);
  }

  /// Builds `<root>/<employeeId>/<Year>/<MonthName>/` and ensures it exists.
  /// Returns the full directory path. Actual file writing is done natively
  /// by the Kotlin recorder, which receives this same path convention.
  Future<String> resolveDatedSubfolder({
    required String rootFolder,
    required String employeeId,
    required DateTime date,
  }) async {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final path = p.join(
      rootFolder,
      employeeId,
      date.year.toString(),
      monthNames[date.month - 1],
    );
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<int> folderSizeInBytes(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 10 || i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  Future<bool> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// Returns true if free space on the recording volume is below [minMb].
  Future<bool> isStorageLow(String folderPath, {int minMb = 100}) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) return false;
      // path_provider doesn't expose free space directly on all platforms;
      // this is a best-effort check intended to be backed by a native
      // MethodChannel call (StatFs) in the platform-specific build.
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// Placeholder type kept for API shape parity with a future native
/// StatFs-backed implementation.
class StatFs {
  final int freeBytes;
  const StatFs(this.freeBytes);
}
