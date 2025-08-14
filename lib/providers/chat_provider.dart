import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'; // 추가
import 'dart:convert';

class ChatProvider extends ChangeNotifier {
  final List<Map<String, String>> _messages = [];
  bool _newSessionAvailable = false;

  List<Map<String, String>> get messages => List.unmodifiable(_messages);
  bool get newSessionAvailable => _newSessionAvailable;


  Future<void> sendMessage(String question, String currentUserUid) async {
    if (question.trim().isEmpty) return;

    _messages.add({"user": question});
    notifyListeners();

    try {
      // 1) 현재 사용자 토큰 가져오기
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _messages.add({"bot": "로그인이 필요합니다."});
        notifyListeners();
        return;
      }
      final idToken = await user.getIdToken(true);

      // 2) 서버 URL 설정
      final url = Uri.parse('http://localhost:8080/chat');
      // 안드로이드 에뮬레이터면 아래 사용
      // final url = Uri.parse('http://10.0.2.2:8080/chat');

      // 3) 요청 보내기 (Authorization 헤더 추가)
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "question": question,
          "firebaseUid": currentUserUid, // 서버가 헤더에서 uid 추출한다면 이건 제거 가능
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

        //  수정된 부분: 서버 필드 이름에 맞춤
        if (data['newSessionAvailable'] == true) {
          _newSessionAvailable = true; // UI에서 버튼 표시
        }


        _messages.add({"bot": botAnswer});
      } else if (response.statusCode == 401) {
        _messages.add({"bot": "인증 실패(401). 토큰 확인 필요."});
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
    _newSessionAvailable = false; // 새 세션 버튼 숨김
    notifyListeners();
  }
}
