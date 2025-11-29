import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // [필수] Provider 사용을 위해 추가
import '../providers/bottom_nav_provider.dart'; // [필수] Provider 파일 import
import '../constants/colors.dart';
import 'community_tab.dart';
import 'walk_tab.dart';
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 탭 컨트롤러, 탭바 모두 제거하고 바로 내용물(CommunityTab)만 보여줍니다.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CommunityTab(),
      ),
    );
  }
}