import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

// Providers
import 'providers/chat_provider.dart';
import 'providers/video_provider.dart';

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/step_counter_screen.dart';
import 'screens/community_screen.dart';
import 'screens/all_menu_screen.dart';
import 'screens/group_screen.dart'; // 라우트용
import 'screens/record/record_screen.dart'; // 라우트용

// Constants
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
      title: 'FitHouse',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: mainGreen,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: const Color(0xFFC7EF98),
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

  final List<Widget> _pages = [
    const ChatbotScreen(),
    const ProfileScreen(),
    const StepCounterScreen(),
    const CommunityScreen(),
    const AllMenuScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // [디자인 수정] 화이트 배경 + 로고 (알림 삭제됨)
        backgroundColor: const Color(0xFFA9C18D),
        elevation: 0,
        centerTitle: false, // 왼쪽 정렬

        title: Row(
          children: [
            // 로고 이미지
            Image.asset(
              'assets/images/splash_logo.png',
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.home_filled,
                    color: mainGreen, size: 28);
              },
            ),
            const SizedBox(width: 8),
            // 텍스트
            const Text(
              'FitHouse',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold, // [수정됨] w900 -> bold (적당한 굵기)
                fontSize: 22,
                fontFamily: 'PyeojinGothic',
              ),
            ),
          ],
        ),
        // actions: [] 부분을 삭제하여 알림 아이콘을 없앴습니다.
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
          BottomNavigationBarItem(icon: Icon(Icons.diversity_1), label: '가족운동'),
          BottomNavigationBarItem(
              icon: Icon(Icons.directions_walk), label: '만보기'),
          BottomNavigationBarItem(icon: Icon(Icons.cabin), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: '전체'),
        ],
      ),
    );
  }
}