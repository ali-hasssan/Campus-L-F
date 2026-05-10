class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String userDepartment;
  final String userPhotoUrl;
  final String itemName;
  final String description;
  final String color;
  final String area;
  final String category;
  final String type;
  final String status;
  final DateTime timestamp;
  final List<String> images;

  // ── Resolved info — jis user ka saath item resolve hua
  final String resolvedWithUserId;
  final String resolvedWithUserName;
  final String resolvedWithUserDept;
  final String resolvedWithUserPhoto;
  final DateTime? resolvedAt;

  const PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    this.userDepartment = '',
    this.userPhotoUrl = '',
    required this.itemName,
    required this.description,
    required this.color,
    required this.area,
    required this.category,
    required this.type,
    this.status = 'active',
    required this.timestamp,
    this.images = const [],
    this.resolvedWithUserId = '',
    this.resolvedWithUserName = '',
    this.resolvedWithUserDept = '',
    this.resolvedWithUserPhoto = '',
    this.resolvedAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> j) => PostModel(
        id: j['id'],
        userId: j['userId'],
        userName: j['userName'],
        userPhone: j['userPhone'] ?? '',
        userDepartment: j['userDepartment'] ?? '',
        userPhotoUrl: j['userPhotoUrl'] ?? '',
        itemName: j['itemName'],
        description: j['description'],
        color: j['color'],
        area: j['area'],
        category: j['category'],
        type: j['type'],
        status: j['status'] ?? 'active',
        timestamp: DateTime.parse(j['timestamp']),
        images: List<String>.from(j['images'] ?? []),
        resolvedWithUserId: j['resolvedWithUserId'] ?? '',
        resolvedWithUserName: j['resolvedWithUserName'] ?? '',
        resolvedWithUserDept: j['resolvedWithUserDept'] ?? '',
        resolvedWithUserPhoto: j['resolvedWithUserPhoto'] ?? '',
        resolvedAt: j['resolvedAt'] != null
            ? DateTime.parse(j['resolvedAt'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userPhone': userPhone,
        'userDepartment': userDepartment,
        'userPhotoUrl': userPhotoUrl,
        'itemName': itemName,
        'description': description,
        'color': color,
        'area': area,
        'category': category,
        'type': type,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
        'images': images,
        'resolvedWithUserId': resolvedWithUserId,
        'resolvedWithUserName': resolvedWithUserName,
        'resolvedWithUserDept': resolvedWithUserDept,
        'resolvedWithUserPhoto': resolvedWithUserPhoto,
        'resolvedAt': resolvedAt?.toIso8601String(),
      };

  PostModel copyWith({
    String? itemName,
    String? description,
    String? color,
    String? area,
    String? category,
    String? type,
    String? status,
    String? userDepartment,
    String? userPhotoUrl,
    List<String>? images,
    String? resolvedWithUserId,
    String? resolvedWithUserName,
    String? resolvedWithUserDept,
    String? resolvedWithUserPhoto,
    DateTime? resolvedAt,
  }) =>
      PostModel(
        id: id,
        userId: userId,
        userName: userName,
        userPhone: userPhone,
        userDepartment: userDepartment ?? this.userDepartment,
        userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
        itemName: itemName ?? this.itemName,
        description: description ?? this.description,
        color: color ?? this.color,
        area: area ?? this.area,
        category: category ?? this.category,
        type: type ?? this.type,
        status: status ?? this.status,
        timestamp: timestamp,
        images: images ?? this.images,
        resolvedWithUserId: resolvedWithUserId ?? this.resolvedWithUserId,
        resolvedWithUserName: resolvedWithUserName ?? this.resolvedWithUserName,
        resolvedWithUserDept: resolvedWithUserDept ?? this.resolvedWithUserDept,
        resolvedWithUserPhoto:
            resolvedWithUserPhoto ?? this.resolvedWithUserPhoto,
        resolvedAt: resolvedAt ?? this.resolvedAt,
      );
}
