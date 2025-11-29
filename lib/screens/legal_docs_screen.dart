import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../util/legal_docs_loader.dart';

class LegalDocsScreen extends StatelessWidget {
  const LegalDocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,

        // [수정] 메인 화면과 동일한 디자인의 AppBar 적용
        appBar: AppBar(
          backgroundColor: const Color(0xFFA9C18D), // 연두색 배경
          elevation: 0,
          centerTitle: true,

          // 흰색 뒤로가기 버튼
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),

          // 흰색 제목 글씨 & 폰트 통일
          title: const Text(
            '약관 및 개인정보 처리방침',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              fontFamily: 'PyeojinGothic', // 폰트 통일
            ),
          ),

          // 아이콘 테마 흰색 설정
          iconTheme: const IconThemeData(color: Colors.white),

          // 탭바 디자인 (기존 흰색 배경 유지)
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: Colors.white, // 탭바 영역은 흰색으로
              child: const TabBar(
                labelColor: Color(0xFF32CB56), // 선택된 탭 (초록)
                unselectedLabelColor: grey,    // 선택 안된 탭 (회색)
                indicatorColor: Color(0xFF32CB56), // 인디케이터 (초록)
                tabs: [
                  Tab(text: '개인정보처리방침'),
                  Tab(text: '이용약관'),
                ],
              ),
            ),
          ),
        ),

        body: const TabBarView(
          children: [
            _DocFutureView(loader: LegalDocsLoader.loadPrivacyKo),
            _DocFutureView(loader: LegalDocsLoader.loadTermsKo),
          ],
        ),
      ),
    );
  }
}

class _DocFutureView extends StatelessWidget {
  final Future<String> Function() loader;
  const _DocFutureView({required this.loader});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: loader(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '문서를 불러오지 못했습니다.\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final text = snap.data ?? '';
        return Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: SelectableText(
              text,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
        );
      },
    );
  }
}