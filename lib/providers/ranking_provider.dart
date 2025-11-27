import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fithouse/models/ranking_entry.dart';
import 'package:fithouse/services/ranking_service.dart';
import 'package:fithouse/api/http_client.dart';

class RankingProvider extends ChangeNotifier {
  final RankingService service;

  int? myFamilyId;   // 내 가족 ID 저장

  List<RankingEntry> dailyRanking = [];
  List<RankingEntry> weeklyRanking = [];

  bool loadingDaily = false;
  bool loadingWeekly = false;

  RankingProvider({required this.service});

  /// 내 가족 ID 불러오기
  Future<void> loadMyFamilyId() async {
    final uri = Uri.parse("$baseUrl/family/mine");
    final res = await httpClient.get(uri, headers: await authHeaders());

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      myFamilyId = json["familyId"];
      notifyListeners();
    }
  }

  /// 일간 랭킹 로드
  Future<void> loadDailyRanking() async {
    loadingDaily = true;
    notifyListeners();

    dailyRanking = await service.loadDailyRanking();

    loadingDaily = false;
    notifyListeners();
  }

  /// 주간 랭킹 로드
  Future<void> loadWeeklyRanking() async {
    loadingWeekly = true;
    notifyListeners();

    weeklyRanking = await service.loadWeeklyRanking();

    loadingWeekly = false;
    notifyListeners();
  }
}
