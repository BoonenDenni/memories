import 'package:supabase_flutter/supabase_flutter.dart';

/// One row in `public.user_book_status` for the current user.
class UserBookStatus {
  UserBookStatus({
    required this.userId,
    required this.bookId,
    required this.status,
    this.userRating,
    this.note,
    this.finishedAt,
  });

  final String userId;
  final String bookId;
  final String status;
  final int? userRating;
  final String? note;
  final DateTime? finishedAt;

  static UserBookStatus? fromRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final uid = row['user_id']?.toString();
    final bid = row['book_id']?.toString();
    final st = row['status']?.toString();
    if (uid == null || uid.isEmpty || bid == null || bid.isEmpty || st == null) {
      return null;
    }
    final rawRating = row['rating'] ?? row['user_rating'];
    int? rating;
    if (rawRating is num) {
      rating = rawRating.toInt();
    }
    final rawNote = row['notes'] ?? row['note'];
    final rawFinished = row['finished_at'];
    DateTime? finished;
    if (rawFinished is String) {
      finished = DateTime.tryParse(rawFinished);
    } else if (rawFinished is DateTime) {
      finished = rawFinished;
    }
    return UserBookStatus(
      userId: uid,
      bookId: bid,
      status: st,
      userRating: rating,
      note: rawNote?.toString(),
      finishedAt: finished,
    );
  }

  static Future<UserBookStatus?> fetchForBook(
    SupabaseClient client,
    String bookId,
  ) async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from('user_book_status')
        .select(
          'user_id, book_id, status, rating, notes, finished_at',
        )
        .eq('book_id', bookId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return fromRow(Map<String, dynamic>.from(row as Map));
  }
}

/// Values matching `public.book_read_status`.
abstract class BookReadStatus {
  static const wantsToRead = 'wants_to_read';
  static const reading = 'reading';
  static const finished = 'finished';
  static const dropped = 'dropped';

  static const List<String> all = [
    wantsToRead,
    reading,
    finished,
    dropped,
  ];

  static String label(String value) {
    switch (value) {
      case wantsToRead:
        return 'Want to read';
      case reading:
        return 'Reading';
      case finished:
        return 'Finished';
      case dropped:
        return 'Dropped';
      default:
        return value;
    }
  }
}
