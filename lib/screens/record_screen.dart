import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fithouse/api/personal_workout_api.dart';
import 'package:fithouse/models/personal_workout.dart';
import 'package:fithouse/models/paged.dart';

/// ===== mood badge (mood_badge.dart 내용 합침) =====
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
/// ===============================================

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

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

  double _heightCm = 170;
  double _weightKg = 65;
  int _age = 25;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double get _bmi {
    final h = _heightCm / 100.0;
    if (h <= 0) return 0;
    return double.parse(((_weightKg) / (h * h)).toStringAsFixed(1));
  }

  Future<void> _loadInitial() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final Paged<PersonalWorkout> resp =
      await api.list(userId: kUserId, page: 0, size: _size);
      setState(() {
        _items
          ..clear()
          ..addAll(resp.content);
        _page = 0;
        _hasMore = _page + 1 < resp.totalPages;
        _initialLoaded = true;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final next = _page + 1;
      final resp = await api.list(userId: kUserId, page: next, size: _size);
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
    if (_scroll.position.maxScrollExtent - _scroll.position.pixels <= threshold) {
      _loadMore();
    }
  }

  Future<void> _onCreate() async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _EditSheet(),
    );
    if (result == null) return;
    try {
      final created = await api.create(
        userId: kUserId,
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('운동 기록이 추가되었습니다.')));
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _onEdit(PersonalWorkout item) async {
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
        userId: kUserId,
        date: result.date,
        workoutName: result.workoutName,
        duration: result.duration,
        satisfactionLevel: result.satisfactionLevel,
        memo: result.memo,
      );
      setState(() {
        final idx = _items.indexWhere((e) => e.workoutId == item.workoutId);
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

  Future<void> _onDelete(PersonalWorkout item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 운동 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete(workoutId: item.workoutId, userId: kUserId);
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

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final emailFallback = user?.email ?? '';
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (emailFallback.isNotEmpty ? emailFallback.split('@').first : '사용자');

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 28, child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$name님', style: Theme.of(context).textTheme.titleMedium),
                      Text('개인 지표', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _openProfileEditSheet,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('편집'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _metricChip('키', '${_heightCm.toStringAsFixed(0)}cm'),
                const SizedBox(width: 8),
                _metricChip('몸무게', '${_weightKg.toStringAsFixed(0)}kg'),
                const SizedBox(width: 8),
                _metricChip('나이', '$_age세'),
                const SizedBox(width: 8),
                _metricChip('BMI', _bmi.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openProfileEditSheet() {
    final heightCtrl = TextEditingController(text: _heightCm.toStringAsFixed(0));
    final weightCtrl = TextEditingController(text: _weightKg.toStringAsFixed(0));
    final ageCtrl = TextEditingController(text: '$_age');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final padding =
            MediaQuery.of(context).viewInsets + const EdgeInsets.all(16);
        return Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('개인 정보 입력', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: heightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '키(cm)'),
              ),
              TextField(
                controller: weightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '몸무게(kg)'),
              ),
              TextField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '나이'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final h = double.tryParse(heightCtrl.text.trim());
                  final w = double.tryParse(weightCtrl.text.trim());
                  final a = int.tryParse(ageCtrl.text.trim());
                  if (h == null || h <= 0 || w == null || w <= 0 || a == null || a <= 0) {
                    _showError('값을 올바르게 입력하세요.');
                    return;
                  }
                  setState(() {
                    _heightCm = h;
                    _weightKg = w;
                    _age = a;
                  });
                  Navigator.pop(context);
                },
                child: const Text('저장'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인운동 기록')),
      floatingActionButton: FloatingActionButton(
        onPressed: _onCreate,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
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
              subtitle: Text('시간 ${item.duration}분 • 컨디션 ${item.satisfactionLevel ?? 0}$memoTail'),
              onTap: () => _onEdit(item),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _onDelete(item),
              ),
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
    final padding = MediaQuery.of(context).viewInsets + const EdgeInsets.all(16);
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
                validator: (v) => (v == null || v.trim().isEmpty) ? '운동명을 입력하세요.' : null,
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
                    onChanged: (v) => setState(() => _satisfaction = v ?? 2),
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
