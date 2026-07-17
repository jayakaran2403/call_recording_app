import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/employee.dart';

class AuthState {
  final Employee? employee;
  final bool isLoading;

  const AuthState({this.employee, this.isLoading = false});

  bool get isLoggedIn => employee != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> restoreSession() async {
    state = const AuthState(isLoading: true);
    try {
      final prefs =
          await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
      final id = prefs.getString(AppConstants.keyEmployeeId);
      if (id == null || id.isEmpty) {
        state = const AuthState(isLoading: false);
        return;
      }
      final name = prefs.getString(AppConstants.keyEmployeeName) ?? id;
      state = AuthState(
        employee: Employee(employeeId: id, employeeName: name, passwordHash: ''),
        isLoading: false,
      );
    } catch (_) {
      state = const AuthState(isLoading: false);
    }
  }

  Future<void> setEmployeeName(String name) async {
    final id = name.trim();
    try {
      final prefs =
          await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
      await prefs.setString(AppConstants.keyEmployeeId, id);
      await prefs.setString(AppConstants.keyEmployeeName, id);
    } catch (_) {
      // Even if persistence fails, still let the employee proceed to the
      // dashboard for this session rather than blocking them.
    }
    state = AuthState(
      employee: Employee(employeeId: id, employeeName: id, passwordHash: ''),
      isLoading: false,
    );
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyEmployeeId);
      await prefs.remove(AppConstants.keyEmployeeName);
    } catch (_) {}
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
