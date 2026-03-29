import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/book_with_categories.dart';

class _CategoryRow {
  const _CategoryRow({required this.id, required this.name});
  final String id;
  final String name;
}

class _BookBrowseResult {
  const _BookBrowseResult({required this.books, this.emptyMessage});
  final List<BookWithCategories> books;
  final String? emptyMessage;
}

class BrowseBooksScreen extends StatefulWidget {
  const BrowseBooksScreen({super.key});

  @override
  State<BrowseBooksScreen> createState() => _BrowseBooksScreenState();
}

class _BrowseBooksScreenState extends State<BrowseBooksScreen> {
  late final Future<List<_CategoryRow>> _categoriesFuture;
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedCategoryIds = {};

  /// `null` until the user taps "Show books".
  Future<_BookBrowseResult>? _booksFuture;

  bool _booksLoading = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_CategoryRow>> _loadCategories() async {
    final client = Supabase.instance.client;
    final raw = await client.from('categories').select('id, name').order('name');
    return _asMapList(raw)
        .map(
          (r) => _CategoryRow(
            id: _asString(r['id']),
            name: r['name']?.toString() ?? '',
          ),
        )
        .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
        .toList();
  }

  Future<void> _onShowBooks() async {
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one category to load books.'),
        ),
      );
      return;
    }

    setState(() {
      _booksLoading = true;
      _booksFuture = _fetchBooksForFilter(
        Set<String>.from(_selectedCategoryIds),
        _searchController.text,
      );
    });

    try {
      await _booksFuture;
    } finally {
      if (mounted) {
        setState(() {
          _booksLoading = false;
        });
      }
    }
  }

  Future<_BookBrowseResult> _fetchBooksForFilter(
    Set<String> selectedCategoryIds,
    String searchQuery,
  ) async {
    final client = Supabase.instance.client;

    final linksFiltered =
        await _linksForCategoryIds(client, selectedCategoryIds);
    final bookIdSet = linksFiltered
        .map((e) => _asString(e['book_id']))
        .where((id) => id.isNotEmpty)
        .toSet();

    if (bookIdSet.isEmpty) {
      return const _BookBrowseResult(
        books: [],
        emptyMessage:
            'No book_categories rows were returned for the categories you '
            'picked. If Table Editor shows links but this screen does not, Row '
            'Level Security often hides them from the app: add SELECT on '
            'public.book_categories for role authenticated (see repo migration '
            '20250329120001). Also confirm category_id in book_categories matches '
            'the category id you selected (not an old duplicate category row).',
      );
    }

    var bookRows = await _fetchBookRowsById(client, bookIdSet);

    if (bookRows.isEmpty) {
      return const _BookBrowseResult(
        books: [],
        emptyMessage:
            'book_categories points to books, but the books table returned no '
            'rows. Check Row Level Security on public.books (you need SELECT '
            'for authenticated users), and that those book ids still exist.',
      );
    }

    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      final beforeSearch = bookRows.length;
      bookRows = bookRows.where((row) {
        final title = (row['title']?.toString() ?? '').toLowerCase();
        final author = (row['author']?.toString() ?? '').toLowerCase();
        final series = (row['serie_name']?.toString() ?? '').toLowerCase();
        return title.contains(q) ||
            author.contains(q) ||
            series.contains(q);
      }).toList();
      if (bookRows.isEmpty && beforeSearch > 0) {
        return const _BookBrowseResult(
          books: [],
          emptyMessage:
              'No books match your search text in title, author, or series. '
              'Clear the search field and tap Show books again.',
        );
      }
    }

    final fullLinks = await _bookCategoryLinksForBooks(client, bookIdSet);
    final categoryIds = fullLinks
        .map((e) => _asString(e['category_id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    final idToName = await _categoryNamesById(client, categoryIds);

    final bookIdToNames = <String, List<String>>{};
    for (final link in fullLinks) {
      final bid = _asString(link['book_id']);
      final cid = _asString(link['category_id']);
      final name = idToName[cid];
      if (bid.isNotEmpty &&
          cid.isNotEmpty &&
          name != null &&
          name.isNotEmpty) {
        bookIdToNames.putIfAbsent(bid, () => []).add(name);
      }
    }

    final books = bookRows
        .map(
          (row) => BookWithCategories.fromBookRow(
            row,
            bookIdToNames[_asString(row['id'])] ?? const [],
          ),
        )
        .toList();
    return _BookBrowseResult(books: books);
  }

  static const int _idBatchSize = 40;

  /// PostgREST `in.("uuid",...)` on uuid columns can return no rows; `eq` /
  /// `or(eq,...)` matches reliably.
  static Future<List<Map<String, dynamic>>> _selectByUuidColumnIn(
    SupabaseClient client,
    String table,
    String selectClause,
    String uuidColumn,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return [];
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += _idBatchSize) {
      final batch = ids.sublist(i, min(i + _idBatchSize, ids.length));
      final dynamic raw;
      if (batch.length == 1) {
        raw = await client
            .from(table)
            .select(selectClause)
            .eq(uuidColumn, batch.single);
      } else {
        final orClause = batch
            .map((id) => '$uuidColumn.eq.${_postgrestQuotedFilterValue(id)}')
            .join(',');
        raw = await client.from(table).select(selectClause).or(orClause);
      }
      out.addAll(_asMapList(raw));
    }
    return out;
  }

  static String _postgrestQuotedFilterValue(String value) {
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }

  static Future<List<Map<String, dynamic>>> _linksForCategoryIds(
    SupabaseClient client,
    Set<String> categoryIds,
  ) async {
    if (categoryIds.isEmpty) return [];
    return _selectByUuidColumnIn(
      client,
      'book_categories',
      'book_id, category_id',
      'category_id',
      categoryIds.toList(),
    );
  }

  static Future<List<Map<String, dynamic>>> _fetchBookRowsById(
    SupabaseClient client,
    Set<String> bookIdSet,
  ) async {
    if (bookIdSet.isEmpty) return [];
    final out = await _selectByUuidColumnIn(
      client,
      'books',
      'id, title, author, description, download_url, book_rating, serie_name',
      'id',
      bookIdSet.toList(),
    );
    out.sort(
      (a, b) => (a['title']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['title']?.toString() ?? '').toLowerCase()),
    );
    return out;
  }

  static Future<List<Map<String, dynamic>>> _bookCategoryLinksForBooks(
    SupabaseClient client,
    Set<String> bookIdSet,
  ) async {
    if (bookIdSet.isEmpty) return [];
    return _selectByUuidColumnIn(
      client,
      'book_categories',
      'book_id, category_id',
      'book_id',
      bookIdSet.toList(),
    );
  }

  static Future<Map<String, String>> _categoryNamesById(
    SupabaseClient client,
    Set<String> categoryIds,
  ) async {
    if (categoryIds.isEmpty) return {};
    final idToName = <String, String>{};
    final rows = await _selectByUuidColumnIn(
      client,
      'categories',
      'id, name',
      'id',
      categoryIds.toList(),
    );
    for (final c in rows) {
      final cid = _asString(c['id']);
      final name = c['name']?.toString();
      if (cid.isNotEmpty && name != null && name.isNotEmpty) {
        idToName[cid] = name;
      }
    }
    return idToName;
  }

  static List<Map<String, dynamic>> _asMapList(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) {
      throw FormatException(
        'Expected a list from Supabase, got ${raw.runtimeType}',
      );
    }
    return raw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static String _asString(Object? value) => value?.toString() ?? '';

  Future<void> _openDownload(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No download link for this book.')),
      );
      return;
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download link is not a valid http(s) URL.'),
        ),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  String _ratingLabel(double? r) {
    if (r == null) return '—';
    if (r == r.roundToDouble()) return r.toStringAsFixed(0);
    return r.toStringAsFixed(1);
  }

  Widget _line(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(List<_CategoryRow> categories) {
    return Material(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filter',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick categories, optionally narrow by text, then load books.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              Text(
                'No categories available yet. Add categories in Supabase first.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((c) {
                  final selected = _selectedCategoryIds.contains(c.id);
                  return FilterChip(
                    label: Text(c.name),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedCategoryIds.add(c.id);
                        } else {
                          _selectedCategoryIds.remove(c.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search (title, author, series)',
                hintText: 'Optional — apply after loading categories',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onShowBooks(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_booksLoading || categories.isEmpty) ? null : _onShowBooks,
              icon: _booksLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(_booksLoading ? 'Loading…' : 'Show books'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    final future = _booksFuture;
    if (future == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Select categories and tap Show books. Nothing is loaded until then.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return FutureBuilder<_BookBrowseResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load books',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }
        final result = snapshot.data!;
        final books = result.books;
        if (books.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                result.emptyMessage ??
                    'No books match these filters. Try other categories or clear the search.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final b = books[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _line(context, 'Author', b.author ?? '—'),
                    _line(context, 'Series', b.serieName ?? '—'),
                    _line(
                      context,
                      'Rating',
                      _ratingLabel(b.bookRating),
                    ),
                    _line(
                      context,
                      'Categories',
                      b.categoryNames.isEmpty
                          ? '—'
                          : b.categoryNames.join(', '),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (b.description?.trim().isNotEmpty ?? false)
                          ? b.description!.trim()
                          : '—',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: () => _openDownload(context, b.downloadUrl),
                        icon: const Icon(Icons.download_outlined, size: 20),
                        label: const Text('Open download link'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse books')),
      body: FutureBuilder<List<_CategoryRow>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load categories',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }
          final categories = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilterSection(categories),
              const Divider(height: 1),
              Expanded(child: _buildResultsSection()),
            ],
          );
        },
      ),
    );
  }
}
