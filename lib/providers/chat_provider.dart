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

        final String botAnswer = data['response'] ?? '응답이 없습니다.';
        final List<ExerciseVideo> videoList = [];

        if (data['videos'] != null && data['videos'] is List) {
          for (final videoJson in (data['videos'] as List)) {
            videoList.add(ExerciseVideo.fromJson(videoJson));
          }
        }

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