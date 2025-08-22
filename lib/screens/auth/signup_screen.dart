import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fithouse/api/auth_api.dart';
import 'package:fithouse/models/user_entity.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fithouse/constants/colors.dart';


// Role / Gender → 한글 라벨
extension RoleKo on Role {
  String get ko {
    switch (this) {
      case Role.GRANDMA:  return '할머니';
      case Role.GRANDPA:  return '할아버지';
      case Role.MOM:      return '엄마';
      case Role.DAD:      return '아빠';
      case Role.DAUGHTER: return '딸';
      case Role.SON:      return '아들';
    }
  }
}

extension GenderKo on Gender {
  String get ko {
    switch (this) {
      case Gender.MALE:   return '남성';
      case Gender.FEMALE: return '여성';
    }
  }
}

class SignupWizardScreen extends StatefulWidget {
  const SignupWizardScreen({super.key});
  @override
  State<SignupWizardScreen> createState() => _SignupWizardScreenState();
}

class _SignupWizardScreenState extends State<SignupWizardScreen> {
  final _page = PageController();
  int _step = 0;
  final int _totalSteps = 4;

  final _formEmail = GlobalKey<FormState>();
  final _formPw = GlobalKey<FormState>();
  final _formProfile = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _name = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  Gender? _gender;
  DateTime? _birthdate;
  Role? _role;
  XFile? _profileImage;

  bool _showPw = false;
  bool _showPw2 = false;
  bool _loading = false;
  bool _termsAgreed = false;
  String? _error;

  final List<Role> _roleOptions = [
    Role.GRANDMA, Role.GRANDPA, Role.MOM, Role.DAD,
    Role.DAUGHTER, Role.SON
  ];

  final List<Gender> _genderOptions = [Gender.MALE, Gender.FEMALE];

