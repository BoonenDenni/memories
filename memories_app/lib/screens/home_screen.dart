import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'browse_books_screen.dart';
import 'my_library_screen.dart';

/// Placeholder actions — wire navigation per feature later.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _placeholders = <_PlaceholderAction>[
    _PlaceholderAction(label: 'Browse books', icon: Icons.menu_book_outlined),
    _PlaceholderAction(label: 'My list', icon: Icons.bookmark_outline),
    _PlaceholderAction(label: 'Categories', icon: Icons.category_outlined),
    _PlaceholderAction(label: 'Profile', icon: Icons.person_outline),
  ];

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (email.isNotEmpty)
                Text(
                  'Signed in as $email',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              const SizedBox(height: 8),
              Text(
                'Choose an action',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: _placeholders.length,
                  itemBuilder: (context, index) {
                    final item = _placeholders[index];
                    return FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.center,
                      ),
                      onPressed: () {
                        if (index == 0) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const BrowseBooksScreen(),
                            ),
                          );
                          return;
                        }
                        if (index == 1) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MyLibraryScreen(),
                            ),
                          );
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('“${item.label}” — connect this later'),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            item.label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderAction {
  const _PlaceholderAction({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}
