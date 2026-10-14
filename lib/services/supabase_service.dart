import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/question.dart';
import '../models/answer_result.dart';
import '../models/competition.dart';
import '../models/help_state.dart';
import '../models/attempt_result.dart';
import '../models/user_profile.dart';
import '../models/mission.dart';
import '../models/odd_survival.dart';
import '../models/achievement.dart';
import '../models/reward_chest.dart';
import '../models/streak_dashboard.dart';
import '../models/practice_journey.dart';
import '../models/practice_lives.dart';
import '../models/guess_it.dart';
import '../models/odd_one_out.dart';
import '../models/mode_journey.dart';
import '../game/models/game_question.dart';
import '../game/models/game_mode.dart';
import '../game/models/game_result.dart';
import '../game/mappers/game_result_mapper.dart';
import '../game/progression/game_progression_service.dart';
import '../game/progression/coin_transaction.dart';
import '../game/models/speed_quiz_answer_result.dart';
import '../game/models/speed_quiz_result.dart';
import '../game/models/speed_quiz_state.dart';
import 'guest_progress_store.dart';
import 'app_events.dart';

/// Thin wrapper around everything the app needs from Supabase. Screens call
/// this instead of touching the Supabase client directly, so there's one
/// place to change if a table/function name ever changes.
class SupabaseService {
  SupabaseService._();
  static final instance = SupabaseService._();
  static const authRedirectUri = 'io.juaquiz.app://login-callback';
  StreamSubscription<Uri>? _deepLinkSubscription;

