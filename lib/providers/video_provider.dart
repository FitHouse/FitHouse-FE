import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/video_item.dart';
import '../api/http_client.dart' show baseUrl, getJson;

class VideoProvider extends ChangeNotifier {
  List<String> ages = ['전체'];
  List<String> factors = ['전체'];
  List<String> levels = ['전체'];
  List<String> tools = ['전체'];
  List<VideoItem> videos = [];

  int currentPage = 1;
  int totalPages = 1;
  int totalCount = 0;

  bool isLoading = false;

  String keyword = "";
  String age = "전체";
  String factor = "전체";
  String level = "전체";
  String tool = "전체";

  Future<void> loadFilterOptions() async {
    try {
      final res = await getJson("$baseUrl/video/filters");

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));

        ages = ["전체", ...List<String>.from(data["ages"])];
        factors = ["전체", ...List<String>.from(data["factors"])];
        levels = ["전체", ...List<String>.from(data["levels"])];
        tools = ["전체", ...List<String>.from(data["tools"])];

        notifyListeners();
      } else {
        print("필터 로딩 실패: ${res.statusCode}");
      }
    } catch (e) {
      print("필터 로딩 오류: $e");
    }
  }

  Future<void> searchVideos({int page = 1}) async {
    isLoading = true;
    notifyListeners();

    final queryParams = {
      "page": page.toString(),
      "size": "30",
      "keyword": keyword,
      "age": age,
      "factor": factor,
      "level": level,
      "tool": tool,
    };

    final uri = Uri.parse("$baseUrl/video").replace(queryParameters: queryParams);

    try {
      final res = await getJson(uri.toString());

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));

        videos = (data["videos"] as List)
            .map((e) => VideoItem.fromJson(e))
            .toList();

        for (var v in videos) {
          print("VIDEO URL = ${v.videoUrl}");
        }

        final urlCount = <String, int>{};
        for (var v in videos) {
          urlCount[v.videoUrl] = (urlCount[v.videoUrl] ?? 0) + 1;
        }
        urlCount.forEach((url, cnt) {
          if (cnt > 1) {
            print("중복 URL ($cnt개): $url");
          }
        });

        await _applyFavoriteState();

        currentPage = data["currentPage"];
        totalPages = data["totalPages"];
        totalCount = data["totalCount"];
      } else {
        print("검색 실패: ${res.statusCode}");
      }
    } catch (e) {
      print("검색 오류: $e");
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> _applyFavoriteState() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user!.getIdToken();

    final futures = videos.map((v) async {
      final res = await http.get(
        Uri.parse('$baseUrl/api/favorite-video/check?videoUrl=${Uri.encodeComponent(v.videoUrl)}'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      try {
        final decoded = jsonDecode(res.body);

        bool isFav = false;

        if (decoded is bool) {
          isFav = decoded;
        } else if (decoded is Map<String, dynamic>) {
          isFav = decoded["favorite"] == true;
        }

        v.isFavorite = isFav;
      } catch (e) {
        print("favorite 파싱 오류: $e");
        v.isFavorite = false;
      }
    }).toList();

    await Future.wait(futures);
  }

  Future<void> applyFilters({
    required String newKeyword,
    required String newAge,
    required String newFactor,
    required String newLevel,
    required String newTool,
  }) async {
    keyword = newKeyword;
    age = newAge;
    factor = newFactor;
    level = newLevel;
    tool = newTool;

    await searchVideos(page: 1);
  }
}
