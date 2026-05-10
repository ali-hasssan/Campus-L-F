class UserModel {
  final String id;
  final String name;
  final String email;
  final String password;
  final String department;
  final String semester;
  final String phone;
  final bool profileComplete;
  final String profileImageUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.department = '',
    this.semester = '',
    this.phone = '',
    this.profileComplete = false,
    this.profileImageUrl = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        password: j['password'],
        department: j['department'] ?? '',
        semester: j['semester'] ?? '',
        phone: j['phone'] ?? '',
        profileComplete: j['profileComplete'] ?? false,
        profileImageUrl: j['profileImageUrl'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'department': department,
        'semester': semester,
        'phone': phone,
        'profileComplete': profileComplete,
        'profileImageUrl': profileImageUrl,
      };

  UserModel copyWith({
    String? name,
    String? department,
    String? semester,
    String? phone,
    bool? profileComplete,
    String? profileImageUrl,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email,
        password: password,
        department: department ?? this.department,
        semester: semester ?? this.semester,
        phone: phone ?? this.phone,
        profileComplete: profileComplete ?? this.profileComplete,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      );
}
