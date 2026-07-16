import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../services/native_bridge_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final permissionServiceProvider =
    Provider<PermissionService>((ref) => PermissionService());
final nativeBridgeProvider =
    Provider<NativeBridgeService>((ref) => NativeBridgeService());

class SettingsState {
  final String? folderPath;
  final bool recordingEnabled;
  final bool allPermissionsGranted;
  final bool serviceRunning;

  const SettingsState({
    this.folderPath,
    this.recordingEnabled = false,
    this.allPermissionsGranted = false,
    this.serviceRunning = false,
  });

  SettingsState copyWith({
    String? folderPath,
    bool? recordingEnabled,
    bool? allPermissionsGranted,
    bool? serviceRunning,
  }) {
    return SettingsState(
      folderPath: folderPath ?? this.folderPath,
      recordingEnabled: recordingEnabled ?? this.recordingEnabled,
      allPermissionsGranted:
          allPermissionsGranted ?? this.allPermissionsGranted,
      serviceRunning: serviceRunning ?? this.serviceRunning,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._storage, this._permissions, this._bridge)
      : super(const SettingsState()) {
    _load();
  }

  final StorageService _storage;
  final PermissionService _permissions;
  final NativeBridgeService _bridge;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final folder = await _storage.getSavedFolderPath() ??
        await _storage.defaultFolderPath();
    final granted = await _permissions.allGranted;
    final running = await _bridge.isServiceRunning();
    state = SettingsState(
      folderPath: folder,
      recordingEnabled: prefs.getBool(AppConstants.prefRecordingEnabled) ?? false,
      allPermissionsGranted: granted,
      serviceRunning: running,
    );
  }

  Future<void> setFolder(String path) async {
    await _storage.saveFolderPath(path);
    await _bridge.updateFolderPath(path);
    state = state.copyWith(folderPath: path);
  }

  Future<void> refreshPermissionStatus() async {
    final granted = await _permissions.allGranted;
    state = state.copyWith(allPermissionsGranted: granted);
  }

  Future<bool> toggleRecording(bool enabled) async {
    if (enabled && !state.allPermissionsGranted) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefRecordingEnabled, enabled);

    bool serviceRunning;
    if (enabled) {
      final folder = state.folderPath ?? await _storage.defaultFolderPath();
      serviceRunning = await _bridge.startForegroundService(folderPath: folder);
    } else {
      await _bridge.stopForegroundService();
      serviceRunning = false;
    }

    state = state.copyWith(
      recordingEnabled: enabled,
      serviceRunning: serviceRunning,
    );
    return true;
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(
    ref.watch(storageServiceProvider),
    ref.watch(permissionServiceProvider),
    ref.watch(nativeBridgeProvider),
  );
});
