import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:fithouse/api/http_client.dart';
import 'package:fithouse/api/personal_workout_api.dart';
import 'package:fithouse/models/paged.dart';
import 'package:fithouse/models/personal_workout.dart';


String moodEmoji(int? level) {
  switch (level) {
    case 1:
      return '😵';
    case 2:
      return '🙂';
    case 3:
      return '😄';
    default:
      return '❓';
  }
}

Color moodColor(int? level) {
  switch (level) {
    case 1:
      return Colors.redAccent;
    case 2:
      return Colors.amber;
    case 3:
      return Colors.green;
    default:
      return Colors.grey;
  }
}

Widget moodBadge(int? level) {
  final color = moodColor(level);
  return CircleAvatar(
    radius: 18,
    backgroundColor: color.withOpacity(0.15),
    child: Text(moodEmoji(level), style: const TextStyle(fontSize: 18)),
  );
}

String roleLabel(String? role) {
  switch (role) {
    case 'GRANDMA':
      return '할머니';
    case 'GRANDPA':
      return '할아버지';
    case 'MOM':
      return '엄마';
    case 'DAD':
      return '아빠';
    case 'DAUGHTER':
      return '딸';
    case 'SON':
      return '아들';
    default:
      return role ?? '역할없음';
  }
}

String genderLabel(String? gender) {
  switch (gender) {
    case 'MALE':
      return '남';
    case 'FEMALE':
      return '여';
    default:
      return gender ?? '-';
  }
}

String normalizeUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  final u = url.trim();
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  if (u.startsWith('/')) return '$assetBaseUrl$u';
  return '$assetBaseUrl/$u';
}

class RecordScreen extends StatefulWidget {
  final int? userId;
  const RecordScreen({super.key, this.userId});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final PersonalWorkoutApi api = PersonalWorkoutApi();
  final ScrollController _scroll = ScrollController();

  final List<PersonalWorkout> _items = [];
  bool _loading = false;
  bool _initialLoaded = false;
  int _page = 0;
  final int _size = 20;
  bool _hasMore = true;

  double? _heightCm;
  double? _weightKg;
  int? _age;

  String? _name;
  String? _role;
  String? _email;
  String? _gender;
  DateTime? _birthdate;
  String? _familyName;
  bool _detailsOpen = false;

  bool _myInfoLoading = false;
  String? _myInfoError;

  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadMyInfo();
    _loadInitial();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double get _bmi {
    final h = (_heightCm ?? 0) / 100.0;
    final w = _weightKg ?? 0;
    if (h <= 0 || w <= 0) return 0;
    return double.parse((w / (h * h)).toStringAsFixed(1));
  }

