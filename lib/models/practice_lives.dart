class PracticeLives {
  final int availableLives;
  final int maxLives;
  final DateTime? nextRechargeAt;
  final int rechargeSeconds;

  const PracticeLives({
    required this.availableLives,
    required this.maxLives,
    required this.nextRechargeAt,
    required this.rechargeSeconds,
  });

  factory PracticeLives.fromMap(Map<String, dynamic> map) {
    final rawNext = map['next_recharge_at'] as String?;
    return PracticeLives(
      availableLives: (map['available_lives'] as num?)?.toInt() ?? 0,
      maxLives: (map['max_lives'] as num?)?.toInt() ?? 5,
      nextRechargeAt: rawNext == null ? null : DateTime.tryParse(rawNext)?.toLocal(),
      rechargeSeconds: (map['recharge_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  bool get full => availableLives >= maxLives;
  bool get empty => availableLives <= 0;

  String get remainingLabel => rechargeSeconds <= 0
      ? 'Ready'
      : "${(rechargeSeconds ~/ 60).toString().padLeft(2, '0')}:${(rechargeSeconds % 60).toString().padLeft(2, '0')}";
}
