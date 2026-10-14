import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Persists a guest player's progression on the device.
///
/// The guest cache is device-scoped rather than tied to an anonymous
/// Supabase user id. That means a player keeps the same local progress even
/// if the anonymous session is refreshed while the app is installed.
/// Uninstalling the app removes this local cache; a real account is what
/// makes progress restorable after reinstalling.
class GuestProgressStore {
  GuestProgressStore._();

  static const _key = 'jua_guest_progress_v1';
  static const _dailyBestKey = 'jua_guest_best_daily_v1';
  static const _practiceBestKey = 'jua_guest_best_practice_v1';
  static const _speedBestKey = 'jua_guest_best_speed_v1';

  static Future<Map<String, dynamic>?> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Ignore a corrupt cache; the server profile remains the fallback.
    }
    return null;
  }

  static Future<UserProfile?> loadProfile(String userId) async {
    final map = await _read();
    if (map == null) return null;

    try {
      return UserProfile.fromMap({
        'id': userId,
        'username': map['username'] ?? 'Player',
        'xp': (map['xp'] as num?)?.toInt() ?? 0,
        'level': (map['level'] as num?)?.toInt() ?? 1,
        'current_streak': (map['current_streak'] as num?)?.toInt() ?? 0,
        'longest_streak': (map['longest_streak'] as num?)?.toInt() ?? 0,
        'total_attempts': (map['total_attempts'] as num?)?.toInt() ?? 0,
        'total_correct': (map['total_correct'] as num?)?.toInt() ?? 0,
        'total_questions': (map['total_questions'] as num?)?.toInt() ?? 0,
        'practice_rounds': (map['practice_rounds'] as num?)?.toInt() ?? 0,
        'coins': (map['coins'] as num?)?.toInt() ?? 0,
        'is_guest': true,
        'last_completed_date': map['last_completed_date'],
      });
    } catch (_) {
      return null;
    }
  }

  static Future<int> loadBestScore({required bool dailyChallenge, bool speedQuiz = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = speedQuiz
        ? _speedBestKey
        : (dailyChallenge ? _dailyBestKey : _practiceBestKey);
    return prefs.getInt(key) ?? 0;
  }

  static Future<int> loadSpeedBestScore() => loadBestScore(
        dailyChallenge: false,
        speedQuiz: true,
      );

  static Future<void> saveBestScore({
    required bool dailyChallenge,
    required int score,
    bool speedQuiz = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = speedQuiz
        ? _speedBestKey
        : (dailyChallenge ? _dailyBestKey : _practiceBestKey);
    final current = prefs.getInt(key) ?? 0;
    if (score > current) {
      await prefs.setInt(key, score);
    }
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      'username': profile.username,
      'xp': profile.xp,
      'level': profile.level,
      'current_streak': profile.currentStreak,
      'longest_streak': profile.longestStreak,
      'total_attempts': profile.totalAttempts,
      'total_correct': profile.totalCorrect,
      'total_questions': profile.totalQuestions,
      'practice_rounds': profile.practiceRounds,
      'coins': profile.coins,
      'last_completed_date': profile.lastCompletedDate?.toIso8601String(),
    };
    await prefs.setString(_key, jsonEncode(map));
  }
}
