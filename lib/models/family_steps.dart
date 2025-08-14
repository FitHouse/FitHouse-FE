// family_steps.dart
class FamilySteps {
  final int userId;
  final int familyId;
  final String name;
  final int today;
  final int week;
  final int month;
  final int goal;

  const FamilySteps({
    required this.userId,
    required this.familyId,
    required this.name,
    required this.today,
    required this.week,
    required this.month,
    required this.goal,
  });

  factory FamilySteps.fromJson(Map<String, dynamic> j) => FamilySteps(
    userId: j['userId'] ?? 0,
    familyId: j['familyId'] ?? 0,
    name: j['name'] ?? '익명',
    today: j['today'] ?? j['steps'] ?? 0,
    week: j['week'] ?? 0,
    month: j['month'] ?? 0,
    goal: j['goal'] ?? 10000,
  );

  FamilySteps copyWith({
    int? userId,
    int? familyId,
    String? name,
    int? today,
    int? week,
    int? month,
    int? goal,
  }) {
    return FamilySteps(
      userId: userId ?? this.userId,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      today: today ?? this.today,
      week: week ?? this.week,
      month: month ?? this.month,
      goal: goal ?? this.goal,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'familyId': familyId,
    'name': name,
    'today': today,
    'week': week,
    'month': month,
    'goal': goal,
  };
}
