import 'dart:convert';
import 'package:flutter/material.dart';

import 'community_detail_screen.dart';
import 'community_compose_screen.dart';
import '../api/http_client.dart' show baseUrl, getJson;

/// (간단) 가족 미소속 에러 - 당장은 이 파일 안에 로컬 클래스로 둔다.
/// 나중에 재사용 필요해지면 lib/error/no_family_joined_error.dart로 분리하면 됨.
class NoFamilyJoinedError implements Exception {
  final String message;
  NoFamilyJoinedError([this.message = '소속된 가족이 없습니다.']);
  @override
  String toString() => message;
}

class FamilyMember {
  final int id;
  final String name;
  final String? avatarUrl;
  const FamilyMember({required this.id, required this.name, this.avatarUrl});

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
    id: j['id'] as int,
    name: j['name'] as String,
    avatarUrl: j['profileImageUrl'] as String?,
  );
}

class FamilySummary {
  final int familyId;
  final String familyName;
  final List<FamilyMember> members;
  final int totalPosts;
  final int monthlyPosts;
  final int memberCount;
  final DateTime? lastPostedAt;
  final int myMemberId;

  const FamilySummary({
    required this.familyId,
    required this.familyName,
    required this.members,
    required this.totalPosts,
    required this.monthlyPosts,
    required this.memberCount,
    required this.lastPostedAt,
    required this.myMemberId,
  });

  factory FamilySummary.fromJson(Map<String, dynamic> j) => FamilySummary(
    familyId: j['familyId'] as int,
    familyName: j['familyName'] as String,
    members: (j['members'] as List)
        .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalPosts: j['totalPosts'] as int,
    monthlyPosts: j['monthlyPosts'] as int,
    memberCount: j['memberCount'] as int,
    lastPostedAt: j['lastPostedAt'] == null
        ? null
        : DateTime.parse(j['lastPostedAt'] as String),
    myMemberId: j['myMemberId'] as int,
  );
}

class FeedItem {
  final int id;
  final int authorId;
  final String imageUrl;
  final String thumbnailUrl;
  final String? comment;
  final DateTime date;

  const FeedItem({
    required this.id,
    required this.authorId,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.date,
    this.comment,
  });

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
    id: j['id'] as int,
    authorId: j['authorId'] as int,
    imageUrl: j['imageUrl'] as String,
    thumbnailUrl: j['thumbnailUrl'] as String,
    date: DateTime.parse(j['date'] as String),
    comment: j['comment'] as String?,
  );
}

class PageResponse<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalPages;
  final int totalElements;
  const PageResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalPages,
    required this.totalElements,
  });
}

class CommunityRepo {
  final String baseUrl;
  CommunityRepo({required this.baseUrl});

  Future<FamilySummary> fetchFamilySummary() async {
    final res = await getJson('$baseUrl/api/community/family');

    if (res.statusCode == 404 || res.statusCode == 500) {
      throw NoFamilyJoinedError();
    }

    if (res.statusCode != 200) {
      throw Exception('summary ${res.statusCode}: ${res.body}');
    }

    final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
    return FamilySummary.fromJson(jsonMap);
  }

  Future<PageResponse<FeedItem>> fetchFeed({
    required int familyId,
    required int page,
    required int size,
    int? memberId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/community/list').replace(
      queryParameters: {
        'familyId': '$familyId',
        'page': '$page',
        'size': '$size',
        if (memberId != null) 'memberId': '$memberId',
        'sort': 'date,desc',
      },
    );
    final res = await getJson(uri.toString());
    if (res.statusCode != 200) {
      throw Exception('photos ${res.statusCode}: ${res.body}');
    }
    final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (jsonMap['content'] as List)
        .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return PageResponse<FeedItem>(
      content: items,
      page: jsonMap['page'] as int,
      size: jsonMap['size'] as int,
      totalElements: (jsonMap['totalElements'] as num).toInt(),
      totalPages: jsonMap['totalPages'] as int,
    );
  }

