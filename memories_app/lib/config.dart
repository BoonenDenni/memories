/// Supabase credentials from `--dart-define` / `--dart-define-from-file` at build time.
class AppConfig {
  AppConfig._();

  static const String _supabaseUrlRaw = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String _supabaseAnonKeyRaw = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Trimmed URL (whitespace in `dart_defines.json` breaks host validation).
  static String get supabaseUrl => _supabaseUrlRaw.trim();

  /// Publishable (`sb_publishable_...`) or legacy anon JWT (`eyJ...`). Never `sb_secret_...`.
  static String get supabaseAnonKey => _supabaseAnonKeyRaw.trim();

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// `sb_secret_` is the **secret** (backend-only) key — invalid for client apps.
  static bool get looksLikeSecretKey =>
      supabaseAnonKey.startsWith('sb_secret_');
}
