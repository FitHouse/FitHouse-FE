// lib/screens/delete_account_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fithouse/api/user_profile_api.dart';
import 'package:fithouse/constants/colors.dart'; // buttonGreen, white, grey 등 정의

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _api = UserProfileApi();
  final _pwController = TextEditingController();

  bool _agreeFamily = false;
  bool _agreeData = false;
  bool _agreeIrrev = false;
  bool _loading = false;

  String? _errorText;

  bool get _isEmailPasswordUser {
    final user = FirebaseAuth.instance.currentUser;
    final providers = user?.providerData.map((e) => e.providerId).toList() ?? [];
    return providers.contains('password');
  }

  bool get _canSubmit {
    final checks = _agreeFamily && _agreeData && _agreeIrrev;
    if (!checks) return false;
    if (_isEmailPasswordUser) {
      return _pwController.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _showOkDialog(String message, {String title = '안내'}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            if (title.isNotEmpty) const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
            ),
            const SizedBox(height: 24),
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
    if (!_canSubmit || _loading) return;
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다.');

      if (_isEmailPasswordUser) {
        final email = user.email;
        final pw = _pwController.text.trim();
        if (email == null || email.isEmpty) {
          throw Exception('이메일을 확인할 수 없습니다.');
        }
        try {
          final cred = EmailAuthProvider.credential(email: email, password: pw);
          await user.reauthenticateWithCredential(cred);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'wrong-password') {
            await _showOkDialog('비밀번호가 일치하지 않습니다.');
            return;
          }
          await _showOkDialog('인증에 실패했습니다. 다시 시도해주세요.');
          return;
        }
      }

      await _api.deleteAccount();

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      await _showOkDialog('회원 탈퇴가 완료되었습니다.');
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString());
      await _showOkDialog('탈퇴에 실패했습니다.\n잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fieldBg = Color(0xFFF5F6F8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('회원 탈퇴'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
        children: [
          const Text(
            '회원 탈퇴 이전에 아래의 사항을 확인해주세요',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.25),
          ),
          const SizedBox(height: 25),

          _InfoCard(children: const [
            _Bullet('현재 소속된 가족이 있을 경우 자동으로 가족에서 탈퇴됩니다.'),
            _Bullet('프로필, 운동 기록 등 개인 데이터는 삭제됩니다.'),
            _Bullet('법령상 보관 대상은 기간 내 보관 후 파기됩니다.'),
            _Bullet('동일 이메일로 재가입 시 신규 계정으로 처리됩니다.'),
          ]),

          const SizedBox(height: 22),

          CheckboxListTile(
            value: _agreeFamily,
            onChanged: _loading ? null : (v) => setState(() => _agreeFamily = v ?? false),
            activeColor: buttonGreen,
            title: const Text('소속 가족 자동 탈퇴에 동의합니다.'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _agreeData,
            onChanged: _loading ? null : (v) => setState(() => _agreeData = v ?? false),
            activeColor: buttonGreen,
            title: const Text('관련 정보 및 개인 데이터 삭제에 동의합니다.'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _agreeIrrev,
            onChanged: _loading ? null : (v) => setState(() => _agreeIrrev = v ?? false),
            activeColor: buttonGreen,
            title: const Text('본 작업은 되돌릴 수 없음을 이해했습니다.'),
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 30),

          if (_isEmailPasswordUser) ...[
            const Text(
              '본인 확인을 위해 비밀번호를 입력해주세요.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _pwController,
              obscureText: true,
              enabled: !_loading,
              decoration: const InputDecoration(
                hintText: '비밀번호',
                hintStyle: TextStyle(color: grey),
                filled: true,
                fillColor: fieldBg,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Color(0xFFDBE1E6)),
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _canSubmit && !_loading ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit ? Colors.red : const Color(0xFFDBE1E6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('회원 탈퇴'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECF0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 6, color: Color(0xFF9AA4AE)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}
