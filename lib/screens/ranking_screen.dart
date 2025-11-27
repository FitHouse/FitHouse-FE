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
  Widget build(BuildContext context) {
    final ranking = context.watch<RankingProvider>();

    return Column(
      children: [
        // ======================= Info 버튼 추가된 영역 =======================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 가운데 텍스트
              const Center(
                child: Text(
                  "가족 랭킹",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // ⭐ 오른쪽 info 버튼
              Positioned(
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.info_outline, size: 22),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const RankingInfoDialog(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // =====================================================================

        TabBar(
          controller: tabController,
          labelColor: Colors.black,
          tabs: const [
            Tab(text: "일간 랭킹"),
            Tab(text: "주간 랭킹"),
          ],
        ),

        Expanded(
          child: TabBarView(
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
        ),
      ],
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
      return const Center(child: CircularProgressIndicator());
    }

    if (list.isEmpty) {
      return const Center(child: Text("데이터가 없습니다."));
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
          Text(
            isWeekly
                ? "👟 아직 랭킹에 들지 못한 가족들이 있어요!\n이번 주엔 더 힘내봐요 🙂"
                : "💡 아직 기록이 부족한 가족들이 있어요.\n오늘은 가볍게 한 걸음 더 걸어볼까요?",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          ...zeroFamilies.map(
                (item) => _zeroFamilyCard(item, item.familyId == myFamilyId),
          ),
        ],
      ],
    );
  }

  Widget _zeroFamilyCard(RankingEntry item, bool isMyFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color:
        isMyFamily ? const Color(0xFFDFF5D8) : Colors.grey[100], // 연한 녹색
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyFamily ? const Color(0xFF6BCF63) : Colors.grey[300]!,
          width: isMyFamily ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_outlined,
              color: isMyFamily ? const Color(0xFF6BCF63) : Colors.grey[700]),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              item.familyName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Text(
            "0%",
            style: TextStyle(
              fontSize: 14,
              color: isMyFamily ? const Color(0xFF6BCF63) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingCard(RankingEntry item, bool isMyFamily) {
    const mainGreen = Color(0xFF6BCF63);
    const lightGreen = Color(0xFFDFF5D8);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isMyFamily ? lightGreen : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMyFamily ? mainGreen : Colors.transparent,
          width: isMyFamily ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _rankIcon(item.rank),
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),

              CircleAvatar(
                radius: 24,
                backgroundImage: item.familyImageUrl != null
                    ? NetworkImage(item.familyImageUrl!)
                    : const AssetImage("assets/images/splash_logo.png")
                as ImageProvider,
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  item.familyName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _progressBar(item.achievement),

          const SizedBox(height: 10),

          Center(
            child: Text(
              "${item.achievement.toStringAsFixed(1)}% 달성  (${item.steps} / ${item.goal})",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _rankIcon(int rank) {
    switch (rank) {
      case 1:
        return "🥇";
      case 2:
        return "🥈";
      case 3:
        return "🥉";
      default:
        return "$rank위";
    }
  }

  Widget _progressBar(double percentage) {
    final double p = percentage.clamp(0, 100);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: p / 100,
        minHeight: 11,
        backgroundColor: Colors.grey[300],
        valueColor: AlwaysStoppedAnimation(
          p >= 100 ? Colors.green : Colors.green,
        ),
      ),
    );
  }
}
