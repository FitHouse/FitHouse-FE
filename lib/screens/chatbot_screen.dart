import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../constants/colors.dart';
import 'video_player_dialog.dart';

import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../models/exercise_video.dart';

class ChatbotScreen extends StatefulWidget {
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  // 기능 관련 코드는 그대로 유지됩니다.
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

  // 기존 _buildVideoRecommendations 위젯은 그대로 사용합니다.
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
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return VideoPlayerDialog(videoUrl: video.url);
                },
              );
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

  // --- 🎨 디자인 적용을 위해 추가된 헬퍼 위젯들 ---

  // 새로운 말풍선 디자인을 위한 위젯
  Widget _buildChatMessage(ChatMessage message) {
    final bool isUser = message.isUser;
    final color = isUser ? Color(0xFF32CB56) : Color(0xFFE5E5EA);
    final textColor = isUser ? Colors.white : Colors.black;

    // 말풍선 자체의 디자인은 그대로 유지합니다.
    Widget messageBubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message.text, style: TextStyle(color: textColor)),
    );

    // Row의 구조를 변경하여 아바타와 [말풍선+영상] 컬럼으로 나눕니다.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start, // 아바타와 콘텐츠를 위로 정렬
        children: [
          // 챗봇인 경우에만 아바타 표시
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.smart_toy, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],

          // ## 핵심 변경 ##
          // 말풍선과 영상 목록을 하나의 Column으로 묶어줍니다.
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 1. 말풍선
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: messageBubble,
                ),

                // 2. 영상 추천 목록 (말풍선 바로 아래에 위치)
                if (message.videos.isNotEmpty)
                  _buildVideoRecommendations(message.videos),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 새로운 텍스트 입력창 디자인을 위한 위젯
  Widget _buildTextInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: "Type Message",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onSubmitted: (_) => _sendQuestion(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF50D31D),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _sendQuestion,
            ),
          ),
        ],
      ),
    );
  }

  // --- 🎨 여기가 UI 디자인을 적용하는 핵심 부분입니다 ---
  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final chatMessages = chatProvider.messages;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: chatMessages.length,
                itemBuilder: (context, index) {
                  final message = chatMessages[index];
                  // 기존 itemBuilder 로직 대신 새로운 디자인의 위젯을 호출
                  return _buildChatMessage(message);
                },
              ),
            ),

            // '새 대화 시작' 버튼 (디자인 적용됨)
            if (chatProvider.newSessionAvailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () async {
                    if (currentUserUid != null) {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;
                      final idToken = await user.getIdToken(true);
                      final url = Uri.parse('http://localhost:8080/chat/reset?uid=$currentUserUid');
                      try {
                        final response = await http.post(
                          url,
                          headers: {"Authorization": "Bearer $idToken"},
                        );
                        if (response.statusCode == 200) {
                          chatProvider.clearMessages();
                          chatProvider.addBotMessage("새로운 대화를 시작합니다.");
                        } else {
                          chatProvider.addBotMessage("서버 세션 초기화 실패: ${response.statusCode}");
                        }
                      } catch (e) {
                        chatProvider.addBotMessage("서버 세션 초기화 오류: $e");
                      }
                    }
                  },
                  child: const Text("새 대화 시작", style: TextStyle(fontSize: 16)),
                ),
              ),

            // 새로운 디자인의 텍스트 입력창
            _buildTextInput(),
          ],
        ),
      ),
    );
  }
}