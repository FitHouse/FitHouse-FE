import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/http_client.dart' show baseUrl, httpClient, authHeaders;
import '../constants/colors.dart' show buttonGreen;

/// 블록 사용자 모델 (가족 요약에서 프로필 매칭용)
class BlockedUser {
  final int memberId;
  final String name;
  final String? avatarUrl;
  const BlockedUser({required this.memberId, required this.name, this.avatarUrl});

  BlockedUser copyWith({int? memberId, String? name, String? avatarUrl}) {
    return BlockedUser(
      memberId: memberId ?? this.memberId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class BlockListScreen extends StatefulWidget {
  const BlockListScreen({super.key});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  bool _loading = true;
  String? _error;
  List<int> _blockedIds = [];
  final Map<int, BlockedUser> _blockedUsers = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) 차단 ID 리스트
      final blocksRes = await httpClient.get(
        Uri.parse('$baseUrl/api/community/blocks'),
        headers: await authHeaders(),
      );
      if (blocksRes.statusCode != 200) {
        throw Exception('blocks ${blocksRes.statusCode}: ${blocksRes.body}');
      }
      final ids = (jsonDecode(blocksRes.body) as List).cast<int>();

      // 2) 가족 요약으로 id -> 프로필 매핑
      final famRes = await httpClient.get(
        Uri.parse('$baseUrl/api/community/family'),
        headers: await authHeaders(),
      );
      List<dynamic> members = [];
      if (famRes.statusCode == 200) {
        final data = jsonDecode(famRes.body) as Map<String, dynamic>;
        members = (data['members'] as List? ?? []);
      }

      final map = <int, BlockedUser>{};
      for (final id in ids) {
        final m = members.cast<Map<String, dynamic>?>().firstWhere(
              (e) => e != null && e['id'] == id,
          orElse: () => null,
        );
        if (m != null) {
          map[id] = BlockedUser(
            memberId: id,
            name: ((m['name'] as String?) ?? '').trim().isEmpty
                ? '알수없음'
                : m['name'] as String,
            avatarUrl: m['profileImageUrl'] as String?,
          );
        } else {
          map[id] = const BlockedUser(memberId: 0, name: '알수없음')
              .copyWith(memberId: id);
        }
      }

      if (!mounted) return;
      setState(() {
        _blockedIds = ids;
        _blockedUsers
          ..clear()
          ..addAll(map);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmUnblock(int memberId) async {
    final user = _blockedUsers[memberId];
    final name = user?.name ?? '사용자';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Center(child: Text('차단 해제할까요?')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                '"$name" 님의 차단을 해제합니다.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '해제 후에는 다시 게시글과 활동이 보일 수 있어요.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black54),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('취소', textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('차단 해제', textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (ok == true) {
      await _unblock(memberId);
    }
  }

  Future<void> _unblock(int memberId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/community/blocks/$memberId');
      final res = await httpClient.delete(uri, headers: await authHeaders());

      if (res.statusCode == 200 || res.statusCode == 204) {
        if (!mounted) return;
        setState(() {
          _blockedIds.remove(memberId);
          _blockedUsers.remove(memberId);
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('해제 실패: ${res.statusCode} ${res.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('해제 중 오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 배경색 흰색 설정

      // [수정] 메인 화면과 동일한 디자인의 AppBar 적용
      appBar: AppBar(
        backgroundColor: const Color(0xFFA9C18D), // 연두색 배경
        elevation: 0,
        centerTitle: true,

        // 흰색 뒤로가기 버튼
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        // 흰색 제목 글씨 & 폰트 통일
        title: const Text(
          '차단 관리',
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

      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            const _CenteredInfo(
              icon: Icons.error_outline,
              title: '차단 목록을 불러오지 못했습니다.',
              subtitle:
              '네트워크 상태를 확인하고 다시 시도해 주세요.',
            ),
          ],
        )
            : (_blockedIds.isEmpty)
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            _CenteredInfo(
              icon: Icons.block_outlined,
              title: '차단한 사용자가 없습니다.',
              subtitle: '커뮤니티에서 차단한 사용자가 이곳에 표시됩니다.',
            ),
          ],
        )
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _blockedIds.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final id = _blockedIds[i];
            final u = _blockedUsers[id];
            final displayName =
            (u?.name ?? '').trim().isEmpty ? '알수없음' : u!.name;
            final avatarUrl = u?.avatarUrl;

            return ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage:
                (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              title: Text(displayName),
              trailing: OutlinedButton(
                onPressed: () => _confirmUnblock(id),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(96, 36),
                  side: BorderSide(color: buttonGreen, width: 1),
                  foregroundColor: buttonGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('차단 해제'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CenteredInfo extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _CenteredInfo({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final subColor =
    Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Icon(icon, size: 56, color: Colors.black38),
            const SizedBox(height: 10),
            Text(title,
                style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: subColor)),
            ],
          ],
        ),
      ),
    );
  }
}