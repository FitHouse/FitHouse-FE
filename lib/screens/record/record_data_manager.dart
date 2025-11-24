// File: lib/screens/record/record_data_manager.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:fithouse/main.dart';
import 'package:fithouse/api/http_client.dart';
import 'package:fithouse/api/personal_workout_api.dart';
import 'package:fithouse/models/paged.dart';
import 'package:fithouse/models/personal_workout.dart';

// 메인 테마 색상: 새로운 파스텔 톤 (#8FC7A7)
const Color mainGreen = Color(0xFF8FC7A7);

// 이벤트 마커에 사용할 파스텔 색상 리스트
final pastelColors = const [
  Color(0xFFB3E5FC), // 연한 하늘색
  Color(0xFFFFCDD2), // 연한 빨간색
  Color(0xFFC8E6C9), // 연한 녹색
  Color(0xFFFFF9C4), // 연한 노란색
  Color(0xFFD1C4E9), // 연한 보라색
  Color(0xFFFFE0B2), // 연한 주황색
  Color(0xFFDCEDC8), // 연한 라임색
];

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

// 🎯 이벤트 인덱스에 따라 마커 색상을 순환하며 반환하는 헬퍼 함수
Color getEventMarkerColor(int index) {
  if (index < 0) return Colors.grey;
  return pastelColors[index % pastelColors.length];
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

String dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Widget metricChip(String label, String value) {
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

// -----------------------------------------------------------------------------
// 데이터 관리 클래스 (RecordStateData, RecordDataManager)
// -----------------------------------------------------------------------------

class RecordStateData {
  MyInfo? myInfo;
  List<PersonalWorkout> items = [];
  Map<DateTime, List<PersonalWorkout>> events = {};
  bool myInfoLoading = false;
  String? myInfoError;
  bool loading = false;
  bool dirty = false;
  final int size = 300;

  double get bmi {
    final h = (myInfo?.height ?? 0) / 100.0;
    final w = myInfo?.weight ?? 0;
    if (h <= 0 || w <= 0) return 0;
    return double.parse((w / (h * h)).toStringAsFixed(1));
  }

  void groupEvents(List<PersonalWorkout> workouts) {
    events = {};
    for (var workout in workouts) {
      final dateKey = DateTime.utc(workout.date.year, workout.date.month, workout.date.day);
      if (events[dateKey] == null) events[dateKey] = [];
      events[dateKey]!.add(workout);
    }
  }

  List<PersonalWorkout> getEventsForDay(DateTime day) {
    final dateKey = DateTime.utc(day.year, day.month, day.day);
    return events[dateKey] ?? [];
  }
}

class RecordDataManager {
  final int? userId;
  final PersonalWorkoutApi api = PersonalWorkoutApi();
  final RecordStateData data = RecordStateData();
  final void Function(VoidCallback fn) updateState;

  RecordDataManager({required this.userId, required this.updateState});

  int _calcAge(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  Future<void> loadMyInfo() async {
    updateState(() { data.myInfoLoading = true; data.myInfoError = null; });
    try {
      final uri = Uri.parse(userId == null ? '$baseUrl/api/users/me' : '$baseUrl/family/member/$userId');
      final res = await httpClient.get(uri, headers: await authHeaders(json: false));
      if (res.statusCode != 200) { updateState(() => data.myInfoError = '오류'); return; }

      final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
      final info = MyInfo.fromJson(jsonMap);

      int? calculatedAge = info.birthdate != null ? _calcAge(info.birthdate!) : info.age;

      updateState(() {
        data.myInfo = MyInfo(
          userId: info.userId, name: info.name, role: info.role, email: info.email, gender: info.gender,
          birthdate: info.birthdate, age: calculatedAge, height: info.height, weight: info.weight,
          familyName: info.familyName, profileImageUrl: normalizeUrl(info.profileImageUrl),
        );
      });
    } catch (_) { updateState(() => data.myInfoError = '오류'); }
    finally { updateState(() => data.myInfoLoading = false); }
  }

  Future<void> loadInitial() async {
    if (data.loading) return;
    updateState(() => data.loading = true);
    try {
      final Paged<PersonalWorkout> resp;
      if (userId == null) {
        resp = await api.list(page: 0, size: data.size);
      } else {
        final uri = Uri.parse('$baseUrl/family/member/$userId?page=0&size=${data.size}');
        final res = await httpClient.get(uri, headers: await authHeaders());
        final resultData = jsonDecode(res.body);
        if (resultData != null && resultData['workouts'] is Map<String, dynamic>) {
          resp = Paged.fromJson(resultData['workouts'], PersonalWorkout.fromJson);
        } else {
          resp = Paged(content: [], page: 0, totalPages: 0);
        }
      }
      updateState(() {
        data.items.clear(); data.items.addAll(resp.content);
        data.groupEvents(data.items);
      });
    } catch (e) { rethrow; }
    finally { updateState(() => data.loading = false); }
  }

  Future<PersonalWorkout> createWorkout({
    required DateTime date, required String workoutName, required int duration,
    required int? satisfactionLevel, required String? memo,
  }) async {
    final created = await api.create(
      date: date, workoutName: workoutName, duration: duration,
      satisfactionLevel: satisfactionLevel, memo: memo,
    );
    updateState(() {
      data.items.add(created); data.groupEvents(data.items);
      data.dirty = true;
    });
    return created;
  }

  Future<PersonalWorkout> updateWorkout({
    required int workoutId, required DateTime date, required String workoutName,
    required int duration, required int? satisfactionLevel, required String? memo,
  }) async {
    final updated = await api.update(
      workoutId: workoutId, date: date, workoutName: workoutName,
      duration: duration, satisfactionLevel: satisfactionLevel, memo: memo,
    );
    updateState(() {
      final idx = data.items.indexWhere((e) => e.workoutId == workoutId);
      if (idx != -1) data.items[idx] = updated;
      data.groupEvents(data.items); data.dirty = true;
    });
    return updated;
  }

  Future<void> deleteWorkout(int workoutId) async {
    await api.delete(workoutId: workoutId);
    updateState(() {
      data.items.removeWhere((e) => e.workoutId == workoutId);
      data.groupEvents(data.items); data.dirty = true;
    });
  }
}

// -----------------------------------------------------------------------------
// [3] 입력 및 수정 시트 (EditSheet)
// -----------------------------------------------------------------------------

class EditResult {
  final DateTime date; final String workoutName; final int duration; final int? satisfactionLevel; final String? memo;
  EditResult({required this.date, required this.workoutName, required this.duration, this.satisfactionLevel, this.memo});
}

class EditSheet extends StatefulWidget {
  final EditResult? initial;
  const EditSheet({super.key, this.initial});
  @override
  State<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<EditSheet> {
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
    _satisfaction = i?.satisfactionLevel ?? 3;
    _memoCtrl.text = i?.memo ?? '';
  }

  @override
  void dispose() { _nameCtrl.dispose(); _durationCtrl.dispose(); _memoCtrl.dispose(); super.dispose(); }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, EditResult(date: _date, workoutName: _nameCtrl.text.trim(), duration: int.parse(_durationCtrl.text.trim()), satisfactionLevel: _satisfaction, memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim()));
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
              ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: mainGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}