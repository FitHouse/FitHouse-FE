import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/video_provider.dart';
import '../models/video_item.dart';
import '../constants/colors.dart';

class VideoListScreen extends StatefulWidget {
  const VideoListScreen({super.key});

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  String tempKeyword = "";
  String? tempAge = "전체";
  String? tempFactor = "전체";
  String? tempLevel = "전체";
  String? tempTool = "전체";

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final provider = context.read<VideoProvider>();
      await provider.loadFilterOptions();
      await provider.searchVideos(page: 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("운동 영상 모음"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterArea(provider),

          _buildResultInfo(provider),

          Expanded(
            child: provider.isLoading
                ? const Center(
              child: CircularProgressIndicator(color: buttonGreen),
            )
                : provider.videos.isEmpty
                ? const Center(child: Text("조건에 맞는 영상이 없습니다."))
                : ListView.builder(
              itemCount: provider.videos.length,
              itemBuilder: (_, i) =>
                  _buildVideoTile(provider.videos[i]),
            ),
          ),

          if (!provider.isLoading) _buildPagination(provider),
        ],
      ),
    );
  }

  Widget _buildFilterArea(VideoProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "운동명 검색",
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: buttonGreen, width: 2),
              ),
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (v) => tempKeyword = v.trim(),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: "연령대",
                  items: provider.ages,
                  value: tempAge,
                  onChanged: (v) => setState(() => tempAge = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  label: "체력요인",
                  items: provider.factors,
                  value: tempFactor,
                  onChanged: (v) => setState(() => tempFactor = v),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: "체력수준",
                  items: provider.levels,
                  value: tempLevel,
                  onChanged: (v) => setState(() => tempLevel = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  label: "소도구",
                  items: provider.tools,
                  value: tempTool,
                  onChanged: (v) => setState(() => tempTool = v),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              // 초기화 버튼
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        tempKeyword = "";
                        tempAge = "전체";
                        tempFactor = "전체";
                        tempLevel = "전체";
                        tempTool = "전체";
                      });

                      provider.applyFilters(
                        newKeyword: "",
                        newAge: "전체",
                        newFactor: "전체",
                        newLevel: "전체",
                        newTool: "전체",
                      );
                    },
                    child: const Text("초기화", style: TextStyle(fontSize: 14)),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // 검색 버튼
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    onPressed: () {
                      provider.applyFilters(
                        newKeyword: tempKeyword,
                        newAge: tempAge ?? "전체",
                        newFactor: tempFactor ?? "전체",
                        newLevel: tempLevel ?? "전체",
                        newTool: tempTool ?? "전체",
                      );
                    },
                    child: const Text(
                      "검색",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
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

  Widget _buildResultInfo(VideoProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        "총 ${provider.totalCount}개 중 ${provider.videos.length}개 표시",
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildVideoTile(VideoItem v) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Image.network(
          v.thumbnailUrl,
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
          final uri = Uri.parse(v.videoUrl);
          if (await canLaunchUrl(uri)) launchUrl(uri);
        },
      ),
    );
  }

  Widget _buildPagination(VideoProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (provider.currentPage > 1)
            _pageBtn("＜", provider.currentPage - 1),

          const SizedBox(width: 12),

          Text(
            "${provider.currentPage} / ${provider.totalPages}",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),

          const SizedBox(width: 12),

          if (provider.currentPage < provider.totalPages)
            _pageBtn("＞", provider.currentPage + 1),
        ],
      ),
    );
  }

  Widget _pageBtn(String text, int targetPage) {
    return GestureDetector(
      onTap: () {
        context.read<VideoProvider>().searchVideos(page: targetPage);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
