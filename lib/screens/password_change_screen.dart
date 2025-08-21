// lib/screens/password_change_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _page = PageController();
  int _step = 0;

  final _cur = TextEditingController();
  final _n1  = TextEditingController();
  final _n2  = TextEditingController();

  bool _loading = false;
  String? _curError;

  @override
  void initState() {
    super.initState();
    // 소셜 로그인은 진입 즉시 막기
    final hasPasswordProvider = FirebaseAuth.instance.currentUser
        ?.providerData
        .any((p) => p.providerId == 'password') ?? false;
    if (!hasPasswordProvider) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('소셜 로그인 계정은 비밀번호를 변경할 수 없습니다.')),
        );
        Navigator.pop(context, false);
      });
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _cur.dispose();
    _n1.dispose();
    _n2.dispose();
    super.dispose();
  }

  // 버튼 활성화 조건
  bool get _nextEnabled => _cur.text.trim().length >= 6 && !_loading;
  bool get _confirmEnabled =>
      _n1.text.trim().length >= 6 &&
          _n1.text == _n2.text &&
          !_loading;

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Text(
      t,
      style: Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );

  InputDecoration _deco(String hint, {String? error}) => InputDecoration(
    hintText: hint,
    errorText: error,
    filled: true,
    fillColor: const Color(0xFFF3F5F6),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  // 1단계: 현재 비밀번호 검증
  Future<void> _verifyCurrent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 상태를 확인해주세요.')),
      );
      return;
    }
    setState(() { _loading = true; _curError = null; });
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _cur.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
      if (!mounted) return;
      _curError = null;
      await _page.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      setState(() => _step = 1);
    } on FirebaseAuthException {
      setState(() => _curError = '현재 비밀번호가 올바르지 않습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 2단계: 새 비밀번호 적용
  Future<void> _applyNew() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.currentUser!
          .updatePassword(_n1.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? '변경에 실패했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('비밀번호 변경')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // STEP 0: 현재 비밀번호
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title('비밀번호 변경을 위해\n현재 비밀번호를 입력하세요'),
                      const Text('현재 비밀번호'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cur,
                        obscureText: true,
                        onChanged: (_) => setState(() {}),
                        decoration: _deco('현재 비밀번호 입력', error: _curError),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _nextEnabled ? _verifyCurrent : null,
                          child: _loading
                              ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('다음'),
                        ),
                      ),
                    ],
                  ),
                  // STEP 1: 새 비밀번호
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title('새로운 비밀번호를\n입력해주세요'),
                      const Text('새 비밀번호'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _n1,
                        obscureText: true,
                        onChanged: (_) => setState(() {}),
                        decoration: _deco('새로운 비밀번호 입력'),
                      ),
                      const SizedBox(height: 16),
                      const Text('비밀번호 확인'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _n2,
                        obscureText: true,
                        onChanged: (_) => setState(() {}),
                        decoration: _deco('비밀번호 재확인'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Text('•', style: TextStyle(color: Colors.grey)),
                          ),
                          Expanded(
                            child: Text(
                              '비밀번호는 6자 이상이어야 합니다.',
                              style: TextStyle(
                                color: _n1.text.trim().length >= 6
                                    ? Colors.grey
                                    : Colors.red.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _confirmEnabled ? _applyNew : null,
                          child: _loading
                              ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('확인'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
