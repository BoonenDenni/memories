import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book_with_categories.dart';
import '../models/user_book_status.dart';
import '../utils/open_download_url.dart';

class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({super.key, required this.book});

  final BookWithCategories book;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _loading = true;
  bool _saving = false;
  UserBookStatus? _existing;

  late String _status;
  int? _userRating;
  late final TextEditingController _noteController;
  List<String> _categoryNames = [];

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _status = BookReadStatus.wantsToRead;
    _categoryNames = List.from(widget.book.categoryNames);
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final existing = await UserBookStatus.fetchForBook(client, widget.book.id);
      if (existing != null) {
        _existing = existing;
        _status = existing.status;
        _userRating = existing.userRating;
        _noteController.text = existing.note ?? '';
      }
      if (_categoryNames.isEmpty) {
        _categoryNames = await _fetchCategoryNames(client, widget.book.id);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  static Future<List<String>> _fetchCategoryNames(
    SupabaseClient client,
    String bookId,
  ) async {
    final linksRaw = await client
        .from('book_categories')
        .select('category_id')
        .eq('book_id', bookId) as List<dynamic>;
    final ids = <String>{};
    for (final e in linksRaw) {
      final id = (e as Map)['category_id']?.toString();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return [];
    final catsRaw = await client
        .from('categories')
        .select('name')
        .inFilter('id', ids.toList()) as List<dynamic>;
    final names = <String>{};
    for (final e in catsRaw) {
      final n = (e as Map)['name']?.toString();
      if (n != null && n.isNotEmpty) names.add(n);
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to save.')),
        );
      }
      return;
    }

    String? finishedAtIso;
    if (_status == BookReadStatus.finished) {
      final preserved = _existing?.finishedAt ?? DateTime.now().toUtc();
      finishedAtIso = preserved.toIso8601String();
    } else {
      finishedAtIso = null;
    }

    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('user_book_status').upsert({
        'user_id': user.id,
        'book_id': widget.book.id,
        'status': _status,
        'rating': _userRating,
        'notes': _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        'finished_at': finishedAtIso,
      }, onConflict: 'user_id,book_id');
      if (!mounted) return;
      _existing = UserBookStatus(
        userId: user.id,
        bookId: widget.book.id,
        status: _status,
        userRating: _userRating,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        finishedAt: finishedAtIso == null
            ? null
            : DateTime.tryParse(finishedAtIso),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to your library')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  static String _formatCatalogRating(double r) {
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

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final catalogRating = b.bookRating;

    return Scaffold(
      appBar: AppBar(title: Text(b.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _line(context, 'Author', b.author ?? '—'),
                  _line(context, 'Series', b.serieName ?? '—'),
                  _line(
                    context,
                    'Catalog rating',
                    catalogRating == null
                        ? '—'
                        : '${_formatCatalogRating(catalogRating)} / 5',
                  ),
                  _line(
                    context,
                    'Categories',
                    _categoryNames.isEmpty ? '—' : _categoryNames.join(', '),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    (b.description?.trim().isNotEmpty ?? false)
                        ? b.description!.trim()
                        : '—',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => openDownloadUrl(context, b.downloadUrl),
                      icon: const Icon(Icons.download_outlined, size: 20),
                      label: const Text('Open download link'),
                    ),
                  ),
                  const Divider(height: 32),
                  Text(
                    'Your library',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _status,
                        items: BookReadStatus.all
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(BookReadStatus.label(s)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _status = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Your rating',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _userRating,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('No rating'),
                          ),
                          ...List.generate(
                            5,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1}'),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _userRating = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'Optional thoughts about this book',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 3,
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save to library'),
                  ),
                ],
              ),
            ),
    );
  }
}
