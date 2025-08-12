import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fithouse/api/http_client.dart';
import 'package:fithouse/models/paged.dart';
import 'package:fithouse/models/personal_workout.dart';

const int kUserId = 1;

class PersonalWorkoutApi {
  final http.Client _client;
  PersonalWorkoutApi({http.Client? client}) : _client = client ?? httpClient;

  Future<Paged<PersonalWorkout>> list({
    required int userId,
    int page = 0,
    int size = 20,
    DateTime? start,
    DateTime? end,
  }) async {
    final uri = Uri.parse('$baseUrl/api/personal-workouts').replace(
      queryParameters: {
        'userId': '$userId',
        'page': '$page',
        'size': '$size',
        if (start != null) 'start': _dateStr(start),
        if (end != null) 'end': _dateStr(end),
      },
    );
    final res = await _client.get(uri, headers: await authHeaders(json: false));
    if (res.statusCode != 200) {
      throw Exception('List failed: ${res.statusCode} ${res.body}');
    }
    return Paged.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
          (m) => PersonalWorkout.fromJson(m),
    );
  }

  Future<PersonalWorkout> create({
    required int userId,
    required DateTime date,
    required String workoutName,
    required int duration,
    int? satisfactionLevel,
    String? memo,
  }) async {
    final uri = Uri.parse('$baseUrl/api/personal-workouts');
    final body = jsonEncode({
      'userId': userId,
      'date': _dateStr(date),
      'workoutName': workoutName,
      'duration': duration,
      if (satisfactionLevel != null) 'satisfactionLevel': satisfactionLevel,
      if (memo != null && memo.isNotEmpty) 'memo': memo,
    });
    final res =
    await _client.post(uri, headers: await authHeaders(), body: body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Create failed: ${res.statusCode} ${res.body}');
    }
    return PersonalWorkout.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
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
    final uri = Uri.parse('$baseUrl/api/personal-workouts/$workoutId')
        .replace(queryParameters: {'userId': '$userId'});
    final patch = <String, dynamic>{};
    if (date != null) patch['date'] = _dateStr(date);
    if (workoutName != null) patch['workoutName'] = workoutName;
    if (duration != null) patch['duration'] = duration;
    if (satisfactionLevel != null) patch['satisfactionLevel'] = satisfactionLevel;
    if (memo != null) patch['memo'] = memo;

    final res =
    await _client.put(uri, headers: await authHeaders(), body: jsonEncode(patch));
    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.statusCode} ${res.body}');
    }
    return PersonalWorkout.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> delete({
    required int workoutId,
    required int userId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/personal-workouts/$workoutId')
        .replace(queryParameters: {'userId': '$userId'});
    final res = await _client.delete(uri, headers: await authHeaders(json: false));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Delete failed: ${res.statusCode} ${res.body}');
    }
  }
}

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