  @override
  void dispose() {
    _page.dispose();
    _email.dispose();
    _pw.dispose();
    _pw2.dispose();
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  // ===== validators =====
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

  String? _validatePw2(String? v) {
    if (v == null || v.isEmpty) return '비밀번호를 한 번 더 입력하세요';
    if (v != _pw.text) return '비밀번호가 일치하지 않습니다';
    return null;
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '닉네임을 입력하세요';
    if (s.length < 2) return '닉네임은 2자 이상';
    final ok = RegExp(r'^[a-zA-Z0-9\u1100-\u11FF\u3130-\u318F\uAC00-\uD7A3._-]+$').hasMatch(s);
    if (!ok) return '영문/한글/숫자/._-만 사용 가능';
    return null;
  }

  String? _validateHeight(String? v) {
    if (v == null || v.isEmpty) return '키를 입력하세요';
    if (double.tryParse(v) == null) return '숫자를 입력하세요';
    return null;
  }

  String? _validateWeight(String? v) {
    if (v == null || v.isEmpty) return '몸무게를 입력하세요';
    if (double.tryParse(v) == null) return '숫자를 입력하세요';
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = pickedFile;
      });
    }
  }

  Future<void> _go(int to) async {
    setState(() => _error = null);
    if (to == _step) return;
    setState(() => _step = to);
    await _page.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _next() async {
    switch (_step) {
      case 0:
        if (!_termsAgreed) return;
        break;
      case 1:
        if (!(_formEmail.currentState?.validate() ?? false)) return;
        break;
      case 2:
        if (!(_formPw.currentState?.validate() ?? false)) return;
        break;
      case 3:
        if (!(_formProfile.currentState?.validate() ?? false)) return;
        if (_gender == null) {
          setState(() => _error = '성별을 선택해주세요.');
          return;
        }
        if (_birthdate == null) {
          setState(() => _error = '생일을 선택해주세요.');
          return;
        }
        if (_role == null) {
          setState(() => _error = '역할을 선택해주세요.');
          return;
        }
        await _submit();
        return;
    }
    await _go(_step + 1);
  }

  Future<void> _prev() async {
    if (_loading) return;
    if (_step == 0) {
      // 첫 페이지에서 뒤로가기 → 로그인 화면으로 복귀
      if (mounted) Navigator.pop(context);
      return;
    }
    await _go(_step - 1);
  }

  Future<bool> _onWillPop() async {
    // 안드로이드 하드웨어 뒤로가기 대응
    if (_loading) return false;
    if (_step == 0) {
      Navigator.pop(context);
      return false;
    }
    await _go(_step - 1);
    return false;
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _email.text.trim().toLowerCase();
    final pw = _pw.text;
    final nickname = _name.text.trim();

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pw,
      );
      final user = cred.user!;
      await user.updateDisplayName(nickname);

      final String? idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw Exception('ID 토큰 발급 실패');
      }

      await AuthApi.registerFirebaseWithProfile(
        idToken: idToken,
        name: nickname,
        email: user.email!,
        gender: _gender!,
        birthdate: DateFormat('yyyy-MM-dd').format(_birthdate!),
        height: double.parse(_height.text),
        weight: double.parse(_weight.text),
        role: _role!,
      );

      if (_profileImage != null) {
        await AuthApi.uploadProfileImage(
          imageFile: io.File(_profileImage!.path),
          firebaseUid: user.uid,
        );
      }

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

  Widget _progressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalSteps, (i) {
        final active = i <= _step;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? buttonGreen : buttonGreen.withOpacity(0.2),
          ),
        );
      }),
    );
  }

  Widget _stepTerms() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.privacy_tip_outlined, size: 72, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                '서비스 이용을 위해 아래 약관을 확인해주세요.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // 약관 카드
              Card(
                elevation: 0,
                color: const Color(0xFFF8F9FB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('이용약관', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('서비스 이용에 관한 기본 약관', style: TextStyle(color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: 이용약관 상세 보기(웹뷰/링크)
                        },
                      ),
                      const Divider(height: 20),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('개인정보 처리방침', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('개인정보 수집 및 이용에 대한 안내', style: TextStyle(color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: 개인정보 처리방침 상세 보기(웹뷰/링크)
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _termsAgreed,
                onChanged: (v) => setState(() => _termsAgreed = v ?? false),
                title: const Text(
                  '위 약관 및 개인정보 처리방침에 동의합니다.',
                  style: TextStyle(fontSize: 14),
                ),
                activeColor: buttonGreen,
                checkColor: Colors.white,
                side: BorderSide(color: buttonGreen),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepEmail() {
    return Form(
      key: _formEmail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이메일을 입력해주세요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: '이메일 주소'),
            validator: _validateEmail,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _next(),
          ),
        ],
      ),
    );
  }

  Widget _stepPassword() {
    return Form(
      key: _formPw,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('사용하실 비밀번호를 입력해주세요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pw,
            obscureText: !_showPw,
            decoration: InputDecoration(
              labelText: '비밀번호 (6자 이상)',
              suffixIcon: IconButton(
                icon:
                Icon(_showPw ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPw = !_showPw),
              ),
            ),
            validator: _validatePw,
            onFieldSubmitted: (_) => _next(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pw2,
            obscureText: !_showPw2,
            decoration: InputDecoration(
              labelText: '비밀번호 확인',
              suffixIcon: IconButton(
                icon:
                Icon(_showPw2 ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPw2 = !_showPw2),
              ),
            ),
            validator: _validatePw2,
            onFieldSubmitted: (_) => _next(),
          ),
          const SizedBox(height: 8),
          Text('• 영문/숫자 조합 권장',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _stepProfile() {
    return Form(
      key: _formProfile,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _profileImage != null
                        ? (!kIsWeb
                        ? FileImage(io.File(_profileImage!.path))
                    as ImageProvider<Object>
                        : Image.network(_profileImage!.path).image)
                        : null,
                    child: _profileImage == null
                        ? Icon(Icons.camera_alt,
                        size: 40, color: Colors.grey.shade600)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child:
                      const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 닉네임 (2~30자, 한글 허용, 카운터 (0/30))
            TextFormField(
              controller: _name,
              keyboardType: TextInputType.name,
              decoration: const InputDecoration(
                labelText: '닉네임',
                counterText: '',
              ),
              inputFormatters: [
                // 한글(자모/완성), 영문/숫자/._- 허용
                FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z0-9\u1100-\u11FF\u3130-\u318F\uAC00-\uD7A3._-]'),
                ),
                LengthLimitingTextInputFormatter(30),
              ],
              maxLength: 30,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              onChanged: (_) => setState(() {}),
              validator: _validateName,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '영문/한글/숫자 및 . _ - 사용 가능 · 최소 2자, 최대 30자',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${_name.text.length}/30)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 역할
            InputDecorator(
              decoration: InputDecoration(
                labelText: '역할',
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Role>(
                  value: _role,
                  isExpanded: true,
                  hint: const Text('역할을 선택하세요'),
                  onChanged: (Role? v) => setState(() => _role = v),
                  items: _roleOptions.map<DropdownMenuItem<Role>>((Role value) {
                    return DropdownMenuItem<Role>(
                      value: value,
                      child: Text(value.ko),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 성별
            InputDecorator(
              decoration: InputDecoration(
                labelText: '성별',
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Gender>(
                  value: _gender,
                  isExpanded: true,
                  hint: const Text('성별을 선택하세요'),
                  onChanged: (Gender? v) => setState(() => _gender = v),
                  items: _genderOptions.map<DropdownMenuItem<Gender>>((Gender value) {
                    return DropdownMenuItem<Gender>(
                      value: value,
                      child: Text(value.ko),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 생일
            TextFormField(
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _birthdate = date);
                }
              },
              decoration: InputDecoration(
                labelText: '생일',
                suffixIcon: const Icon(Icons.calendar_today),
                hintText: _birthdate != null
                    ? DateFormat('yyyy-MM-dd').format(_birthdate!)
                    : '선택해주세요',
              ),
            ),
            const SizedBox(height: 16),

            // 키/몸무게
            TextFormField(
              controller: _height,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '키 (cm)'),
              validator: _validateHeight,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _weight,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '몸무게 (kg)'),
              validator: _validateWeight,
              onFieldSubmitted: (_) => _next(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _totalSteps - 1;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('회원가입'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _prev,
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        body: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 12),
                _progressDots(),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: PageView(
                      controller: _page,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _stepTerms(),
                        _stepEmail(),
                        _stepPassword(),
                        _stepProfile(),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonGreen,
                        disabledBackgroundColor: buttonGreen.withOpacity(0.35),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (!_loading && (_step == 0 ? _termsAgreed : true)) ? _next : null,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_step == _totalSteps - 1 ? '가입하기' : '다음'),
                    ),
                  ),
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PolicyRow({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: 상세 약관 페이지로 이동 (웹뷰/외부링크 등)
      },
    );
  }
}
