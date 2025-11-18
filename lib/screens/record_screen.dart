import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import 'package:fithouse/main.dart';
import 'package:fithouse/api/http_client.dart';
import 'package:fithouse/api/personal_workout_api.dart';
import 'package:fithouse/models/paged.dart';
import 'package:fithouse/models/personal_workout.dart';
import '../constants/colors.dart';

// -----------------------------------------------------------------------------
// [1] 헬퍼 함수 및 위젯
// -----------------------------------------------------------------------------

String moodEmoji(int? level) {
  switch (level) {
    case 1: return '😵';
    case 2: return '😣';
    case 3: return '🙂';
    case 4: return '😄';
    default: return '❓';
  }
}

String moodLabel(int? level) {
  switch (level) {
    case 1: return '매우 힘듦';
    case 2: return '힘듦';
    case 3: return '보통';
    case 4: return '만족';
    default: return '알 수 없음';
  }
}

Color moodColor(int? level) {
  switch (level) {
    case 1: return Colors.redAccent;
    case 2: return Colors.orange;
    case 3: return Colors.amber;
    case 4: return Colors.green;
    default: return Colors.grey;
  }
}

Widget moodBadge(int? level) {
  final color = moodColor(level);
  return Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(moodEmoji(level), style: const TextStyle(fontSize: 20)),
  );
}

String roleLabel(String? role) {
  switch (role) {
    case 'GRANDMA': return '할머니';
    case 'GRANDPA': return '할아버지';
    case 'MOM': return '엄마';
    case 'DAD': return '아빠';
    case 'DAUGHTER': return '딸';
    case 'SON': return '아들';
    default: return role ?? '역할없음';
  }
}

String genderLabel(String? gender) {
  switch (gender) {
    case 'MALE': return '남';
    case 'FEMALE': return '여';
    default: return gender ?? '-';
  }
}

String normalizeUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  final u = url.trim();
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  if (u.startsWith('/')) return '$assetBaseUrl$u';
  return '$assetBaseUrl/$u';
}

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Widget _metricChip(String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), textAlign: TextAlign.center),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// [2] 메인 화면 (RecordScreen)
// -----------------------------------------------------------------------------

