class StreakDay {
  final DateTime date;
  final bool completed;
  final int streakValue;
  final bool shieldUsed;

  const StreakDay({
    required this.date,
    required this.completed,
    required this.streakValue,
    required this.shieldUsed,
  });

  factory StreakDay.fromMap(Map<String, dynamic> map) {
    return StreakDay(
      date: DateTime.parse(map['date'] as String),
      completed: map['completed'] as bool? ?? false,
      streakValue: (map['streak_value'] as num?)?.toInt() ?? 0,
      shieldUsed: map['shield_used'] as bool? ?? false,
    );
  }
}

class StreakDashboardData {
  final int currentStreak;
  final int longestStreak;
  final int streakShields;
  final DateTime? lastCompletedDate;
  final int? nextMilestone;
  final int nextMilestoneCoins;
  final int nextMilestoneShields;
  final List<StreakDay> days;

  const StreakDashboardData({
    required this.currentStreak,
    required this.longestStreak,
    required this.streakShields,
    required this.lastCompletedDate,
    required this.nextMilestone,
    required this.nextMilestoneCoins,
    required this.nextMilestoneShields,
    required this.days,
  });

  factory StreakDashboardData.fromMap(Map<String, dynamic> map) {
    final rawDays = (map['days'] as List?) ?? const [];
    return StreakDashboardData(
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longest_streak'] as num?)?.toInt() ?? 0,
      streakShields: (map['streak_shields'] as num?)?.toInt() ?? 0,
      lastCompletedDate: map['last_completed_date'] == null
          ? null
          : DateTime.parse(map['last_completed_date'] as String),
      nextMilestone: (map['next_milestone'] as num?)?.toInt(),
      nextMilestoneCoins: (map['next_milestone_coins'] as num?)?.toInt() ?? 0,
      nextMilestoneShields: (map['next_milestone_shields'] as num?)?.toInt() ?? 0,
      days: rawDays
          .map((e) => StreakDay.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
  }

  bool get completedToday {
    if (days.isEmpty) return false;
    return days.last.completed;
  }

  int get completedDays => days.where((d) => d.completed).length;
  int get protectedDays => days.where((d) => d.shieldUsed).length;
}
