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
    if (user == null) return;

    try {
      final idToken = await user.getIdToken();
      final res = await http.get(
        Uri.parse('$baseUrl/api/favorite-video/list'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (mounted) {
        setState(() {
          favorites = jsonDecode(res.body);
          isLoading = false;
        });
      }
    } catch (e) {
      print("즐겨찾기 로드 실패: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _removeFavorite(String rawUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user!.getIdToken();

      // 1) 서버로 보낼 때만 인코딩
      final encodedUrl = Uri.encodeComponent(rawUrl);

      await httpClient.delete(
        Uri.parse('$baseUrl/api/favorite-video?videoUrl=$encodedUrl'),
        headers: {
          'Authorization': 'Bearer $idToken',
        },
      );

      // 2) DB에서도 삭제됨 → 프론트 리스트에서도 제거
      setState(() {
        favorites.removeWhere((item) => item["videoUrl"] == rawUrl);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "즐겨찾기에서 삭제되었습니다",
              style: TextStyle(color: Colors.black87, fontSize: 14),
            ),
            backgroundColor: Colors.white,
            elevation: 2,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint("삭제 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 배경색 흰색 지정

      // [수정] 메인과 동일한 디자인의 AppBar 적용
      appBar: AppBar(
        backgroundColor: const Color(0xFFA9C18D), // 메인과 동일한 연두색
        elevation: 0,
        centerTitle: true,

        // 흰색 뒤로가기 버튼
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        // 흰색 제목 글씨 & 폰트 통일
        title: const Text(
          "영상 즐겨찾기",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PyeojinGothic',
          ),
        ),

        // 아이콘 테마 흰색 설정
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: buttonGreen))
          : favorites.isEmpty
          ? _buildEmptyView()
          : _buildFavoriteList(),
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
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 110,
                    height: 85,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            // 제목 및 정보
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item["trngNm"] ?? "",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${item["aggrpNm"] ?? '-'} / ${item["ftnsFctrNm"] ?? '-'}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 삭제 버튼
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