  Future<List<int>> fetchBlockedUserIds() async {
    final res = await getJson('$baseUrl/api/community/blocks');
    if (res.statusCode != 200) {
      throw Exception('blocks ${res.statusCode}: ${res.body}');
    }
    return (jsonDecode(res.body) as List).cast<int>();
  }
}

class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab>
    with AutomaticKeepAliveClientMixin {
  late final CommunityRepo _repo = CommunityRepo(baseUrl: baseUrl);
  final _scroll = ScrollController();

  FamilySummary? _summary;
  List<FeedItem> _feed = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _size = 30;
  int? _selectedMemberId;
  int? _myMemberId;

  // 가족 미소속 플래그
  bool _noFamily = false;

  // 차단된 사용자 id들
  Set<int> _blockedUserIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _noFamily = false;
    });
    try {
      final s = await _repo.fetchFamilySummary();
      _summary = s;
      _myMemberId = s.myMemberId;

      // 차단 목록
      final blocked = await _repo.fetchBlockedUserIds();
      _blockedUserIds = blocked.toSet();

      _page = 0;
      _hasMore = true;
      _feed.clear();
      await _fetchPage(reset: true);
      if (!mounted) return;
      setState(() {});
    } on NoFamilyJoinedError {
      if (!mounted) return;
      setState(() {
        _noFamily = true;
        _summary = null;
        _feed = [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('불러오기 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchPage({bool reset = false}) async {
    final s = _summary!;
    setState(() => _loadingMore = true);
    try {
      final pageRes = await _repo.fetchFeed(
        familyId: s.familyId,
        page: _page,
        size: _size,
        memberId: _selectedMemberId,
      );

      // 차단된 작성자 글 제외
      final filtered = pageRes.content
          .where((it) => !_blockedUserIds.contains(it.authorId))
          .toList();

      if (!mounted) return;
      setState(() {
        if (reset) {
          _feed = filtered;
        } else {
          _feed.addAll(filtered);
        }
        _hasMore = _page + 1 < pageRes.totalPages;
        if (_hasMore) _page += 1;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _loadMore() async {
    if (_summary == null || !_hasMore) return;
    await _fetchPage();
  }

  Future<void> _onSelectMember(int? id) async {
    setState(() {
      _selectedMemberId = id;
      _page = 0;
      _hasMore = true;
      _feed.clear();
    });
    await _fetchPage(reset: true);
  }

  Future<void> _goCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CommunityComposeScreen.create(),
      ),
    );
    if (!mounted) return;
    if (result is Map && result['created'] == true) {
      await _load();
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 가족 미소속 전용 뷰
    if (_noFamily) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            _NoFamilyView(),
          ],
        ),
      );
    }

    final s = _summary!;
    final feed = _feed;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _FamilyHeader(
                familyName: s.familyName,
                subtitle: '가족 ${s.memberCount}명 · 이번 달 사진 ${s.monthlyPosts}장',
                onCompose: _goCreate,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _MemberCarousel(
              members: s.members,
              selectedMemberId: _selectedMemberId,
              onSelect: _onSelectMember,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final item = feed[index];
                  final member = s.members.firstWhere(
                        (m) => m.id == item.authorId,
                    orElse: () =>
                        FamilyMember(id: item.authorId, name: '알수없음'),
                  );
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final args = CommunityDetailArgs(
                        postId: item.id.toString(),
                        authorId: item.authorId, // 차단 시 필요
                        authorName: member.name,
                        authorAvatarUrl: member.avatarUrl,
                        createdAt: item.date,
                        imageUrls: [item.imageUrl],
                        content: item.comment ?? '',
                        isMine:
                        _myMemberId != null && item.authorId == _myMemberId,
                      );

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityDetailScreen(args: args),
                        ),
                      );

                      if (!mounted) return;
                      if (result is Map) {
                        if (result['deleted'] == true) {
                          setState(() {
                            _feed.removeWhere(
                                    (it) => it.id.toString() == result['postId']);
                          });
                        } else if (result['updated'] == true) {
                          final idx = _feed.indexWhere((it) =>
                          it.id.toString() ==
                              (result['postId'] as String));
                          if (idx != -1) {
                            final old = _feed[idx];
                            final newImageUrl =
                            (result['newImageUrl'] as String?)?.trim();
                            final newContent =
                            (result['content'] as String?)?.trim();

                            final updated = FeedItem(
                              id: old.id,
                              authorId: old.authorId,
                              date: old.date,
                              imageUrl: (newImageUrl != null &&
                                  newImageUrl.isNotEmpty)
                                  ? newImageUrl
                                  : old.imageUrl,
                              thumbnailUrl: (newImageUrl != null &&
                                  newImageUrl.isNotEmpty)
                                  ? newImageUrl
                                  : old.thumbnailUrl,
                              comment: (newContent != null &&
                                  newContent.isNotEmpty)
                                  ? newContent
                                  : old.comment,
                            );

                            setState(() {
                              _feed[idx] = updated;
                            });
                          }
                        } else if (result['blockedMemberId'] != null) {
                          final int blockedId =
                          result['blockedMemberId'] as int;
                          setState(() {
                            _blockedUserIds.add(blockedId); // 이후 로드도 제외
                            _feed.removeWhere(
                                    (it) => it.authorId == blockedId); // 즉시 숨김
                          });
                        }
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            item.thumbnailUrl,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: _MiniMemberBadge(member: member),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: feed.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _loadingMore
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
                : const SizedBox.shrink(),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

/// 가족 미소속 전용 뷰 (가벼운 빈 상태 화면)
class _NoFamilyView extends StatelessWidget {
  const _NoFamilyView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7);
    return Center(
      child: Column(
        children: [
          const Icon(Icons.group_off_outlined, size: 56, color: Colors.black38),
          const SizedBox(height: 10),
          const Text(
            '소속된 가족이 없습니다.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '가족 그룹을 생성하거나 초대 코드를 입력해 참여해 주세요.',
            style: TextStyle(fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}

class _FamilyHeader extends StatelessWidget {
  const _FamilyHeader({
    required this.familyName,
    required this.subtitle,
    required this.onCompose,
  });

  final String familyName;
  final String subtitle;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  familyName,
                  style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          FloatingActionButton.small(
            onPressed: onCompose,
            heroTag: 'headerComposeButton',
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 1,
            child: const Icon(Icons.edit, size: 22),
          ),
        ],
      ),
    );
  }
}

class _MemberCarousel extends StatelessWidget {
  const _MemberCarousel({
    required this.members,
    required this.selectedMemberId,
    required this.onSelect,
  });

  final List<FamilyMember> members;
  final int? selectedMemberId;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _MemberChip(
        label: '전체',
        selected: selectedMemberId == null,
        onTap: () => onSelect(null),
        icon: Icons.groups_rounded,
      ),
      ...members.map(
            (m) => _MemberChip(
          label: m.name,
          selected: selectedMemberId == m.id,
          onTap: () => onSelect(m.id),
          avatarUrl: m.avatarUrl,
        ),
      ),
    ];

    return SizedBox(
      height: 80,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => items[i],
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.avatarUrl,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.green.shade50 : Colors.white;
    final border = selected ? Colors.green : Colors.grey.shade200;
    final textColor = selected ? Colors.green.shade700 : Colors.black87;

    Widget avatar = CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white,
      child: icon != null ? Icon(icon, size: 18, color: Colors.grey.shade700) : null,
    );

    if (icon == null && (avatarUrl ?? '').isNotEmpty) {
      avatar = CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: Colors.white,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            avatar,
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMemberBadge extends StatelessWidget {
  const _MiniMemberBadge({required this.member});

  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final nameTrim = member.name.trim();
    final initials = nameTrim.isEmpty ? '?' : nameTrim[0];
    final img = (member.avatarUrl ?? '').isNotEmpty
        ? CircleAvatar(radius: 8, backgroundImage: NetworkImage(member.avatarUrl!))
        : CircleAvatar(
      radius: 8,
      backgroundColor: Colors.white,
      child: Text(
        initials,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          img,
          const SizedBox(width: 4),
          Text(
            member.name,
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
