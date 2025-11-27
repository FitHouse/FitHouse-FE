import 'dart:convert';
import 'package:fithouse/api/http_client.dart';
import 'package:fithouse/models/ranking_entry.dart';

class RankingService {
  const RankingService();

  /// 일간 랭킹 가져오기
  Future<List<RankingEntry>> loadDailyRanking() async {
    final uri = Uri.parse("$baseUrl/api/families/ranking/daily");
    final res = await httpClient.get(uri, headers: await authHeaders());

    if (res.statusCode != 200) {
      throw Exception("일간 랭킹 불러오기 실패: ${res.body}");
    }

    final data = jsonDecode(res.body);
    List list = data['families'];

    return list.map((e) => RankingEntry.fromJson(e)).toList();
  }

  /// 주간 랭킹 가져오기
  Future<List<RankingEntry>> loadWeeklyRanking() async {
    final now = DateTime.now();
    DateTime lastSunday = now.subtract(Duration(days: now.weekday % 7));

    final formatted =
        "${lastSunday.year}-${lastSunday.month.toString().padLeft(2, '0')}-${lastSunday.day.toString().padLeft(2, '0')}";

    final uri = Uri.parse("$baseUrl/api/families/ranking/weekly?endDate=$formatted");

    final res = await httpClient.get(uri, headers: await authHeaders());

    if (res.statusCode != 200) {
      throw Exception("주간 랭킹 불러오기 실패: ${res.body}");
    }

    final data = jsonDecode(res.body);

    List list = data['families'];
    return list.map((e) => RankingEntry.fromJson(e)).toList();
  }

}
