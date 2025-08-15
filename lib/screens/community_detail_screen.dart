import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import 'community_compose_screen.dart';

const String kBaseUrl = 'http://marketalert.iptime.org:8080';

class CommunityDetailArgs {
  final String postId;
  final String authorName;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final List<String> imageUrls;
  final String content;
  final bool isMine;

  const CommunityDetailArgs({
    required this.postId,
    required this.authorName,
    required this.createdAt,
    required this.imageUrls,
    required this.content,
    required this.isMine,
    this.authorAvatarUrl,
  });
}

class CommunityDetailScreen extends StatefulWidget {
  final CommunityDetailArgs args;
  const CommunityDetailScreen({super.key, required this.args});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late String _content;
  late List<String> _imageUrls;

  @override
  void initState() {
    super.initState();
    _content = widget.args.content;
    _imageUrls = List.of(widget.args.imageUrls);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // 삭제
  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: const Text('삭제 후에는 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    ) ?? false;

    if (!ok) return;

    Future<http.Response> _req() async {
      final user = FirebaseAuth.instance.currentUser!;
      final token = await user.getIdToken();
      final uri = Uri.parse('$kBaseUrl/api/community/photos/${widget.args.postId}');
      return http.delete(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
    }

    try {
      var res = await _req();
      if (res.statusCode == 401 || res.statusCode == 403) {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        res = await _req();
      }

      if (res.statusCode == 200 || res.statusCode == 204) {
        if (!mounted) return;
        Navigator.pop(context, {'deleted': true, 'postId': widget.args.postId});
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: ${res.statusCode} ${res.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 중 오류: $e')),
      );
    }
  }

  // 수정
  Future<void> _goEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityComposeScreen.edit(
          postId: widget.args.postId,
          initialContent: _content,
          initialImageUrl: _imageUrls.isNotEmpty ? _imageUrls.first : null,
        ),
      ),
    );

    if (!mounted) return;
    if (result is Map && result['updated'] == true) {
      setState(() {
        _content = (result['content'] as String?)?.trim() ?? _content;
        final newUrl = result['newImageUrl'] as String?;
        if (newUrl != null && newUrl.isNotEmpty) {
          _imageUrls = [newUrl];
          _currentPage = 0;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정되었습니다.')),
      );
    }
  }

  void _onMorePressed() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('수정'),
              onTap: () {
                Navigator.pop(context);
                _goEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('삭제'),
              onTap: () {
                Navigator.pop(context);
                _deletePost();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _Header(
                    authorName: a.authorName,
                    avatarUrl: a.authorAvatarUrl,
                    createdAt: a.createdAt,
                    trailing: a.isMine
                        ? IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: _onMorePressed,
                    )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  if (_imageUrls.isNotEmpty) ...[
                    _ImagePager(
                      images: _imageUrls,
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                    ),
                    const SizedBox(height: 6),
                    _DotsIndicator(
                      count: _imageUrls.length,
                      index: _currentPage,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _Body(content: _content),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String authorName;
  final String? avatarUrl;
  final DateTime createdAt;
  final Widget trailing;

  const _Header({
    required this.authorName,
    required this.avatarUrl,
    required this.createdAt,
    this.trailing = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final dateText =
        '${createdAt.year}.${_two(createdAt.month)}.${_two(createdAt.day)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
            avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authorName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  dateText,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}

class _ImagePager extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  const _ImagePager({
    required this.images,
    required this.controller,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: PageView.builder(
          controller: controller,
          onPageChanged: onPageChanged,
          itemCount: images.length,
          itemBuilder: (_, i) => Image.network(
            images[i],
            fit: BoxFit.cover,
            loadingBuilder: (c, w, p) =>
            p == null ? w : const Center(child: CircularProgressIndicator()),
            errorBuilder: (c, e, s) => Container(
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int index;
  const _DotsIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? Colors.black87 : Colors.black26,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}

class _Body extends StatelessWidget {
  final String content;
  const _Body({required this.content});

  @override
  Widget build(BuildContext context) {
    return Text(
      content,
      style: const TextStyle(fontSize: 16, height: 1.5),
    );
  }
}