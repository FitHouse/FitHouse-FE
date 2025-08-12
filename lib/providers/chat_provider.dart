import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatProvider extends ChangeNotifier {
  final List<Map<String, String>> _messages = [];

  List<Map<String, String>> get messages => List.unmodifiable(_messages);

  Future<void> sendMessage(String question, String currentUserUid) async {
    if (question.trim().isEmpty) return;

    _messages.add({"user": question});
    notifyListeners();

    try {
      // chrome 에뮬레이터에서 로컬 서버에 접근하려면
      final url = Uri.parse('http://localhost:8080/chat');
      // Android 에뮬레이터 사용 시 '10.0.2.2' 사용, 필요에 따라 수정
      //final url = Uri.parse('http://10.0.2.2:8080/chat');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "question": question,
          "firebaseUid": currentUserUid,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        String botAnswer;
        if (data['response'] is String) {
          botAnswer = data['response'];
        } else if (data['response'] is Map &&
            data['response'].containsKey('content')) {
          botAnswer = data['response']['content'];
        } else {
          botAnswer = data['response'].toString();
        }

        _messages.add({"bot": botAnswer});
      } else {
        _messages.add({"bot": "서버 오류 발생: ${response.statusCode}"});
      }
    } catch (e) {
      _messages.add({"bot": "네트워크 오류 발생: $e"});
    }

    notifyListeners();
  }

  void addBotMessage(String message) {
    _messages.add({"bot": message});
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
