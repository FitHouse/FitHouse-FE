import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/exercise_video.dart';
import '../providers/chat_provider.dart';

class VideoListScreen extends StatefulWidget {
  const VideoListScreen({super.key});

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  // 임시 선택 값
  String? _tempAge = '전체';
  String? _tempFactor = '전체';
  String? _tempLevel = '전체';
  String? _tempTool = '전체';

  // 최종 선택 값
  String _selectedAge = '전체';
  String _selectedFactor = '전체';
  String _selectedLevel = '전체';
  String _selectedTool = '전체';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadVideos();
    });
  }

  Future<void> _loadVideos() async {
    try {
      final provider = context.read<ChatProvider>();
      await provider.fetchAllVideos();

      setState(() => _isLoading = false);
    } catch (e) {
      print("영상 로딩 오류: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final allVideos = chatProvider.allVideos;

    final ages = chatProvider.availableAges;
    final factors = chatProvider.availableFactors;
    final levels = chatProvider.availableLevels;
    final tools = chatProvider.availableTools;

    // ⭐ 필터 적용된 리스트 생성
    final filtered = allVideos.where((v) {
      if (_selectedAge != '전체' && v.aggrpNm != _selectedAge) return false;
      if (_selectedFactor != '전체' && v.ftnsFctrNm != _selectedFactor) return false;
      if (_selectedLevel != '전체' && v.ftnsLvlNm != _selectedLevel) return false;

      if (_selectedTool != '전체' &&
          !v.toolNm.split(',').map((e) => e.trim()).contains(_selectedTool)) {
        return false;
      }

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("운동 영상 모음"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilters(ages, factors, levels, tools),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              _isLoading
                  ? "영상을 불러오는 중..."
                  : "총 ${filtered.length}개의 영상",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF50D31D)))
                : filtered.isEmpty
                ? const Center(child: Text("조건에 맞는 영상이 없습니다."))
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, idx) =>
                  _buildVideoTile(filtered[idx]),
            ),
          ),
        ],
      ),
    );
  }

  // ============================= 필터 UI =============================
  Widget _buildFilters(List<String> ages, List<String> factors,
      List<String> levels, List<String> tools) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: "연령대명",
                  items: ages,
                  value: _tempAge,
                  onChanged: (v) => setState(() => _tempAge = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  label: "체력요인명",
                  items: factors,
                  value: _tempFactor,
                  onChanged: (v) => setState(() => _tempFactor = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: "체력수준명",
                  items: levels,
                  value: _tempLevel,
                  onChanged: (v) => setState(() => _tempLevel = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  label: "소도구명",
                  items: tools,
                  value: _tempTool,
                  onChanged: (v) => setState(() => _tempTool = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF50D31D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () {
              setState(() {
                _selectedAge = _tempAge ?? '전체';
                _selectedFactor = _tempFactor ?? '전체';
                _selectedLevel = _tempLevel ?? '전체';
                _selectedTool = _tempTool ?? '전체';
              });
            },
            child: const Text("검색", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items
                  .map((item) =>
                  DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ============================= 영상 타일 UI =============================
  Widget _buildVideoTile(ExerciseVideo v) {
    final img = v.thumbnailUrl.replaceAll("http:", "https:");

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Image.network(
          img,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 90,
            height: 90,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          ),
        ),
        title: Text(v.trngNm, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          "${v.aggrpNm} / ${v.ftnsFctrNm} / ${v.ftnsLvlNm}",
          style: const TextStyle(fontSize: 12),
        ),
        onTap: () async {
          final uri = Uri.parse(v.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
      ),
    );
  }
}
