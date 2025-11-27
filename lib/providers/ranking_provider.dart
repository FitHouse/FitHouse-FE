import 'package:flutter/material.dart';
import 'package:fithouse/models/ranking_entry.dart';
import 'package:fithouse/services/ranking_service.dart';

class RankingProvider extends ChangeNotifier {
  final RankingService service;

  List<RankingEntry> dailyRanking = [];
  List<RankingEntry> weeklyRanking = [];

  bool loadingDaily = false;
  bool loadingWeekly = false;

  RankingProvider({required this.service});

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
