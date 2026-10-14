/// Server verdict for a Speed Quiz question.
class SpeedQuizAnswerResult {
  final bool isCorrect;
  final bool timedOut;
  final String? chosen;
  final String? correctOption;
  final int points;
  final int score;
  final int correctCount;
  final int answeredCount;
  final int totalQuestions;
  final int elapsedMs;
  final bool finished;

  const SpeedQuizAnswerResult({
    required this.isCorrect,
    required this.timedOut,
    required this.chosen,
    required this.correctOption,
    required this.points,
    required this.score,
    required this.correctCount,
    required this.answeredCount,
    required this.totalQuestions,
    required this.elapsedMs,
    required this.finished,
  });

  factory SpeedQuizAnswerResult.fromMap(Map<String, dynamic> map) {
    return SpeedQuizAnswerResult(
      isCorrect: map['is_correct'] as bool? ?? false,
      timedOut: map['timed_out'] as bool? ?? false,
      chosen: map['chosen'] as String?,
      correctOption: map['correct_option'] as String?,
      points: (map['points'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toInt() ?? 0,
      correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
      answeredCount: (map['answered'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
      elapsedMs: (map['elapsed_ms'] as num?)?.toInt() ?? 0,
      finished: map['finished'] as bool? ?? false,
    );
  }
}
