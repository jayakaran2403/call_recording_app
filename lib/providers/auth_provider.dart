import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee.dart';
import '../repository/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthState {
  final Employee? employee;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({this.employee, this.isLoading = false, this.errorMessage});

  bool get isLoggedIn => employee != null;

  AuthState copyWith({
    Employee? employee,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      employee: employee ?? this.employee,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true);
    final employee = await _repository.currentSession();
    state = AuthState(employee: employee, isLoading: false);
  }

  Future<bool> login(String employeeId, String password) async {
    if (employeeId.trim().isEmpty || password.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Employee ID and password are required.',
      );
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final employee = await _repository.login(employeeId.trim(), password);
    if (employee == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid Employee ID or password.',
      );
      return false;
    }
    state = AuthState(employee: employee, isLoading: false);
    return true;
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
