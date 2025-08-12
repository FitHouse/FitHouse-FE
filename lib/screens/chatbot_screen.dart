import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';  // 추가


class ChatbotScreen extends StatefulWidget {
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> chatMessages = [];

  String? currentUserUid;

  @override
  void initState() {
    super.initState();

    // 초기 로그인 유저 UID 설정
    currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    // 로그인 상태 변경 감지 리스너 추가
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        currentUserUid = user?.uid;
      });
    });
  }


  Future<void> sendQuestion(String question) async {
    if (question.trim().isEmpty) return;
    if (currentUserUid == null) {
      setState(() {
        chatMessages.add({"bot": "로그인 상태가 아닙니다. 먼저 로그인 해주세요."});
      });
      return;
    }

    setState(() {
      chatMessages.add({"user": question});
    });

    try {
      // final url = Uri.parse('http://localhost:8080/chat'); // chrome 에뮬레이터에서 로컬 서버에 접근하려면
      final url = Uri.parse('http://10.0.2.2:8080/chat'); // Android 에뮬레이터에서 로컬 서버에 접근하려면

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

        setState(() {
          chatMessages.add({"bot": botAnswer});
        });
      } else {
        setState(() {
          chatMessages.add({"bot": "서버 오류 발생: ${response.statusCode}"});
        });
      }
    } catch (e) {
      setState(() {
        chatMessages.add({"bot": "네트워크 오류 발생: $e"});
      });
    }

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final message = chatMessages[index];
                if (message.containsKey("user")) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      margin: EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(message["user"]!),
                    ),
                  );
                } else {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      margin: EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(message["bot"]!),
                    ),
                  );
                }
              },
            ),
          ),
          TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: "질문 입력"),
            onSubmitted: (value) => sendQuestion(value),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => sendQuestion(_controller.text),
            child: Text("보내기"),
          ),
        ],
      ),
    );
  }
}