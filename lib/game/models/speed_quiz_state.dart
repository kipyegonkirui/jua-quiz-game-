class SpeedQuizState {
  final String status;
  final int currentIndex;
  final int score;
  final int correctCount;
  final int answeredCount;
  final int totalQuestions;
  final int secondsPerQuestion;
  final DateTime? servedAt;

  const SpeedQuizState({
    required this.status,
    required this.currentIndex,
    required this.score,
    required this.correctCount,
    required this.answeredCount,
    required this.totalQuestions,
    required this.secondsPerQuestion,
    required this.servedAt,
  });

  bool get isFinished => status == 'completed';

  factory SpeedQuizState.fromMap(Map<String, dynamic> map) {
    final rawServedAt = map['served_at'];
    return SpeedQuizState(
      status: map['status'] as String? ?? 'playing',
      currentIndex: (map['current_index'] as num?)?.toInt() ?? 1,
      score: (map['score'] as num?)?.toInt() ?? 0,
      correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
      answeredCount: (map['answered'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
      secondsPerQuestion: (map['seconds_per_question'] as num?)?.toInt() ?? 10,
      servedAt: rawServedAt == null ? null : DateTime.tryParse(rawServedAt.toString())?.toLocal(),
    );
  }
}
