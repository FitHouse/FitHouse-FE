import 'package:flutter/material.dart';

/// =========================
/// 프로필 데이터 모델
/// =========================
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

/// =========================
/// 내 정보 수정 화면
/// =========================
class SettingEditProfileScreen extends StatefulWidget {
  final ProfileData initial;
  const SettingEditProfileScreen({super.key, required this.initial});

  @override
  State<SettingEditProfileScreen> createState() =>
      _SettingEditProfileScreenState();
}

class _SettingEditProfileScreenState extends State<SettingEditProfileScreen> {
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
  }

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  double get _bmi => _weightKg / ((_heightCm / 100) * (_heightCm / 100));

  void _saveAndPop() {
    Navigator.pop(
      context,
      ProfileData(
        nickname: _nick.text.trim(),
        birth: _birth,
        email: _email,
        heightCm: _heightCm,
        weightKg: _weightKg,
      ),
    );
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
        title: const Text('내 정보 변경'),
        actions: [
          TextButton(onPressed: _saveAndPop, child: const Text('저장')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 50, bottom: 12),
        children: [
          // ===== 프로필 이미지 =====
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child:
                  avatarUrl == null ? const Icon(Icons.person, size: 50) : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(padding: const EdgeInsets.all(6)),
                    onPressed: () {
                      // TODO: 이미지 선택/업로드
                    },
                    icon: const Icon(Icons.edit, size: 20),
                  ),
                ),
              ],
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
                TextField(
                  controller: _nick,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    hintText: '사용할 수 있는 닉네임입니다',
                    border: OutlineInputBorder(),
                    counterText: '',
                    isDense: true,
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 16),
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
                  '${_heightCm.toStringAsFixed(0)}cm / ${_weightKg.toStringAsFixed(1)}kg (BMI ${_bmi.isFinite ? _bmi.toStringAsFixed(1) : '-'})',
                  onEdit: () async {
                    final res = await _openSheet<_HWResult>(
                      HeightWeightSheet( // ⬅ 시트 전용
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
                    final res = await _openSheet<String>(
                      TextEditSheet(
                        label: 'YYYY-MM-DD',
                        initial: _birth,
                      ),
                    );
                    if (res != null) setState(() => _birth = res);
                  },
                ),
              ],
            ),
          ),

          const _BlockSpacer(),

          // ===== 이메일 & 비밀번호 변경 (풀스크린) =====
          _Section(
            child: Column(
              children: [
                _InfoRow(
                  label: '이메일',
                  value: _email.isEmpty ? '미등록' : _email,
                  onEdit: () async {
                    final res = await _openFullscreen<String>(
                      const TextEditScreen(title: '이메일 변경', label: '이메일'),
                    );
                    if (res != null) setState(() => _email = res);
                  },
                ),
                const Divider(height: 1),
                _InfoRow(
                  label: '비밀번호 변경',
                  value: '',
                  showTrailingButton: false,
                  onEdit: () {},
                  onTapRow: () async {
                    final ok =
                    await _openFullscreen<bool>(const PasswordChangeScreen());
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
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('가족 탈퇴'),
                        content: const Text('소속 가족에서 탈퇴하시겠어요? 이 작업은 되돌릴 수 없습니다.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('탈퇴'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('가족에서 탈퇴했습니다.')),
                      );
                    }
                  },
                  child: const Text('소속 가족 탈퇴'),
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

/// =========================
/// 공용 위젯
/// =========================

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

/// 정보 행(라벨 굵게 + 값은 회색)
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
        ? TextButton(onPressed: onEdit, child: const Text('변경'))
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

/// =========================
/// 바텀시트 공용 핸들(회색 바)
/// =========================
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

/// =========================
/// 바텀시트용 텍스트 입력 화면 (생년월일 등) - 고정 비율 높이
/// =========================
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

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.25,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 25),
            TextField(
              controller: _c,
              decoration: InputDecoration(
                labelText: widget.label,
                border: const OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _c.text.trim()),
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================
/// 키·몸무게 바텀시트 (고정 비율 높이)
/// =========================
class HeightWeightSheet extends StatefulWidget {
  final double initHeightCm;
  final double initWeightKg;
  const HeightWeightSheet({
    super.key,
    required this.initHeightCm,
    required this.initWeightKg,
  });

  @override
  State<HeightWeightSheet> createState() => _HeightWeightSheetState();
}

class _HeightWeightSheetState extends State<HeightWeightSheet> {
  late final TextEditingController _h;
  late final TextEditingController _w;

  @override
  void initState() {
    super.initState();
    _h = TextEditingController(text: widget.initHeightCm.toStringAsFixed(0));
    _w = TextEditingController(text: widget.initWeightKg.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _h.dispose();
    _w.dispose();
    super.dispose();
  }

  void _save() {
    final h = double.tryParse(_h.text);
    final w = double.tryParse(_w.text);
    if (h == null || h <= 0 || w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정상적인 값을 입력하세요.')),
      );
      return;
    }
    Navigator.pop(context, _HWResult(h, w));
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.25,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _h,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '키 (cm)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _w,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '몸무게 (kg)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 키·몸무게 결과 모델
class _HWResult {
  final double heightCm;
  final double weightKg;
  _HWResult(this.heightCm, this.weightKg);
}

/// =========================
/// 풀스크린 다이얼로그(이메일/비번)
/// =========================
class TextEditScreen extends StatefulWidget {
  final String title;
  final String label;
  final String initial;
  const TextEditScreen({
    super.key,
    required this.title,
    required this.label,
    this.initial = '',
  });

  @override
  State<TextEditScreen> createState() => _TextEditScreenState();
}

class _TextEditScreenState extends State<TextEditScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _c.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _c,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}

/// 비밀번호 변경(풀스크린)
class PasswordChangeScreen extends StatelessWidget {
  const PasswordChangeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('비밀번호 변경'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Firebase updatePassword 로직
              Navigator.pop(context, true);
            },
            child: const Text('저장'),
          )
        ],
      ),
      body: const Center(child: Text('비밀번호 변경 화면 구현 예정')),
    );
  }
}
