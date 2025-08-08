import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatbotScreen extends StatefulWidget {
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> chatMessages = [];

  Future<void> sendQuestion(String question) async {
    if (question.trim().isEmpty) return;

    setState(() {
      chatMessages.add({"user": question});
    });

    try {
      final url = Uri.parse('http://10.207.17.156:8000/chat'); // 서버 주소 수정 필요

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"question": question}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String botAnswer;

        if (data['response'] is String) {
          botAnswer = data['response'];
        } else if (data['response'] is Map && data['response'].containsKey('content')) {
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
