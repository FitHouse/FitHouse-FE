import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ===== 모델 =====
class FamilyMember {
  final int id;
  final String name;
  final String? avatarUrl;
  const FamilyMember({required this.id, required this.name, this.avatarUrl});
}

class FamilySummary {
  final int familyId;
  final String familyName;
  final String inviteCode;
  final List<FamilyMember> members;
  final int totalPosts;
  final int monthlyPosts;
  final DateTime? lastPostedAt;

  const FamilySummary({
    required this.familyId,
    required this.familyName,
    required this.inviteCode,
    required this.members,
    required this.totalPosts,
    required this.monthlyPosts,
    this.lastPostedAt,
  });
}

class FeedItem {
  final int id;
  final int authorId; // 멤버 필터용
  const FeedItem({required this.id, required this.authorId});
}

/// ===== 레포(지금은 더미) =====
class CommunityRepo {
  Future<FamilySummary> fetchFamilySummary() async {
    // TODO: 실제 API로 교체: GET /me/family/summary
    await Future.delayed(const Duration(milliseconds: 250));
    const members = [
      FamilyMember(id: 1, name: '엄마'),
      FamilyMember(id: 2, name: '아빠'),
      FamilyMember(id: 3, name: '하민'),
    ];
    return const FamilySummary(
      familyId: 10,
      familyName: '하늘하늘네 가족',
      inviteCode: 'AB12CD',
      members: members,
      totalPosts: 73,
      monthlyPosts: 12,
      lastPostedAt: null,
    );
  }

  Future<List<FeedItem>> fetchFeed(List<FamilyMember> members) async {
    // TODO: 실제 API로 교체: GET /me/family/photos?page=...
    await Future.delayed(const Duration(milliseconds: 200));
    // 더미: 멤버 id 순환하면서 30개
    return List.generate(30, (i) {
      final m = members[i % members.length];
      return FeedItem(id: i + 1, authorId: m.id);
    });
  }
}

/// ===== 메인 탭 위젯 =====
class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab>
    with AutomaticKeepAliveClientMixin {
  final _repo = CommunityRepo();
  final _scroll = ScrollController();

  FamilySummary? _summary;
  List<FeedItem> _feed = [];
  bool _loading = true;
  int? _selectedMemberId; // null = 전체

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await _repo.fetchFamilySummary();
      final f = await _repo.fetchFeed(s.members);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _feed = f;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('불러오기 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyInvite() async {
    if (_summary == null) return;
    await Clipboard.setData(ClipboardData(text: _summary!.inviteCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('초대 코드가 복사됐어요')));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final s = _summary!;
    final filtered = _selectedMemberId == null
        ? _feed
        : _feed.where((e) => e.authorId == _selectedMemberId).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          // 헤더: 가족 타이틀 + 초대 버튼
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _FamilyHeader(
                familyName: '${s.familyName}',
                subtitle: '이번 달 사진 ${s.monthlyPosts}장',
                onInviteTap: _copyInvite,
              ),
            ),
          ),
          // 멤버 캐러셀
          SliverToBoxAdapter(
            child: _MemberCarousel(
              members: s.members,
              selectedMemberId: _selectedMemberId,
              onSelect: (id) => setState(() => _selectedMemberId = id),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          // 3열 그리드(더미)
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
                  final item = filtered[index];
                  final color = Colors
                      .primaries[item.id % Colors.primaries.length]
                      .shade200;
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      // TODO: 상세로 이동
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: color),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: _MiniMemberBadge(
                              member: s.members
                                  .firstWhere((m) => m.id == item.authorId),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

/// ===== 헤더 위젯 =====
class _FamilyHeader extends StatelessWidget {
  const _FamilyHeader({
    required this.familyName,
    required this.subtitle,
    required this.onInviteTap,
  });

  final String familyName;
  final String subtitle;
  final VoidCallback onInviteTap;

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
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE), // 연파랑
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.family_restroom),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(familyName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
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
          TextButton.icon(
            onPressed: onInviteTap,
            style: TextButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('초대'),
          ),
        ],
      ),
    );
  }
}

/// ===== 멤버 캐러셀/칩 =====
class _MemberCarousel extends StatelessWidget {
  const _MemberCarousel({
    required this.members,
    required this.selectedMemberId,
    required this.onSelect,
  });

  final List<FamilyMember> members;
  final int? selectedMemberId; // null = 전체
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
      ...members.map((m) => _MemberChip(
        label: m.name,
        selected: selectedMemberId == m.id,
        onTap: () => onSelect(m.id),
      )),
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.blue.shade50 : Colors.grey.shade100;
    final border = selected ? Colors.blue : Colors.grey.shade300;
    final textColor = selected ? Colors.blue.shade700 : Colors.black87;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: icon != null
                  ? Icon(icon, size: 18, color: Colors.grey.shade700)
                  : null,
            ),
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

/// ===== 우하단 미니 배지 =====
class _MiniMemberBadge extends StatelessWidget {
  const _MiniMemberBadge({required this.member});

  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final nameTrim = member.name.trim();
    final initials = nameTrim.isEmpty ? '?' : nameTrim[0];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: Colors.white,
            child: Text(
              initials,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
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
