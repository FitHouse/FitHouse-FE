import 'package:flutter/material.dart';
import 'walk_tab.dart'; // 기존에 있던 WalkTab import

class WalkScreen extends StatelessWidget {
  const WalkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 뒤로가기 버튼이 필요하므로 AppBar 추가
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '산책로 추천',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: const SafeArea(
        child: WalkTab(), // 기존 WalkTab 내용을 표시
      ),
    );
  }
}