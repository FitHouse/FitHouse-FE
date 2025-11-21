import 'package:fithouse/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';

// 이동할 화면들 import
import 'chatbot_screen.dart';
import 'profile_screen.dart'; // 가족핏
import 'step_counter_screen.dart';
import 'community_screen.dart'; // 게시판
import 'group_screen.dart';
import 'record/record_screen.dart';
import 'setting_screen.dart';

// [추가] 운동 영상 화면과 Provider
import 'video_list_screen.dart';
import '../providers/video_provider.dart';

class AllMenuScreen extends StatelessWidget {
  const AllMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 서비스'),
        centerTitle: true,
        automaticallyImplyLeading: false, // 하단 탭으로 이동하므로 뒤로가기 버튼 숨김
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 1. 건강 & 기록 섹션
              _buildSection(
                context,
                title: '💪 건강 & 기록',
                items: [
                  {
                    'icon': Icons.diversity_1,
                    'label': '가족핏',
                    'page': const ProfileScreen(), // 가족/내정보 화면
                    'color': Colors.indigo
                  },
                  {
                    'icon': Icons.fitness_center,
                    'label': '운동 기록',
                    'page': const RecordScreen(), // 앱바에서 이사 온 기능
                    'color': Colors.orange
                  },
                  {
                    'icon': Icons.directions_walk,
                    'label': '만보기',
                    'page': const StepCounterScreen(),
                    'color': Colors.blue
                  },
                  // [추가됨] 운동 영상 모아보기 버튼
                  {
                    'icon': Icons.ondemand_video,
                    'label': '운동 영상',
                    'page': ChangeNotifierProvider.value(
                      value: context.read<VideoProvider>(),
                      child: const VideoListScreen(),
                    ),
                    'color': Colors.redAccent
                  },
                ],
              ),

              const SizedBox(height: 30),

              // 2. 커뮤니티 & 정보 섹션
              _buildSection(
                context,
                title: '🗣️ 소통 & 정보',
                items: [
                  {
                    'icon': Icons.chat_bubble_outline,
                    'label': '커뮤니티',
                    'page': const CommunityScreen(initialIndex: 0), // 게시판 메인
                    'color': Colors.brown
                  },
                  {
                    'icon': Icons.map_outlined,
                    'label': '산책로 추천',
                    'page': const CommunityScreen(initialIndex: 1), // 산책로 탭
                    'color': Colors.green
                  },
                  {
                    'icon': Icons.chat,
                    'label': 'AI 챗봇',
                    'page': ChangeNotifierProvider.value(
                      value: context.read<ChatProvider>(),
                      child: const ChatbotScreen(),
                    ),
                    'color': Colors.indigo
                  },
                ],
              ),

              const SizedBox(height: 30),

              // 3. 관리 & 설정 섹션
              _buildSection(
                context,
                title: '⚙️ 관리 & 설정',
                items: [
                  {
                    'icon': Icons.vpn_key,
                    'label': '가족 코드',
                    'page': const GroupScreen(), // 앱바에서 이사 온 기능
                    'color': Colors.teal
                  },
                  {
                    'icon': Icons.settings,
                    'label': '환경 설정',
                    'page': const SettingScreen(),
                    'color': Colors.grey
                  },
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 섹션(제목 + 그리드)을 만드는 위젯
  Widget _buildSection(BuildContext context,
      {required String title, required List<Map<String, dynamic>> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 15),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(), // 전체 스크롤을 따르도록 설정
          shrinkWrap: true, // 내용물 크기만큼만 공간 차지
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 한 줄에 3개
            mainAxisSpacing: 15, // 세로 간격
            crossAxisSpacing: 15, // 가로 간격
            childAspectRatio: 0.9, // 버튼 비율
          ),
          itemBuilder: (context, index) {
            return _buildMenuCard(context, items[index]);
          },
        ),
      ],
    );
  }

  // 개별 메뉴 카드 디자인
  Widget _buildMenuCard(BuildContext context, Map<String, dynamic> item) {
    return InkWell(
      onTap: () {
        if (item['page'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => item['page']),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('준비 중인 기능입니다.')),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (item['color'] as Color).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item['icon'],
                size: 28,
                color: item['color'],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item['label'],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}