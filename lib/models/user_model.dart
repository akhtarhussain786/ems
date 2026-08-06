class UserModel {
  final int? id;
  final int? userId;
  final String name;
  final String employeeCode;
  final int? departmentId;
  final int? designationId;
  final String? profilePhoto;
  final String? mobile;
  final String? email;
  final String role;
  final String? token;
  final bool isFieldStaff;

  UserModel({
    this.id,
    this.userId,
    required this.name,
    required this.employeeCode,
    this.departmentId,
    this.designationId,
    this.profilePhoto,
    this.mobile,
    this.email,
    this.role = 'Employee',
    this.token,
    this.isFieldStaff = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'] ?? '',
      employeeCode: json['employee_code'] ?? '',
      departmentId: json['department_id'],
      designationId: json['designation_id'],
      profilePhoto: json['profile_photo'],
      mobile: json['mobile'],
      email: json['email'],
      role: json['role'] ?? 'Employee',
      isFieldStaff: (json['is_field_staff'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'employee_code': employeeCode,
    'department_id': departmentId,
    'designation_id': designationId,
    'profile_photo': profilePhoto,
    'mobile': mobile,
    'email': email,
    'role': role,
    'is_field_staff': isFieldStaff ? 1 : 0,
  };
}
