class DailySteps {
  final String id;
  final String userId;
  final int steps;
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DailySteps({
    required this.id,
    required this.userId,
    required this.steps,
    required this.date,
    required this.createdAt,
    this.updatedAt,
  });

  factory DailySteps.fromJson(Map<String, dynamic> json) {
    return DailySteps(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      steps: json['steps'] as int,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'steps': steps,
        'date': date.toIso8601String().split('T')[0],
      };

  DailySteps copyWith({
    String? id,
    String? userId,
    int? steps,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailySteps(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      steps: steps ?? this.steps,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
