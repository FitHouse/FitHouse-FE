import 'package:fithouse/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';

import 'chatbot_screen.dart';
import 'profile_screen.dart';
import 'step_counter_screen.dart';
import 'community_screen.dart';
import 'group_screen.dart';
import 'record/record_screen.dart';
import 'setting_screen.dart';
import 'video_list_screen.dart';
import '../providers/video_provider.dart';

class AllMenuScreen extends StatelessWidget {
  const AllMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // [수정 1] appBar 부분을 아예 삭제했습니다.

      // [수정 2] 상단 상태바(배터리 등)와 겹치지 않게 SafeArea로 감쌉니다.
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // 상단에 약간의 여백 추가 (너무 딱 붙지 않게)
                const SizedBox(height: 10),

                // 1. 건강 & 기록 섹션 (2열 배치 적용됨)
                _buildSection(
                  context,
                  title: '💪 건강 & 기록',
                  crossAxisCount: 2, // 2열
                  items: [
                    {
                      'icon': Icons.diversity_1,
                      'label': '가족핏',
                      'page': const ProfileScreen(),
                      'color': Colors.indigo
                    },
                    {
                      'icon': Icons.fitness_center,
                      'label': '운동 기록',
                      'page': const RecordScreen(),
                      'color': Colors.orange
                    },
                    {
                      'icon': Icons.directions_walk,
                      'label': '만보기',
                      'page': const StepCounterScreen(),
                      'color': Colors.blue
                    },
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

                // 2. 커뮤니티 & 정보 섹션 (3열)
                _buildSection(
                  context,
                  title: '🗣️ 소통 & 정보',
                  crossAxisCount: 3,
                  items: [
                    {
                      'icon': Icons.chat_bubble_outline,
                      'label': '커뮤니티',
                      'page': const CommunityScreen(initialIndex: 0),
                      'color': Colors.brown
                    },
                    {
                      'icon': Icons.map_outlined,
                      'label': '산책로 추천',
                      'page': const CommunityScreen(initialIndex: 1),
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

                // 3. 관리 & 설정 섹션 (3열)
                _buildSection(
                  context,
                  title: '⚙️ 관리 & 설정',
                  crossAxisCount: 3,
                  items: [
                    {
                      'icon': Icons.vpn_key,
                      'label': '가족 코드',
                      'page': const GroupScreen(),
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
      ),
    );
  }

  // 섹션 빌더 함수 (crossAxisCount 지원)
  Widget _buildSection(
      BuildContext context, {
        required String title,
        required List<Map<String, dynamic>> items,
        int crossAxisCount = 3, // 기본값 3열
      }) {
    // 2열일 때는 가로로 넓게(1.4), 3열일 때는 세로로 약간 길게(0.9)
    final double aspectRatio = crossAxisCount == 2 ? 1.4 : 0.9;

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
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            return _buildMenuCard(context, items[index]);
          },
        ),
      ],
    );
  }

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