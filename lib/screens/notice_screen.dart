import 'package:flutter/material.dart';

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notices = [
      {
        'title': '고객센터 이용 안내',
        'date': '2025-09-17',
        'content': '앱 내 고객센터에서 1:1 문의를 남겨주세요. 답변까지 1~5일 걸릴 수 있습니다.',
      },
      {
        'title': '개인정보 처리방침 시행 안내',
        'date': '2025-08-15',
        'content': '개인정보 처리방침은 “설정 > 이용 안내 > 약관 및 개인정보 처리방침”에서 확인하실 수 있습니다.',
      },
    ];

    const dividerColor = Color(0xFFE6E6E9);

    return Scaffold(
      backgroundColor: Colors.white, // 배경색 흰색

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
          '공지사항',
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

      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        itemCount: notices.length,
        separatorBuilder: (_, __) =>
        const Divider(height: 0, thickness: 0.5, color: dividerColor),
        itemBuilder: (context, index) {
          final n = notices[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            title: Text(
              n['title']!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                n['date']!,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NoticeDetailScreen(
                    title: n['title']!,
                    date: n['date']!,
                    content: n['content']!,
                  ),
                ),
              );
            },
            tileColor: Colors.white,
          );
        },
      ),
    );
  }
}

class NoticeDetailScreen extends StatelessWidget {
  final String title;
  final String date;
  final String content;

  const NoticeDetailScreen({
    super.key,
    required this.title,
    required this.date,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    const dividerColor = Color(0xFFE6E6E9);

    return Scaffold(
      backgroundColor: Colors.white,

      // [수정] 상세 화면도 동일한 앱바 디자인 적용
      appBar: AppBar(
        backgroundColor: const Color(0xFFA9C18D),
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        title: const Text(
          '공지사항',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'PyeojinGothic',
          ),
        ),

        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 18),
              child: const Divider(height: 1, thickness: 1, color: dividerColor),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 16, height: 1.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}