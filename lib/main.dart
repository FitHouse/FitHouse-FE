import 'package:fithouse/providers/ranking_provider.dart';
import 'package:fithouse/services/ranking_service.dart';
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
import 'providers/bottom_nav_provider.dart'; // [필수] 방금 만든 파일 import

// Screens
import 'screens/auth/login_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/ranking_steps_screen.dart';
import 'screens/step_counter_screen.dart';
import 'screens/community_screen.dart';
import 'screens/all_menu_screen.dart';

// Constants
import 'constants/colors.dart';

// 전역 RouteObserver 선언
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (status.isDenied || status.isRestricted) {
    await Permission.notification.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestNotificationPermission();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VideoProvider()),
        // 앱 전체에서 탭 상태를 공유하기 위해 여기에 등록
        ChangeNotifierProvider(create: (_) => BottomNavProvider()),
      ],
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFC7EF98),
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
        fontFamily: 'PyeojinGothic',
        useMaterial3: false,
      ),
      home: const AuthGate(),
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
            ChangeNotifierProvider(create: (_) => RankingProvider(service: const RankingService())),
          ],
          child: const MainScreen(),
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
  // [탭 순서] 0:챗봇, 1:가족, 2:홈(전체메뉴), 3:만보기, 4:커뮤니티
  final List<Widget> _pages = [
    const ChatbotScreen(),
    const ProfileScreen(),
    const AllMenuScreen(),
    const StepCounterScreen(),
    const CommunityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Provider를 통해 현재 탭 번호를 가져옵니다.
    final navProvider = Provider.of<BottomNavProvider>(context);
    final currentIndex = navProvider.currentIndex;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFA9C18D),
        elevation: 0,
        centerTitle: false,
        // [중요] 홈(2번)이 아닐 때만 '뒤로가기(홈으로)' 버튼 표시
        leading: currentIndex != 2
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // 뒤로가기 누르면 홈(2번)으로 이동
            navProvider.changePage(2);
          },
        )
            : null,
        title: Row(
          children: [
            Image.asset(
              'assets/images/splash_logo.png',
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.home_filled, color: mainGreen, size: 28);
              },
            ),
            const SizedBox(width: 8),
            const Text(
              'FitHouse',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                fontFamily: 'PyeojinGothic',
              ),
            ),
          ],
        ),
      ),

      // IndexedStack: 탭이 바뀌어도 화면 상태를 유지해줍니다.
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          // 탭을 누르면 Provider에게 페이지 변경 요청
          navProvider.changePage(index);

          // 만약 만보기(3번)를 눌렀다면 리프레시 로직 실행
          if (index == 3) {
            StepCounterScreenState.instance?.onTabRevisited();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '챗봇'),
          BottomNavigationBarItem(icon: Icon(Icons.diversity_1), label: '가족운동'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: '만보기'),
          BottomNavigationBarItem(icon: Icon(Icons.cabin), label: '커뮤니티'),
        ],
      ),
    );
  }
}