import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';

import '../api/http_client.dart' show baseUrl, postJson;

class CustomerSupportScreen extends StatelessWidget {
  const CustomerSupportScreen({super.key});

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
            '고객센터',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
              fontFamily: 'PyeojinGothic', // 메인과 동일한 폰트
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
                labelColor: Color(0xFF32CB56), // 선택된 탭 글씨색 (초록)
                unselectedLabelColor: grey,    // 선택 안된 탭 글씨색 (회색)
                indicatorColor: Color(0xFF32CB56), // 하단 인디케이터 색상 (초록)
                tabs: [
                  Tab(text: '도움말'),
                  Tab(text: '문의하기'),
                ],
              ),
            ),
          ),
        ),

        body: const TabBarView(
          children: [
            FaqTab(),
            InquiryTab(),
          ],
        ),
      ),
    );
  }
}

/// ================== 도움말(FAQ) ==================
class FaqTab extends StatelessWidget {
  const FaqTab({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': '가족을 추가하려면 어떻게 하나요?',
        'a': '앱 바 왼쪽 상단의 아이콘을 눌러 가족 페이지에 진입합니다. '
            '가족 그룹을 생성하거나 다른 가족 구성원에게 가족 코드를 공유 받아 가족 그룹에 가입할 수 있습니다.'
      },
      {
        'q': '운동 기록은 어디서 확인할 수 있나요?',
        'a': '가족/내정보 화면 내의 "내 기록" 버튼을 눌러 개인 운동 화면에서 확인할 수 있습니다.'
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: faqs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final faq = faqs[i];
        return _FaqItem(question: faq['q']!, answer: faq['a']!);
      },
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      dividerColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      listTileTheme: const ListTileThemeData(
        textColor: Colors.black,
        iconColor: Colors.black,
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: theme,
        child: ExpansionTile(
          onExpansionChanged: (v) => setState(() => _expanded = v),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Text(
            widget.question,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.black,
            ),
          ),
          trailing: RotationTransition(
            turns: AlwaysStoppedAnimation(_expanded ? 0.5 : 0),
            child: const Icon(Icons.expand_more, color: Colors.black),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.answer,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF5F6368),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================== 문의하기 ==================
class InquiryTab extends StatefulWidget {
  const InquiryTab({super.key});
  @override
  State<InquiryTab> createState() => _InquiryTabState();
}

class _InquiryTabState extends State<InquiryTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _agreed = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = FirebaseAuth.instance.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _isEmailValid(String v) {
    final s = v.trim();
    if (s.isEmpty) return false;
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(s);
  }

  bool get _isValid {
    final t = _titleCtrl.text.trim();
    final b = _bodyCtrl.text.trim();
    final e = _emailCtrl.text.trim();
    return t.isNotEmpty && t.length <= 20 && b.isNotEmpty && _isEmailValid(e) && _agreed;
  }

  Future<void> _showSubmittedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              '문의가 접수되었습니다.\n작성해주신 이메일로 답변이 전송됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
            ),
            SizedBox(height: 28),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonGreen,
                foregroundColor: white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('확인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_isValid || _sending) return;

    setState(() => _sending = true);
    try {
      final payload = {
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      };

      final res = await postJson('$baseUrl/support/inquiries', payload)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _titleCtrl.clear();
        _bodyCtrl.clear();
        setState(() => _agreed = false);
        await _showSubmittedDialog();
      } else {
        String msg = '문의 접수 실패 (${res.statusCode})';
        try {
          final m = jsonDecode(res.body);
          if (m is Map && m['message'] is String) msg = m['message'];
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const fieldBg = Color(0xFFF5F6F8);

    final submitEnabled = _isValid && !_sending;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '답변까지 1-5일의 시간이 소요될 수 있습니다. 순차적으로 확인 후 답변드립니다.',
                    style: TextStyle(fontSize: 13, color: grey),
                  ),
                  const SizedBox(height: 16),

                  Stack(
                    children: [
                      TextFormField(
                        controller: _titleCtrl,
                        maxLength: 20,
                        buildCounter: (_, {required currentLength, maxLength, required isFocused}) =>
                        const SizedBox.shrink(),
                        decoration: const InputDecoration(
                          hintText: '제목을 입력해주세요. (20자 이내)',
                          hintStyle: TextStyle(color: grey),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Text(
                          '${_titleCtrl.text.trim().length}/20',
                          style: const TextStyle(fontSize: 12, color: grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _bodyCtrl,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '문의하실 내용을 입력해주세요',
                      hintStyle: TextStyle(color: grey),
                      filled: true,
                      fillColor: fieldBg,
                      contentPadding: EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    '연락 받을 이메일',
                    style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: '이메일을 입력해주세요',
                      hintStyle: TextStyle(color: grey),
                      filled: true,
                      fillColor: fieldBg,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 35),

                  const Text(
                    '개인정보 수집 및 이용',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Transform.scale(
                        scale: 0.95,
                        child: Checkbox(
                          value: _agreed,
                          onChanged: (v) => setState(() => _agreed = v ?? false),
                          activeColor: buttonGreen,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '개인정보 수집 및 이용 동의(필수)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '문의 처리를 위해 이메일, 문의 내용이 포함된 개인정보를 수집하며, '
                          '개인정보처리방침에 따라 3년 후 파기됩니다. '
                          '개인정보 수집 및 이용을 거부할 수 있으며, 거부할 경우 문의가 불가합니다.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),

        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: submitEnabled ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: submitEnabled ? buttonGreen : const Color(0xFFDBE1E6),
                foregroundColor: white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _sending
                  ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                '문의 접수하기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }
}