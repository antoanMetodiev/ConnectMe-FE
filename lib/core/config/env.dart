/// Compile-time config, passed via `--dart-define-from-file=env.json`
/// (see `env.example.json`). Values are public/anon-level, never secrets —
/// Supabase's anon key is meant to ship in the client and is safe only
/// because Row Level Security enforces access on the server side.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
