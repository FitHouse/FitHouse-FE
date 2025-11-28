/// 개별 멤버 카드 (백엔드 DTO: MemberCard)
class FamilySteps {
  final int userId;
  final int familyId;
  final String name;
  final int today;
  final int weekly;
  final int monthly;
  final int goal;

  const FamilySteps({
    required this.userId,
    required this.familyId,
    required this.name,
    required this.today,
    required this.weekly,
    required this.monthly,
    required this.goal,
  });

  factory FamilySteps.fromJson(Map<String, dynamic> j) => FamilySteps(
    userId: j['userId'] ?? 0,
    familyId: j['familyId'] ?? 0,
    name: j['name'] ?? '익명',
    today: j['today'] ?? j['steps'] ?? 0,
    weekly: j['weekly'] ?? j['week'] ?? 0, // weekly 필드명 우선
    monthly: j['monthly'] ?? j['month'] ?? 0,
    goal: j['goal'] ?? 10000,
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'familyId': familyId,
    'name': name,
    'today': today,
    'weekly': weekly,
    'monthly': monthly,
    'goal': goal,
  };

  // copyWith 추가
  FamilySteps copyWith({
    int? userId,
    int? familyId,
    String? name,
    int? today,
    int? weekly,
    int? monthly,
    int? goal,
  }) {
    return FamilySteps(
      userId: userId ?? this.userId,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      today: today ?? this.today,
      weekly: weekly ?? this.weekly,
      monthly: monthly ?? this.monthly,
      goal: goal ?? this.goal,
    );
  }
}

/// 가족 주간 요약 (백엔드 DTO: FamilyWeeklySummary)
class FamilyWeeklySummary {
  final int familyId;
  final int weeklyGoal;
  final int pedometerTotalSteps;
  final int successCount;
  final bool success;
  final int level;
  final String? levelName;
  final int requiredSuccess;

  const FamilyWeeklySummary({
    required this.familyId,
    required this.weeklyGoal,
    required this.pedometerTotalSteps,
    required this.successCount,
    required this.success,
    required this.level,
    required this.levelName,
    required this.requiredSuccess,
  });

  factory FamilyWeeklySummary.fromJson(Map<String, dynamic> j) =>
      FamilyWeeklySummary(
        familyId: j['familyId'] ?? 0,
        weeklyGoal: j['weeklyGoal'] ?? 0,
        pedometerTotalSteps: j['pedometerTotalSteps'] ?? 0,
        successCount: j['successCount'] ?? 0,
        success: j['success'] ?? false,
        level: j['level'] ?? 0,
        levelName: j['levelName'],
        requiredSuccess: j['requiredSuccess'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'familyId': familyId,
    'weeklyGoal': weeklyGoal,
    'pedometerTotalSteps': pedometerTotalSteps,
    'successCount': successCount,
    'success': success,
    'level': level,
    'levelName': levelName,
    'requiredSuccess': requiredSuccess,
  };
}

/// 전체 응답 (백엔드 DTO: FamilyStepsSummaryResponse)
class FamilyStepsSummary {
  final DateTime from;
  final DateTime to;
  final FamilyDailySummary? today;
  final FamilyWeeklySummary? week;
  final List<FamilySteps> members;

  const FamilyStepsSummary({
    required this.from,
    required this.to,
    required this.today,
    required this.week,
    required this.members,
  });

  factory FamilyStepsSummary.fromJson(Map<String, dynamic> j) =>
      FamilyStepsSummary(
        from: DateTime.parse(j['from']),
        to: DateTime.parse(j['to']),
        today: j['today'] != null
            ? FamilyDailySummary.fromJson(j['today'])
            : null,
        week: j['week'] != null
            ? FamilyWeeklySummary.fromJson(j['week'])
            : null,
        members: (j['members'] as List<dynamic>)
            .map((m) => FamilySteps.fromJson(m))
            .toList(),
      );
}


/// 오늘 요약 (백엔드 DTO: FamilyDailySummary)
class FamilyDailySummary {
  final int familyId;
  final int todayGoal;
  final int totalSteps;

  const FamilyDailySummary({
    required this.familyId,
    required this.todayGoal,
    required this.totalSteps,
  });

  factory FamilyDailySummary.fromJson(Map<String, dynamic> j) =>
      FamilyDailySummary(
        familyId: j['familyId'] ?? 0,
        todayGoal: j['todayGoal'] ?? 0,
        totalSteps: j['totalSteps'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'familyId': familyId,
    'todayGoal': todayGoal,
    'totalSteps': totalSteps,
  };
}