class RecordScreen extends StatefulWidget {
  final int? userId;
  const RecordScreen({super.key, this.userId});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with RouteAware {
  final PersonalWorkoutApi api = PersonalWorkoutApi();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<PersonalWorkout>> _events = {};

  final List<PersonalWorkout> _items = [];
  bool _loading = false;
  final int _size = 300;
  bool _dirty = false;

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
    _selectedDay = _focusedDay;
    _loadMyInfo();
    _loadInitial();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadInitial();
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
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  void _groupEvents(List<PersonalWorkout> workouts) {
    _events = {};
    for (var workout in workouts) {
      final dateKey = DateTime.utc(workout.date.year, workout.date.month, workout.date.day);
      if (_events[dateKey] == null) _events[dateKey] = [];
      _events[dateKey]!.add(workout);
    }
  }

  List<PersonalWorkout> _getEventsForDay(DateTime day) {
    final dateKey = DateTime.utc(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  Future<void> _loadMyInfo() async {
    setState(() { _myInfoLoading = true; _myInfoError = null; });
    try {
      final uri = Uri.parse(widget.userId == null ? '$baseUrl/api/users/me' : '$baseUrl/family/member/${widget.userId}');
      final res = await httpClient.get(uri, headers: await authHeaders(json: false));
      if (res.statusCode != 200) { setState(() => _myInfoError = '오류'); return; }

      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      final info = MyInfo.fromJson(jsonMap);
      setState(() {
        _name = info.name; _role = info.role; _email = info.email; _gender = info.gender;
        _birthdate = info.birthdate; _age = info.birthdate != null ? _calcAge(info.birthdate!) : info.age;
        _heightCm = info.height; _weightKg = info.weight; _familyName = info.familyName;
        _profileImageUrl = normalizeUrl(info.profileImageUrl);
      });
    } catch (_) { setState(() => _myInfoError = '오류'); }
    finally { if (mounted) setState(() => _myInfoLoading = false); }
  }

  Future<void> _loadInitial() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final Paged<PersonalWorkout> resp;
      if (widget.userId == null) {
        resp = await api.list(page: 0, size: _size);
      } else {
        final uri = Uri.parse('$baseUrl/family/member/${widget.userId}?page=0&size=$_size');
        final res = await httpClient.get(uri, headers: await authHeaders());
        final data = jsonDecode(res.body);
        if (data != null && data['workouts'] is Map<String, dynamic>) {
          resp = Paged.fromJson(data['workouts'], PersonalWorkout.fromJson);
        } else {
          resp = Paged(content: [], page: 0, totalPages: 0);
        }
      }
      setState(() {
        _items.clear(); _items.addAll(resp.content);
        _groupEvents(_items);
      });
    } catch (e) { _showError(e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _onCreate() async {
    if (widget.userId != null) return;
    final result = await showModalBottomSheet<_EditResult>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => const _EditSheet(),
    );
    if (result == null) return;
    try {
      final created = await api.create(
        date: result.date, workoutName: result.workoutName, duration: result.duration,
        satisfactionLevel: result.satisfactionLevel, memo: result.memo,
      );
      setState(() {
        _items.add(created); _groupEvents(_items);
        _selectedDay = created.date; _focusedDay = created.date; _dirty = true;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기록되었습니다.')));
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _onEdit(PersonalWorkout item) async {
    if (widget.userId != null) return;
    final result = await showModalBottomSheet<_EditResult>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(initial: _EditResult(date: item.date, workoutName: item.workoutName, duration: item.duration, satisfactionLevel: item.satisfactionLevel, memo: item.memo)),
    );
    if (result == null) return;
    try {
      final updated = await api.update(
        workoutId: item.workoutId, date: result.date, workoutName: result.workoutName,
        duration: result.duration, satisfactionLevel: result.satisfactionLevel, memo: result.memo,
      );
      setState(() {
        final idx = _items.indexWhere((e) => e.workoutId == item.workoutId);
        if (idx != -1) _items[idx] = updated;
        _groupEvents(_items); _dirty = true;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수정되었습니다.')));
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _onDelete(PersonalWorkout item) async {
    if (widget.userId != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제'), content: const Text('기록을 삭제하시겠습니까?'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제'))],
      ),
    );
    if (ok != true) return;
    try {
      await api.delete(workoutId: item.workoutId);
      setState(() { _items.removeWhere((e) => e.workoutId == item.workoutId); _groupEvents(_items); _dirty = true; });
    } catch (e) { _showError(e.toString()); }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- UI Components ---

  Widget _avatar() {
    final url = _profileImageUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade200, backgroundImage: NetworkImage(url), onBackgroundImageError: (_, __) {});
    }
    return const CircleAvatar(radius: 24, backgroundColor: Color(0xFFF1F3F5), child: Icon(Icons.person, color: Colors.grey));
  }

  Widget _buildHeader() {
    if (_myInfoLoading) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    if (_myInfoError != null) return Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), child: TextButton(onPressed: _loadMyInfo, child: const Text('프로필 로딩 실패 (재시도)')));

    final titleName = '${_name ?? '-'}(${roleLabel(_role)})';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        Row(children: [
          _avatar(), const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titleName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), const Text('오늘도 건강한 하루 되세요!', style: TextStyle(fontSize: 12, color: Colors.grey))])),
          if (widget.userId == null) InkWell(onTap: () => setState(() => _detailsOpen = !_detailsOpen), child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(_detailsOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: mainGreen))),
        ]),
        if (_detailsOpen) ...[
          const SizedBox(height: 16), const Divider(height: 1, color: Color(0xFFEEEEEE)), const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _metricChip('키', _heightCm != null ? '${_heightCm!.toStringAsFixed(0)}cm' : '-')),
            const SizedBox(width: 8), Expanded(child: _metricChip('몸무게', _weightKg != null ? '${_weightKg!.toStringAsFixed(0)}kg' : '-')),
            const SizedBox(width: 8), Expanded(child: _metricChip('나이', _age != null ? '$_age세' : '-')),
            const SizedBox(width: 8), Expanded(child: _metricChip('BMI', (_heightCm != null && _weightKg != null) ? _bmi.toStringAsFixed(1) : '-')),
          ]),
          const SizedBox(height: 16),
          _detailRow('생년월일', _birthdate != null ? _dateStr(_birthdate!) : '-'),
          const SizedBox(height: 8), _detailRow('성별', genderLabel(_gender)),
          const SizedBox(height: 8), _detailRow('가족명', _familyName ?? '-'),
        ],
      ]),
    );
  }

  Widget _detailRow(String label, String value) => Row(children: [SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))), const SizedBox(width: 8), Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))]);

  void _showActionSheet(PersonalWorkout item) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) {
      return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [const SizedBox(height: 16), ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text('수정하기'), onTap: () { Navigator.pop(context); _onEdit(item); }), ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('삭제하기'), onTap: () { Navigator.pop(context); _onDelete(item); }), const SizedBox(height: 8)]));
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _getEventsForDay(_selectedDay ?? DateTime.now());

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) { if (!didPop) Navigator.pop(context, _dirty); },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),

        // ⭐️ [수정 1] 앱바 제목, 아이콘 모두 검정색으로 변경
        appBar: AppBar(
          title: const Text('개인운동 기록', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: mainGreen,
          elevation: 0,
          centerTitle: true,
          leading: BackButton(color: Colors.black, onPressed: () => Navigator.pop(context, _dirty)),
          iconTheme: const IconThemeData(color: Colors.black),
        ),

        // ⭐️ [수정 2] 플러스 아이콘 검정색으로 변경
        floatingActionButton: widget.userId == null ? FloatingActionButton(onPressed: _onCreate, backgroundColor: mainGreen, elevation: 4, child: const Icon(Icons.add, color: Colors.black)) : null,

        body: RefreshIndicator(
          onRefresh: () async { await _loadMyInfo(); await _loadInitial(); },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              _buildHeader(),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
                child: TableCalendar<PersonalWorkout>(
                  locale: 'ko_KR', firstDay: DateTime.utc(2023, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day), eventLoader: _getEventsForDay,

                  // 헤더 스타일
                  headerStyle: const HeaderStyle(
                    titleCentered: true, formatButtonVisible: false,
                    titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    leftChevronIcon: Icon(Icons.chevron_left, color: mainGreen),
                    rightChevronIcon: Icon(Icons.chevron_right, color: mainGreen),
                  ),

                  // ⭐️ [수정 3] 캘린더 날짜 및 배경색 수정
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    // 기본 글씨 검정색
                    defaultTextStyle: const TextStyle(color: Colors.black87, fontSize: 15),
                    // 주말 글씨 빨간색
                    weekendTextStyle: const TextStyle(color: Colors.red, fontSize: 15),

                    // 오늘 날짜: 배경 없이 테두리만, 글씨는 검정
                    todayDecoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: mainGreen, width: 2.0),
                    ),
                    todayTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),

                    // 선택된 날짜: 진한 초록색(Colors.green) 배경 + 검정색 글씨
                    selectedDecoration: const BoxDecoration(
                      color: Colors.green, // ✨ 진한 녹색으로 변경 (mainGreen보다 진하게)
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                        color: Colors.black, // ✨ 글씨를 검정색으로 변경
                        fontWeight: FontWeight.bold,
                        fontSize: 15
                    ),

                    // 이벤트 마커
                    markerDecoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    markerSize: 6,
                    markerMargin: const EdgeInsets.only(top: 8),
                  ),
                  onDaySelected: (selectedDay, focusedDay) { if (!isSameDay(_selectedDay, selectedDay)) setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; }); },
                  onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                ),
              ),

              const SizedBox(height: 24),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(_selectedDay != null ? '${_selectedDay!.month}월 ${_selectedDay!.day}일 운동' : '운동 목록', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              if (selectedEvents.isEmpty)
                Container(padding: const EdgeInsets.all(40), alignment: Alignment.center, child: Column(children: [Icon(Icons.fitness_center, size: 48, color: Colors.grey[300]), const SizedBox(height: 16), const Text('기록된 운동이 없어요.\n오늘 운동을 추가해보세요!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))]))
              else
                ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final item = selectedEvents[index];
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))]),
                      child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(16), child: InkWell(borderRadius: BorderRadius.circular(16), onTap: widget.userId == null ? () => _showActionSheet(item) : null, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [moodBadge(item.satisfactionLevel), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.workoutName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text('${item.duration}분  ·  ${moodLabel(item.satisfactionLevel)}', style: const TextStyle(fontSize: 13, color: Colors.grey)), if (item.memo != null && item.memo!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(item.memo!, style: TextStyle(fontSize: 13, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis))])), if (widget.userId == null) const Icon(Icons.more_vert, color: Colors.grey)])))),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// [3] 입력 및 수정 시트 (_EditSheet)
