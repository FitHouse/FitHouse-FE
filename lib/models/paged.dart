class Paged<T> {
  final List<T> content;
  final int page;
  final int totalPages;

  Paged({required this.content, required this.page, required this.totalPages});

  factory Paged.fromJson(
      Map<String, dynamic> json,
      T Function(Map<String, dynamic>) fromItem,
      ) {
    final items = (json['content'] as List)
        .map((e) => fromItem(e as Map<String, dynamic>))
        .toList();
    return Paged(
      content: items,
      page: json['number'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}
