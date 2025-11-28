import 'dart:convert';
import 'package:fithouse/screens/video_player_dialog.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../api/http_client.dart' show baseUrl, authHeaders, httpClient;
import '../constants/colors.dart';

class FavoriteVideoScreen extends StatefulWidget {
  const FavoriteVideoScreen({super.key});

  @override
  State<FavoriteVideoScreen> createState() => _FavoriteVideoScreenState();
}

class _FavoriteVideoScreenState extends State<FavoriteVideoScreen> {
  List<dynamic> favorites = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();

  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user!.getIdToken();

    final res = await http.get(
      Uri.parse('$baseUrl/api/favorite-video/list'),
      headers: {'Authorization': 'Bearer $idToken'},
    );

    setState(() {
      favorites = jsonDecode(res.body);
      isLoading = false;
    });
  }

  Future<void> _removeFavorite(String rawUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user!.getIdToken();

      // 1) 서버로 보낼 때만 인코딩
      final encodedUrl = Uri.encodeComponent(rawUrl);

      final res = await httpClient.delete(
        Uri.parse('$baseUrl/api/favorite-video?videoUrl=$encodedUrl'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      // 2) DB에서도 삭제됨 → 프론트 리스트에서도 제거
      favorites.removeWhere((item) => item["videoUrl"] == rawUrl);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "즐겨찾기에서 삭제되었습니다",
            style: TextStyle(color: Colors.black87, fontSize: 14),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint("삭제 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: const Color(0xFFA9C18D),
          title: const Text("즐겨찾기 영상"), centerTitle: true
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: buttonGreen))
          : favorites.isEmpty
          ? _buildEmptyView()
          : ListView.builder(
        itemCount: favorites.length,
        itemBuilder: (_, i) {
          final v = favorites[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: Image.network(v["thumbnailUrl"], width: 90, height: 90),
              title: Text(v["trngNm"]),
              subtitle: Text("${v["aggrpNm"]} / ${v["ftnsFctrNm"]}"),

              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: () => _removeFavorite(v["videoUrl"]),
              ),

              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => VideoPlayerDialog(videoUrl: v["videoUrl"]),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            "즐겨찾기한 영상이 없습니다.",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          const Text(
            "영상 목록에서 ⭐ 버튼을 눌러 즐겨찾기해보세요!",
            style: TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final item = favorites[index];
        return _buildFavoriteItem(item);
      },
    );
  }

  Widget _buildFavoriteItem(dynamic item) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => VideoPlayerDialog(videoUrl: item["videoUrl"]),
        );
      },

      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Image.network(
                item["thumbnailUrl"] ?? "",
                width: 110,
                height: 85,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(width: 12),

            // 제목
            Expanded(
              child: Text(
                item["trngNm"] ?? "",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => _removeFavorite(item["videoUrl"]),
            ),
          ],
        ),
      ),
    );
  }
}
