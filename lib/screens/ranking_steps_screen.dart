import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../screens/step_counter_screen.dart';  // 기존 만보기 화면
import '../screens/ranking_screen.dart';   // 새로 만든 랭킹 화면

class RankingStepsScreen extends StatelessWidget {
  final int initialIndex;

  const RankingStepsScreen({
    super.key,
    this.initialIndex = 0, // 기본값: 만보기 탭
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
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
                    Tab(text: '만보기'),
                    Tab(text: '랭킹'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    StepCounterScreen(), // 만보기
                    RankingScreen(),   // 랭킹
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
