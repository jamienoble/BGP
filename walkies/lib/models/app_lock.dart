class AppLock {
  final String id;
  final String userId;
  final String appPackageName;
  final String appName;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppLock({
    required this.id,
    required this.userId,
    required this.appPackageName,
    required this.appName,
    required this.isLocked,
    required this.createdAt,
    this.updatedAt,
  });

  factory AppLock.fromJson(Map<String, dynamic> json) {
    return AppLock(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      appPackageName: json['app_package_name'] as String,
      appName: json['app_name'] as String,
      isLocked: json['is_locked'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'app_package_name': appPackageName,
        'app_name': appName,
        'is_locked': isLocked,
      };

  AppLock copyWith({
    String? id,
    String? userId,
    String? appPackageName,
    String? appName,
    bool? isLocked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppLock(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      appPackageName: appPackageName ?? this.appPackageName,
      appName: appName ?? this.appName,
      isLocked: isLocked ?? this.isLocked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
