// 가족 초대코드 복사 및 카카오톡 공유 기능 포함 배포용 완성 코드
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart'; // 공유 기능 패키지

import 'package:fithouse/api/http_client.dart';
import 'package:fithouse/screens/record_screen.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _familyNameCtrl = TextEditingController();
  final _familyCommentCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();

  bool _loading = false;
  Map<String, dynamic>? _mine;
  String? _createdInviteCode;

  bool get _inFamily => _mine?['familyId'] != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchMine());
  }

  @override
  void dispose() {
    _familyNameCtrl.dispose();
    _familyCommentCtrl.dispose();
    _inviteCodeCtrl.dispose();
    super.dispose();
  }

  // Firebase 인증 헤더 가져오기
  Future<Map<String, String>> _authHeader() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');
    final idToken = await user.getIdToken(true);
    return {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    };
  }

  // 초대코드 공유 함수
  Future<void> _shareInviteCode(String code) async {
    final message = '핏하우스 가족 초대코드: $code\n앱에서 입력하고 가족으로 함께하세요!';
    await Share.share(message, subject: '핏하우스 가족 초대');
  }

  // 내 가족 정보 불러오기
  Future<void> _fetchMine() async {
    setState(() => _loading = true);
    try {
      final headers = await _authHeader();
      final url = Uri.parse('$baseUrl/family/mine');
      final res = await http.get(url, headers: headers);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _mine = json);
      } else {
        _showSnack('가족 정보를 불러오지 못했습니다.');
      }
    } catch (_) {
      _showSnack('네트워크 연결이 원활하지 않습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 가족 생성
  Future<void> _createFamily() async {
    if (_inFamily) {
      _showSnack('이미 가족이 생성되어 있습니다.');
      return;
    }
    final name = _familyNameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('가족 이름을 입력하세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      final headers = await _authHeader();
      final url = Uri.parse('$baseUrl/family');
      final body = jsonEncode({
        'familyName': name,
        'familyComment': _familyCommentCtrl.text.trim().isEmpty
            ? null
            : _familyCommentCtrl.text.trim(),
      });

      final res = await http.post(url, headers: headers, body: body);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final code = json['inviteCode'] as String?;
        if (code != null) {
          setState(() => _createdInviteCode = code);
        }
        _showSnack('가족이 생성되었습니다.');
        await _fetchMine();
      } else {
        _showSnack('가족 생성에 실패했습니다. 잠시 후 다시 시도해주세요.');
      }
    } catch (_) {
      _showSnack('가족 생성 중 문제가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 가족 가입
  Future<void> _joinFamily() async {
    if (_inFamily) {
      _showSnack('이미 가족에 가입되어 있습니다.');
      return;
    }
    final code = _inviteCodeCtrl.text.trim();
    if (code.isEmpty) {
      _showSnack('초대코드를 입력하세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      final headers = await _authHeader();
      final url = Uri.parse('$baseUrl/family/join');
      final body = jsonEncode({'code': code});
      final res = await http.post(url, headers: headers, body: body);

      if (res.statusCode == 200) {
        _showSnack('가족 가입이 완료되었습니다.');
        await _fetchMine();
      } else if (res.statusCode == 404) {
        _showSnack('존재하지 않는 초대코드입니다. 다시 확인해주세요.');
      } else {
        _showSnack('가족 가입에 실패했습니다. 잠시 후 다시 시도해주세요.');
      }
    } catch (_) {
      _showSnack('가족 가입 중 문제가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 공통 스낵바
  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final familyName = _mine?['familyName'];
    final inviteCode = _mine?['inviteCode'];
    final members = (_mine?['members'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('가족'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchMine,
            color: Colors.green,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(
                  title: '내 가족 정보',
                  trailing: IconButton(
                    onPressed: _fetchMine,
                    icon: const Icon(Icons.refresh, color: Colors.green),
                    tooltip: '새로고침',
                  ),
                ),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: (_mine?['familyId'] == null)
                        ? const _EmptyFamilyView()
                        : _FamilyInfoView(
                      familyName: familyName ?? '',
                      inviteCode: inviteCode,
                      members: members,
                      onShare: _shareInviteCode, // 공유 함수 전달
                    ),
                  ),
                ),

                if (!_inFamily) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(title: '가족 생성'),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _familyNameCtrl,
                            decoration: const InputDecoration(
                              labelText: '가족 이름',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _familyCommentCtrl,
                            decoration: const InputDecoration(
                              labelText: '가족 메모(선택)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: _createFamily,
                              icon: const Icon(Icons.group_add),
                              label: const Text('가족 생성'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_createdInviteCode != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '가족 초대코드',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              _createdInviteCode!,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                          ClipboardData(text: _createdInviteCode!));
                                      _showSnack('초대코드를 복사했습니다.');
                                    },
                                    icon: const Icon(Icons.copy, color: Colors.green),
                                    label: const Text('복사하기'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: const BorderSide(color: Colors.green),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _shareInviteCode(_createdInviteCode!),
                                    icon: const Icon(Icons.share, color: Colors.green),
                                    label: const Text('공유하기'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green,
                                      side: const BorderSide(color: Colors.green),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  _SectionHeader(title: '초대코드로 가입'),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _inviteCodeCtrl,
                            decoration: const InputDecoration(
                              labelText: '초대코드',
                              hintText: '예: ABCD12',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side: const BorderSide(color: Colors.green),
                              ),
                              onPressed: _joinFamily,
                              icon: const Icon(Icons.login),
                              label: const Text('가족 가입'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: Colors.green,
                backgroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Divider(height: 20, thickness: 1, color: Colors.green),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _EmptyFamilyView extends StatelessWidget {
  const _EmptyFamilyView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '가족에 가입되어 있지 않습니다.',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 6),
        Text(
          '가족을 생성하거나 초대코드로 가입하세요.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class _FamilyInfoView extends StatelessWidget {
  final String familyName;
  final String? inviteCode;
  final List members;
  final Future<void> Function(String code)? onShare;

  const _FamilyInfoView({
    required this.familyName,
    this.inviteCode,
    required this.members,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyValueRow(label: '가족 이름', value: familyName),
        if (inviteCode != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 96, child: Text('가족 코드', style: TextStyle(color: Colors.black54))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inviteCode!,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.green),
                tooltip: '복사',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: inviteCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('가족 코드를 복사했습니다.')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.green),
                tooltip: '공유',
                onPressed: () => onShare?.call(inviteCode!),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Text('가족 구성원', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (members.isEmpty)
          const Text('구성원이 없습니다.', style: TextStyle(color: Colors.black54))
        else
          ...members.map((m) {
            final name = m['name'] ?? '';
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.green),
                title: Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.black54,
    );
    final valueStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label, style: labelStyle)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: valueStyle)),
      ],
    );
  }
}
