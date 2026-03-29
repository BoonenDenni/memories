import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book_with_categories.dart';
import '../models/user_book_status.dart';
import 'book_detail_screen.dart';

class MyLibraryScreen extends StatefulWidget {
  const MyLibraryScreen({super.key});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _LibraryRow {
  _LibraryRow({
    required this.book,
    required this.status,
    this.userRating,
    this.finishedAt,
  });

  final BookWithCategories book;
  final String status;
  final int? userRating;
  final DateTime? finishedAt;
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  Future<List<_LibraryRow>>? _future;

  static const _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  static List<DateTime> _last12MonthStarts(DateTime now) {
    final start = DateTime(now.year, now.month - 11, 1);
    return List.generate(
      12,
      (i) => DateTime(start.year, start.month + i, 1),
    );
  }

  static String _monthTickLabel(DateTime m) =>
      '${_monthLabels[m.month - 1]}\n${m.year}';

  Future<List<_LibraryRow>> _load() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return [];

    final raw = await client
        .from('user_book_status')
        .select('book_id, status, rating, notes, finished_at, books(*)')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false);

    final out = <_LibraryRow>[];
    for (final item in raw as List) {
      final map = Map<String, dynamic>.from(item as Map);
      final booksRaw = map['books'];
      if (booksRaw is! Map) continue;
      final bookRow = Map<String, dynamic>.from(booksRaw);
      final book = BookWithCategories.fromBookRow(bookRow, const []);
      final status = map['status']?.toString() ?? BookReadStatus.wantsToRead;
      final r = map['rating'];
      int? ur;
      if (r is num) ur = r.toInt();
      DateTime? fin;
      final fa = map['finished_at'];
      if (fa is String) {
        fin = DateTime.tryParse(fa);
      }
      out.add(
        _LibraryRow(
          book: book,
          status: status,
          userRating: ur,
          finishedAt: fin,
        ),
      );
    }
    return out;
  }

  static List<double> _finishedPerMonthBuckets(
    List<_LibraryRow> rows,
    List<DateTime> monthStarts,
  ) {
    final counts = List<double>.filled(12, 0);
    for (final row in rows) {
      if (row.status != BookReadStatus.finished) continue;
      final dt = row.finishedAt;
      if (dt == null) continue;
      final key = DateTime(dt.year, dt.month, 1);
      final idx = monthStarts.indexWhere(
        (m) => m.year == key.year && m.month == key.month,
      );
      if (idx >= 0) {
        counts[idx] += 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<_LibraryRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}'),
              ),
            );
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No books in your library yet. Browse the catalog and open a '
                  'book to set status and save.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            );
          }

          final now = DateTime.now();
          final monthStarts = _last12MonthStarts(now);
          final bucketCounts = _finishedPerMonthBuckets(rows, monthStarts);
          double maxY = 1;
          if (bucketCounts.isNotEmpty) {
            final peak = bucketCounts.reduce(math.max);
            maxY = math.max(1.0, peak * 1.25);
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Finished books per month',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                if (bucketCounts.every((c) => c == 0))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Mark books as finished to see your monthly completions.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(
                        12,
                        (i) => BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: bucketCounts[i],
                              width: 14,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              if (value != value.roundToDouble()) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                value.toInt().toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i > 11) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _monthTickLabel(monthStarts[i]),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(fontSize: 9),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 32),
                Text(
                  'Your books',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                ...rows.map((r) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        r.book.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          r.book.author ?? '—',
                          BookReadStatus.label(r.status),
                          if (r.userRating != null) '★ ${r.userRating}/5',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => BookDetailScreen(book: r.book),
                          ),
                        );
                        await _reload();
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
