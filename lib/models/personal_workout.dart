class PersonalWorkout {
  final int workoutId;
  final int userId;
  final DateTime date;
  final String workoutName;
  final int duration;
  final int? satisfactionLevel;
  final String? memo;

  PersonalWorkout({
    required this.workoutId,
    required this.userId,
    required this.date,
    required this.workoutName,
    required this.duration,
    this.satisfactionLevel,
    this.memo,
  });

  factory PersonalWorkout.fromJson(Map<String, dynamic> json) {
    return PersonalWorkout(
      workoutId: json['workoutId'] as int,
      userId: json['userId'] as int,
      date: DateTime.parse(json['date'] as String),
      workoutName: json['workoutName'] as String,
      duration: json['duration'] as int,
      satisfactionLevel: json['satisfactionLevel'] as int?,
      memo: json['memo'] as String?,
    );
  }

  Map<String, dynamic> toJsonCreate({
    required int userId,
  }) {
    return {
      'userId': userId,
      'date': _dateStr(date),
      'workoutName': workoutName,
      'duration': duration,
      if (satisfactionLevel != null) 'satisfactionLevel': satisfactionLevel,
      if (memo != null && memo!.isNotEmpty) 'memo': memo,
    };
  }

  Map<String, dynamic> toJsonUpdate() {
    return {
      'date': _dateStr(date),
      'workoutName': workoutName,
      'duration': duration,
      if (satisfactionLevel != null) 'satisfactionLevel': satisfactionLevel,
      if (memo != null) 'memo': memo,
    };
  }
}

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
