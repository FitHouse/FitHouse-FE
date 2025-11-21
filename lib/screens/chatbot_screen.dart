import 'package:fithouse/providers/video_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../constants/colors.dart';
import 'video_player_dialog.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../models/exercise_video.dart';

import 'video_list_screen.dart';

import '../api/http_client.dart' show baseUrl, httpClient, authHeaders;

class ChatbotScreen extends StatefulWidget {

  const ChatbotScreen({super.key});
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWelcome();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _displayNameOrEmailPrefix() {
    final u = FirebaseAuth.instance.currentUser;
    final name = (u?.displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = (u?.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    return '회원'; // fallback
  }

  String _welcomeMessage() {
    final hasUser = FirebaseAuth.instance.currentUser != null;
    final who = hasUser ? '${_displayNameOrEmailPrefix()}님' : '';
    return '안녕하세요 $who! \n운동/건강 관련해서 무엇이든 물어보세요.\n\n예: "초보자가 할 수 있는 운동 추천해줘"';
  }

  void _maybeShowWelcome() {
    final chatProv = context.read<ChatProvider>();
    if (chatProv.messages.isEmpty) {
      chatProv.addBotMessage(_welcomeMessage());
    }
  }

  void _sendQuestion() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    if (currentUserUid == null) {
      context.read<ChatProvider>().addBotMessage("로그인 상태가 아닙니다. 먼저 로그인 해주세요.");
      setState(() {
        _controller.clear();
      });
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
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
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
                          child:
                          const Icon(Icons.videocam_off, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "${video.trngNm} \n(기구: ${video.toolNm.isEmpty ? '없음' : video.toolNm})",
                      style: const TextStyle(fontSize: 12),
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

  Widget _buildChatMessage(ChatMessage message, bool isLastMessage) {
    final bool isUser = message.isUser;
    final color = isUser ? const Color(0xFF32CB56) : const Color(0xFFE5E5EA);
    final textColor = isUser ? Colors.white : Colors.black;

    final messageBubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message.text, style: TextStyle(color: textColor)),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.smart_toy, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: messageBubble,
                ),
                if (message.videos.isNotEmpty)
                  _buildVideoRecommendations(message.videos),

                if (!isUser && isLastMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: _buildVideoListButton(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
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
            decoration: const BoxDecoration(
              color: Color(0xFF50D31D),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendQuestion,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoListButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChangeNotifierProvider.value(
              value: context.read<VideoProvider>(),
              child: VideoListScreen(),
            ),
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      child: const Text(
        "운동 영상 모아보기",
        style: TextStyle(
          fontSize: 14,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

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
                  final bool isLastMessage = index == chatMessages.length - 1;
                  return _buildChatMessage(message, isLastMessage);
                },
              ),
            ),

            // 새 대화 시작
            if (chatProvider.newSessionAvailable)
              Padding(
                padding:
                const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
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
                    if (currentUserUid == null) {
                      chatProvider.addBotMessage("로그인 상태가 아닙니다. 먼저 로그인 해주세요.");
                      return;
                    }

                    final url = Uri.parse('$baseUrl/chat/reset')
                        .replace(queryParameters: {'uid': currentUserUid!});

                    try {
                      final response = await httpClient.post(
                        url,
                        headers: await authHeaders(),
                      );
                      if (response.statusCode == 200) {
                        chatProvider.clearMessages();
                        chatProvider.addBotMessage("새로운 대화를 시작합니다.");
                        chatProvider.addBotMessage(_welcomeMessage());
                      } else {
                        chatProvider.addBotMessage(
                            "서버 세션 초기화 실패: ${response.statusCode}");
                      }
                    } catch (e) {
                      chatProvider.addBotMessage("서버 세션 초기화 오류: $e");
                    }
                  },
                  child: const Text("새 대화 시작", style: TextStyle(fontSize: 16)),
                ),
              ),

            if (chatProvider.newSessionAvailable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
              ),

            _buildTextInput(),
          ],
        ),
      ),
    );
  }
}
