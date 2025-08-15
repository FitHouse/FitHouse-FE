class FamilyDailyRecord {
  final int userId;
  final String name;
  final String role;
  final String? profileImageUrl;
  final int totalMinutes;
  final Map<String, int> workoutMinutes;

  FamilyDailyRecord({
    required this.userId,
    required this.name,
    required this.role,
    required this.profileImageUrl,
    required this.totalMinutes,
    required this.workoutMinutes,
  });

  factory FamilyDailyRecord.fromJson(Map<String, dynamic> json) {
    return FamilyDailyRecord(
      userId: json['userId'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      totalMinutes: json['totalMinutes'] as int,
      workoutMinutes: Map<String, int>.from(json['workouts'] ?? {}),
    );
  }
}
