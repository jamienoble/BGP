class StepGoal {
  final String id;
  final String userId;
  final int dailySteps;
  final DateTime createdAt;
  final DateTime? updatedAt;

  StepGoal({
    required this.id,
    required this.userId,
    required this.dailySteps,
    required this.createdAt,
    this.updatedAt,
  });

  factory StepGoal.fromJson(Map<String, dynamic> json) {
    return StepGoal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dailySteps: json['daily_steps'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'daily_steps': dailySteps,
      };

  StepGoal copyWith({
    String? id,
    String? userId,
    int? dailySteps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StepGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dailySteps: dailySteps ?? this.dailySteps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
