import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../api/auth_api.dart';

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
  String? _error;

  final List<Role> _roleOptions = [
    Role.GRANDMA, Role.GRANDPA, Role.MOM, Role.DAD,
    Role.DAUGHTER, Role.SON
  ];

  final List<Gender> _genderOptions = [
    Gender.MALE, Gender.FEMALE
  ];

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

  String? _validatePw2(String? v) {
    if (v == null || v.isEmpty) return '비밀번호를 한 번 더 입력하세요';
    if (v != _pw.text) return '비밀번호가 일치하지 않습니다';
    return null;
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '닉네임을 입력하세요';
    if (s.length < 2 || s.length > 16) return '닉네임은 2~16자';
    final ok = RegExp(r'^[a-zA-Z0-9\uAC00-\uD7A3._-]+$').hasMatch(s);
    if (!ok) return '영문/숫자/한글/._-만 사용 가능';
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

  // ---- step 이동 ----
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
    if (_step == 0 || _loading) return;
    await _go(_step - 1);
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
      await user.reload(); // displayName 갱신 반영

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
            color: active ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
          ),
        );
      }),
    );
  }

  Widget _stepTerms() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.description_outlined, size: 72, color: Colors.grey),
          SizedBox(height: 12),
          Text('이용약관은 추후 추가됩니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _stepEmail() {
    return Form(
      key: _formEmail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이메일을 입력해주세요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
          const Text('사용하실 비밀번호를 입력해주세요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pw,
            obscureText: !_showPw,
            decoration: InputDecoration(
              labelText: '비밀번호 (6자 이상)',
              suffixIcon: IconButton(
                icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
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
                icon: Icon(_showPw2 ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPw2 = !_showPw2),
              ),
            ),
            validator: _validatePw2,
            onFieldSubmitted: (_) => _next(),
          ),
          const SizedBox(height: 8),
          Text('• 영문/숫자 조합 권장', style: TextStyle(color: Colors.grey.shade600)),
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
                        ? FileImage(io.File(_profileImage!.path)) as ImageProvider<Object>
                        : Image.network(_profileImage!.path).image)
                        : null,
                    child: _profileImage == null
                        ? Icon(Icons.camera_alt, size: 40, color: Colors.grey.shade600)
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
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: '닉네임'),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\uAC00-\uD7A3._-]')),
              ],
              validator: _validateName,
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                  labelText: '역할',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Role>(
                  value: _role,
                  isExpanded: true,
                  hint: const Text('역할을 선택하세요'),
                  onChanged: (Role? newValue) {
                    setState(() {
                      _role = newValue;
                    });
                  },
                  items: _roleOptions.map<DropdownMenuItem<Role>>((Role value) {
                    return DropdownMenuItem<Role>(
                      value: value,
                      child: Text(value.toString().split('.').last),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            InputDecorator(
              decoration: InputDecoration(
                  labelText: '성별',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Gender>(
                  value: _gender,
                  isExpanded: true,
                  hint: const Text('성별을 선택하세요'),
                  onChanged: (Gender? newValue) {
                    setState(() {
                      _gender = newValue;
                    });
                  },
                  items: _genderOptions.map<DropdownMenuItem<Gender>>((Gender value) {
                    return DropdownMenuItem<Gender>(
                      value: value,
                      child: Text(value.toString().split('.').last),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                hintText: _birthdate != null ? DateFormat('yyyy-MM-dd').format(_birthdate!) : '선택해주세요',
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _height,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '키 (cm)',
              ),
              validator: _validateHeight,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _weight,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '몸무게 (kg)',
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
    final isLast = _step == _totalSteps - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _prev,
        ),
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
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _step == 0 || _loading ? null : _prev,
                        child: const Text('이전'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _next,
                        child: _loading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(isLast ? '가입하기' : '다음'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
