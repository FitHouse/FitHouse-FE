import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

const String _baseAndroid = 'http://10.0.2.2:8080';
const String _baseOther = 'http://localhost:8080';
String get _baseUrl => Platform.isAndroid ? _baseAndroid : _baseOther;

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _baseUrlCtrl = TextEditingController(text: _baseUrl);
  final _familyNameCtrl = TextEditingController();
  final _familyCommentCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();

  bool _loading = false;
  String _log = '';
  Map<String, dynamic>? _mine;

  String? _createdInviteCode;

  bool get _inFamily => _mine?['familyId'] != null;

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
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
    setState(() {
      _log = '${DateTime.now().toIso8601String()}  $s\n$_log';
    });
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
      final url = Uri.parse('${_baseUrlCtrl.text}/family');
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
      final url = Uri.parse('${_baseUrlCtrl.text}/family/join');
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

  Future<void> _fetchMine() async {
    setState(() => _loading = true);
    try {
      final headers = await _authHeader();
      final url = Uri.parse('${_baseUrlCtrl.text}/family/mine');
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchMine());
  }

  @override
  Widget build(BuildContext context) {
    final familyId = _mine?['familyId'];
    final familyName = _mine?['familyName'];
    final members = (_mine?['members'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('가족 만들기/참여')),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _baseUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: '예: http://10.0.2.2:8080',
              ),
            ),
            const SizedBox(height: 16),

            // 가족 생성 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('가족 생성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _familyNameCtrl,
                      decoration: const InputDecoration(labelText: '가족 이름'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _familyCommentCtrl,
                      decoration: const InputDecoration(labelText: '가족 메모(선택)'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _inFamily ? null : _createFamily,
                      child: const Text('가족 생성'),
                    ),
                  ],
                ),
              ),
            ),

            // 생성된 초대코드 표시
            if (_createdInviteCode != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('생성된 초대코드', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _createdInviteCode!,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          IconButton(
                            tooltip: '복사',
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: _createdInviteCode!));
                              _showSnack('초대코드를 복사했습니다.');
                            },
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 초대코드로 가입
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('초대코드로 가입', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _inviteCodeCtrl,
                      decoration: const InputDecoration(labelText: 'inviteCode'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _inFamily ? null : _joinFamily,
                      child: const Text('가족 가입'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 내 가족 정보
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('내 가족 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          onPressed: _fetchMine,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (familyId == null)
                      const Text('가족에 가입되어 있지 않습니다.')
                    else ...[
                      Text('familyId: $familyId'),
                      Text('familyName: ${familyName ?? ''}'),
                      const SizedBox(height: 8),
                      const Text('Members'),
                      for (final m in members)
                        Text('- ${m['userId']} / ${m['name'] ?? ''} / ${m['gender'] ?? ''}'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Text('요청 로그', style: TextStyle(fontWeight: FontWeight.w600)),
            Container(
              height: 180,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: SingleChildScrollView(child: Text(_log)),
            ),
          ],
        ),
      ),
    );
  }
}
