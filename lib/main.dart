import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/ads_service.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';
import 'theme/app_theme.dart';
import 'widgets/jua_scene.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();
  await SupabaseService.instance.startAuthDeepLinkListener();
  await SupabaseService.instance.ensureSignedIn();

  // Ads/push matter but aren't critical to the app working — don't let
  // either one failing (unsupported platform, no network on first launch, an
  // SDK hiccup) block the whole app from ever showing its UI, the way it did
  // when this ran on an unsupported platform.
  try {
    await AdsService.initialize();
  } catch (e) {
    debugPrint('AdsService failed to initialize: $e');
  }
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('NotificationService failed to initialize: $e');
  }

  // Sound is polish, never a blocker: init() swallows its own errors.
  await SoundService.instance.init();

  runApp(const JuaQuizApp());
}

class JuaQuizApp extends StatelessWidget {
  const JuaQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jua Quiz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => JuaScene(child: child ?? const SizedBox.shrink()),
      home: const AuthGate(),
    );
  }
}

/// A session always exists by the time this builds — main() awaits
/// ensureSignedIn() first — so this just keeps OneSignal's identity in sync
/// as the session changes (guest -> real account, account -> fresh guest on
/// log-out) and guards the rare gap with a spinner instead of a blank frame.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService.instance.authStateChanges,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        NotificationService.login(session.user.id);
        return const HomeShell();
      },
    );
  }
}
