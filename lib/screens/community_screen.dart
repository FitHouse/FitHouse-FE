import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'community_tab.dart';
import 'walk_tab.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
                    CommunityTab(),
                    WalkTab(),
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