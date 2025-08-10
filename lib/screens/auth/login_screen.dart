import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pw.text,
      );
      // 성공 시 AuthGate가 알아서 MainScreen으로 전환됨
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? '로그인 실패');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '비밀번호 재설정: 이메일을 입력하세요.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호 재설정 메일을 보냈습니다.')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? '재설정 메일 발송 실패');
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '이메일'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '이메일을 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pw,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: '비밀번호',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? '비밀번호를 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('로그인'),
              ),
            ),
            TextButton(
              onPressed: _loading ? null : _resetPassword,
              child: const Text('비밀번호 재설정'),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('아직 계정이 없나요?'),
                TextButton(
                  onPressed: _loading ? null : () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                  },
                  child: const Text('회원가입'),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
