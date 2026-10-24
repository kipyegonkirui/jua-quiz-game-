import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'startup/jua_bootstrap.dart';
import 'theme/app_theme.dart';
import 'widgets/jua_scene.dart';
import 'screens/home_shell.dart';

/// Startup work (Supabase, deep links, guest sign-in, ads, push, sound) now
/// runs inside JuaBootstrap while the animated Jua Quiz loading screen plays.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JuaBootstrap(app: JuaQuizApp()));
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

/// A session always exists by the time this builds — JuaBootstrap runs
/// ensureSignedIn() before showing the app — so this just keeps OneSignal's
/// identity in sync as the session changes (guest -> real account, account ->
/// fresh guest on log-out) and guards the rare gap with a spinner instead of
/// a blank frame.
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
