import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

import '../api/http_client.dart' show baseUrl;
import '../models/chat_message.dart';
import '../models/exercise_video.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _newSessionAvailable = false;

  List<ExerciseVideo> _allVideos = [];

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get newSessionAvailable => _newSessionAvailable;

  List<ExerciseVideo> get allVideos => List.unmodifiable(_allVideos);

  List<String> _availableAges = ['전체'];
  List<String> _availableFactors = ['전체'];
  List<String> _availableLevels = ['전체'];
  List<String> _availableTools = ['전체'];

  List<String> get availableAges => List.unmodifiable(_availableAges);
  List<String> get availableFactors => List.unmodifiable(_availableFactors);
  List<String> get availableLevels => List.unmodifiable(_availableLevels);
  List<String> get availableTools => List.unmodifiable(_availableTools);


  static const String actualServiceKey =
      "S%2B7zSRvCnsne4FGNa9yGGQo3VWzoncxKCq4rLOK2EOCQPoLXkZrCd72Xp%2B2rbDbwwwHPlcIH1DvOcVTqKzatgw%3D%3D";


  Future<void> fetchAllVideos() async {
    final url =
        "https://apis.data.go.kr/B551014/SRVC_TODZ_VDO_PKG/TODZ_VDO_TRNG_GUIDE_I"
        "?serviceKey=$actualServiceKey"
        "&pageNo=1"
        "&numOfRows=300"
        "&resultType=JSON";

    print("📡 최종 API 요청 URL = $url");

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "User-Agent": "Mozilla/5.0",
          "Accept": "*/*",
        },
      );

      final raw = utf8.decode(response.bodyBytes);
      print("RAW = $raw");

      if (response.statusCode != 200) {
        print("API 상태코드 오류: ${response.statusCode}");
        return;
      }

      final jsonData = jsonDecode(raw);
      final items = jsonData["response"]?["body"]?["items"]?["item"];

      if (items == null) {
        print("item 없음");
        return;
      }

      if (items is List) {
        _allVideos = items
            .map((e) => ExerciseVideo.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else if (items is Map) {
        _allVideos = [
          ExerciseVideo.fromJson(Map<String, dynamic>.from(items))
        ];
      }

      print("총 ${_allVideos.length}개 로딩 완료");
      _extractUniqueFilters();
      notifyListeners();
    } catch (e) {
      print("에러: $e");
    }
  }

  void _extractUniqueFilters() {
    final Set<String> ages = {};
    final Set<String> factors = {};
    final Set<String> levels = {};
    final Set<String> tools = {};

    for (final v in _allVideos) {
      if (v.aggrpNm.isNotEmpty) ages.add(v.aggrpNm);
      if (v.ftnsFctrNm.isNotEmpty) factors.add(v.ftnsFctrNm);
      if (v.ftnsLvlNm.isNotEmpty) levels.add(v.ftnsLvlNm);

      if (v.toolNm.isNotEmpty && v.toolNm != '없음') {
        tools.addAll(v.toolNm.split(',').map((e) => e.trim()));
      }
    }

    _availableAges = ['전체', ...ages];
    _availableFactors = ['전체', ...factors];
    _availableLevels = ['전체', ...levels];
    _availableTools = ['전체', ...tools];
  }


  Future<void> sendMessage(String question, String currentUserUid) async {
    if (question.trim().isEmpty) return;

    _messages.add(ChatMessage(text: question, isUser: true));
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        addBotMessage("로그인이 필요합니다.");
        return;
      }
      final idToken = await user.getIdToken(true);

      final url = Uri.parse('$baseUrl/chat');

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "question": question,
          "firebaseUid": currentUserUid,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        final String botAnswer = data['response'] ?? '응답 없음';
        final List<ExerciseVideo> videoList = [];

        if (data['videos'] != null && data['videos'] is List) {
          for (final v in data['videos']) {
            videoList.add(ExerciseVideo.fromJson(v));
          }
        }

        _messages.add(
          ChatMessage(text: botAnswer, isUser: false, videos: videoList),
        );

        _newSessionAvailable = data['newSessionAvailable'] ?? false;
      } else {
        addBotMessage("서버 오류: ${response.statusCode}");
      }
    } catch (e) {
      addBotMessage("네트워크 오류: $e");
    }

    notifyListeners();
  }

  void addBotMessage(String msg) {
    _messages.add(ChatMessage(text: msg, isUser: false));
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _newSessionAvailable = false;
    notifyListeners();
  }
}
