import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'community_tab.dart';
import 'walk_tab.dart';

class CommunityScreen extends StatelessWidget {
  // [추가된 부분] 몇 번째 탭을 보여줄지 결정하는 변수
  final int initialIndex;

  const CommunityScreen({
    super.key,
    this.initialIndex = 0, // 기본값은 0 (첫 번째 탭: 커뮤니티)
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex, // [중요] 전달받은 인덱스로 시작 탭 설정
      child: Scaffold(
        backgroundColor: white,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: white,
                child: const TabBar(
                  labelColor: Color(0xFF32CB56),
                  unselectedLabelColor: grey,
                  indicatorColor: Color(0xFF32CB56),
                  tabs: [
                    Tab(text: '커뮤니티'),
                    Tab(text: '산책로 추천'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    CommunityTab(), // index 0
                    WalkTab(),      // index 1
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}