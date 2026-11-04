/// Configuration constants for Supabase and the Incline platform.
/// Supports dynamic injection via --dart-define at build time for CI/CD pipelines.
class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://iyqqpbvnszyrrgerniog.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5cXFwYnZuc3p5cnJnZXJuaW9nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYyMzE1NjIsImV4cCI6MjA4MTgwNzU2Mn0.EAmMC21oRiyV8sgixS8eQE3-b17_-Y9kn2-os8fv0Eo',
  );

  static const String appName = 'INCLINE';
  static const String tagline = 'Rise.Reflect.Repeat.';
  static const String companyName = 'Incline - Rise.Reflect.Repeat';
  static const String supportPhone = '+91 8298293003';
  static const String defaultBranchName = 'INCLINE Club';

  /// Live Razorpay Public Key ID configured on Incline production gateway
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_live_SdlsRODfrr8eJL',
  );

  /// Application version tracking
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
}
