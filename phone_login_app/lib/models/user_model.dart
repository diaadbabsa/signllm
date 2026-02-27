class UserModel {
  final int id;
  final String username;
  final String fullName;
  final String role;
  final String schoolName;
  final bool isActive;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.schoolName,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'student',
      schoolName: json['school_name'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'role': role,
      'school_name': schoolName,
      'is_active': isActive,
    };
  }
}