  int _calcAge(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  // 1. _loadMyInfo() 수정: userId에 따라 다른 API 호출
  Future<void> _loadMyInfo() async {
    setState(() {
      _myInfoLoading = true;
      _myInfoError = null;
    });
    try {
      final uri = Uri.parse(
          widget.userId == null
              ? '$baseUrl/api/users/me'
              : '$baseUrl/family/member/${widget.userId}'
      );
      final res =
      await httpClient.get(uri, headers: await authHeaders(json: false));

      if (res.statusCode != 200) {
        setState(() {
          _myInfoError = '서버 오류: ${res.statusCode}';
        });
        return;
      }

      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      final info = MyInfo.fromJson(jsonMap);

      setState(() {
        _name = info.name;
        _role = info.role;
        _email = info.email;
        _gender = info.gender;
        _birthdate = info.birthdate;
        _age = info.birthdate != null ? _calcAge(info.birthdate!) : info.age;
        _heightCm = info.height;
        _weightKg = info.weight;
        _familyName = info.familyName;
        _profileImageUrl = normalizeUrl(info.profileImageUrl);
      });
    } catch (_) {
      setState(() {
        _myInfoError = '서버 오류';
      });
    } finally {
      if (mounted) {
        setState(() {
          _myInfoLoading = false;
        });
      }
    }
  }

  // 2. _loadInitial() 수정: userId에 따라 다른 API 호출 및 파싱 로직 변경
  Future<void> _loadInitial() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final Paged<PersonalWorkout> resp;
      if (widget.userId == null) {
        // 본인 기록 API
        print('My workout record API call');
        resp = await api.list(page: 0, size: _size);
      } else {
        // 가족 구성원 기록 API 호출 (URL 수정 및 데이터 파싱 방식 변경)
        final uri = Uri.parse('$baseUrl/family/member/${widget.userId}?page=0&size=$_size');
        print('Family member workout record API call: $uri');
        final res = await httpClient.get(uri, headers: await authHeaders());
        print('Response status code: ${res.statusCode}');
        print('Response body: ${res.body}'); // Add log here
        final data = jsonDecode(res.body);

        if (data != null && data['workouts'] is Map<String, dynamic>) {
          resp = Paged.fromJson(data['workouts'], PersonalWorkout.fromJson);
        } else {
          resp = Paged(content: [], page: 0, totalPages: 0);
          print('Workout record data is missing or in an invalid format.');
        }
      }

      setState(() {
        _items
          ..clear()
          ..addAll(resp.content);
        _page = 0;
        _hasMore = _page + 1 < resp.totalPages;
        _initialLoaded = true;
      });
    } catch (e) {
      print('API call error: $e');
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 3. _loadMore() 수정: userId에 따라 다른 API 호출 및 파싱 로직 변경
  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final next = _page + 1;
      final Paged<PersonalWorkout> resp;
      if (widget.userId == null) {
        resp = await api.list(page: next, size: _size);
      } else {
        // 가족 구성원 기록 API 호출 (URL 수정 및 데이터 파싱 방식 변경)
        final uri = Uri.parse('$baseUrl/family/member/${widget.userId}?page=$next&size=$_size');
        final res = await httpClient.get(uri, headers: await authHeaders());
        final data = jsonDecode(res.body);

        // 'workoutDTOs' 필드를 추출하여 파싱합니다.
        // 해당 필드가 null이거나 유효하지 않은 경우를 대비한 방어 로직 추가
        if (data != null && data['workouts'] is Map<String, dynamic>) {
          resp = Paged.fromJson(data['workouts'], PersonalWorkout.fromJson);
        } else {
          // 데이터가 없거나 형식이 잘못된 경우 빈 Paged 객체 반환
          resp = Paged(content: [], page: next, totalPages: _page + 1); // 현재 페이지까지는 데이터가 있다고 가정
        }
      }
      setState(() {
        _items.addAll(resp.content);
        _page = next;
        _hasMore = _page + 1 < resp.totalPages;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    const threshold = 200.0;
    if (_scroll.position.maxScrollExtent - _scroll.position.pixels <=
        threshold) {
      _loadMore();
    }
  }

  // 4. _onCreate() 수정: 본인 기록일 때만 허용
  Future<void> _onCreate() async {
    if (widget.userId != null) return; // 가족 기록 페이지에서는 생성 불가
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _EditSheet(),
    );
    if (result == null) return;
    try {
      final created = await api.create(
        date: result.date,
        workoutName: result.workoutName,
        duration: result.duration,
        satisfactionLevel: result.satisfactionLevel,
        memo: result.memo,
      );
      setState(() {
        _items.insert(0, created);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('운동 기록이 추가되었습니다.')));
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  // 5. _onEdit() 수정: 본인 기록일 때만 허용
  Future<void> _onEdit(PersonalWorkout item) async {
    if (widget.userId != null) return; // 가족 기록 페이지에서는 수정 불가
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(
        initial: _EditResult(
          date: item.date,
          workoutName: item.workoutName,
          duration: item.duration,
          satisfactionLevel: item.satisfactionLevel,
          memo: item.memo,
        ),
      ),
    );
    if (result == null) return;

    try {
      final updated = await api.update(
        workoutId: item.workoutId,
        date: result.date,
        workoutName: result.workoutName,
        duration: result.duration,
        satisfactionLevel: item.satisfactionLevel,
        memo: result.memo,
      );
      setState(() {
        final idx =
        _items.indexWhere((e) => e.workoutId == item.workoutId);
        if (idx != -1) _items[idx] = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('수정되었습니다.')));
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  // 6. _onDelete() 수정: 본인 기록일 때만 허용
  Future<void> _onDelete(PersonalWorkout item) async {
    if (widget.userId != null) return; // 가족 기록 페이지에서는 삭제 불가
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 운동 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete(workoutId: item.workoutId);
      setState(() {
        _items.removeWhere((e) => e.workoutId == item.workoutId);
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _avatar() {
    final url = _profileImageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: Image.network(
            url,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.person, size: 28),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
          ),
        ),
      );
    }
    return const CircleAvatar(radius: 28, child: Icon(Icons.person));
  }

  Widget _buildHeader() {
    if (_myInfoLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Card(
          child: SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    if (_myInfoError != null) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline),
              const SizedBox(width: 8),
              const Expanded(child: Text('프로필을 불러오지 못했습니다. 서버 오류')),
              TextButton(
                onPressed: _loadMyInfo,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final titleName = '${_name ?? '-'}(${roleLabel(_role)})';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _avatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleName,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('개인 지표',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _detailsOpen = !_detailsOpen),
                  icon: Icon(
                      _detailsOpen
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18),
                  label: const Text('상세'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _metricChip('키',
                    _heightCm != null ? '${_heightCm!.toStringAsFixed(0)}cm' : '-'),
                const SizedBox(width: 8),
                _metricChip('몸무게',
                    _weightKg != null ? '${_weightKg!.toStringAsFixed(0)}kg' : '-'),
                const SizedBox(width: 8),
                _metricChip('나이', _age != null ? '$_age세' : '-'),
                const SizedBox(width: 8),
                _metricChip('BMI',
                    (_heightCm != null && _weightKg != null) ? _bmi.toStringAsFixed(1) : '-'),
              ],
            ),
            AnimatedCrossFade(
              crossFadeState: _detailsOpen
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    _detailRow('생년월일',
                        _birthdate != null ? _dateStr(_birthdate!) : '-'),
                    const SizedBox(height: 8),
                    _detailRow('성별', genderLabel(_gender)),
                    const SizedBox(height: 8),
                    _detailRow('이메일', _email ?? '-'),
                    const SizedBox(height: 8),
                    _detailRow('내 가족 이름', _familyName ?? '-'),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
            width: 80,
            child:
            Text(label, style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인운동 기록')),
      // 7. FloatingActionButton 숨기기: 본인 기록일 때만 표시
      floatingActionButton: widget.userId == null
          ? FloatingActionButton(
        onPressed: _onCreate,
        child: const Icon(Icons.add),
      )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadMyInfo();
          await _loadInitial();
        },
        child: ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: 1 + _items.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) return _buildHeader();
            final idx = index - 1;
            if (idx >= _items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final item = _items[idx];
            final memoTail =
            (item.memo != null && item.memo!.isNotEmpty) ? ' • ${item.memo}' : '';
            return ListTile(
              leading: moodBadge(item.satisfactionLevel),
              title: Text('${_dateStr(item.date)} · ${item.workoutName}'),
              subtitle: Text(
                  '시간 ${item.duration}분 • 컨디션 ${item.satisfactionLevel ?? 0}$memoTail'),
              // 8. onTap과 trailing 버튼: 본인 기록일 때만 활성화
              onTap: widget.userId == null ? () => _onEdit(item) : null,
              trailing: widget.userId == null
                  ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _onDelete(item),
              )
                  : null,
            );
          },
        ),
      ),
    );
  }
}

