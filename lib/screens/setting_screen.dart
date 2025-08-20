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

  // 정수면 170, 소수면 177.7 로 표시
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
    final themeText = Theme.of(context).textTheme;

    // ✅ 여기서 소수 유지 포맷 적용
    final heightCm = p.height == null ? '-' : _fmtNum(p.height!);
    final weightKg = p.weight == null ? '-' : p.weight!.toStringAsFixed(1);
    final bmi = p.bmi == null ? '-' : p.bmi!.toStringAsFixed(1);

    final avatarAbsUrl = _abs(p.profileImageUrl) ?? FirebaseAuth.instance.currentUser?.photoURL;
    final nickname = p.name ?? '사용자';
    final familyName = p.familyName;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // 상단 프로필 카드
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
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
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(height: 1.25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nickname, style: themeText.titleMedium),
                              const SizedBox(height: 4),
                              if (familyName != null && familyName.isNotEmpty)
                                Text('가족: $familyName'),
                              Text('키/몸무게: $heightCm cm / $weightKg kg'),
                              Text('BMI: $bmi'),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        tooltip: '내 정보 수정',
                        onPressed: _openEditProfile,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 계정 설정
            const _SectionTitle('계정 설정'),
            SwitchListTile(
              title: const Text('운동 알림'),
              value: _workoutNoti,
              onChanged: (v) {
                setState(() => _workoutNoti = v);
                // TODO: 서버/FCM 동기화 필요 시 붙이기
              },
            ),
            SwitchListTile(
              title: const Text('공지 알림'),
              value: _noticeNoti,
              onChanged: (v) {
                setState(() => _noticeNoti = v);
                // TODO: 서버 동기화
              },
            ),
            ListTile(
              title: const Text('계정 연동'),
              subtitle: const Text('Google 연동됨'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 계정 연동 상세 화면
              },
            ),

            // 기타
            const _SectionTitle('기타'),
            ListTile(title: const Text('고객센터'), onTap: () {}),
            ListTile(title: const Text('공지사항'), onTap: () {}),
            ListTile(title: const Text('약관 및 개인정보 처리방침'), onTap: () {}),
            const ListTile(title: Text('앱 버전'), subtitle: Text('2.0.7')),

            ListTile(
              title: const Text('로그아웃'),
              onTap: _signOut,
            ),
            ListTile(
              title: const Text('회원 탈퇴'),
              textColor: Colors.red,
              onTap: () async {
                // TODO
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall,
    ),
  );
}
