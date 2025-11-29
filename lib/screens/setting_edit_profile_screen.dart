import 'dart:io';
import 'package:fithouse/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../api/user_profile_api.dart';
import '../models/user_profile.dart';
import 'password_change_screen.dart';

import '../api/http_client.dart' show baseUrl;

String? _abs(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (!url.startsWith('/')) url = '/$url';
  return '$baseUrl$url';
}

class ProfileData {
  final String nickname;
  final String? birth;
  final String? email;
  final double? heightCm;
  final double? weightKg;

  const ProfileData({
    required this.nickname,
    this.birth,
    this.email,
    this.heightCm,
    this.weightKg,
  });

  ProfileData copyWith({
    String? nickname,
    String? birth,
    String? email,
    double? heightCm,
    double? weightKg,
  }) {
    return ProfileData(
      nickname: nickname ?? this.nickname,
      birth: birth ?? this.birth,
      email: email ?? this.email,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
    );
  }
}

// 내 정보 수정 화면
class SettingEditProfileScreen extends StatefulWidget {
  final ProfileData initial;
  final String? currentImageUrl;
  final bool hasFamily;

  const SettingEditProfileScreen({
    super.key,
    required this.initial,
    this.currentImageUrl,
    this.hasFamily = false,
  });

  @override
  State<SettingEditProfileScreen> createState() =>
      _SettingEditProfileScreenState();
}

class _SettingEditProfileScreenState extends State<SettingEditProfileScreen> {
  final _api = UserProfileApi();
  final _picker = ImagePicker();

  bool _saving = false;
  bool _leaving = false;
  UserProfile? _latestFromServer;

  String? avatarUrl;

  late final TextEditingController _nick;
  late String _birth;
  late String _email;
  late double _heightCm;
  late double _weightKg;

  @override
  void initState() {
    super.initState();
    _nick = TextEditingController(text: widget.initial.nickname);
    _birth = widget.initial.birth ?? '';
    _email = widget.initial.email ?? '';
    _heightCm = widget.initial.heightCm ?? 170;
    _weightKg = widget.initial.weightKg ?? 65;

    avatarUrl = _abs(widget.currentImageUrl);
  }

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  double get _bmi => _weightKg / ((_heightCm / 100) * (_heightCm / 100));

