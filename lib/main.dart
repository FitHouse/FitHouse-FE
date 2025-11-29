import 'package:fithouse/providers/ranking_provider.dart';
import 'package:fithouse/screens/walk_screen.dart';
import 'package:fithouse/services/ranking_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

// [필수] 날짜 형식을 위한 import
import 'package:intl/date_symbol_data_local.dart';

// Providers
import 'providers/chat_provider.dart';
import 'providers/video_provider.dart';
import 'providers/bottom_nav_provider.dart';

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

  // [필수] 앱 실행 전 날짜 데이터 초기화
  await initializeDateFormatting();

  await requestNotificationPermission();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VideoProvider()),
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

      // 한국어 지원 설정
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
      ],

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
          // 선택된 아이콘 색상
          selectedItemColor: Color(0xFFA9C18D),
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
  // [탭 순서] 0:챗봇, 1:가족, 2:홈, 3:만보기, 4:산책로
  final List<Widget> _pages = [
    const ChatbotScreen(),
    const ProfileScreen(),
    const AllMenuScreen(),
    const StepCounterScreen(),
    const WalkScreen(),
  ];

  // [핵심] 탭 인덱스에 따라 앱바 제목 위젯을 반환하는 함수
  Widget _getAppBarTitle(int index) {
    // 요청하신 공통 텍스트 스타일 (흰색, 굵게, 20px)
    const textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 20,
      fontFamily: 'PyeojinGothic',
    );

    // 2번(홈)이 아니면 각 화면에 맞는 한글 텍스트 리턴
    if (index != 2) {
      switch (index) {
        case 0: return const Text('건강 AI', style: textStyle);
        case 1: return const Text('가족운동', style: textStyle);
        case 3: return const Text('만보기', style: textStyle);
        case 4: return const Text('산책로', style: textStyle);
        default: return const Text('FitHouse', style: textStyle);
      }
    }

    // 2번(홈)이면 로고 + 영어 텍스트 리턴
    return Row(
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
          style: textStyle, // 위에서 정의한 스타일 재사용
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<BottomNavProvider>(context);
    final currentIndex = navProvider.currentIndex;

    // 현재 탭이 홈(2번)인지 확인
    final isHome = currentIndex == 2;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFA9C18D),
        elevation: 0,

        // [핵심 1] 정렬 로직: 홈이면 왼쪽 정렬(false), 아니면 가운데 정렬(true)
        centerTitle: !isHome,

        // [핵심 2] 뒤로가기 버튼 로직: 홈이면 없음(null), 아니면 흰색 백버튼(홈으로 이동)
        leading: !isHome
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // 메인 화면 탭에서 뒤로가기는 '홈 탭(2번)'으로 이동
            navProvider.changePage(2);
          },
        )
            : null,

        // [핵심 3] 제목 로직: 함수 호출
        title: _getAppBarTitle(currentIndex),

        // 아이콘 테마 흰색 설정
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          navProvider.changePage(index);
          // 만보기(3번)를 누르면 리프레시
          if (index == 3) {
            StepCounterScreenState.instance?.onTabRevisited();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '챗봇'),
          BottomNavigationBarItem(icon: Icon(Icons.diversity_1), label: '가족운동'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_walk), label: '만보기'),
          // 추천해주신 아이콘 (hiking 추천)
          BottomNavigationBarItem(icon: Icon(Icons.park), label: '산책로'),
        ],
      ),
    );
  }
}