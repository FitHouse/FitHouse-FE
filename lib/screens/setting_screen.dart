import 'package:fithouse/screens/customer_support_screen.dart';
import 'package:fithouse/screens/legal_docs_screen.dart';
import 'package:fithouse/screens/notice_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/user_profile_api.dart';
import '../models/user_profile.dart';
import 'setting_edit_profile_screen.dart';

import '../api/http_client.dart' show baseUrl;

String? _abs(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (!url.startsWith('/')) url = '/$url';
  return '$baseUrl$url';
}

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  late final UserProfileApi _api;
  UserProfile? _profile;
  bool _loading = true;
  String? _error;

  // 앱 버전
  String _appVersion = '-';
  String _buildNumber = '-';

  String _fmtNum(double v) =>
      (v == v.roundToDouble()) ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _api = UserProfileApi();
    _load();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {
      // 실패시 기본값 유지
    }
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
    final bmiStr = (p.bmi == null) ? null : 'BMI: ${p.bmi!.toStringAsFixed(1)}';

    final avatarAbsUrl =
        _abs(p.profileImageUrl) ?? FirebaseAuth.instance.currentUser?.photoURL;
    final nickname = p.name ?? '사용자';
    final familyName = p.familyName;

    final hwLine = '키/몸무게: $heightCm cm / $weightKg kg';

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
                                        .copyWith(
                                        fontWeight: FontWeight.w500, fontSize: 22),
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
                                hwLine,
                                softWrap: false,
                                style: const TextStyle(height: 1.25),
                              ),
                            ),

                            if (bmiStr != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                bmiStr,
                                style: const TextStyle(height: 1.25),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const _BlockSpacer(),

            // ===== 이용 안내 =====
            _SectionHeader('이용 안내', left: 22, fontSize: 18),
            _Section(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('고객센터'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomerSupportScreen()),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('공지사항'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NoticeScreen()),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('약관 및 개인정보 처리방침'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LegalDocsScreen()),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('앱 버전'),
                    subtitle: Text(_appVersion),
                  ),
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
                    title: const Text(
                      '회원 탈퇴',
                      style: TextStyle(color: Colors.red),
                    ),
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

class _SectionHeader extends StatelessWidget {
  final String text;
  final double left;
  final double fontSize;

  const _SectionHeader(
      this.text, {
        super.key,
        this.left = 16,
        this.fontSize = 16,
      });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(left, 14, 16, 8),
    child: Text(
      text,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: fontSize),
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
