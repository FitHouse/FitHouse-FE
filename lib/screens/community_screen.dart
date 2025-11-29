import 'package:flutter/material.dart';
import 'community_tab.dart'; // 내용물 import

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // [여기에 앱바를 만듭니다]
      appBar: AppBar(
        backgroundColor: const Color(0xFFA9C18D), // 메인과 동일한 연두색
        elevation: 0,
        centerTitle: true,

        // 뒤로가기 버튼
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        // 제목
        title: const Text(
          '커뮤니티',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'NanumGothic',
          ),
        ),

        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // [내용물 연결] 여기에 CommunityTab을 넣습니다.
      body: const CommunityTab(),
    );
  }
}