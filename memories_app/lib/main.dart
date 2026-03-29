import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'agent_debug_log.dart';
import 'app.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const _ConfigErrorApp());
    return;
  }

  if (AppConfig.looksLikeSecretKey) {
    runApp(const _WrongApiKeyTypeApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // #region agent log
  Uri? parsed;
  try {
    parsed = Uri.parse(AppConfig.supabaseUrl);
  } catch (_) {}
  await agentDebugLog(
    hypothesisId: 'A',
    location: 'main.dart:afterSupabaseInit',
    message: 'supabase_init_complete',
    data: {
      'urlHost': parsed?.host ?? 'parse_failed',
      'urlHasSsl': parsed?.scheme == 'https',
      'anonKeyLen': AppConfig.supabaseAnonKey.length,
      'keyLooksPublishable':
          AppConfig.supabaseAnonKey.startsWith('sb_publishable_'),
      'keyLooksLegacyJwt': AppConfig.supabaseAnonKey.startsWith('eyJ'),
      'rawHadTrailingSpace': AppConfig.supabaseAnonKey !=
          const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
    },
  );
  // #endregion

  runApp(const MemoriesApp());
}

/// Secret key (`sb_secret_`) was pasted — must use publishable or legacy anon JWT.
class _WrongApiKeyTypeApp extends StatelessWidget {
  const _WrongApiKeyTypeApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wrong API key type',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'SUPABASE_ANON_KEY looks like a secret key (sb_secret_...). '
                  'The app must use the publishable client key or the legacy anon JWT.',
                ),
                const SizedBox(height: 16),
                Text(
                  'In Supabase Dashboard → Project Settings → API:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Use the publishable key (sb_publishable_...), or\n'
                  '• Use the legacy anon public key (long eyJ... JWT).\n'
                  '• Never use the secret / service_role key in the mobile or web app.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Update dart_defines.json, then hot-restart or run again.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when dart-defines are missing so `flutter run` fails clearly.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supabase not configured',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add secrets locally (not in git): copy dart_defines.example.json to dart_defines.json, fill in URL and anon key, then run:',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'flutter run -d web-server --dart-define-from-file=dart_defines.json\n\n'
                  'PowerShell: do not put a space after --dart-define= or Flutter will treat the URL as a file path.\n\n'
                  'Use the publishable key (sb_publishable_...) or legacy anon JWT (eyJ...) from Dashboard → Settings → API. Never sb_secret_...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text(
                  'Or use Run and Debug with .vscode/launch.json (same dart_defines.json).',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
