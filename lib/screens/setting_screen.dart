import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../api/user_profile_api.dart';
import '../models/user_profile.dart';
import 'setting_edit_profile_screen.dart';

const _baseUrl = 'http://marketalert.iptime.org:8080';

String? _abs(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (!url.startsWith('/')) url = '/$url';
  return '$_baseUrl$url';
}

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _workoutNoti = true;
  bool _noticeNoti = true;

  late final UserProfileApi _api;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  String _fmtNum(double v) =>
      (v == v.roundToDouble()) ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _api = UserProfileApi();
    _load();
    _printIdToken();
  }

  Future<void> _printIdToken() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
    debugPrint('=== FIREBASE ID TOKEN ===');
    debugPrint(token);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _api.fetchMe();
      if (!mounted) return;
      setState(() => _profile = me);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그아웃 되었습니다.')),
    );
  }

  Future<void> _openEditProfile() async {
    final p = _profile;
    if (p == null) return;

    final initial = ProfileData(
      nickname: p.name ?? (FirebaseAuth.instance.currentUser?.displayName ?? '사용자'),
      birth: p.birthdate,
      email: p.email ?? FirebaseAuth.instance.currentUser?.email,
      heightCm: p.height,
      weightKg: p.weight,
    );

    final updated = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingEditProfileScreen(
          initial: initial,
          currentImageUrl: p.profileImageUrl,
          hasFamily: p.familyId != null,
        ),
      ),
    );

    if (!mounted || updated == null) return;
    setState(() => _profile = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36),
              const SizedBox(height: 8),
              Text(
                '프로필 불러오기 실패',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('다시 시도'))
            ],
          ),
        ),
      );
    }

    final p = _profile!;
    final textTheme = Theme.of(context).textTheme;

    final heightCm = p.height == null ? '-' : _fmtNum(p.height!);
    final weightKg = p.weight == null ? '-' : p.weight!.toStringAsFixed(1);
    final bmi = p.bmi == null ? '-' : p.bmi!.toStringAsFixed(1);

    final avatarAbsUrl =
        _abs(p.profileImageUrl) ?? FirebaseAuth.instance.currentUser?.photoURL;
    final nickname = p.name ?? '사용자';
    final familyName = p.familyName;

    final hwLine = '키/몸무게: $heightCm cm / $weightKg kg';
    final hwWithBmi = (bmi == '-') ? hwLine : '$hwLine (BMI $bmi)';

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ===== 상단 프로필 영역 =====
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 프로필 사진
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: (avatarAbsUrl != null && avatarAbsUrl.isNotEmpty)
                            ? NetworkImage(avatarAbsUrl)
                            : null,
                        child: (avatarAbsUrl == null || avatarAbsUrl.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    nickname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: (textTheme.titleLarge ??
                                        const TextStyle(fontSize: 40))
                                        .copyWith(fontWeight: FontWeight.w500, fontSize: 22),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.settings),
                                  tooltip: '내 정보 수정',
                                  onPressed: _openEditProfile,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // 가족명 (있을 때만)
                            if (familyName != null && familyName.isNotEmpty)
                              Text(
                                '가족: $familyName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(height: 1.25),
                              ),

                            const SizedBox(height: 2),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                hwWithBmi,
                                softWrap: false,
                                style: const TextStyle(height: 1.25),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const _BlockSpacer(),

            const _BoldSectionHeader('계정 설정'),
            _Section(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('운동 알림'),
                    value: _workoutNoti,
                    onChanged: (v) => setState(() => _workoutNoti = v),
                  ),
                  SwitchListTile(
                    title: const Text('공지 알림'),
                    value: _noticeNoti,
                    onChanged: (v) => setState(() => _noticeNoti = v),
                  ),
                  ListTile(
                    title: const Text('계정 연동'),
                    subtitle: const Text('Google 연동됨'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: 계정 연동 상세
                    },
                  ),
                ],
              ),
            ),

            const _BlockSpacer(),

            const _BoldSectionHeader('기타'),
            _Section(
              child: Column(
                children: const [
                  ListTile(title: Text('고객센터')),
                  ListTile(title: Text('공지사항')),
                  ListTile(title: Text('약관 및 개인정보 처리방침')),
                  ListTile(title: Text('앱 버전'), subtitle: Text('2.0.7')),
                ],
              ),
            ),

            const _BlockSpacer(),

            _Section(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('로그아웃'),
                    onTap: _signOut,
                  ),
                  ListTile(
                    title: const Text('회원 탈퇴',
                        style:
                        TextStyle(color: Colors.red)),
                    onTap: () async {
                      // TODO: 탈퇴 확인 + 서버 요청
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BlockSpacer extends StatelessWidget {
  const _BlockSpacer();
  @override
  Widget build(BuildContext context) =>
      Container(height: 6, color: const Color(0xFFF2F3F5));
}

class _BoldSectionHeader extends StatelessWidget {
  final String text;
  const _BoldSectionHeader(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child, super.key});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: child,
  );
}
