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

    Future.microtask(() {
      final provider = context.read<RankingProvider>();
      provider.loadDailyRanking();
      provider.loadWeeklyRanking();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ranking = context.watch<RankingProvider>();

    return Column(
      children: [
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
              RankingListView(ranking.dailyRanking, ranking.loadingDaily),
              RankingListView(ranking.weeklyRanking, ranking.loadingWeekly),
            ],
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// 리스트 UI
/// ---------------------------------------------------------------------------
class RankingListView extends StatelessWidget {
  final List<RankingEntry> list;
  final bool loading;

  const RankingListView(this.list, this.loading, {super.key});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (list.isEmpty) {
      return const Center(child: Text("데이터가 없습니다."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              // 순위
              Text(
                "${item.rank}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(width: 16),

              // 가족 이미지
              CircleAvatar(
                radius: 25,
                backgroundImage: item.familyImageUrl != null
                    ? NetworkImage(item.familyImageUrl!)
                    : const AssetImage("assets/images/splash_logo.png")
                as ImageProvider,
              ),

              const SizedBox(width: 16),

              // 이름 & 걸음 수
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.familyName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${item.steps} 걸음",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
