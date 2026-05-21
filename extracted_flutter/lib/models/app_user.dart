class AppUser {
  final int id;
  final String username;
  final String employeeName;
  final String role; // 'employee' | 'manager'
  final String roleName;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.username,
    required this.employeeName,
    required this.role,
    required this.roleName,
    required this.isActive,
  });

  bool get isManager => role == 'manager';
  bool get isEmployee => role == 'employee';

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as int,
      username: map['username']?.toString() ?? '',
      employeeName: map['employee_name']?.toString() ?? '',
      role: map['role']?.toString() ?? 'employee',
      roleName: map['role_name']?.toString() ?? 'موظف',
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'employee_name': employeeName,
        'role': role,
        'role_name': roleName,
        'is_active': isActive ? 1 : 0,
      };
}
