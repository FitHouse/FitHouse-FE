import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'setting_edit_profile_screen.dart'; // ProfileData, SettingEditProfileScreen

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  // 예시 데이터 (실앱: 서버/Firebase에서 불러오기)
  String? avatarUrl;
  String nickname = '홍길동';
  String familyName = '길동패밀리';
  double heightCm = 172;
  double weightKg = 67.3;

  // 알림 스위치 상태
  bool _workoutNoti = true;
  bool _noticeNoti = true;

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그아웃 되었습니다.')),
    );
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.push<ProfileData>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingEditProfileScreen(
          initial: ProfileData(
            nickname: nickname,
            birth: '2000-01-01',
            email: FirebaseAuth.instance.currentUser?.email ?? 'abc1234@naver.com',
            heightCm: heightCm,
            weightKg: weightKg,
          ),
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        nickname = updated.nickname;
        heightCm = updated.heightCm ?? heightCm;
        weightKg = updated.weightKg ?? weightKg;
        // 필요하면 birth/email도 상태로 들고와서 카드에 표시 가능
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        children: [
          // =========================
          // 상단 프로필 카드
          // =========================
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                      child: avatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(height: 1.25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nickname, style: t.titleMedium),
                            const SizedBox(height: 4),
                            Text('가족: $familyName'),
                            Text(
                              '키/몸무게: ${heightCm.toStringAsFixed(0)}cm / ${weightKg.toStringAsFixed(1)}kg (BMI ${bmi.toStringAsFixed(1)})',
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openEditProfile,
                      child: const Text('내 정보 수정'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // =========================
          // 계정 설정
          // =========================
          const _SectionTitle('계정 설정'),
          SwitchListTile(
            title: const Text('운동 알림'),
            value: _workoutNoti,
            onChanged: (v) {
              setState(() => _workoutNoti = v);
              // TODO: FCM/서버와 동기화
            },
          ),
          SwitchListTile(
            title: const Text('공지 알림'),
            value: _noticeNoti,
            onChanged: (v) {
              setState(() => _noticeNoti = v);
              // TODO: 서버와 동기화
            },
          ),
          ListTile(
            title: const Text('계정 연동'),
            subtitle: const Text('Google 연동됨'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 계정 연동 페이지로 이동
            },
          ),

          // =========================
          // 기타
          // =========================
          const _SectionTitle('기타'),
          ListTile(title: const Text('고객센터'), onTap: () {}),
          ListTile(title: const Text('공지사항'), onTap: () {}),
          ListTile(title: const Text('약관 및 개인정보 처리방침'), onTap: () {}),
          const ListTile(title: Text('앱 버전'), subtitle: Text('2.0.7')),

          // =========================
          // 로그아웃 & 회원탈퇴
          // =========================
          ListTile(
            title: const Text('로그아웃'),
            onTap: _signOut,
          ),
          ListTile(
            title: const Text('회원 탈퇴'),
            textColor: Colors.red,
            onTap: () async {
              // TODO: 탈퇴 확인 다이얼로그 + 서버 요청
            },
          ),
          const SizedBox(height: 16),
        ],
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
