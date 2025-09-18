import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'signup_screen.dart';
import 'package:fithouse/constants/colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pwFocus = FocusNode();

  bool _showPw = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['prefillEmail'] is String) {
      _email.text = (args['prefillEmail'] as String);
      Future.microtask(() => _pwFocus.requestFocus());
      setState(() {});
    }
  }

  bool get _canSubmit =>
      _email.text.trim().isNotEmpty && _pw.text.length >= 6 && !_loading;

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '이메일을 입력하세요';
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
    return ok ? null : '올바른 이메일 형식이 아닙니다';
  }

  String? _validatePw(String? v) {
    if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
    if (v.length < 6) return '비밀번호는 6자 이상';
    return null;
  }

  String _humanizeLoginError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return '올바르지 않은 비밀번호입니다.';
      case 'user-not-found':
      case 'invalid-credential':
        return '올바르지 않은 정보입니다.';
      case 'invalid-email':
        return '올바르지 않은 이메일 형식입니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다. 관리자에게 문의하세요.';
      case 'too-many-requests':
        return '시도가 너무 많습니다. 잠시 후 다시 시도하세요.';
      case 'network-request-failed':
        return '네트워크 오류가 발생했습니다. 연결을 확인하세요.';
      default:
        return e.message ?? '로그인에 실패했습니다.';
    }
  }

  OutlineInputBorder _roundedBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: 1),
  );

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_canSubmit) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pw.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _humanizeLoginError(e));
    } catch (_) {
      setState(() => _error = '알 수 없는 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grey = Colors.grey.shade300;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 200, 16, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'FitHouse',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 60,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: const Color(0xFF488500),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '이메일로 로그인해주세요',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 이메일
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        cursorColor: buttonGreen,
                        decoration: InputDecoration(
                          labelText: '이메일 주소',
                          labelStyle: const TextStyle(color: Color(0xFF4B4B4B)),
                          floatingLabelStyle: const TextStyle(color: buttonGreen),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: _roundedBorder(grey),
                          enabledBorder: _roundedBorder(grey),
                          focusedBorder: _roundedBorder(buttonGreen),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        validator: _validateEmail,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                          setState(() {});
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),

                      // 비밀번호
                      TextFormField(
                        controller: _pw,
                        focusNode: _pwFocus, // 포커스 연결
                        obscureText: !_showPw,
                        cursorColor: buttonGreen,
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          labelStyle: const TextStyle(color: Color(0xFF4B4B4B)),
                          floatingLabelStyle: const TextStyle(color: buttonGreen),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: _roundedBorder(grey),
                          enabledBorder: _roundedBorder(grey),
                          focusedBorder: _roundedBorder(buttonGreen),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPw ? Icons.visibility_off : Icons.visibility,
                              color: buttonGreen,
                            ),
                            onPressed: () =>
                                setState(() => _showPw = !_showPw),
                            tooltip:
                            _showPw ? '비밀번호 숨기기' : '비밀번호 보기',
                          ),
                        ),
                        validator: _validatePw,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                          setState(() {});
                        },
                        onEditingComplete: _submit,
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],

                      const SizedBox(height: 22),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _canSubmit ? _submit : null,
                          child: _loading
                              ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Text('로그인'),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('계정이 없으신가요?'),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: buttonGreen,
                            ),
                            onPressed: _loading
                                ? null
                                : () async {
                              final ok = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const SignupWizardScreen(),
                                ),
                              );
                              if (ok == true && mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text('회원가입이 완료되었습니다.'),
                                  ),
                                );
                              }
                            },
                            child: const Text('회원가입'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
