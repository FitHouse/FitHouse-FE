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
import 'package:fithouse/util/legal_docs_loader.dart';

// Role / Gender → 한글 라벨
extension RoleKo on Role {
  String get ko {
    switch (this) {
      case Role.GRANDMA:
        return '할머니';
      case Role.GRANDPA:
        return '할아버지';
      case Role.MOM:
        return '엄마';
      case Role.DAD:
        return '아빠';
      case Role.DAUGHTER:
        return '딸';
      case Role.SON:
        return '아들';
    }
  }
}

extension GenderKo on Gender {
  String get ko {
    switch (this) {
      case Gender.MALE:
        return '남성';
      case Gender.FEMALE:
        return '여성';
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
  final _birthdateController = TextEditingController();

  Gender? _gender;
  DateTime? _birthdate;
  Role? _role;
  XFile? _profileImage;

  bool _showPw = false;
  bool _showPw2 = false;
  bool _loading = false;
  bool _termsAgreed = false;
  bool _ageConfirmed = false;
  String? _error;

  final List<Role> _roleOptions = [
    Role.GRANDMA,
    Role.GRANDPA,
    Role.MOM,
    Role.DAD,
    Role.DAUGHTER,
    Role.SON
  ];
  final List<Gender> _genderOptions = [Gender.MALE, Gender.FEMALE];

  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  DateTime get _latestAllowedBirthdate {
    final now = DateTime.now();
    return DateTime(now.year - 14, now.month, now.day);
  }

  @override
  void dispose() {
    _page.dispose();
    _email.dispose();
    _pw.dispose();
    _pw2.dispose();
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    _birthdateController.dispose();
    super.dispose();
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

  String? _validatePw2(String? v) {
    if (v == null || v.isEmpty) return '비밀번호를 한 번 더 입력하세요';
    if (v != _pw.text) return '비밀번호가 일치하지 않습니다';
    return null;
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '닉네임을 입력하세요';
    if (s.length < 2) return '닉네임은 2자 이상';
    final ok = RegExp(r'^[a-zA-Z0-9\u1100-\u11FF\u3130-\u318F\uAC00-\uD7A3._-]+$')
        .hasMatch(s);
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
    if (!(_termsAgreed && _ageConfirmed)) return;
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
    setState(() => _error = '생년월일을 선택해주세요.');
    return;
    }
    if (_role == null) {
    setState(() => _error = '역할을 선택해주세요.');
    return;
    }
    if (_ageFrom(_birthdate!) < 14) {
    setState(() => _error = '만 14세 미만은 가입할 수 없습니다.');
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
      if (mounted) Navigator.pop(context);
      return;
    }
    await _go(_step - 1);
  }

  Future<bool> _onWillPop() async {
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

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final m = MediaQuery.of(ctx);
          final capped = m.textScaleFactor.clamp(1.0, 1.05);

          return MediaQuery(
            data: m.copyWith(textScaleFactor: capped),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '회원가입이 완료되었습니다.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        '확인',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _humanizeAuthError(e));
    } catch (e) {
      setState(() => _error = '서버 오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickBirthdateWithDialog() async {
    final media = MediaQuery.of(context);
    final init = _birthdate ?? DateTime(DateTime.now().year - 20, 1, 1);
    final firstDate = DateTime(1900, 1, 1);
    final lastDate = _latestAllowedBirthdate;

    DateTime temp = init.isAfter(lastDate) ? lastDate : init;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final localMedia = MediaQuery.of(ctx);
        final capped = localMedia.textScaleFactor.clamp(1.0, 1.1);
        final double dialogHeight = (media.size.height * 0.65).clamp(360.0, 520.0);

        return MediaQuery(
          data: localMedia.copyWith(textScaleFactor: capped),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            title: const Text(
              '생년월일 선택',
              style: TextStyle(fontWeight: FontWeight.w700),
              overflow: TextOverflow.visible,
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            content: SizedBox(
              width: double.maxFinite,
              height: dialogHeight,
              child: Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: Theme.of(ctx).colorScheme.copyWith(
                    primary: buttonGreen,
                    secondary: buttonGreen,
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: temp,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  onDateChanged: (d) => temp = d,
                ),
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(
                    '${temp.year.toString().padLeft(4, '0')}-'
                        '${temp.month.toString().padLeft(2, '0')}-'
                        '${temp.day.toString().padLeft(2, '0')}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      final picked = DateTime.tryParse(result);
      if (picked != null) {
        if (picked.isAfter(_latestAllowedBirthdate)) {
          setState(() => _error = '만 14세 미만은 가입할 수 없습니다.');
          return;
        }
        setState(() {
          _birthdate = picked;
          _birthdateController.text = DateFormat('yyyy-MM-dd').format(picked);
        });
      }
    }
  }

  // 약관/개인정보 팝업
  Future<void> _openDocDialog({
    required String title,
    required Future<String> loader,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(ctx).size.height * 0.5,
          child: FutureBuilder<String>(
            future: loader,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (snap.hasError) {
                return Center(child: Text('문서를 불러오지 못했습니다: ${snap.error}'));
              }
              final text = snap.data ?? '';
              return Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: SelectableText(
                    text,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                ),
              );
            },
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
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

  Widget _scrollWrap(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
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
                        subtitle:
                        const Text('서비스 이용에 관한 기본 약관', style: TextStyle(color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openDocDialog(
                          title: '이용약관',
                          loader: LegalDocsLoader.loadTermsKo(),
                        ),
                      ),
                      const Divider(height: 20),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title:
                        const Text('개인정보 처리방침', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle:
                        const Text('개인정보 수집 및 이용에 대한 안내', style: TextStyle(color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openDocDialog(
                          title: '개인정보처리방침',
                          loader: LegalDocsLoader.loadPrivacyKo(),
                        ),
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
                title: const Text('위 약관 및 개인정보 처리방침에 동의합니다.', style: TextStyle(fontSize: 14)),
                activeColor: buttonGreen,
                checkColor: Colors.white,
                side: BorderSide(color: buttonGreen),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _ageConfirmed,
                onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
                title: const Text('만 14세 이상입니다.', style: TextStyle(fontSize: 14)),
                subtitle: const Text('만 14세 미만은 가입할 수 없습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
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
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이메일을 입력해주세요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              cursorColor: buttonGreen,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '이메일 주소',
                labelStyle: const TextStyle(color: Color(0xFF4B4B4B)),
                floatingLabelStyle: TextStyle(color: buttonGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: buttonGreen),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: _validateEmail,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _next(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepPassword() {
    return Form(
      key: _formPw,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('사용하실 비밀번호를 입력해주세요',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pw,
              obscureText: !_showPw,
              cursorColor: buttonGreen,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '비밀번호 (6자 이상)',
                labelStyle: const TextStyle(color: Color(0xFF4B4B4B)),
                floatingLabelStyle: TextStyle(color: buttonGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: buttonGreen),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility,
                      color: buttonGreen),
                  onPressed: () => setState(() => _showPw = !_showPw),
                  tooltip: _showPw ? '비밀번호 숨기기' : '비밀번호 보기',
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: _validatePw,
              onFieldSubmitted: (_) => _next(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pw2,
              obscureText: !_showPw2,
              cursorColor: buttonGreen,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '비밀번호 확인',
                labelStyle: const TextStyle(color: Color(0xFF4B4B4B)),
                floatingLabelStyle: TextStyle(color: buttonGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: buttonGreen),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_showPw2 ? Icons.visibility_off : Icons.visibility,
                      color: buttonGreen),
                  onPressed: () => setState(() => _showPw2 = !_showPw2),
                  tooltip: _showPw2 ? '비밀번호 숨기기' : '비밀번호 보기',
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: _validatePw2,
              onFieldSubmitted: (_) => _next(),
            ),
            const SizedBox(height: 8),
            Text('• 영문/숫자 조합 권장', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _stepProfile() {
    final avatarRadius =
    (MediaQuery.of(context).size.width * 0.18).clamp(44.0, 60.0);

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
                    radius: avatarRadius,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _profileImage != null
                        ? (!kIsWeb
                        ? FileImage(io.File(_profileImage!.path))
                    as ImageProvider<Object>
                        : Image.network(_profileImage!.path).image)
                        : null,
                    child: _profileImage == null
                        ? Icon(Icons.camera_alt, size: 40, color: Colors.grey.shade600)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: buttonGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 닉네임
            TextFormField(
              controller: _name,
              keyboardType: TextInputType.name,
              cursorColor: buttonGreen,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '닉네임',
                counterText: '',
                labelStyle: const TextStyle(color: Color(0xFF4B4B4B)),
                floatingLabelStyle: TextStyle(color: buttonGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: buttonGreen),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              inputFormatters: [
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
                Text('(${_name.text.length}/30)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            // 역할
            InputDecorator(
              decoration: InputDecoration(
                labelText: '역할',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Role>(
                  value: _role,
                  isExpanded: true,
                  hint: const Text('역할을 선택하세요'),
                  onChanged: (Role? v) => setState(() => _role = v),
                  items: _roleOptions
                      .map<DropdownMenuItem<Role>>((Role value) =>
                      DropdownMenuItem<Role>(value: value, child: Text(value.ko)))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 성별
            InputDecorator(
              decoration: InputDecoration(
                labelText: '성별',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Gender>(
                  value: _gender,
                  isExpanded: true,
                  hint: const Text('성별을 선택하세요'),
                  onChanged: (Gender? v) => setState(() => _gender = v),
                  items: _genderOptions
                      .map<DropdownMenuItem<Gender>>((Gender value) =>
                      DropdownMenuItem<Gender>(value: value, child: Text(value.ko)))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 생년월일
            TextFormField(
              controller: _birthdateController,
              readOnly: true,
              onTap: _pickBirthdateWithDialog,
              cursorColor: buttonGreen,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '생년월일',
                labelStyle: const TextStyle(color: Color(0xFF4B4B4B)),
                floatingLabelStyle: TextStyle(color: buttonGreen),
                suffixIcon: const Icon(Icons.calendar_today, color: buttonGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: buttonGreen),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 6.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('만 14세 이상만 가입할 수 있습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 16),
            // 키
            TextFormField(
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              cursorColor: buttonGreen,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '키 (cm)',
                labelStyle: const TextStyle(color: Color(0xFF4B4B4B)),
                floatingLabelStyle: TextStyle(color: buttonGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: buttonGreen),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: _validateHeight,
            ),
            const SizedBox(height: 16),
            // 몸무게
            TextFormField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              cursorColor: buttonGreen,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: '몸무게 (kg)',
                labelStyle: const TextStyle(color: Color(0xFF4B4B4B)),
                floatingLabelStyle: TextStyle(color: buttonGreen),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: buttonGreen),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
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
    final media = MediaQuery.of(context);
    final cappedTextScale = media.textScaleFactor.clamp(1.0, 1.2);
    final isLast = _step == _totalSteps - 1;
    final isKeyboardVisible = media.viewInsets.bottom > 0;

    return MediaQuery(
      data: media.copyWith(textScaleFactor: cappedTextScale),
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('회원가입'),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _prev),
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
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        isKeyboardVisible ? 8 : 16,
                      ),
                      child: PageView(
                        controller: _page,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _scrollWrap(_stepTerms()),
                          _scrollWrap(_stepEmail()),
                          _scrollWrap(_stepPassword()),
                          _scrollWrap(_stepProfile()),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                  if (!isKeyboardVisible)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
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
                          onPressed: (!_loading &&
                              (_step == 0 ? (_termsAgreed && _ageConfirmed) : true))
                              ? _next
                              : null,
                          child: _loading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : Text(isLast ? '가입하기' : '다음'),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

class BirthDateSheet extends StatefulWidget {
  final DateTime? initial;
  const BirthDateSheet({super.key, this.initial});

  @override
  State<BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<BirthDateSheet> {
  late DateTime _selected;
  final DateTime _firstDate = DateTime(1900, 1, 1);
  DateTime get _lastDate14 {
    final now = DateTime.now();
    return DateTime(now.year - 14, now.month, now.day);
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final base = widget.initial ?? DateTime(DateTime.now().year - 20, 1, 1);
    _selected = base.isAfter(_lastDate14) ? _lastDate14 : base;
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    final ButtonStyle greenButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: buttonGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
      child: Wrap(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenH * 0.3,
              maxHeight: screenH * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 20),
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: buttonGreen,
                      secondary: buttonGreen,
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate:
                    _selected.isAfter(_lastDate14) ? _lastDate14 : _selected,
                    firstDate: _firstDate,
                    lastDate: _lastDate14,
                    onDateChanged: (d) => setState(() => _selected = d),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: greenButtonStyle,
                    onPressed: () => Navigator.pop(context, _fmt(_selected)),
                    child: const Text('저장'),
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
