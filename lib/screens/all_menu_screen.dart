import 'package:flutter/material.dart';
import '../constants/colors.dart'; // 색상 파일 import (mainGreen 등을 위해)

// 이동할 화면들 import
import 'group_screen.dart';
import 'record/record_screen.dart';
import 'setting_screen.dart';

class AllMenuScreen extends StatelessWidget {
  const AllMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 메뉴 아이템 정의
    final List<Map<String, dynamic>> menuItems = [
      {
        'icon': Icons.group_add,
        'label': '가족 관리',
        'page': const GroupScreen(),
        'color': Colors.lightGreen, // 테마 색상 활용
      },
      {
        'icon': Icons.fitness_center,
        'label': '개인운동 기록',
        'page': const RecordScreen(),
        'color': Colors.orangeAccent,
      },
      {
        'icon': Icons.settings,
        'label': '환경 설정',
        'page': const SettingScreen(),
        'color': Colors.grey,
      },
      // 추후 기능 추가 시 여기에 계속 추가하면 됩니다.
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 서비스'),
        automaticallyImplyLeading: false, // 탭 화면이므로 뒤로가기 숨김
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "바로가기",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: menuItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 한 줄에 3개 배치
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  childAspectRatio: 0.85, // 세로로 약간 긴 비율
                ),
                itemBuilder: (context, index) {
                  return _buildMenuCard(context, menuItems[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, Map<String, dynamic> item) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => item['page']),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
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
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}