class _EditResult {
  final DateTime date;
  final String workoutName;
  final int duration;
  final int? satisfactionLevel;
  final String? memo;

  _EditResult({
    required this.date,
    required this.workoutName,
    required this.duration,
    this.satisfactionLevel,
    this.memo,
  });
}

class _EditSheet extends StatefulWidget {
  final _EditResult? initial;
  const _EditSheet({this.initial});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _form = GlobalKey<FormState>();
  late DateTime _date;
  final _nameCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  int _satisfaction = 2;
  final _memoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _date = i?.date ?? DateTime.now();
    _nameCtrl.text = i?.workoutName ?? '';
    _durationCtrl.text = (i?.duration ?? 30).toString();
    _satisfaction = i?.satisfactionLevel ?? 2;
    _memoCtrl.text = i?.memo ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      _EditResult(
        date: _date,
        workoutName: _nameCtrl.text.trim(),
        duration: int.parse(_durationCtrl.text.trim()),
        satisfactionLevel: _satisfaction,
        memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding =
        MediaQuery.of(context).viewInsets + const EdgeInsets.all(16);
    return Padding(
      padding: padding,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('날짜: ${_dateStr(_date)}'),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _pickDate, child: const Text('변경')),
                ],
              ),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '운동명'),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? '운동명을 입력하세요.' : null,
                maxLength: 100,
              ),
              TextFormField(
                controller: _durationCtrl,
                decoration: const InputDecoration(labelText: '시간(분)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '시간을 입력하세요.';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return '1 이상의 숫자를 입력하세요.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('컨디션'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _satisfaction,
                    onChanged: (v) =>
                        setState(() => _satisfaction = v ?? 2),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1')),
                      DropdownMenuItem(value: 2, child: Text('2')),
                      DropdownMenuItem(value: 3, child: Text('3')),
                    ],
                  ),
                  const SizedBox(width: 12),
                  moodBadge(_satisfaction),
                ],
              ),
              TextFormField(
                controller: _memoCtrl,
                decoration: const InputDecoration(labelText: '메모(선택)'),
                maxLength: 10000,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _submit, child: const Text('저장')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _metricChip(String label, String value) {
  return Chip(
    label: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  );
}

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class MyInfo {
  final int? userId;
  final String? firebaseUid;
  final String? name;
  final String? role;
  final String? email;
  final String? gender;
  final DateTime? birthdate;
  final int? age;
  final double? height;
  final double? weight;
  final double? bmi;
  final int? familyId;
  final String? familyName;
  final String? profileImageUrl;

  MyInfo({
    this.userId,
    this.firebaseUid,
    this.name,
    this.role,
    this.email,
    this.gender,
    this.birthdate,
    this.age,
    this.height,
    this.weight,
    this.bmi,
    this.familyId,
    this.familyName,
    this.profileImageUrl,
  });

  factory MyInfo.fromJson(Map<String, dynamic> j) {
    DateTime? bd;
    final bdStr = j['birthdate'];
    if (bdStr is String && bdStr.isNotEmpty) {
      bd = DateTime.tryParse(bdStr);
    }
    double? _toD(v) => v == null ? null : (v as num).toDouble();
    return MyInfo(
      userId: j['userId'] as int?,
      firebaseUid: j['firebaseUid'] as String?,
      name: j['name'] as String?,
      role: j['role'] as String?,
      email: j['email'] as String?,
      gender: j['gender'] as String?,
      birthdate: bd,
      age: j['age'] as int?,
      height: _toD(j['height']),
      weight: _toD(j['weight']),
      bmi: _toD(j['bmi']),
      familyId: j['familyId'] as int?,
      familyName: j['familyName'] as String?,
      profileImageUrl: j['profileImageUrl'] as String?,
    );
  }
}