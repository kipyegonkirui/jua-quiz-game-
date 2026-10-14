import '../widgets/jua_dialog.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/xp_service.dart';
import '../services/app_events.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<UserProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.instance.getMyProfile();
    AppEvents.dataVersion.addListener(_refresh);
    AppEvents.profile.addListener(_profileChanged);
    AppEvents.tabRequest.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    AppEvents.dataVersion.removeListener(_refresh);
    AppEvents.profile.removeListener(_profileChanged);
    AppEvents.tabRequest.removeListener(_onTabRequested);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final profile = AppEvents.profile.value;
    setState(() {
      _future = profile != null
          ? Future.value(profile)
          : SupabaseService.instance.getMyProfile();
    });
  }

  void _profileChanged() {
    if (!mounted) return;
    final profile = AppEvents.profile.value;
    if (profile != null) {
      setState(() => _future = Future.value(profile));
    }
  }

  // IndexedStack keeps this screen alive. Re-read the profile whenever the
  // user opens the Stats tab so progress never looks stale.
  void _onTabRequested() {
    if (!mounted || AppEvents.tabRequest.value != AppTabs.stats) return;
    _refresh();
  }

  Future<void> _openAccountFlow(AccountFlowMode mode) async {
    final linked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AccountScreen(mode: mode)),
    );
    if (linked == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<UserProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final p = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(p.username, style: juaSceneTitleStyle),
              const SizedBox(height: 4),
              Text('Level ${p.level}', style: juaSceneBodyStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: XpService.progressToNextLevel(p.xp),
                  minHeight: 10,
                  backgroundColor: Colors.white38,
                  color: AppColors.sunGold,
                ),
              ),
              const SizedBox(height: 4),
              Text('${XpService.xpToNextLevel(p.xp)} XP to level ${p.level + 1}',
                  style: juaSceneCaptionStyle),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.local_fire_department_rounded, label: 'Current streak', value: '${p.currentStreak}')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.emoji_events_rounded, label: 'Best streak', value: '${p.longestStreak}')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.quiz_rounded, label: 'Challenges done', value: '${p.totalAttempts}')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.check_circle_rounded, label: 'Accuracy', value: '${(p.accuracy * 100).round()}%')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.bolt_rounded, label: 'Practice rounds', value: '${p.practiceRounds}')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.star_rounded, label: 'Total XP', value: '${p.xp}')),
                ],
              ),
              const SizedBox(height: 28),
              _AccountSection(profile: p, onOpenFlow: _openAccountFlow),
            ],
          );
        },
      ),
    );
  }
}

/// Guests get a save-progress pitch; registered players get their email and
/// a log-out option. There's deliberately no log-out for guests — it would
/// just strand their progress with nothing to sign back into.
class _AccountSection extends StatelessWidget {
  final UserProfile profile;
  final void Function(AccountFlowMode mode) onOpenFlow;

  const _AccountSection({required this.profile, required this.onOpenFlow});

  @override
  Widget build(BuildContext context) {
    if (!profile.isGuest) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: AppColors.savannaGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    SupabaseService.instance.currentUser?.email ?? 'Account saved',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => SupabaseService.instance.signOut(),
              child: const Text('Log out'),
            ),
          ],
        ),
      );
    }

    return JuaDialogCard(
      title: 'Playing as Guest',
      message:
          'Your progress is saved on this device while Jua Quiz is installed. Create an account only if you want to restore it after reinstalling.',
      art: JuaDialogArt.chestOpen,
      artHeight: 96,
      tone: JuaDialogTone.green,
      buttons: [
        JuaDialogButton(
          label: 'Create account',
          icon: Icons.person_add_alt_1_rounded,
          style: JuaDialogButtonStyle.green,
          onPressed: () => onOpenFlow(AccountFlowMode.createAccount),
        ),
        JuaDialogButton(
          label: 'Already have an account? Log in',
          style: JuaDialogButtonStyle.light,
          onPressed: () => onOpenFlow(AccountFlowMode.logIn),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.savannaGreen),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}
