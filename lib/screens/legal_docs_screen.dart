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
        backgroundColor: white,
        appBar: AppBar(
          backgroundColor: white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            '약관 및 개인정보 처리방침',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF32CB56),
            unselectedLabelColor: grey,
            indicatorColor: Color(0xFF32CB56),
            tabs: [
              Tab(text: '개인정보처리방침'),
              Tab(text: '이용약관'),
            ],
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
