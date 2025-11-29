import 'package:fithouse/screens/widgets/ranking_info_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fithouse/providers/ranking_provider.dart';
import 'package:fithouse/models/ranking_entry.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);

    Future.microtask(() async {
      final provider = context.read<RankingProvider>();
      await provider.loadMyFamilyId();
      provider.loadDailyRanking();
      provider.loadWeeklyRanking();
    });
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ranking = context.watch<RankingProvider>();

    // 메인 테마 색상 (연두색)
    const mainThemeColor = Color(0xFFA9C18D);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: mainThemeColor,
        elevation: 0,
        centerTitle: true,

        // 뒤로가기 버튼
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        // 제목
        title: const Text(
          "가족 랭킹",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PyeojinGothic',
          ),
        ),

        // [추가] Info 버튼 (우측 상단)
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const RankingInfoDialog(),
              );
            },
          ),
        ],

        // [핵심 수정] 탭바 디자인 변경 (흰색 박스 스타일)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10), // 여백 조정
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2), // 선택 안 된 배경 (반투명 흰색)
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: tabController,
              // 선택된 탭 디자인 (흰색 캡슐)
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab, // 탭 전체를 채움
              dividerColor: Colors.transparent, // 기본 밑줄 제거

              // 글자 색상 설정
              labelColor: mainThemeColor, // 선택된 글씨: 연두색
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),

              unselectedLabelColor: Colors.white, // 선택 안 된 글씨: 흰색
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),

              tabs: const [
                Tab(text: "일간 랭킹"),
                Tab(text: "주간 랭킹"),
              ],
            ),
          ),
        ),
      ),

      body: TabBarView(
        controller: tabController,
        children: [
          RankingListView(
            ranking.dailyRanking,
            ranking.loadingDaily,
            isWeekly: false,
          ),
          RankingListView(
            ranking.weeklyRanking,
            ranking.loadingWeekly,
            isWeekly: true,
          ),
        ],
      ),
    );
  }
}

class RankingListView extends StatelessWidget {
  final List<RankingEntry> list;
  final bool loading;
  final bool isWeekly;

  const RankingListView(
      this.list,
      this.loading, {
        super.key,
        required this.isWeekly,
      });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6BCF63)));
    }

    if (list.isEmpty) {
      return const Center(
        child: Text(
          "랭킹 데이터가 없습니다.",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    final myFamilyId =
        Provider.of<RankingProvider>(context, listen: false).myFamilyId;

    final zeroFamilies = list.where((e) => e.steps == 0).toList();
    final normalFamilies = list.where((e) => e.steps > 0).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 상위 랭킹 카드
        ...normalFamilies.map(
              (item) => _rankingCard(item, item.familyId == myFamilyId),
        ),

        const SizedBox(height: 35),

        // 0걸음 가족 멘트
        if (zeroFamilies.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWeekly
                      ? "👟 이번 주엔 더 힘내봐요!"
                      : "💡 오늘은 가볍게 한 걸음 더 걸어볼까요?",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                ...zeroFamilies.map(
                      (item) => _zeroFamilyCard(item, item.familyId == myFamilyId),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _zeroFamilyCard(RankingEntry item, bool isMyFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyFamily ? const Color(0xFF6BCF63) : Colors.grey[300]!,
          width: isMyFamily ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_walk,
              color: isMyFamily ? const Color(0xFF6BCF63) : Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.familyName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            "0 걸음",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingCard(RankingEntry item, bool isMyFamily) {
    const mainGreen = Color(0xFF6BCF63);
    const lightGreen = Color(0xFFE8F5E9);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isMyFamily ? lightGreen : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMyFamily ? mainGreen : Colors.transparent,
          width: isMyFamily ? 1.5 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 순위
              SizedBox(
                width: 40,
                child: Text(
                  _rankIcon(item.rank),
                  style: TextStyle(
                    fontSize: item.rank <= 3 ? 24 : 18,
                    fontWeight: FontWeight.bold,
                    color: item.rank <= 3 ? null : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),

              // 프로필 이미지
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey[200],
                backgroundImage: item.familyImageUrl != null
                    ? NetworkImage(item.familyImageUrl!)
                    : const AssetImage("assets/images/splash_logo.png")
                as ImageProvider,
              ),
              const SizedBox(width: 14),

              // 이름
              Expanded(
                child: Text(
                  item.familyName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 진행률 바
          _progressBar(item.achievement),

          const SizedBox(height: 8),

          // 걸음 수 텍스트
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                "${item.steps} ",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: mainGreen,
                ),
              ),
              Text(
                "/ ${item.goal} 걸음 (${item.achievement.toStringAsFixed(0)}%)",
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rankIcon(int rank) {
    switch (rank) {
      case 1: return "🥇";
      case 2: return "🥈";
      case 3: return "🥉";
      default: return "$rank";
    }
  }

  Widget _progressBar(double percentage) {
    final double p = percentage.clamp(0, 100);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LinearProgressIndicator(
        value: p / 100,
        minHeight: 8,
        backgroundColor: Colors.grey[200],
        valueColor: const AlwaysStoppedAnimation(Color(0xFF6BCF63)),
      ),
    );
  }
}