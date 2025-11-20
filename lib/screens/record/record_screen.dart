import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:fithouse/main.dart'; // routeObserver
import 'package:fithouse/models/personal_workout.dart';
import 'package:fithouse/constants/colors.dart'; // mainGreen 상수를 가져옴

// 같은 폴더에 있는 데이터 관리 파일을 상대 경로로 import
import 'record_data_manager.dart';

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
  late RecordDataManager _dataManager;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _detailsOpen = false;

  @override
  void initState() {
    super.initState();
    _dataManager = RecordDataManager(userId: widget.userId, updateState: setState);
    _selectedDay = _focusedDay;
    _dataManager.loadMyInfo();
    _dataManager.loadInitial();
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
    _dataManager.loadMyInfo();
    _dataManager.loadInitial();
  }

  // API 호출 후 결과에 따라 UI/데이터 업데이트
  Future<void> _onCreate() async {
    if (widget.userId != null) return;
    final result = await showModalBottomSheet<EditResult>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => const EditSheet(),
    );
    if (result == null) return;
    try {
      final created = await _dataManager.createWorkout(
        date: result.date, workoutName: result.workoutName, duration: result.duration,
        satisfactionLevel: result.satisfactionLevel, memo: result.memo,
      );
      setState(() {
        _selectedDay = created.date;
        _focusedDay = created.date;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기록되었습니다.')));
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _onEdit(PersonalWorkout item) async {
    if (widget.userId != null) return;
    final result = await showModalBottomSheet<EditResult>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => EditSheet(initial: EditResult(date: item.date, workoutName: item.workoutName, duration: item.duration, satisfactionLevel: item.satisfactionLevel, memo: item.memo)),
    );
    if (result == null) return;
    try {
      await _dataManager.updateWorkout(
        workoutId: item.workoutId, date: result.date, workoutName: result.workoutName,
        duration: result.duration, satisfactionLevel: result.satisfactionLevel, memo: result.memo,
      );
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
      await _dataManager.deleteWorkout(item.workoutId);
    } catch (e) { _showError(e.toString()); }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- UI Components ---

  Widget _avatar() {
    final url = _dataManager.data.myInfo?.profileImageUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: 24, backgroundColor: Colors.grey.shade200, backgroundImage: NetworkImage(url), onBackgroundImageError: (_, __) {});
    }
    return const CircleAvatar(radius: 24, backgroundColor: Color(0xFFF1F3F5), child: Icon(Icons.person, color: Colors.grey));
  }

  Widget _buildHeader() {
    final data = _dataManager.data;
    // 테마에서 primaryColor를 가져와 사용합니다.
    final Color headerIconColor = Theme.of(context).primaryColor;

    if (data.myInfoLoading) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    if (data.myInfoError != null) return Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), child: TextButton(onPressed: _dataManager.loadMyInfo, child: const Text('프로필 로딩 실패 (재시도)')));

    final info = data.myInfo;
    final titleName = '${info?.name ?? '-'}(${roleLabel(info?.role)})';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        // 상단 전체를 클릭 가능하게 감싸서 터치 영역을 넓혀줍니다.
        InkWell(
          onTap: () => setState(() => _detailsOpen = !_detailsOpen),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: _detailsOpen ? Radius.zero : const Radius.circular(24),
            bottomRight: _detailsOpen ? Radius.zero : const Radius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              _avatar(),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titleName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('오늘도 건강한 하루 되세요!', style: TextStyle(fontSize: 12, color: Colors.grey))
                      ]
                  )
              ),
              // 요청하신 화살표 버튼 (항상 보이도록 수정)
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    _detailsOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: headerIconColor,
                    size: 28, // 아이콘 크기를 살짝 키워 시인성 확보
                  )
              ),
            ]),
          ),
        ),
        if (_detailsOpen) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: metricChip('키', info?.height != null ? '${info!.height!.toStringAsFixed(0)}cm' : '-')),
                  const SizedBox(width: 8), Expanded(child: metricChip('몸무게', info?.weight != null ? '${info!.weight!.toStringAsFixed(0)}kg' : '-')),
                  const SizedBox(width: 8), Expanded(child: metricChip('나이', info?.age != null ? '${info!.age}세' : '-')),
                  const SizedBox(width: 8), Expanded(child: metricChip('BMI', (info?.height != null && info?.weight != null) ? data.bmi.toStringAsFixed(1) : '-')),
                ]),
                const SizedBox(height: 16),
                _detailRow('생년월일', info?.birthdate != null ? dateStr(info!.birthdate!) : '-'),
                const SizedBox(height: 8), _detailRow('성별', genderLabel(info?.gender)),
                const SizedBox(height: 8), _detailRow('가족명', info?.familyName ?? '-'),
              ],
            ),
          ),
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
    final data = _dataManager.data;
    final selectedEvents = data.getEventsForDay(_selectedDay ?? DateTime.now());
    final Color primaryColor = Theme.of(context).primaryColor;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) { if (!didPop) Navigator.pop(context, data.dirty); },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),

        // 앱바 스타일: 테마를 따릅니다.
        appBar: AppBar(
          title: const Text('개인운동 기록', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          elevation: 0,
          centerTitle: true,
          leading: BackButton(color: Colors.black, onPressed: () => Navigator.pop(context, data.dirty)),
          iconTheme: const IconThemeData(color: Colors.black),
        ),

        // 플로팅 액션 버튼: Theme.of(context).primaryColor 사용
        floatingActionButton: widget.userId == null ? FloatingActionButton(onPressed: _onCreate, backgroundColor: primaryColor, elevation: 4, child: const Icon(Icons.add, color: Colors.black)) : null,

        body: RefreshIndicator(
          onRefresh: () async { await _dataManager.loadMyInfo(); await _dataManager.loadInitial(); },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              _buildHeader(),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
                child: TableCalendar<PersonalWorkout>(
                  locale: 'ko_KR', firstDay: DateTime.utc(2023, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day), eventLoader: data.getEventsForDay,

                  // [수정] 요일 행 높이 설정 (월화수목금 짤림 방지)
                  daysOfWeekHeight: 30.0,

                  // 헤더 스타일: primaryColor 사용
                  headerStyle: HeaderStyle(
                    titleCentered: true, formatButtonVisible: false,
                    titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    leftChevronIcon: Icon(Icons.chevron_left, color: primaryColor),
                    rightChevronIcon: Icon(Icons.chevron_right, color: primaryColor),
                  ),

                  // 캘린더 날짜 및 배경색 스타일
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: const TextStyle(color: Colors.black87, fontSize: 15),
                    weekendTextStyle: const TextStyle(color: Colors.red, fontSize: 15),

                    // 오늘 날짜: primaryColor 사용
                    todayDecoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 2.0),
                    ),
                    todayTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),

                    // 선택된 날짜: 진한 녹색 (Colors.green) 사용
                    selectedDecoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15
                    ),

                    // ❌ markerDecoration을 제거하여 커스텀 빌더 사용
                    // markerDecoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    markerSize: 6,
                    markerMargin: const EdgeInsets.only(top: 8),
                  ),

                  // 🎯 calendarBuilders를 사용하여 이벤트 마커 커스텀 빌드
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();

                      // 이벤트 개수에 따라 마커를 중앙에 모아서 표시
                      return Positioned(
                        right: 8, bottom: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            events.length.clamp(0, 3), // 최대 3개까지만 마커 표시
                                (index) {
                              // getEventMarkerColor 함수를 사용하여 파스텔 색상을 순환하며 가져옴
                              final color = getEventMarkerColor(index);

                              return Container(
                                width: 6.0,
                                height: 6.0,
                                margin: const EdgeInsets.only(left: 1.0),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
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