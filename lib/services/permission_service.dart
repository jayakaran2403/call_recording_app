import 'package:permission_handler/permission_handler.dart';

/// Result of a single permission request, used to drive the
/// explanation UI when a permission is denied.
class PermissionResult {
  final Permission permission;
  final PermissionStatus status;
  final String label;
  final String rationale;

  const PermissionResult({
    required this.permission,
    required this.status,
    required this.label,
    required this.rationale,
  });

  bool get isGranted => status.isGranted || status.isLimited;
}

/// Requests the permissions required for call recording, one at a time,
/// in the order specified by the product spec.
class PermissionService {
  // Ordered list: (permission, human label, rationale shown on denial)
  static final List<(Permission, String, String)> _requiredPermissions = [
    (
      Permission.microphone,
      'Record Audio',
      'Needed to record business calls for compliance and quality purposes.',
    ),
    (
      Permission.phone,
      'Phone State',
      'Needed to detect when a call starts and ends so recording can be triggered automatically.',
    ),
    (
      Permission.location,
      'Fine Location',
      'Needed to attach the call location to each recording for field verification.',
    ),
    (
      Permission.notification,
      'Notifications',
      'Needed to show the persistent "Recording Active" status while the service runs in the background.',
    ),
  ];

  Future<List<PermissionResult>> requestAll() async {
    final results = <PermissionResult>[];
    for (final (permission, label, rationale) in _requiredPermissions) {
      final status = await permission.request();
      results.add(PermissionResult(
        permission: permission,
        status: status,
        label: label,
        rationale: rationale,
      ));
    }
    return results;
  }

  Future<bool> get allGranted async {
    for (final (permission, _, _) in _requiredPermissions) {
      final status = await permission.status;
      if (!status.isGranted && !status.isLimited) return false;
    }
    return true;
  }

  Future<void> openSettings() => openAppSettings();

  List<(Permission, String, String)> get requiredPermissions =>
      _requiredPermissions;
}
