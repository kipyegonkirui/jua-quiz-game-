/// Every value a real account/service issues you lives here, in one place.
/// Replace the placeholders below before you run the app for real.
///
/// The AdMob IDs are already set to Google's official public TEST ids, so the
/// app runs safely showing test ads even before you've created your own
/// AdMob account. Swap them for your real ad unit IDs before publishing —
/// shipping with test IDs means you earn nothing; shipping with real IDs
/// before Google approves your app can get your AdMob account flagged, so
/// only switch them once your AdMob app is set up (see README.md).
class AppConfig {
  // ---- Sharing ----
  /// Link added to WhatsApp shares (your Play Store page). Leave empty until the app is published.
  static const shareUrl = '';

  // ---- Supabase (Project Settings > API in your Supabase dashboard) ----
  static const supabaseUrl = 'https://zlfhnxvvbbuhdsaynfju.supabase.co';
  static const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpsZmhueHZ2YmJ1aGRzYXluZmp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA0OTg2MzUsImV4cCI6MjEwNjA3NDYzNX0.H3I3ApwfuQErd9t6AlZm_bXzoJLBicnzMxR_w_BPpIw';

  // ---- OneSignal (Settings > Keys & IDs in your OneSignal dashboard) ----
  static const oneSignalAppId = '97acb94d-1b4a-4160-b784-a21aac3d72fb';

  // ---- AdMob ----
  // Android App ID goes in android/app/src/main/AndroidManifest.xml (see
  // ANDROID_SETUP.md) — it can't be set from Dart. These two are ad unit IDs,
  // which the Dart code below does use directly.
  static const admobBannerUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Google test banner
  static const admobInterstitialUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Google test interstitial

  // Ad units for later phases (already Google's public TEST ids). Unused until
  // the rewarded-video and App Open features are built.
  static const admobRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917'; // Google test rewarded
  static const admobAppOpenUnitId = 'ca-app-pub-3940256099942544/9257395921'; // Google test app open

  // How many questions in one practice round. Must match v_size in
  // start_practice_round() in supabase/003_phase1_practice_and_timezone.sql.
  static const practiceRoundSize = 5;

  // How many questions make up one daily challenge. Must match the LIMIT in
  // get_or_create_today_challenge() in supabase/schema.sql if you change it.
  static const questionsPerChallenge = 5;
}
