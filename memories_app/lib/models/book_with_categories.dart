/// Book row plus resolved category names (from `book_categories` + `categories`).
class BookWithCategories {
  BookWithCategories({
    required this.id,
    required this.title,
    this.author,
    this.description,
    this.downloadUrl,
    this.bookRating,
    this.serieName,
    required this.categoryNames,
  });

  final String id;
  final String title;
  final String? author;
  final String? description;
  final String? downloadUrl;
  final double? bookRating;
  final String? serieName;
  final List<String> categoryNames;

  /// Flat `books` row + names already resolved (e.g. merged client-side).
  factory BookWithCategories.fromBookRow(
    Map<String, dynamic> row,
    List<String> categoryNames,
  ) {
    final ratingRaw = row['book_rating'];
    double? rating;
    if (ratingRaw is num) {
      rating = ratingRaw.toDouble();
    }

    final names = {...categoryNames}.where((n) => n.isNotEmpty).toList()..sort();

    final id = row['id']?.toString();
    if (id == null || id.isEmpty) {
      throw FormatException('Book row missing id: $row');
    }

    return BookWithCategories(
      id: id,
      title: row['title']?.toString() ?? '',
      author: row['author'] as String?,
      description: row['description'] as String?,
      downloadUrl: row['download_url'] as String?,
      bookRating: rating,
      serieName: row['serie_name'] as String?,
      categoryNames: names,
    );
  }
}
