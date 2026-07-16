class Employee {
  final int? id;
  final String employeeId;
  final String employeeName;
  final String passwordHash;
  final DateTime? loginTime;

  const Employee({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.passwordHash,
    this.loginTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'password': passwordHash,
      'loginTime': loginTime?.toIso8601String(),
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?,
      employeeId: map['employeeId'] as String,
      employeeName: map['employeeName'] as String,
      passwordHash: map['password'] as String,
      loginTime: map['loginTime'] != null
          ? DateTime.tryParse(map['loginTime'] as String)
          : null,
    );
  }

  Employee copyWith({
    int? id,
    String? employeeId,
    String? employeeName,
    String? passwordHash,
    DateTime? loginTime,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      passwordHash: passwordHash ?? this.passwordHash,
      loginTime: loginTime ?? this.loginTime,
    );
  }
}