  SupabaseClient get _client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Starts listening for verification/login links opened from email.
  ///
  /// There are two Android cases: the app may already be running when the
  /// user taps the email link, or Android may launch the app because of that
  /// link. We handle both the live stream and the initial link.
  Future<void> startAuthDeepLinkListener() async {
    _deepLinkSubscription?.cancel();
    final appLinks = AppLinks();

    // Handle a link that launched the app from a terminated/background state.
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleAuthDeepLink(initialUri);
      }
    } catch (e) {
      print('Initial auth deep-link failed: $e');
    }

    // Handle a link delivered while the app is already running.
    _deepLinkSubscription = appLinks.uriLinkStream.listen(
      _handleAuthDeepLink,
      onError: (Object error) {
        print('Auth deep-link stream failed: $error');
      },
    );
  }

  Future<void> _handleAuthDeepLink(Uri uri) async {
    if (uri.scheme != 'io.juaquiz.app' || uri.host != 'login-callback') {
      return;
    }

    try {
      await _client.auth.getSessionFromUrl(uri);
      print('Jua Quiz auth deep-link handled successfully.');
    } on AuthException catch (e) {
      print('Auth deep-link failed: ${e.message}');
    } catch (e) {
      print('Auth deep-link failed: $e');
    }
  }

  // ---------------------------------------------------------------- Auth --
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  User? get currentUser => _client.auth.currentUser;

  /// True once signed in as a real (email-linked) account; false for a guest.
  bool get isGuest => currentUser?.isAnonymous ?? true;

  /// Call once at app startup. If there's no session at all — first ever
  /// launch, or right after a log-out — starts a guest session so the app
  /// is immediately usable with no sign-up required.
  Future<void> ensureSignedIn() async {
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
  }

  /// Sends the email-verification link that attaches [email] to the CURRENT
  /// guest. Because it is the same underlying user id, XP, streak and history
  /// carry over automatically once the link is opened.
  Future<void> sendCreateAccountLink(String email) async {
    await _client.auth.updateUser(
      UserAttributes(email: email),
      emailRedirectTo: authRedirectUri,
    );
  }

  /// Sends a passwordless login link for an existing account.
  /// [shouldCreateUser] is false so an unknown email does not silently create
  /// an orphan account.
  Future<void> sendLoginLink(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
      emailRedirectTo: authRedirectUri,
    );
  }

  /// Signs out of a real account and drops straight back into a fresh guest
  /// session, since the app has no other state to show once signed out.
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _client.auth.signInAnonymously();
  }

  // ------------------------------------------------------------- Profile --
  Future<UserProfile> getMyProfile() async {
    final uid = currentUser!.id;
    final guest = isGuest;

    if (guest) {
      final local = await GuestProgressStore.loadProfile(uid);
      if (local != null) {
        AppEvents.profile.value = local;
        _reconcileGuestProfileInBackground(uid, local);
        return local;
      }
    }

    try {
      final row = await _client.from('profiles').select().eq('id', uid).single();
      final remote = UserProfile.fromMap(row);
      AppEvents.profile.value = remote;
      if (guest) await GuestProgressStore.saveProfile(remote);
      return remote;
    } catch (e) {
      if (guest) {
        final local = await GuestProgressStore.loadProfile(uid);
        if (local != null) {
          AppEvents.profile.value = local;
          return local;
        }
      }
      rethrow;
    }
  }

  Future<void> _reconcileGuestProfileInBackground(
    String uid,
    UserProfile local,
  ) async {
    try {
      final row = await _client.from('profiles').select().eq('id', uid).single();
      final remote = UserProfile.fromMap(row);
      final merged = _mergeGuestProfiles(remote, local);
      await GuestProgressStore.saveProfile(merged);
    } catch (_) {
      // The local snapshot is already sufficient for the current UI.
    }
  }

  UserProfile _mergeGuestProfiles(UserProfile remote, UserProfile local) {
    final localDate = local.lastCompletedDate;
    final remoteDate = remote.lastCompletedDate;
    final useLocalStreak = localDate != null &&
        (remoteDate == null || localDate.isAfter(remoteDate) ||
            (localDate.isAtSameMomentAs(remoteDate)));

    return remote.copyWith(
      username: remote.username,
      xp: local.xp > remote.xp ? local.xp : remote.xp,
      level: local.level > remote.level ? local.level : remote.level,
      currentStreak: useLocalStreak ? local.currentStreak : remote.currentStreak,
      longestStreak: local.longestStreak > remote.longestStreak
          ? local.longestStreak
          : remote.longestStreak,
      totalAttempts: local.totalAttempts > remote.totalAttempts
          ? local.totalAttempts
          : remote.totalAttempts,
      totalCorrect: local.totalCorrect > remote.totalCorrect
          ? local.totalCorrect
          : remote.totalCorrect,
      totalQuestions: local.totalQuestions > remote.totalQuestions
          ? local.totalQuestions
          : remote.totalQuestions,
      practiceRounds: local.practiceRounds > remote.practiceRounds
          ? local.practiceRounds
          : remote.practiceRounds,
      coins: remote.coins,
      lastCompletedDate: useLocalStreak ? localDate : remoteDate,
    );
  }

  /// Publishes any server-confirmed game result to the UI immediately.
  /// Mode-specific RPCs remain authoritative for XP, coins and streaks.
  Future<void> publishConfirmedGameResult(GameResult result) async {
    if (currentUser == null) return;

    UserProfile? base = AppEvents.profile.value;
    if (base == null && isGuest) {
      base = await GuestProgressStore.loadProfile(currentUser!.id);
    }
    base ??= UserProfile(
      id: currentUser!.id,
      username: currentUser?.userMetadata?['username'] as String? ?? 'Player',
      xp: 0,
      level: 1,
      currentStreak: 0,
      longestStreak: 0,
      totalAttempts: 0,
      totalCorrect: 0,
      totalQuestions: 0,
      practiceRounds: 0,
      coins: 0,
      streakShields: 0,
      isGuest: isGuest,
    );

    final updated = GameProgressionService.applyResult(
      base: base,
      result: result,
      completedAt: result.mode == GameMode.dailyChallenge ? DateTime.now() : null,
    );
    AppEvents.publishProfile(updated);

    if (isGuest) {
      await GuestProgressStore.saveProfile(updated);
      final isDaily = result.mode == GameMode.dailyChallenge;
      if (result.mode == GameMode.dailyChallenge || result.mode == GameMode.practice) {
        await GuestProgressStore.saveBestScore(
          dailyChallenge: isDaily,
          score: result.score,
        );
      } else if (result.mode == GameMode.speedQuiz) {
        await GuestProgressStore.saveBestScore(
          dailyChallenge: false,
          speedQuiz: true,
          score: result.score,
        );
      }
      _reconcileGuestProfileInBackground(currentUser!.id, updated);
    } else {
      _refreshPublishedProfileInBackground();
    }

    // Unlock permanent achievements from server-authoritative progress.
    // The RPC only derives state from confirmed database records.
    if (!isGuest) {
      try { await syncAchievements(); } catch (_) {}
    }
  }

  /// Backward-compatible wrapper used by Practice/Daily UI.
  Future<void> publishConfirmedRound({
    required AttemptResult result,
    required bool dailyChallenge,
  }) async {
    final mode = dailyChallenge ? GameMode.dailyChallenge : GameMode.practice;
    await publishConfirmedGameResult(
      GameResultMapper.fromAttemptResult(mode: mode, result: result),
    );
    if (dailyChallenge && !isGuest) {
      // The streak shield inventory is server-authoritative. Refresh it now so
      // the home/progression UI reflects shields earned or consumed immediately.
      try {
        final profile = await getMyProfile();
        AppEvents.publishProfile(profile);
      } catch (_) {}
    }
  }

  Future<void> _refreshPublishedProfileInBackground() async {
    try {
      final row = await _client.from('profiles').select().eq('id', currentUser!.id).single();
      AppEvents.profile.value = UserProfile.fromMap(row);
    } catch (_) {}
  }

  /// Mirrors a server-confirmed completed round into device storage when the
  /// player is still a guest. This is intentionally a cache, not a way to
  /// award XP: the server result remains authoritative.
  Future<void> cacheGuestRoundResult({
    required AttemptResult result,
    required bool dailyChallenge,
  }) async {
    if (!isGuest || currentUser == null) return;

    final uid = currentUser!.id;
    UserProfile? remote;
    UserProfile? local;

    try {
      final row = await _client.from('profiles').select().eq('id', uid).single();
      remote = UserProfile.fromMap(row);
    } catch (_) {
      // The device cache can still be updated if the network/server is
      // temporarily unavailable.
    }
    local = await GuestProgressStore.loadProfile(uid);

    final base = remote == null
        ? (local ?? UserProfile(
            id: uid,
            username: 'Player',
            xp: 0,
            level: 1,
            currentStreak: 0,
            longestStreak: 0,
            totalAttempts: 0,
            totalCorrect: 0,
            totalQuestions: 0,
            isGuest: true,
          ))
        : _mergeGuestProfiles(remote, local ?? remote);

    // The RPC result tells us the authoritative XP after this round. If the
    // server profile already contains that result, do not add it a second
    // time. If the server profile is stale but the device cache is ahead, the
    // result still wins for XP while the counters advance locally.
    final serverAlreadyIncludesRound = dailyChallenge
        ? remote != null &&
            remote.totalAttempts > (local?.totalAttempts ?? 0)
        : remote != null &&
            remote.practiceRounds > (local?.practiceRounds ?? 0);

    final nextAttempts = dailyChallenge
        ? base.totalAttempts + (serverAlreadyIncludesRound ? 0 : 1)
        : base.totalAttempts;
    final nextPracticeRounds = dailyChallenge
        ? base.practiceRounds
        : base.practiceRounds + (serverAlreadyIncludesRound ? 0 : 1);

    final cached = base.copyWith(
      xp: result.newXp > base.xp ? result.newXp : base.xp,
      level: result.newLevel > base.level ? result.newLevel : base.level,
      currentStreak: result.currentStreak > 0
          ? result.currentStreak
          : base.currentStreak,
      longestStreak: result.longestStreak > base.longestStreak
          ? result.longestStreak
          : base.longestStreak,
      totalAttempts: nextAttempts,
      totalCorrect: serverAlreadyIncludesRound
          ? base.totalCorrect
          : base.totalCorrect + result.score,
      totalQuestions: serverAlreadyIncludesRound
          ? base.totalQuestions
          : base.totalQuestions + result.total,
      practiceRounds: nextPracticeRounds,
      lastCompletedDate: dailyChallenge ? DateTime.now() : base.lastCompletedDate,
    );

    await GuestProgressStore.saveProfile(cached);
    await GuestProgressStore.saveBestScore(
      dailyChallenge: dailyChallenge,
      score: result.score,
    );
  }

  Future<void> updateUsername(String username) async {
    await _client.from('profiles').update({'username': username}).eq('id', currentUser!.id);
    if (isGuest) {
      final local = await GuestProgressStore.loadProfile(currentUser!.id);
      if (local != null) {
        await GuestProgressStore.saveProfile(local.copyWith(username: username));
      }
    }
  }

  // ------------------------------------------------------- Daily challenge --
  /// Returns the id of today's challenge, creating it server-side on the
  /// first request of the day if it doesn't exist yet.
  Future<String> getTodayChallengeId() async {
    final res = await _client.rpc('get_or_create_today_challenge');
    return res as String;
  }

  Future<List<Question>> getChallengeQuestions(String challengeId) async {
    final rows = await _client.rpc(
      'get_challenge_questions',
      params: {'p_challenge_id': challengeId},
    );
    return (rows as List).map((r) => Question.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Returns true if the signed-in user has already completed the given
  /// challenge (used to decide whether to show the quiz or a "come back
  /// tomorrow" screen).
  Future<bool> hasCompletedChallenge(String challengeId) async {
    final rows = await _client
        .from('attempts')
        .select('id')
        .eq('user_id', currentUser!.id)
        .eq('daily_challenge_id', challengeId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// Read-only personal best for the daily challenge. Scores remain server-authoritative.
  Future<int> getDailyBestScore() async {
    final rows = await _client
        .from('attempts')
        .select('score')
        .eq('user_id', currentUser!.id)
        .order('score', ascending: false)
        .limit(1);
    final remote = (rows as List).isEmpty
        ? 0
        : (rows.first['score'] as num).toInt();
    if (!isGuest) return remote;
    final local = await GuestProgressStore.loadBestScore(dailyChallenge: true);
    return remote > local ? remote : local;
  }


  /// Checks one answer on the server and LOCKS it. Returns which option was
  /// right, so the app can colour it green (and the player's pick red if wrong).
  Future<AnswerResult> answerDailyQuestion({
    required String challengeId,
    required String questionId,
    required String choice,
  }) async {
    final res = await _client.rpc('answer_daily_question', params: {
      'p_challenge_id': challengeId,
      'p_question_id': questionId,
      'p_choice': choice,
    });
    return AnswerResult.fromMap(res as Map<String, dynamic>);
  }

  /// Answers already given today, keyed by question id — lets the app resume a
  /// half-finished challenge instead of starting over.
  Future<Map<String, AnswerResult>> getDailyProgress(String challengeId) async {
    final rows = await _client.rpc('get_daily_progress', params: {'p_challenge_id': challengeId});
    return _progressMap(rows);
  }

  /// Scores the answers the server has recorded (nothing is sent from here).
  /// See submit_daily_attempt() in supabase/005_answer_feedback.sql.
  Future<AttemptResult> submitAttempt({required String challengeId}) async {
    final res = await _client.rpc('submit_daily_attempt', params: {'p_challenge_id': challengeId});
    return AttemptResult.fromMap(res as Map<String, dynamic>);
  }

  Map<String, AnswerResult> _progressMap(dynamic rows) {
    return {
      for (final r in (rows as List))
        (r as Map<String, dynamic>)['question_id'] as String: AnswerResult.fromMap(r),
    };
  }

  // ------------------------------------------------------ Practice rounds --
  /// Starts a practice round (or resumes the unfinished one) and returns its
  /// id. The server picks the questions — see start_practice_round().
  Future<String> startPracticeRound() async {
    final res = await _client.rpc('start_practice_round');
    return res as String;
  }

  Future<PracticeLives> getPracticeLives() async {
    final res = await _client.rpc('get_practice_lives');
    return PracticeLives.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<PracticeLives> consumePracticeLife() async {
    final res = await _client.rpc('consume_practice_life');
    return PracticeLives.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<bool> abandonPracticeLevelRound(String roundId) async {
    final res = await _client.rpc(
      'abandon_practice_level_round',
      params: {'p_round_id': roundId},
    );
    return res == true;
  }

  Future<String> startPracticeLevelRound(int level) async {
    final res = await _client.rpc(
      'start_practice_level_round',
      params: {'p_level': level},
    );
    return res as String;
  }

  Future<PracticeJourneyData> getPracticeJourney({int throughLevel = 100}) async {
    final res = await _client.rpc(
      'get_practice_journey',
      params: {'p_through_level': throughLevel},
    );
    return PracticeJourneyData.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<PracticeJourneyData> unlockPracticeBatchByAd(int batch) async {
    final res = await _client.rpc(
      'unlock_practice_batch_by_ad',
      params: {'p_batch_number': batch},
    );
    return PracticeJourneyData.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// Read-only personal best for completed practice rounds.
  Future<int> getPracticeBestScore() async {
    final rows = await _client
        .from('practice_rounds')
        .select('score')
        .eq('user_id', currentUser!.id)
        .eq('status', 'completed')
        .order('score', ascending: false)
        .limit(1);
    final remote = (rows as List).isEmpty
        ? 0
        : (rows.first['score'] as num).toInt();
    if (!isGuest) return remote;
    final local = await GuestProgressStore.loadBestScore(dailyChallenge: false);
    return remote > local ? remote : local;
  }

  Future<List<Question>> getPracticeQuestions(String roundId) async {
    final rows = await _client.rpc(
      'get_practice_questions',
      params: {'p_round_id': roundId},
    );
    return (rows as List).map((r) => Question.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<AnswerResult> answerPracticeQuestion({
    required String roundId,
    required String questionId,
    required String choice,
  }) async {
    final res = await _client.rpc('answer_practice_question', params: {
      'p_round_id': roundId,
      'p_question_id': questionId,
      'p_choice': choice,
    });
    return AnswerResult.fromMap(res as Map<String, dynamic>);
  }

  Future<Map<String, AnswerResult>> getPracticeProgress(String roundId) async {
    final rows = await _client.rpc('get_practice_progress', params: {'p_round_id': roundId});
    return _progressMap(rows);
  }

  /// One shot per round: the server rejects a second submit, so a round can't
  /// be replayed for repeat XP. Scores the recorded answers. Never affects the streak.
  Future<AttemptResult> submitPracticeRound({required String roundId}) async {
    final res = await _client.rpc('submit_practice_round', params: {'p_round_id': roundId});
    return AttemptResult.fromMap(res as Map<String, dynamic>);
  }


  // ------------------------------------------------------------ Guess It --
  Future<String> startGuessItRound() async {
    final res = await _client.rpc('start_guess_it_round');
    return res as String;
  }

  Future<List<GuessItQuestion>> getGuessItQuestions(String roundId) async {
    final rows = await _client.rpc(
      'get_guess_it_questions',
      params: {'p_round_id': roundId},
    );
    return (rows as List)
        .map((row) => GuessItQuestion.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<GuessItAnswerResult> answerGuessItQuestion({
    required String roundId,
    required String questionId,
    required String choice,
    required int timeMs,
  }) async {
    final res = await _client.rpc('answer_guess_it_question', params: {
      'p_round_id': roundId,
      'p_question_id': questionId,
      'p_choice': choice,
      'p_time_ms': timeMs,
    });
    return GuessItAnswerResult.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<GuessItHintResult> useGuessItHint({
    required String roundId,
    required String questionId,
  }) async {
    final res = await _client.rpc('use_guess_it_hint', params: {
      'p_round_id': roundId,
      'p_question_id': questionId,
    });
    final result = GuessItHintResult.fromMap(Map<String, dynamic>.from(res as Map));
    final profile = AppEvents.profile.value;
    if (profile != null && profile.coins != result.coinsBalance) {
      AppEvents.publishProfile(profile.copyWith(coins: result.coinsBalance));
    }
    return result;
  }

  Future<GuessItGameResult> submitGuessItRound(String roundId) async {
    final res = await _client.rpc('submit_guess_it_round', params: {
      'p_round_id': roundId,
    });
    final result = GuessItGameResult.fromMap(Map<String, dynamic>.from(res as Map));
    if (currentUser != null) {
      try {
        if (isGuest) {
          final row = await _client.from('profiles').select().eq('id', currentUser!.id).single();
          final profile = UserProfile.fromMap(row);
          AppEvents.publishProfile(profile);
          await GuestProgressStore.saveProfile(profile);
          await GuestProgressStore.saveBestScore(dailyChallenge: false, speedQuiz: true, score: result.score);
        } else {
          final profile = await getMyProfile();
          AppEvents.publishProfile(profile);
        }
      } catch (_) {}
    }
    return result;
  }


  // ------------------------------------------- Mode level journeys (021) --
  Future<PracticeJourneyData> getModeJourney(JourneyMode mode, {int throughLevel = 100}) async {
    final res = await _client.rpc('get_mode_journey', params: {
      'p_mode': mode.key,
      'p_through_level': throughLevel,
    });
    return PracticeJourneyData.fromMap(Map<String, dynamic>.from(res as Map));
  }

  // ------------------------------------------------ Odd One Out: Survival --
  Map<String, dynamic> _map(dynamic res) => Map<String, dynamic>.from(res as Map);

  Future<SurvivalStatus> getOddSurvivalStatus() async =>
      SurvivalStatus.fromMap(_map(await _client.rpc('get_odd_survival_status')));

  Future<SurvivalState> startOddSurvivalRun() async =>
      SurvivalState.fromMap(_map(await _client.rpc('start_odd_survival_run')));

  Future<SurvivalState> beginOddSurvivalPuzzle(String runId, String puzzleId) async =>
      SurvivalState.fromMap(_map(await _client.rpc('begin_odd_survival_puzzle',
          params: {'p_run_id': runId, 'p_puzzle_id': puzzleId})));

  Future<SurvivalAnswer> answerOddSurvival(String runId, String puzzleId, String choice) async =>
      SurvivalAnswer.fromMap(_map(await _client.rpc('answer_odd_survival',
          params: {'p_run_id': runId, 'p_puzzle_id': puzzleId, 'p_choice': choice})));

  Future<SurvivalState> oddSurvivalSecondWind(String runId) async {
    final m = _map(await _client.rpc('odd_survival_second_wind', params: {'p_run_id': runId}));
    final coins = (m['coins_balance'] as num?)?.toInt();
    final profile = AppEvents.profile.value;
    if (coins != null && profile != null && profile.coins != coins) {
      AppEvents.publishProfile(profile.copyWith(coins: coins));
    }
    return SurvivalState.fromMap(m);
  }

  Future<SurvivalResult> finishOddSurvivalRun(String runId) async {
    final result = SurvivalResult.fromMap(_map(await _client.rpc('finish_odd_survival_run', params: {'p_run_id': runId})));
    await getCoinBalance();
    return result;
  }

  /// The "Did you know?" line for a question. Null if there isn't one, or if
  /// the player hasn't answered it yet (the server decides).
  Future<String?> getQuestionFact(String questionId) async {
    final res = await _client.rpc('get_question_fact', params: {'p_question_id': questionId});
    final t = (res as String?)?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<void> reportQuestion(String questionId, String reason, {String? note}) async {
    await _client.rpc('report_question', params: {
      'p_question_id': questionId,
      'p_reason': reason,
      'p_note': note,
    });
  }

  Future<PracticeLives> getModeLives(JourneyMode mode) async {
    final res = await _client.rpc('get_mode_lives', params: {'p_mode': mode.key});
    return PracticeLives.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// Starts (or resumes) a level. Returns the id of the underlying mode round.
  Future<String> startModeLevel(JourneyMode mode, int level) async {
    final res = await _client.rpc('start_mode_level', params: {
      'p_mode': mode.key,
      'p_level': level,
    });
    return res as String;
  }

  /// Turns a submitted round into stars. Call after the mode's own submit.
  Future<ModeLevelResult> completeModeLevel(String roundId) async {
    final res = await _client.rpc('complete_mode_level', params: {'p_round_id': roundId});
    return ModeLevelResult.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<bool> abandonModeLevel(String roundId) async {
    final res = await _client.rpc('abandon_mode_level', params: {'p_round_id': roundId});
    return res as bool? ?? false;
  }

  Future<PracticeJourneyData> unlockModeBatchByAd(JourneyMode mode, int batch) async {
    final res = await _client.rpc('unlock_mode_batch_by_ad', params: {
      'p_mode': mode.key,
      'p_batch_number': batch,
    });
    return PracticeJourneyData.fromMap(Map<String, dynamic>.from(res as Map));
  }

  // ------------------------------------------------------- Odd One Out --
  Future<OddOneOutStatus> getOddOneOutStatus() async {
    final res = await _client.rpc('get_odd_one_out_status');
    return OddOneOutStatus.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<String> startOddOneOutRound(OddOneOutMode mode) async {
    final res = await _client.rpc('start_odd_one_out_round', params: {'p_mode': mode.value});
    return res as String;
  }

  Future<List<OddOneOutPuzzle>> getOddOneOutPuzzles(String roundId) async {
    final rows = await _client.rpc('get_odd_one_out_puzzles', params: {'p_round_id': roundId});
    return (rows as List)
        .map((row) => OddOneOutPuzzle.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<OddOneOutAnswerResult> answerOddOneOutPuzzle({
    required String roundId,
    required String puzzleId,
    required String choice,
    required int timeMs,
  }) async {
    final res = await _client.rpc('answer_odd_one_out_puzzle', params: {
      'p_round_id': roundId,
      'p_puzzle_id': puzzleId,
      'p_choice': choice,
      'p_time_ms': timeMs,
    });
    return OddOneOutAnswerResult.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<OddOneOutHintResult> useOddOneOutHint({
    required String roundId,
    required String puzzleId,
  }) async {
    final res = await _client.rpc('use_odd_one_out_hint', params: {
      'p_round_id': roundId,
      'p_puzzle_id': puzzleId,
    });
    final result = OddOneOutHintResult.fromMap(Map<String, dynamic>.from(res as Map));
    final profile = AppEvents.profile.value;
    if (profile != null && profile.coins != result.coinsBalance) {
      AppEvents.publishProfile(profile.copyWith(coins: result.coinsBalance));
    }
    return result;
  }

  Future<OddOneOutResult> submitOddOneOutRound(String roundId) async {
    final res = await _client.rpc('submit_odd_one_out_round', params: {'p_round_id': roundId});
    final result = OddOneOutResult.fromMap(Map<String, dynamic>.from(res as Map));
    if (currentUser != null) {
      try {
        final profile = await getMyProfile();
        AppEvents.publishProfile(profile);
        if (isGuest) await GuestProgressStore.saveProfile(profile);
      } catch (_) {
        // The round is already scored server-side; a display refresh failure
        // must not turn a finished round into an error.
      }
    }
    AppEvents.notifyProgressChanged();
    return result;
  }

  // --------------------------------------------------------- Speed Quiz --
  Future<String> startSpeedQuizRound() async {
    final res = await _client.rpc('start_speed_quiz_round');
    return res as String;
  }

  Future<List<GameQuestion>> getSpeedQuizQuestions(String roundId) async {
    final rows = await _client.rpc(
      'get_speed_quiz_questions',
      params: {'p_round_id': roundId},
    );
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).map((row) {
      return GameQuestion(
        id: row['id'] as String,
        text: row['question_text'] as String,
        options: {
          'a': row['option_a'] as String,
          'b': row['option_b'] as String,
          'c': row['option_c'] as String,
          'd': row['option_d'] as String,
        },
        position: (row['position'] as num?)?.toInt() ?? 0,
        difficulty: row['difficulty'] as String?,
        timeLimit: const Duration(seconds: 10),
      );
    }).toList();
  }

  Future<SpeedQuizState> getSpeedQuizState(String roundId) async {
    final res = await _client.rpc(
      'get_speed_quiz_state',
      params: {'p_round_id': roundId},
    );
    return SpeedQuizState.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<List<SpeedQuizAnswerResult>> getSpeedQuizProgress(String roundId) async {
    final rows = await _client.rpc(
      'get_speed_quiz_progress',
      params: {'p_round_id': roundId},
    );
    return (rows as List).map((r) => SpeedQuizAnswerResult.fromMap({
          ...Map<String, dynamic>.from(r as Map),
          'score': 0,
          'correct_count': 0,
          'answered': 0,
          'total_questions': 0,
          'finished': false,
        })).toList();
  }

  Future<SpeedQuizAnswerResult> answerSpeedQuizQuestion({
    required String roundId,
    required String questionId,
    String? choice,
    bool forceTimeout = false,
  }) async {
    final res = await _client.rpc('answer_speed_quiz_question', params: {
      'p_round_id': roundId,
      'p_question_id': questionId,
      'p_choice': choice,
      'p_force_timeout': forceTimeout,
    });
    return SpeedQuizAnswerResult.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<SpeedQuizResult> submitSpeedQuizRound({required String roundId}) async {
    final res = await _client.rpc('submit_speed_quiz_round', params: {'p_round_id': roundId});
    return SpeedQuizResult.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<int> getSpeedQuizBestScore() async {
    final rows = await _client
        .from('speed_quiz_rounds')
        .select('score')
        .eq('user_id', currentUser!.id)
        .eq('status', 'completed')
        .order('score', ascending: false)
        .limit(1);
    final remote = (rows as List).isEmpty
        ? 0
        : (rows.first['score'] as num).toInt();
    if (!isGuest) return remote;
    final local = await GuestProgressStore.loadSpeedBestScore();
    return remote > local ? remote : local;
  }

  Future<void> publishConfirmedSpeedQuiz({required SpeedQuizResult result}) {
    return publishConfirmedGameResult(GameResultMapper.fromSpeedQuizResult(result));
  }

  // ------------------------------------------- Hints & second chances (Phase 4) --
  // [contextType] is 'daily' (contextId = challenge id) or 'practice' (round id).

  /// Hints/second chances left, hints already used, and any question waiting
  /// on a second-chance decision. Lets the app redraw after a restart.
  Future<HelpState> getHelpState({required String contextType, required String contextId}) async {
    final res = await _client.rpc('get_help_state', params: {
      'p_context_type': contextType,
      'p_context_id': contextId,
    });
    return HelpState.fromMap(res as Map<String, dynamic>);
  }

  /// Tells the server a rewarded video was watched. [kind] is 'hint' or
  /// 'second_chance'. Throws if the server refuses (e.g. limit reached).
  Future<void> claimReward({
    required String contextType,
    required String contextId,
    required String questionId,
    required String kind,
  }) async {
    await _client.rpc('claim_reward', params: {
      'p_context_type': contextType,
      'p_context_id': contextId,
      'p_question_id': questionId,
      'p_kind': kind,
    });
  }

  /// The two WRONG options to hide. The server never sends the right one.
  Future<Set<String>> useHint({
    required String contextType,
    required String contextId,
    required String questionId,
  }) async {
    final res = await _client.rpc('use_hint', params: {
      'p_context_type': contextType,
      'p_context_id': contextId,
      'p_question_id': questionId,
    });
    final ids = (res as Map<String, dynamic>)['wrong_option_ids'] as List;
    return ids.map((e) => e as String).toSet();
  }

  /// "No thanks" to a second chance: locks the wrong answer and reveals the right one.
  Future<AnswerResult> declineSecondChance({
    required String contextType,
    required String contextId,
    required String questionId,
  }) async {
    final res = await _client.rpc('decline_second_chance', params: {
      'p_context_type': contextType,
      'p_context_id': contextId,
      'p_question_id': questionId,
    });
    return AnswerResult.fromMap(res as Map<String, dynamic>);
  }

  // ------------------------------------------------ Coins & competitions (Phase 5) --

  /// Spends coins on a hint for this question. Returns the new coin balance.
  /// Never charges twice for the same question. After this, call [useHint].
  Future<int> buyHint({
    required String contextType,
    required String contextId,
    required String questionId,
  }) async {
    final res = await _client.rpc('buy_hint', params: {
      'p_context_type': contextType,
      'p_context_id': contextId,
      'p_question_id': questionId,
    });
    return ((res as Map<String, dynamic>)['coins'] as num).toInt();
  }

  /// Reads the authoritative current coin balance and synchronizes the local
  /// profile snapshot when one is available.
  Future<int> getCoinBalance() async {
    final res = await _client.rpc('get_coin_balance');
    final balance = (res as num?)?.toInt() ?? 0;
    final profile = AppEvents.profile.value;
    if (profile != null && profile.coins != balance) {
      AppEvents.publishProfile(profile.copyWith(coins: balance));
    }
    return balance;
  }

  /// Spends coins for a supported economy reason. The server performs the
  /// authorization, balance check and idempotency check.
  Future<CoinSpendResult> spendCoins({
    required int amount,
    required String reason,
    String? refId,
  }) async {
    final res = await _client.rpc('spend_coins', params: {
      'p_amount': amount,
      'p_reason': reason,
      'p_ref': refId,
    });
    final result = CoinSpendResult.fromMap(res as Map<String, dynamic>);

    final profile = AppEvents.profile.value;
    if (profile != null && profile.coins != result.balance) {
      AppEvents.publishProfile(profile.copyWith(coins: result.balance));
    }
    return result;
  }

  /// Returns recent coin movements for the signed-in player.
  Future<List<CoinTransaction>> getCoinLedger({int limit = 20}) async {
    final res = await _client.rpc('get_coin_ledger', params: {'p_limit': limit});
    return (res as List)
        .map((e) => CoinTransaction.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Upcoming, open and recently finished competitions, with my own progress.
  /// (The server also settles any that have just closed.)
  Future<List<Competition>> listCompetitions() async {
    final res = await _client.rpc('list_competitions');
    return (res as List).map((e) => Competition.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Joins a competition (safe to call again). Fails with 'not_started' /
  /// 'closed' outside the window.
  Future<CompetitionEntry> startCompetitionEntry(String competitionId) async {
    final res = await _client.rpc('start_competition_entry', params: {'p_id': competitionId});
    return CompetitionEntry.fromMap(res as Map<String, dynamic>);
  }

  /// My current question (or the finished summary). Asking again returns the
  /// same question with the time that is really left.
  Future<CompetitionQuestionState> competitionNextQuestion(String competitionId) async {
    final res = await _client.rpc('competition_next_question', params: {'p_id': competitionId});
    return CompetitionQuestionState.fromMap(res as Map<String, dynamic>);
  }

  /// [choice] null = skipped / out of time (counts as wrong).
  Future<CompetitionAnswerResult> competitionAnswer({
    required String competitionId,
    required String questionId,
    String? choice,
  }) async {
    final res = await _client.rpc('competition_answer', params: {
      'p_id': competitionId,
      'p_question_id': questionId,
      'p_choice': choice,
    });
    return CompetitionAnswerResult.fromMap(res as Map<String, dynamic>);
  }

  Future<CompetitionResults> getCompetitionResults(String competitionId) async {
    final res = await _client.rpc('get_competition_results', params: {'p_id': competitionId});
    return CompetitionResults.fromMap(res as Map<String, dynamic>);
  }



  /// Loads the server-authoritative streak dashboard and recent calendar.
  /// The server owns the streak/shield state; this is a read-only projection.
  Future<Map<String, dynamic>> getLoginCalendar() async {
    final res = await _client.rpc('get_login_calendar');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> claimLoginReward() async {
    final res = await _client.rpc('claim_login_reward');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<StreakDashboardData> getStreakDashboard({int days = 90}) async {
    final res = await _client.rpc('get_streak_dashboard', params: {'p_days': days});
    return StreakDashboardData.fromMap(Map<String, dynamic>.from(res as Map));
  }

  // ------------------------------------------------------------- Missions --
  Future<List<Mission>> getDailyMissions() async {
    final rows = await _client.rpc('get_daily_missions');
    return (rows as List)
        .map((e) => Mission.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<MissionClaimResult> claimMission(String missionId) async {
    final res = await _client.rpc('claim_daily_mission', params: {'p_mission_id': missionId});
    final result = MissionClaimResult.fromMap(Map<String, dynamic>.from(res as Map));
    final profile = AppEvents.profile.value;
    if (profile != null) {
      final nextXp = result.newXp;
      final nextLevel = result.newLevel;
      final nextCoins = result.balance;
      if (profile.xp != nextXp || profile.level != nextLevel || profile.coins != nextCoins) {
        AppEvents.publishProfile(profile.copyWith(
          xp: nextXp,
          level: nextLevel,
          coins: nextCoins,
        ));
      }
    }
    return result;
  }

  // ------------------------------------------------------ Achievements --
  Future<int> syncAchievements() async {
    final res = await _client.rpc('sync_achievements');
    return (res as num).toInt();
  }

  Future<List<Achievement>> getAchievements() async {
    final rows = await _client.rpc('get_achievements');
    return (rows as List)
        .map((e) => Achievement.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<AchievementClaimResult> claimAchievement(String achievementId) async {
    final res = await _client.rpc('claim_achievement', params: {'p_achievement_id': achievementId});
    final result = AchievementClaimResult.fromMap(Map<String, dynamic>.from(res as Map));
    final profile = AppEvents.profile.value;
    if (profile != null && (profile.xp != result.newXp || profile.level != result.newLevel || profile.coins != result.balance)) {
      AppEvents.publishProfile(profile.copyWith(xp: result.newXp, level: result.newLevel, coins: result.balance));
    }
    return result;
  }

  // ------------------------------------------------------ Reward chests --
  Future<int> syncRewardChests() async {
    final res = await _client.rpc('sync_reward_chests');
    return (res as num).toInt();
  }

  Future<List<RewardChest>> getRewardChests() async {
    final rows = await _client.rpc('get_reward_chests');
    return (rows as List)
        .map((e) => RewardChest.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<RewardChestClaimResult> claimRewardChest(String chestId) async {
    final res = await _client.rpc('claim_reward_chest', params: {'p_chest_id': chestId});
    final result = RewardChestClaimResult.fromMap(Map<String, dynamic>.from(res as Map));
    final profile = AppEvents.profile.value;
    if (profile != null && (profile.xp != result.newXp || profile.level != result.newLevel || profile.coins != result.balance)) {
      AppEvents.publishProfile(profile.copyWith(xp: result.newXp, level: result.newLevel, coins: result.balance));
    }
    return result;
  }

  // ----------------------------------------------------------- Leaderboard --
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final rows = await _client.from('leaderboard').select();
    final entries = (rows as List)
        .map((r) => LeaderboardEntry.fromMap(r as Map<String, dynamic>))
        .toList();

    // The server view can lag behind the profile snapshot immediately after
    // a completed round. Overlay the latest known profile for the current
    // player so their own XP/rank updates immediately, then the next remote
    // refresh replaces the snapshot with the server view.
    if (currentUser != null) {
      final uid = currentUser!.id;
      UserProfile? currentProfile = AppEvents.profile.value;
      if (currentProfile == null && isGuest) {
        currentProfile = await GuestProgressStore.loadProfile(uid);
      }
      if (currentProfile != null) {
        final currentEntry = LeaderboardEntry(
          id: uid,
          username: currentProfile.username,
          xp: currentProfile.xp,
          level: currentProfile.level,
          currentStreak: currentProfile.currentStreak,
        );
        final index = entries.indexWhere((e) => e.id == uid);
        if (index >= 0) {
          entries[index] = currentEntry;
        } else {
          entries.add(currentEntry);
        }
        entries.sort((a, b) {
          final xpCompare = b.xp.compareTo(a.xp);
          if (xpCompare != 0) return xpCompare;
          return a.username.compareTo(b.username);
        });
      }
    }

    return entries;
  }
}
