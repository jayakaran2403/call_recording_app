import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../database/database_helper.dart';
import '../models/employee.dart';

/// Handles employee authentication and persistence of the logged-in
/// session.
///
/// Session state (which employee is currently logged in) is stored via
/// SharedPreferences rather than flutter_secure_storage. The actual
/// password is never stored in plaintext anywhere — only its SHA-256
/// hash lives in the local SQLite database. SharedPreferences here only
/// remembers *which* employee ID is currently signed in, which isn't
/// sensitive on its own, so the extra Android Keystore-backed encryption
/// layer isn't needed for this value and was a source of unreliable
/// hangs on some devices.
class AuthRepository {
  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

  /// Validates credentials against the local employee cache.
  ///
  /// NOTE: In production this should first call the backend auth API and
  /// cache the resulting employee record locally for offline login. The
  /// local-only check below is the offline fallback / dev-mode path.
  Future<Employee?> login(String employeeId, String password) async {
    final existing = await DatabaseHelper.instance.getEmployeeById(employeeId);
    final hashed = _hash(password);

    Employee employee;
    if (existing == null) {
      // First-time login on this device — cache locally.
      // Replace with a real API call before production rollout.
      employee = Employee(
        employeeId: employeeId,
        employeeName: employeeId,
        passwordHash: hashed,
        loginTime: DateTime.now(),
      );
      await DatabaseHelper.instance.upsertEmployee(employee);
    } else {
      if (existing.passwordHash != hashed) return null;
      employee = existing.copyWith(loginTime: DateTime.now());
      await DatabaseHelper.instance.upsertEmployee(employee);
    }

    await _persistSession(employee);
    return employee;
  }

  Future<void> _persistSession(Employee employee) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyEmployeeId, employee.employeeId);
    await prefs.setString(AppConstants.keyEmployeeName, employee.employeeName);
    await prefs.setString(
        AppConstants.prefLoggedInEmployeeId, employee.employeeId);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyEmployeeId);
    await prefs.remove(AppConstants.keyEmployeeName);
    await prefs.remove(AppConstants.prefLoggedInEmployeeId);
  }

  Future<Employee?> currentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final employeeId = prefs.getString(AppConstants.keyEmployeeId);
    if (employeeId == null) return null;
    return DatabaseHelper.instance.getEmployeeById(employeeId);
  }
}
