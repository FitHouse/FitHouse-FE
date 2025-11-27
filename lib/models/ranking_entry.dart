class RankingEntry {
  final int familyId;
  final String familyName;
  final String? familyImageUrl;
  final int steps;        // daily: steps, weekly: totalSteps
  final int goal;         // 추가
  final double achievement; // 추가
  final int rank;

  RankingEntry({
    required this.familyId,
    required this.familyName,
    required this.familyImageUrl,
    required this.steps,
    required this.goal,
    required this.achievement,
    required this.rank,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      familyId: json['familyId'],
      familyName: json['familyName'],
      familyImageUrl: json['familyImageUrl'],
      steps: (json['steps'] ?? json['totalSteps'] ?? 0),
      goal: json['goal'] ?? 0,
      achievement: (json['achievement'] ?? 0).toDouble(),
      rank: json['rank'] ?? 0,
    );
  }
}
