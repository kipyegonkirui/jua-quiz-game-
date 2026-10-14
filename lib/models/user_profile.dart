class UserProfile {
  final String id;
  final String username;
  final int xp;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final int totalAttempts;
  final int totalCorrect;
  final int totalQuestions;
  final int practiceRounds;
  final int coins;
  final int streakShields;
  final bool isGuest;
  final DateTime? lastCompletedDate;

  UserProfile({
    required this.id,
    required this.username,
    required this.xp,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalAttempts,
    required this.totalCorrect,
    required this.totalQuestions,
    this.practiceRounds = 0,
    this.coins = 0,
    this.streakShields = 0,
    required this.isGuest,
    this.lastCompletedDate,
  });

  double get accuracy => totalQuestions == 0 ? 0 : totalCorrect / totalQuestions;

  UserProfile copyWith({
    String? id,
    String? username,
    int? xp,
    int? level,
    int? currentStreak,
    int? longestStreak,
    int? totalAttempts,
    int? totalCorrect,
    int? totalQuestions,
    int? practiceRounds,
    int? coins,
    int? streakShields,
    bool? isGuest,
    DateTime? lastCompletedDate,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      totalCorrect: totalCorrect ?? this.totalCorrect,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      practiceRounds: practiceRounds ?? this.practiceRounds,
      coins: coins ?? this.coins,
      streakShields: streakShields ?? this.streakShields,
      isGuest: isGuest ?? this.isGuest,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    );
  }

  bool get completedToday {
    if (lastCompletedDate == null) return false;
    final now = DateTime.now();
    return lastCompletedDate!.year == now.year &&
        lastCompletedDate!.month == now.month &&
        lastCompletedDate!.day == now.day;
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      xp: map['xp'] as int,
      level: map['level'] as int,
      currentStreak: map['current_streak'] as int,
      longestStreak: map['longest_streak'] as int,
      totalAttempts: map['total_attempts'] as int,
      totalCorrect: map['total_correct'] as int,
      totalQuestions: map['total_questions'] as int,
      practiceRounds: (map['practice_rounds'] as int?) ?? 0,
      coins: (map['coins'] as int?) ?? 0,
      streakShields: (map['streak_shields'] as int?) ?? 0,
      isGuest: map['is_guest'] as bool,
      lastCompletedDate: map['last_completed_date'] == null
          ? null
          : DateTime.parse(map['last_completed_date'] as String),
    );
  }
}

class LeaderboardEntry {
  final String id;
  final String username;
  final int xp;
  final int level;
  final int currentStreak;

  LeaderboardEntry({
    required this.id,
    required this.username,
    required this.xp,
    required this.level,
    required this.currentStreak,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      id: map['id'] as String,
      username: map['username'] as String,
      xp: map['xp'] as int,
      level: map['level'] as int,
      currentStreak: map['current_streak'] as int,
    );
  }
}
