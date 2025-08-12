import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

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

    currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        currentUserUid = user?.uid;
      });
    });
  }

  void _sendQuestion() {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    if (currentUserUid == null) {
      context.read<ChatProvider>().addBotMessage("로그인 상태가 아닙니다. 먼저 로그인 해주세요.");
      _controller.clear();
      return;
    }

    context.read<ChatProvider>().sendMessage(question, currentUserUid!);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chatMessages = context.watch<ChatProvider>().messages;

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
