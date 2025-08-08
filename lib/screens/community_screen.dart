import 'package:flutter/material.dart';
import '../constants/colors.dart';

class CommunityScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // 탭 개수: 커뮤니티 / 산책로 추천
      child: Column(
        children: [
          Container(
            color: white, // 탭 배경
            child: TabBar(
              labelColor: mainGreen,
              unselectedLabelColor: grey,
              indicatorColor: mainGreen,
              tabs: [
                Tab(text: '커뮤니티'),
                Tab(text: '산책로 추천'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                CommunityTab(),
                WalkTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 커뮤니티 탭 내용
class CommunityTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '커뮤니티 게시글 리스트',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}

// 산책로 추천 탭 내용
class WalkTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '산책로 추천 리스트',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}
