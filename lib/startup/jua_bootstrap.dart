import 'package:flutter/material.dart';

import '../services/ads_service.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';
import '../services/supabase_service.dart';
import '../widgets/jua_loading_screen.dart';

enum _Phase { loading, finishing, ready, failed }

/// Shows the animated [JuaLoadingScreen] while the app's startup work runs,
/// then plays the completion burst and cross-fades into [app].
///
/// Startup work is the same as the old main(): Supabase init, deep-link
/// listener, guest sign-in, then ads / push / sound (those three never block).
/// If a critical step fails (e.g. no network on first launch), a retry screen
/// is shown instead of a dead app.
class JuaBootstrap extends StatefulWidget {
  const JuaBootstrap({super.key, required this.app});

  /// The real app, shown once startup has finished.
  final Widget app;

  @override
  State<JuaBootstrap> createState() => _JuaBootstrapState();
}

class _JuaBootstrapState extends State<JuaBootstrap> {
  /// Keeps the intro animation (~1.6s) from being cut short on fast starts.
  static const _minShow = Duration(milliseconds: 2200);

  _Phase _phase = _Phase.loading;
  double _progress = 0;
  String _message = 'Starting up...';

  // Remembered so Retry never re-runs a step that already succeeded
  // (Supabase.initialize must only run once).
  bool _supabaseReady = false;
  bool _linksReady = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _step(
    double progressAfter,
    String message,
    Future<void> Function() body, {
    bool critical = true,
  }) async {
    if (!mounted) return;
    setState(() => _message = message);
    try {
      await body();
    } catch (e) {
      if (critical) rethrow;
      debugPrint('Startup step "$message" failed: $e');
    }
    if (!mounted) return;
    setState(() => _progress = progressAfter);
  }

  Future<void> _run() async {
    setState(() {
      _phase = _Phase.loading;
      _progress = 0;
      _message = 'Starting up...';
    });
    final minShow = Future<void>.delayed(_minShow);

    try {
      await _step(0.2, 'Starting up...', () async {
        if (!_supabaseReady) {
          await SupabaseService.initialize();
          _supabaseReady = true;
        }
      });
      await _step(0.35, 'Connecting...', () async {
        if (!_linksReady) {
          await SupabaseService.instance.startAuthDeepLinkListener();
          _linksReady = true;
        }
      });
      await _step(0.6, 'Signing you in...', () => SupabaseService.instance.ensureSignedIn());

      // Ads/push/sound matter but must never block the UI from showing.
      await _step(0.75, 'Getting ready...', () => AdsService.initialize(), critical: false);
      await _step(0.9, 'Getting ready...', () => NotificationService.initialize(), critical: false);
      await _step(1.0, 'Almost there...', () => SoundService.instance.init(), critical: false);
    } catch (e) {
      debugPrint('Startup failed: $e');
      if (mounted) setState(() => _phase = _Phase.failed);
      return;
    }

    await minShow;
    if (!mounted) return;
    setState(() => _phase = _Phase.finishing);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _phase == _Phase.ready;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: ready
          ? KeyedSubtree(key: const ValueKey('app'), child: widget.app)
          : MaterialApp(
              key: const ValueKey('startup'),
              debugShowCheckedModeBanner: false,
              home: _phase == _Phase.failed
                  ? _StartupError(onRetry: _run)
                  : JuaLoadingScreen(
                      progress: _progress,
                      done: _phase == _Phase.finishing,
                      message: _message,
                      onFinished: () {
                        if (mounted) setState(() => _phase = _Phase.ready);
                      },
                    ),
            ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JuaLoadingScreen.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                "Can't connect",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: const Color(0xFF0A2E7A),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                onPressed: onRetry,
                child: const Text('Try again', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
