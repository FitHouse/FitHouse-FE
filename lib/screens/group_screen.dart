import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

const String _baseAndroid = 'http://10.0.2.2:8080';
const String _baseOther = 'http://localhost:8080';
String get _baseUrl => Platform.isAndroid ? _baseAndroid : _baseOther;

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
  bool _showDebug = false; // 개발용 로그 패널 토글
  String _log = '';
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

  Future<Map<String, String>> _authHeader() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');
    final idToken = await user.getIdToken(true);
    if (idToken?.isEmpty ?? true) {
      throw Exception('ID 토큰을 가져오지 못했습니다.');
    }
    return {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    };
  }

  void _appendLog(String s) {
    if (!kDebugMode) return;
    setState(() {
      _log = '${DateTime.now().toIso8601String()}  $s\n$_log';
    });
  }

  Future<void> _fetchMine() async {
    setState(() => _loading = true);
    try {
      final headers = await _authHeader();
      final url = Uri.parse('$_baseUrl/family/mine');
      final res = await http.get(url, headers: headers);
      _appendLog('GET /family/mine ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _mine = json);
      } else {
        _showSnack('가족 조회 실패: ${res.statusCode}');
      }
    } catch (e) {
      _showSnack('가족 조회 오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createFamily() async {
    if (_inFamily) {
      _showSnack('이미 가족이 생성되었습니다.');
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
      final url = Uri.parse('$_baseUrl/family');
      final body = jsonEncode({
        'familyName': name,
        'familyComment': _familyCommentCtrl.text.trim().isEmpty
            ? null
            : _familyCommentCtrl.text.trim(),
      });
      final res = await http.post(url, headers: headers, body: body);
      _appendLog('POST /family ${res.statusCode} ${res.body}');

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final code = json['inviteCode'] as String?;
        if (code != null) {
          _inviteCodeCtrl.text = code;
          setState(() => _createdInviteCode = code);
        }
        _showSnack('가족 생성 완료');
        await _fetchMine();
      } else {
        _appendLog('가족 생성 실패 응답: ${res.body}');
        _showSnack('가족 생성 실패: ${res.statusCode}\n${res.body}');
      }
    } catch (e) {
      _showSnack('가족 생성 오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      final url = Uri.parse('$_baseUrl/family/join');
      final body = jsonEncode({'code': code});
      final res = await http.post(url, headers: headers, body: body);
      _appendLog('POST /family/join ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        _showSnack('가족 가입 완료');
        await _fetchMine();
      } else {
        _appendLog('가족 가입 실패 응답: ${res.body}');
        _showSnack('가족 가입 실패: ${res.statusCode}\n${res.body}');
      }
    } catch (e) {
      _showSnack('가족 가입 오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final familyId = _mine?['familyId'];
    final familyName = _mine?['familyName'];
    final members = (_mine?['members'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('가족'),
        centerTitle: true,
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: _showDebug ? '개발용 로그 숨기기' : '개발용 로그 보기',
              onPressed: () => setState(() => _showDebug = !_showDebug),
              icon: const Icon(Icons.bug_report_outlined),
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchMine,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(
                  title: '내 가족 정보',
                  trailing: IconButton(
                    onPressed: _fetchMine,
                    icon: const Icon(Icons.refresh),
                    tooltip: '새로고침',
                  ),
                ),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: familyId == null
                        ? const _EmptyFamilyView()
                        : _FamilyInfoView(
                      familyId: familyId,
                      familyName: familyName ?? '',
                      members: members,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                _SectionHeader(title: '가족 생성'),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
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
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _inFamily ? null : _createFamily,
                            icon: const Icon(Icons.group_add),
                            label: const Text('가족 생성'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_createdInviteCode != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.vpn_key),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SelectableText(
                              _createdInviteCode!,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: _createdInviteCode!));
                              _showSnack('초대코드를 복사했습니다.');
                            },
                            icon: const Icon(Icons.copy),
                            tooltip: '복사',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                _SectionHeader(title: '초대코드로 가입'),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
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
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _inFamily ? null : _joinFamily,
                            icon: const Icon(Icons.login),
                            label: const Text('가족 가입'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (kDebugMode && _showDebug) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(title: '요청 기록(개발용)'),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                    child: SizedBox(
                      height: 180,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: SingleChildScrollView(child: Text(_log)),
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
              child: LinearProgressIndicator(minHeight: 2),
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
    final color = Theme.of(context).textTheme.titleMedium?.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Divider(height: 20, thickness: 0.8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
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
  final dynamic familyId;
  final String familyName;
  final List members;

  const _FamilyInfoView({
    required this.familyId,
    required this.familyName,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyValueRow(label: '가족 ID', value: '$familyId'),
        const SizedBox(height: 6),
        _KeyValueRow(label: '가족 이름', value: familyName),
        const SizedBox(height: 12),
        const Text('가족 구성원', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (members.isEmpty)
          const Text('구성원이 없습니다.', style: TextStyle(color: Colors.black54))
        else
          ...members.map((m) {
            final uid = m['userId'];
            final name = m['name'] ?? '';
            final gender = m['gender'] ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$uid / $name / $gender')),
                ],
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
