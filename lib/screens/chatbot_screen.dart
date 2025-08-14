import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import 'package:http/http.dart' as http;


class ChatbotScreen extends StatefulWidget {
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  String? currentUserUid;

  @override
  void initState() {
    super.initState();

    // 현재 로그인된 UID 초기화
    currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    // 로그인/로그아웃 상태 변경 감지
    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        currentUserUid = user?.uid;

        if (user != null) {
          // 새 로그인 시 이전 채팅 초기화
          context.read<ChatProvider>().clearMessages();
        }
      });
    });
  }


  void _sendQuestion() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    if (currentUserUid == null) {
      context.read<ChatProvider>().addBotMessage("로그인 상태가 아닙니다. 먼저 로그인 해주세요.");
      setState(() { _controller.clear(); });
      return;
    }

    // 먼저 입력칸 비우기
    setState(() {
      _controller.clear();
    });

    // 서버에 질문 보내기
    await context.read<ChatProvider>().sendMessage(question, currentUserUid!);
  }



  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final chatMessages = chatProvider.messages;

    return Padding(
      padding: const EdgeInsets.all(16),
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
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(vertical: 4),
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
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(vertical: 4),
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

          if (chatProvider.newSessionAvailable)
            ElevatedButton(
              onPressed: () async {
                if (currentUserUid != null) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  final idToken = await user.getIdToken(true);

                  // uid를 query param으로
                  final url = Uri.parse('http://localhost:8080/chat/reset?uid=$currentUserUid');

                  try {
                    final response = await http.post(
                      url,
                      headers: {
                        "Authorization": "Bearer $idToken", // 인증 헤더 필수
                      },
                    );

                    if (response.statusCode == 200) {
                      chatProvider.clearMessages(); // 프론트 메시지 초기화
                    } else {
                      chatProvider.addBotMessage("서버 세션 초기화 실패: ${response.statusCode}");
                    }
                  } catch (e) {
                    chatProvider.addBotMessage("서버 세션 초기화 오류: $e");
                  }
                }
              },
              child: const Text("새 대화 시작"),
            ),


          TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: "질문 입력"),
            onSubmitted: (_) => _sendQuestion(),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _sendQuestion,
            child: const Text("보내기"),
          ),
        ],
      ),
    );
  }
}