// -----------------------------------------------------------------------------

class _EditResult {
  final DateTime date; final String workoutName; final int duration; final int? satisfactionLevel; final String? memo;
  _EditResult({required this.date, required this.workoutName, required this.duration, this.satisfactionLevel, this.memo});
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
  int _satisfaction = 3;
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
  void dispose() { _nameCtrl.dispose(); _durationCtrl.dispose(); _memoCtrl.dispose(); super.dispose(); }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, _EditResult(date: _date, workoutName: _nameCtrl.text.trim(), duration: int.parse(_durationCtrl.text.trim()), satisfactionLevel: _satisfaction, memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('운동 기록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2030), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: mainGreen)), child: child!));
                  if (picked != null) setState(() => _date = picked);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.calendar_today, size: 20, color: Colors.grey), const SizedBox(width: 12), const Text('날짜', style: TextStyle(color: Colors.grey)), const Spacer(), Text('${_date.year}-${_date.month}-${_date.day}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])),
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _nameCtrl, decoration: InputDecoration(labelText: '어떤 운동을 하셨나요?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mainGreen)), floatingLabelStyle: const TextStyle(color: mainGreen)), validator: (v) => (v == null || v.trim().isEmpty) ? '입력해주세요' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _durationCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '운동 시간', suffixText: '분', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mainGreen)), floatingLabelStyle: const TextStyle(color: mainGreen)), validator: (v) => (v == null || v.trim().isEmpty || int.tryParse(v) == null) ? '숫자를 입력해주세요' : null),
              const SizedBox(height: 24),
              const Text('오늘 운동은 어땠나요?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [1, 2, 3, 4].map((score) {
                final isSelected = _satisfaction == score;
                return GestureDetector(onTap: () => setState(() => _satisfaction = score), child: Column(children: [AnimatedContainer(duration: const Duration(milliseconds: 200), padding: EdgeInsets.all(isSelected ? 4 : 0), decoration: BoxDecoration(shape: BoxShape.circle, border: isSelected ? Border.all(color: mainGreen, width: 2) : null), child: Opacity(opacity: isSelected ? 1.0 : 0.5, child: moodBadge(score))), const SizedBox(height: 8), Text(moodLabel(score), style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.black : Colors.grey))]));
              }).toList()),
              const SizedBox(height: 24),
              TextFormField(controller: _memoCtrl, maxLines: 2, decoration: InputDecoration(labelText: '메모 (선택)', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mainGreen)), floatingLabelStyle: const TextStyle(color: mainGreen)), style: const TextStyle(color: Colors.black)),
              const SizedBox(height: 32),
              // ⭐️ [수정 4] 저장 버튼 글씨 검정색
              ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: mainGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// [4] 데이터 모델 (MyInfo)
// -----------------------------------------------------------------------------

class MyInfo {
  final int? userId; final String? firebaseUid; final String? name; final String? role; final String? email;
  final String? gender; final DateTime? birthdate; final int? age; final double? height; final double? weight;
  final double? bmi; final int? familyId; final String? familyName; final String? profileImageUrl;

  MyInfo({this.userId, this.firebaseUid, this.name, this.role, this.email, this.gender, this.birthdate, this.age, this.height, this.weight, this.bmi, this.familyId, this.familyName, this.profileImageUrl});
  factory MyInfo.fromJson(Map<String, dynamic> j) {
    DateTime? bd; if (j['birthdate'] is String && j['birthdate'].isNotEmpty) bd = DateTime.tryParse(j['birthdate']);
    double? _toD(v) => v == null ? null : (v as num).toDouble();
    return MyInfo(userId: j['userId'], firebaseUid: j['firebaseUid'], name: j['name'], role: j['role'], email: j['email'], gender: j['gender'], birthdate: bd, age: j['age'], height: _toD(j['height']), weight: _toD(j['weight']), bmi: _toD(j['bmi']), familyId: j['familyId'], familyName: j['familyName'], profileImageUrl: j['profileImageUrl']);
  }
}