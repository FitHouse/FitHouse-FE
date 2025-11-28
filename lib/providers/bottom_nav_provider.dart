import 'package:flutter/material.dart';

class BottomNavProvider extends ChangeNotifier {
  // 0: 챗봇, 1: 가족운동, 2: 홈(전체메뉴), 3: 만보기, 4: 커뮤니티
  int _currentIndex = 2; // 기본값: 홈

  // 커뮤니티 내부 탭 (0: 게시판, 1: 산책로)
  int _communityTabIndex = 0;

  int get currentIndex => _currentIndex;
  int get communityTabIndex => _communityTabIndex;

  // 단순히 메인 탭만 변경
  void changePage(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  // 커뮤니티 탭으로 이동하면서 내부 탭(게시판/산책로) 설정
  void goToCommunity({int initialTab = 0}) {
    _communityTabIndex = initialTab;
    _currentIndex = 4; // 커뮤니티 탭 인덱스
    notifyListeners();
  }
}