import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../database/database_helper.dart';
import '../models/employee.dart';

class AuthRepository {
  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();

  Future<Employee?> login(String employeeId, String password) async {
    final existing = await DatabaseHelper.instance.getEmployeeById(employeeId);
    final hashed = _hash(password);

    Employee employee;
    if (existing == null) {
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
