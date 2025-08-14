import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

// 새로 만든 모델들을 import 합니다.
import '../models/chat_message.dart';
import '../models/exercise_video.dart';

class ChatProvider extends ChangeNotifier {
  // 메시지 타입을 Map에서 ChatMessage 모델로 변경합니다.
  final List<ChatMessage> _messages = [];
  bool _newSessionAvailable = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get newSessionAvailable => _newSessionAvailable;

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

      //final url = Uri.parse('http://localhost:8080/chat');
      final url = Uri.parse('http://10.0.2.2:8080/chat'); // 안드로이드 에뮬레이터용

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

        // --- 여기가 핵심 수정 부분입니다 ---
        final String botAnswer = data['response'] ?? '응답이 없습니다.';
        final List<ExerciseVideo> videoList = [];

        // 'videos' 필드가 있고, null이 아니며, 리스트 형태인지 확인합니다.
        if (data['videos'] != null && data['videos'] is List) {
          // 리스트의 각 항목(JSON)을 ExerciseVideo 객체로 변환하여 videoList에 추가합니다.
          for (var videoJson in data['videos']) {
            videoList.add(ExerciseVideo.fromJson(videoJson));
          }
        }

        // 텍스트 답변과 영상 목록을 모두 포함하는 ChatMessage를 메시지 목록에 추가합니다.
        _messages.add(ChatMessage(
          text: botAnswer,
          isUser: false,
          videos: videoList,
        ));

        _newSessionAvailable = data['newSessionAvailable'] ?? false;

      } else {
        addBotMessage("서버 오류 발생: ${response.statusCode}");
      }
    } catch (e) {
      addBotMessage("네트워크 오류 발생: $e");
    }

    notifyListeners();
  }

  void addBotMessage(String message) {
    _messages.add(ChatMessage(text: message, isUser: false));
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _newSessionAvailable = false;
    notifyListeners();
  }
}
