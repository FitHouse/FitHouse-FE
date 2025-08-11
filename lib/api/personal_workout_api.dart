import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String _baseAndroid = 'http://10.0.2.2:8080';
const String _baseOther = 'http://localhost:8080';
String get _baseUrl => Platform.isAndroid ? _baseAndroid : _baseOther;

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
}

class PagedWorkout {
  final List<PersonalWorkout> content;
  final int page;
  final int size;
  final int totalPages;
  final int totalElements;

  PagedWorkout({
    required this.content,
    required this.page,
    required this.size,
    required this.totalPages,
    required this.totalElements,
  });

  factory PagedWorkout.fromJson(Map<String, dynamic> json) {
    final items = (json['content'] as List)
        .map((e) => PersonalWorkout.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagedWorkout(
      content: items,
      page: json['number'] as int? ?? 0,
      size: json['size'] as int? ?? items.length,
      totalPages: json['totalPages'] as int? ?? 1,
      totalElements: json['totalElements'] as int? ?? items.length,
    );
  }
}

class PersonalWorkoutApi {
  final http.Client _client;
  PersonalWorkoutApi({http.Client? client}) : _client = client ?? http.Client();

  Future<PagedWorkout> list({
    required int userId,
    int page = 0,
    int size = 20,
    DateTime? start,
    DateTime? end,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/personal-workouts').replace(
      queryParameters: {
        'userId': '$userId',
        'page': '$page',
        'size': '$size',
        if (start != null) 'start': _dateStr(start),
        if (end != null) 'end': _dateStr(end),
      },
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('List failed: ${res.statusCode} ${res.body}');
    }
    return PagedWorkout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<PersonalWorkout> getOne({
    required int workoutId,
    required int userId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/personal-workouts/$workoutId')
        .replace(queryParameters: {'userId': '$userId'});
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Get failed: ${res.statusCode} ${res.body}');
    }
    return PersonalWorkout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<PersonalWorkout> create({
    required int userId,
    required DateTime date,
    required String workoutName,
    required int duration,
    int? satisfactionLevel,
    String? memo,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/personal-workouts');
    final body = jsonEncode({
      'userId': userId,
      'date': _dateStr(date),
      'workoutName': workoutName,
      'duration': duration,
      if (satisfactionLevel != null) 'satisfactionLevel': satisfactionLevel,
      if (memo != null && memo.isNotEmpty) 'memo': memo,
    });
    final res = await _client
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Create failed: ${res.statusCode} ${res.body}');
    }
    return PersonalWorkout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<PersonalWorkout> update({
    required int workoutId,
    required int userId,
    DateTime? date,
    String? workoutName,
    int? duration,
    int? satisfactionLevel,
    String? memo,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/personal-workouts/$workoutId')
        .replace(queryParameters: {'userId': '$userId'});
    final body = jsonEncode({
      if (date != null) 'date': _dateStr(date),
      if (workoutName != null) 'workoutName': workoutName,
      if (duration != null) 'duration': duration,
      if (satisfactionLevel != null) 'satisfactionLevel': satisfactionLevel,
      if (memo != null) 'memo': memo,
    });
    final res = await _client
        .put(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.statusCode} ${res.body}');
    }
    return PersonalWorkout.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> delete({
    required int workoutId,
    required int userId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/personal-workouts/$workoutId')
        .replace(queryParameters: {'userId': '$userId'});
    final res = await _client.delete(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Delete failed: ${res.statusCode} ${res.body}');
    }
  }
}