  String _fmtNum(double v) =>
      (v == v.roundToDouble()) ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ===== 이미지 업로드 =====
  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 90,
    );
    if (x == null) return;
    await _uploadAvatar(File(x.path));
  }

  Future<void> _uploadAvatar(File file) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await _api.uploadProfileImage(file.path);
      _latestFromServer = updated;
      setState(() {
        avatarUrl = _abs(updated.profileImageUrl);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진이 업데이트되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAndPop() async {
    if (_saving) return;

    final Map<String, dynamic> payload = {};

    final nicknameNew = _nick.text.trim();
    if (nicknameNew.isNotEmpty && nicknameNew != widget.initial.nickname) {
      payload['name'] = nicknameNew;
    }

    final birthTrim = _birth.trim();
    final birthOld = (widget.initial.birth ?? '').trim();
    final birthValid = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birthTrim);
    if (birthTrim.isNotEmpty && birthTrim != birthOld) {
      if (!birthValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('생년월일은 YYYY-MM-DD 형식으로 입력하세요.')),
        );
        return;
      }
      payload['birthdate'] = birthTrim;
    }

    if (widget.initial.heightCm == null || _heightCm != widget.initial.heightCm) {
      payload['height'] = _heightCm;
    }
    if (widget.initial.weightKg == null || _weightKg != widget.initial.weightKg) {
      payload['weight'] = _weightKg;
    }

    if (payload.isEmpty && _latestFromServer == null) {
      Navigator.pop<UserProfile?>(context, null);
      return;
    }

    setState(() => _saving = true);
    try {
      UserProfile? result;

      if (payload.isNotEmpty) {
        result = await _api.updateProfile(payload);
      }

      result ??= _latestFromServer;

      if (!mounted) return;
      Navigator.pop<UserProfile>(context, result!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<T?> _openSheet<T>(Widget child) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: child,
        );
      },
    );
  }

  Future<T?> _openFullscreen<T>(Widget child) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // [수정] 메인과 동일한 연두색 배경
        backgroundColor: const Color(0xFFA9C18D),
        elevation: 0,
        centerTitle: true,

        // [수정] 흰색 뒤로가기 버튼
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        // [수정] 흰색 제목 글씨 & 폰트 통일
        title: const Text(
          '내 정보 변경',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PyeojinGothic',
          ),
        ),

        actions: [
          TextButton(
            onPressed: _saving ? null : _saveAndPop,
            // [수정] 저장 버튼 색상을 흰색으로 변경
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'PyeojinGothic', // 폰트 통일
              ),
            ),
            child: const Text('저장'),
          ),
        ],

        // 아이콘 테마 흰색 설정
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: ListView(
        padding: const EdgeInsets.only(top: 50, bottom: 12),
        children: [
          // ===== 프로필 이미지 =====
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _pickFromGallery,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                    child: avatarUrl == null ? const Icon(Icons.person, size: 50) : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: buttonGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ===== 닉네임 =====
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('닉네임'),
                const SizedBox(height: 10),
                Stack(
                  children: [
                    TextField(
                      controller: _nick,
                      maxLength: 30,
                      onChanged: (_) => setState(() {}),
                      cursorColor: buttonGreen,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: buttonGreen, width: 2),
                        ),
                        counterText: '',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: TextStyle(fontSize: 16),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 8,
                      child: Text(
                        '(${_nick.text.length}/30)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),

          const _BlockSpacer(),

          // ===== 키·몸무게 + 생년월일 (바텀시트) =====
          _Section(
            child: Column(
              children: [
                _InfoRow(
                  label: '키·몸무게',
                  value:
                  '${_fmtNum(_heightCm)}cm / ${_weightKg.toStringAsFixed(1)}kg (BMI ${_bmi.isFinite ? _bmi.toStringAsFixed(1) : '-'})',
                  onEdit: () async {
                    final res = await _openSheet<_HWResult>(
                      HeightWeightSheet(
                        initHeightCm: _heightCm,
                        initWeightKg: _weightKg,
                      ),
                    );
                    if (res != null) {
                      setState(() {
                        _heightCm = res.heightCm;
                        _weightKg = res.weightKg;
                      });
                    }
                  },
                ),
                const Divider(height: 1),
                _InfoRow(
                  label: '생년월일',
                  value: _birth.isEmpty ? '미설정' : _birth,
                  onEdit: () async {
                    final init = _birth.isEmpty ? null : DateTime.tryParse(_birth);
                    final res = await _openSheet<String>(
                      BirthDateSheet(initial: init),
                    );
                    if (res != null) setState(() => _birth = res);
                  },
                ),
              ],
            ),
          ),

          const _BlockSpacer(),

          // ===== 이메일 (읽기 전용) & 비밀번호 변경 =====
          _Section(
            child: Column(
              children: [
                _InfoRow(
                  label: '이메일',
                  value: _email,
                  showTrailingButton: false,
                  onEdit: () {},
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                const Divider(height: 1),

                // 비밀번호 변경
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  title: const Text(
                    '비밀번호 변경',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  trailing: null,
                  onTap: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    final isEmailPassword =
                        user?.providerData.any((p) => p.providerId == 'password') ?? false;

                    if (!isEmailPassword) {
                      await showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('비밀번호 변경 불가'),
                          content: const Text('소셜 로그인 계정은 비밀번호를 변경할 수 없습니다.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('확인'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    final ok = await _openFullscreen<bool>(const PasswordChangeScreen());
                    if (ok == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const _BlockSpacer(),

          // ===== 가족 탈퇴 =====
          if (widget.hasFamily)
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '가족을 탈퇴하면 가족 피드/기록 공유 기능을 사용할 수 없습니다.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: _leaving
                        ? null
                        : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('가족 탈퇴', textAlign: TextAlign.center),
                          content: const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              '소속 가족에서 탈퇴하시겠어요?\n이 작업은 되돌릴 수 없습니다.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          actions: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      side: const BorderSide(color: buttonGreen),
                                      backgroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('취소', textAlign: TextAlign.center),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: buttonGreen,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(48),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('탈퇴', textAlign: TextAlign.center),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );


                      if (ok != true || !mounted) return;

                      setState(() => _leaving = true);
                      try {
                        final updated = await _api.leaveFamily();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('가족에서 탈퇴했습니다.')),
                        );

                        Navigator.pop<UserProfile>(context, updated);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('탈퇴 실패: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => _leaving = false);
                      }
                    },
                    child: _leaving
                        ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('탈퇴 중...'),
                      ],
                    )
                        : const Text('소속 가족 탈퇴'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ... (아래 _Section, _BlockSpacer, _InfoRow, _FieldLabel, _SheetHandle 등은 기존과 동일)
class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    color: Colors.white,
    child: child,
  );
}

class _BlockSpacer extends StatelessWidget {
  const _BlockSpacer();
  @override
  Widget build(BuildContext context) =>
      Container(height: 8, color: const Color(0xFFF2F3F5));
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;
  final VoidCallback? onTapRow;
  final bool showTrailingButton;
  final EdgeInsetsGeometry? padding;

  const _InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.onEdit,
    this.onTapRow,
    this.showTrailingButton = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    onTap: onTapRow,
    contentPadding: padding ?? const EdgeInsets.symmetric(vertical: 6),
    title: Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    ),
    subtitle: value.isEmpty
        ? null
        : Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.grey,
        ),
      ),
    ),
    trailing: showTrailingButton
        ? TextButton(
      onPressed: onEdit,
      style: TextButton.styleFrom(
        foregroundColor: buttonGreen,
      ),
      child: const Text('변경'),
    )
        : null,
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
  );
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

class TextEditSheet extends StatefulWidget {
  final String label;
  final String initial;
  const TextEditSheet({
    super.key,
    required this.label,
    this.initial = '',
  });

  @override
  State<TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<TextEditSheet> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  final ButtonStyle greenButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: buttonGreen,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: buttonGreen, width: 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 16),
              TextField(
                controller: _c,
                decoration: InputDecoration(
                  labelText: widget.label,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: greenButtonStyle,
                  onPressed: () => Navigator.pop(context, _c.text.trim()),
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeightWeightSheet extends StatefulWidget {
  const HeightWeightSheet({
    super.key,
    required this.initHeightCm,
    required this.initWeightKg,
  });

  final double initHeightCm;
  final double initWeightKg;

  @override
  State<HeightWeightSheet> createState() => _HeightWeightSheetState();
}

class _HeightWeightSheetState extends State<HeightWeightSheet> {
  late final TextEditingController _h;
  late final TextEditingController _w;

  double get _height => double.tryParse(_h.text) ?? 0;
  double get _weight => double.tryParse(_w.text) ?? 0;
  bool get _valid => _height > 0 && _weight > 0;

  String _fmt(double v) =>
      (v == v.roundToDouble()) ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _h = TextEditingController(text: _fmt(widget.initHeightCm));
    _w = TextEditingController(text: widget.initWeightKg.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _h.dispose();
    _w.dispose();
    super.dispose();
  }

  void _bump(TextEditingController c, double delta, {int fractionDigits = 1}) {
    final v = (double.tryParse(c.text) ?? 0) + delta;
    if (v <= 0) return;
    final str =
    (fractionDigits == 0) ? v.round().toString() : v.toStringAsFixed(fractionDigits);
    setState(() => c.text = str);
  }

  final OutlineInputBorder _boxBorder = OutlineInputBorder(
    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
    borderRadius: BorderRadius.circular(12),
  );

  final OutlineInputBorder _focusBorder = OutlineInputBorder(
    borderSide: const BorderSide(color: buttonGreen, width: 2),
    borderRadius: BorderRadius.circular(12),
  );

  final ButtonStyle _saveStyle = ElevatedButton.styleFrom(
    backgroundColor: buttonGreen,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    elevation: 0,
  );

  Widget _unitPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _numberBox({
    required String label,
    required TextEditingController controller,
    required String unitText,
    required int fractionDigits,
    double step = 0.5,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _bump(controller, -step, fractionDigits: fractionDigits),
                icon: const Icon(Icons.remove),
                splashRadius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      cursorColor: buttonGreen,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 16)
                            .copyWith(right: 56),
                        border: _boxBorder,
                        enabledBorder: _boxBorder,
                        focusedBorder: _focusBorder,
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    Positioned(
                      right: 12,
                      child: _unitPill(unitText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _bump(controller, step, fractionDigits: fractionDigits),
                icon: const Icon(Icons.add),
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _save() {
    if (!_valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정상적인 값을 입력하세요.')),
      );
      return;
    }
    Navigator.pop(context, _HWResult(_height, _weight));
  }

  double? _bmiVal() {
    if (_height <= 0 || _weight <= 0) return null;
    final h = _height / 100;
    final bmi = _weight / (h * h);
    return bmi.isFinite ? bmi : null;
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final bmi = _bmiVal();

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

                const SizedBox(height: 15),

                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _numberBox(
                          label: '키',
                          controller: _h,
                          unitText: 'cm',
                          fractionDigits: 0,
                          step: 1,
                        ),

                        const SizedBox(height: 30),

                        _numberBox(
                          label: '몸무게',
                          controller: _w,
                          unitText: 'kg',
                          fractionDigits: 1,
                          step: 0.5,
                        ),

                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              const Text(
                                'BMI',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                bmi == null ? '-' : bmi.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: buttonGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: _saveStyle,
                    onPressed: _save,
                    child: const Text('저장'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HWResult {
  final double heightCm;
  final double weightKg;
  _HWResult(this.heightCm, this.weightKg);
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
  final DateTime _lastDate = DateTime.now();

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _selected =
    (widget.initial != null) ? widget.initial! : DateTime(DateTime.now().year - 20, 1, 1);
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
                    initialDate: _selected,
                    firstDate: _firstDate,
                    lastDate: _lastDate,
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