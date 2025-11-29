import 'package:flutter/material.dart';
import 'walk_tab.dart'; // 기존에 있던 WalkTab import

class WalkScreen extends StatelessWidget {
  const WalkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 메인 화면(MainScreen)의 Scaffold 안에 들어가므로
    // 여기서는 별도의 AppBar 없이 내용만 반환하거나
    // 배경색 지정을 위해 Scaffold(body: ...)만 남겨둡니다.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: WalkTab(),
    );
  }
}