import 'package:fithouse/screens/community_screen.dart';
import 'package:fithouse/screens/walk_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';

// Providers
import '../providers/bottom_nav_provider.dart';
import '../providers/video_provider.dart';
import '../providers/ranking_provider.dart';

// Screens
import 'record/record_screen.dart';
import 'video_list_screen.dart';
import 'group_screen.dart';
import 'setting_screen.dart';
import 'ranking_screen.dart';
import 'favorite_video_screen.dart';
import 'walk_screen.dart'; // [필수] 이거 없으면 에러납니다!

class AllMenuScreen extends StatelessWidget {
  const AllMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // 1. 건강 & 기록 섹션
                _buildSection(
                  context,
                  title: '💪 건강 & 기록',
                  crossAxisCount: 3,
                  items: [
                    {
                      'icon': Icons.diversity_1,
                      'label': '가족핏',
                      'type': 'tab', // 탭 이동
                      'index': 1,    // 가족운동 탭
                      'color': Colors.indigo
                    },
                    {
                      'icon': Icons.fitness_center,
                      'label': '운동 기록',
                      'type': 'page', // 페이지 이동
                      'page': const RecordScreen(),
                      'color': Colors.orange
                    },
                    {
                      'icon': Icons.directions_walk,
                      'label': '만보기',
                      'type': 'tab', // 탭 이동
                      'index': 3,    // 만보기 탭
                      'color': Colors.blue
                    },
                    {
                      'icon': Icons.emoji_events_rounded,
                      'label': '랭킹',
                      'type': 'page',
                      'page': ChangeNotifierProvider.value(
                        value: context.read<RankingProvider>(),
                        child: const RankingStepsScreen(initialIndex: 1),
                      ),
                      'color': Colors.amber
                    },
                    {
                      'icon': Icons.ondemand_video,
                      'label': '운동 영상',
                      'type': 'page',
                      'page': ChangeNotifierProvider.value(
                        value: context.read<VideoProvider>(),
                        child: const VideoListScreen(),
                      ),
                      'color': Colors.redAccent
                    },
                    {
                      'icon': Icons.star_rounded,
                      'label': '영상 즐겨찾기',
                      'type': 'page',
                      'page': const FavoriteVideoScreen(),
                      'color': Colors.pinkAccent
                    },
                  ],
                ),

                const SizedBox(height: 30),

                // 2. 소통 & 정보 섹션
                _buildSection(
                  context,
                  title: '🗣️ 소통 & 정보',
                  crossAxisCount: 3,
                  items: [
                    {
                      'icon': Icons.chat_bubble_outline,
                      'label': '커뮤니티',
                      'type': 'tab', // 메인 탭 이동
                      'index': 4,    // 커뮤니티 탭 (이제 게시판만 나옴)
                      'color': Colors.brown
                    },
                    {
                      'icon': Icons.map_outlined,
                      'label': '산책로 추천',
                      'type': 'page', // [변경] 새 페이지로 이동
                      'page': const WalkScreen(), // [변경] WalkScreen 연결
                      'color': Colors.green
                    },
                    {
                      'icon': Icons.chat,
                      'label': 'AI 챗봇',
                      'type': 'tab',
                      'index': 0,
                      'color': Colors.indigo
                    },
                  ],
                ),

                const SizedBox(height: 30),

                // 3. 관리 & 설정 섹션
                _buildSection(
                  context,
                  title: '⚙️ 관리 & 설정',
                  crossAxisCount: 3,
                  items: [
                    {
                      'icon': Icons.vpn_key,
                      'label': '가족 코드',
                      'type': 'page',
                      'page': const GroupScreen(),
                      'color': Colors.teal
                    },
                    {
                      'icon': Icons.settings,
                      'label': '환경 설정',
                      'type': 'page',
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

  Widget _buildSection(BuildContext context, {required String title, required List<Map<String, dynamic>> items, int crossAxisCount = 3}) {
    final double aspectRatio = crossAxisCount == 2 ? 1.4 : 0.9;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 15),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) => _buildMenuCard(context, items[index]),
        ),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, Map<String, dynamic> item) {
    return InkWell(
      onTap: () {
        final type = item['type'];

        // 1. 메인 탭 전환 (가족, 만보기, 챗봇)
        if (type == 'tab') {
          context.read<BottomNavProvider>().changePage(item['index']);
        }
        // 2. 커뮤니티 내부 탭 전환 (게시판 vs 산책로)
        else if (type == 'community') {
          context.read<BottomNavProvider>().goToCommunity(initialTab: item['tabIndex']);
        }
        // 3. 새 페이지 이동 (설정, 기록, 영상 등) - 하단바 가려짐 (정상)
        else if (type == 'page' && item['page'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => item['page']),
          );
        }
        else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('준비 중인 기능입니다.')));
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (item['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(item['icon'], size: 28, color: item['color']),
            ),
            const SizedBox(height: 10),
            Text(item['label'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}