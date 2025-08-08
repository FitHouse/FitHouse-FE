import 'package:flutter/material.dart';
import 'dart:async'; // 타이머

import 'screens/chatbot_screens.dart';
import 'screens/profile_screen.dart';
import 'screens/step_counter_screen.dart';
import 'screens/community_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/group_screen.dart';
import 'screens/record_screen.dart';
import 'constants/colors.dart';

void main() {
  runApp(FitHouseApp());
}

class FitHouseApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '핏하우스',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: bgBeige,
        primaryColor: mainGreen,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        appBarTheme: AppBarTheme(
          backgroundColor: mainGreen,
          foregroundColor: black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: white,
          selectedItemColor: naviGreen,
          unselectedItemColor: grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: black),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        fontFamily: 'Pretendard',
        useMaterial3: false,
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset('assets/images/splash_logo.png', width: 180),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    ChatbotScreen(),
    ProfileScreen(),
    StepCounterScreen(),
    CommunityScreen(),
    SettingScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('핏하우스'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.group_add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GroupScreen()),
            );
          },
          tooltip: '그룹 만들기/참여',
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.fitness_center),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RecordScreen()),
              );
            },
            tooltip: '개인운동 기록',
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '챗봇',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '가족/내정보',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_walk),
            label: '만보기',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: '커뮤니티',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
