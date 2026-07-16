import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../database/database_helper.dart';
import '../models/employee.dart';

/// Handles employee authentication and secure persistence of the
/// logged-in session. Passwords are never stored in plaintext.
class AuthRepository {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

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

    await _secureStorage.write(
        key: AppConstants.keyEmployeeId, value: employee.employeeId);
    await _secureStorage.write(
        key: AppConstants.keyEmployeeName, value: employee.employeeName);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.prefLoggedInEmployeeId, employee.employeeId);

    return employee;
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: AppConstants.keyEmployeeId);
    await _secureStorage.delete(key: AppConstants.keyEmployeeName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefLoggedInEmployeeId);
  }

  Future<Employee?> currentSession() async {
    final employeeId = await _secureStorage.read(key: AppConstants.keyEmployeeId);
    if (employeeId == null) return null;
    return DatabaseHelper.instance.getEmployeeById(employeeId);
  }
}
