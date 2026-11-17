/// Build-time configuration.
///
/// Provide your Supabase project credentials with `--dart-define`:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
///
/// When no credentials are supplied the app starts in **demo mode**: the
/// verification code is shown on screen instead of being e-mailed and you can
/// chat with built-in demo peers over an in-memory encrypted transport.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Optional TURN server for peers behind symmetric NATs.
  static const turnUrl = String.fromEnvironment('TURN_URL');
  static const turnUsername = String.fromEnvironment('TURN_USERNAME');
  static const turnCredential = String.fromEnvironment('TURN_CREDENTIAL');

  static bool get demoMode => supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;

  static const appName = 'Cipherly';
  static const codeLength = 6;
  static const resendCooldown = Duration(seconds: 60);

  static List<Map<String, dynamic>> get iceServers => [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        if (turnUrl.isNotEmpty)
          {
            'urls': turnUrl,
            'username': turnUsername,
            'credential': turnCredential,
          },
      ];
}
