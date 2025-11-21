import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

import 'providers/chat_provider.dart';
import 'providers/video_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/step_counter_screen.dart';
import 'screens/community_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/all_menu_screen.dart'; // 새로 만든 파일 import
import 'screens/group_screen.dart'; // 라우트용
import 'screens/record/record_screen.dart'; // 라우트용
import 'constants/colors.dart';

// 전역 RouteObserver 선언
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;

  if (status.isDenied || status.isRestricted) {
    await Permission.notification.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  requestNotificationPermission();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (context) => VideoProvider(),
      child: const FitHouseApp(),
    ),
  );
}

class FitHouseApp extends StatelessWidget {
  const FitHouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '핏하우스',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: mainGreen,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: mainGreen,
          foregroundColor: black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: white,
          selectedItemColor: naviGreen,
          unselectedItemColor: grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: black),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        fontFamily: 'PyeojinGothic',
        useMaterial3: false,
      ),
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/auth': (_) => const AuthGate(),
        // [참고] 필요하다면 여기에 라우트 추가 가능
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', ''),
        Locale('en', ''),
      ],
      locale: const Locale('ko', ''),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final user = snap.data;
        if (user == null) {
          return const LoginScreen();
        }

        return MultiProvider(
          key: ValueKey(user.uid),
          providers: [
            ChangeNotifierProvider(create: (_) => ChatProvider()),
          ],
          child: MainScreen(),
        );
      },
    );
  }
}


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // [변경 2] 페이지 리스트 수정
  final List<Widget> _pages = [
    ChatbotScreen(),
    ProfileScreen(),
    StepCounterScreen(),
    CommunityScreen(),
    const AllMenuScreen(), // 기존 SettingScreen 대신 전체 메뉴 화면으로 교체
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('핏하우스'),
        centerTitle: true,
        // [변경 3] leading(그룹버튼)과 actions(기록버튼) 삭제 -> 앱바가 깔끔해짐
      ),

      // 화면 상태 유지 (Dispose 방지)
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '챗봇'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '가족운동'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: '만보기'),
          BottomNavigationBarItem(icon: Icon(Icons.cabin), label: '커뮤니티'),
          // [변경 4] 아이콘과 라벨 변경 (설정 -> 전체)
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: '전체'),
        ],
      ),
    );
  }
}