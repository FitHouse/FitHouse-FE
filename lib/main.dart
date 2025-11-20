import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/chat_provider.dart';
import 'providers/video_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/step_counter_screen.dart';
import 'screens/community_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/group_screen.dart';
import 'screens/record/record_screen.dart';
import 'constants/colors.dart';

// 전역 RouteObserver 선언
final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    // OS 스플래시 이후 바로 첫 프레임을 그리기 위해 StreamBuilder만 사용
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        // 대기 상태에서도 추가 스플래시/로딩 UI를 띄우지 않음
        if (snap.connectionState == ConnectionState.waiting) {
          // 첫 프레임을 가능한 빨리 그리도록 빈 위젯 반환
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

  final List<Widget> _pages = [
    ChatbotScreen(),
    ProfileScreen(),
    StepCounterScreen(),
    CommunityScreen(),
    SettingScreen(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('핏하우스'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.group_add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GroupScreen()),
            );
          },
          tooltip: '그룹 만들기/참여',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordScreen()),
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
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '챗봇'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '가족/내정보'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: '만보기'),
          BottomNavigationBarItem(icon: Icon(Icons.cabin), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
