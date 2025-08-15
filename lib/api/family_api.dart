import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fithouse/api/http_client.dart'; // baseUrl, authHeaders, httpClient
import 'package:fithouse/models/family_daily_record.dart';

// 가족 하루 운동 기록 조회
Future<List<FamilyDailyRecord>> fetchFamilyDailyRecords() async {
  final headers = await authHeaders();
  final uri = Uri.parse('$baseUrl/family/daily-records');

  final res = await httpClient.get(uri, headers: headers);
  if (res.statusCode == 200) {
    final List<dynamic> jsonList = jsonDecode(res.body);
    return jsonList
        .map((e) => FamilyDailyRecord.fromJson(e))
        .toList();
  } else {
    throw Exception('가족 하루 운동 기록 조회 실패: ${res.statusCode}');
  }
}

// 특정 가족 구성원 신체정보 + 운동기록 조회
Future<Map<String, dynamic>> fetchFamilyMemberDetail({
  required int targetUserId,
  int page = 0,
  int size = 10,
  DateTime? start,
  DateTime? end,
}) async {
  final headers = await authHeaders();
  final queryParams = {
    'page': '$page',
    'size': '$size',
    if (start != null) 'start': start.toIso8601String().split('T').first,
    if (end != null) 'end': end.toIso8601String().split('T').first,
  };

  final uri = Uri.parse('$baseUrl/family/family/member/$targetUserId')
      .replace(queryParameters: queryParams);

  final res = await httpClient.get(uri, headers: headers);
  if (res.statusCode == 200) {
    return jsonDecode(res.body);
  } else {
    throw Exception('가족 구성원 세부 정보 조회 실패: ${res.statusCode}');
  }
}
