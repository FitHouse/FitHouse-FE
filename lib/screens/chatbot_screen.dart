import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../models/exercise_video.dart';
import 'package:http/http.dart' as http; // '새 대화 시작' 버튼을 위해 필요합니다.

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
      final previousUid = currentUserUid;
      setState(() {
        currentUserUid = user?.uid;
      });
      if (user != null && user.uid != previousUid) {
        context.read<ChatProvider>().clearMessages();
      }
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

    setState(() {
      _controller.clear();
    });

    await context.read<ChatProvider>().sendMessage(question, currentUserUid!);
  }

  Widget _buildVideoRecommendations(List<ExerciseVideo> videos) {
    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return GestureDetector(
            onTap: () async {
              final uri = Uri.parse(video.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    child: Image.network(
                      video.thumbnailUrl,
                      height: 100,
                      width: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 100,
                          width: 150,
                          color: Colors.grey[200],
                          child: Icon(Icons.videocam_off, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "${video.trngNm} \n(기구: ${video.toolNm.isEmpty ? '없음' : video.toolNm})",
                      style: TextStyle(fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
                if (message.isUser) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(message.text),
                    ),
                  );
                } else {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(message.text),
                        ),
                        if (message.videos.isNotEmpty)
                          _buildVideoRecommendations(message.videos),
                      ],
                    ),
                  );
                }
              },
            ),
          ),

          // --- 여기가 빠져있던 부분입니다 ---
          if (chatProvider.newSessionAvailable)
            ElevatedButton(
              onPressed: () async {
                if (currentUserUid != null) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  final idToken = await user.getIdToken(true);

                  final url = Uri.parse('http://localhost:8080/chat/reset?uid=$currentUserUid');

                  try {
                    final response = await http.post(
                      url,
                      headers: {
                        "Authorization": "Bearer $idToken",
                      },
                    );

                    if (response.statusCode == 200) {
                      chatProvider.clearMessages();
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

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: "질문 입력",
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendQuestion(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _sendQuestion,
                child: const Text("보내기"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
