import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../api/auth_api.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();

  final _emailFocus = FocusNode();
  final _pwFocus = FocusNode();
  final _nameFocus = FocusNode();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    _emailFocus.dispose();
    _pwFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // --- Validators ---
  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '닉네임을 입력하세요';
    if (s.length < 2 || s.length > 16) return '닉네임은 2~16자';
    final ok = RegExp(r'^[a-zA-Z0-9가-힣._-]+$').hasMatch(s);
    if (!ok) return '영문/숫자/한글/._-만 사용 가능';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '이메일을 입력하세요';
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
    return ok ? null : '올바른 이메일 형식이 아닙니다';
  }

  String? _validatePw(String? v) {
    if (v == null || v.length < 6) return '비밀번호는 6자 이상';
    return null;
  }

  String _humanizeAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다.';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다(6자 이상).';
      case 'operation-not-allowed':
        return '현재 이메일/비번 가입이 비활성화되어 있습니다.';
      default:
        return e.message ?? '회원가입 실패';
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _email.text.trim().toLowerCase();
    final password = _pw.text;
    final nickname = _name.text.trim();

    setState(() { _loading = true; _error = null; });

    UserCredential? cred;
    try {
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(nickname);

      final idToken = await user.getIdToken(true);

      await AuthApi.registerFirebaseWithProfile(
        idToken: idToken!,
        name: nickname,
        email: email,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 완료!')),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _humanizeAuthError(e));

    } catch (e) {
      setState(() => _error = '서버 오류: $e');

    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_loading;

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _email,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '이메일'),
                validator: _validateEmail,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _pwFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pw,
                focusNode: _pwFocus,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: '비밀번호(6자 이상)',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? '비밀번호 보기' : '비밀번호 가리기',
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: _validatePw,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _nameFocus.requestFocus(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                focusNode: _nameFocus,
                decoration: const InputDecoration(labelText: '닉네임'),
                validator: _validateName,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signUp(),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSubmit ? _signUp : null,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('가입하기'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
