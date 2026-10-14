/// The server's verdict on one question.
///
/// Two flavours ([status]):
///  * `final`         the answer is locked. [correctOption] is filled in.
///  * `retry_offered` the FIRST pick was wrong and a second chance is on the
///                    table. [correctOption] is deliberately null — the phone
///                    never learns the answer until the question is settled.
class AnswerResult {
  /// The pick this result is about. For `final` it is the pick that counts;
  /// for `retry_offered` it is the (wrong) first pick.
  final String chosen;

  /// Null while a second chance is still open.
  final String? correctOption;

  final bool isCorrect;
  final String status;

  /// The player's first pick, when there was more than one attempt.
  final String? firstChoice;

  /// True when the final answer came from the second chance.
  final bool secondChanceUsed;

  /// True when the second-chance video was already watched (unused reward).
  final bool retryGranted;

  const AnswerResult({
    required this.chosen,
    required this.isCorrect,
    this.correctOption,
    this.status = 'final',
    this.firstChoice,
    this.secondChanceUsed = false,
    this.retryGranted = false,
  });

  bool get isFinal => status == 'final';
  bool get retryOffered => status == 'retry_offered';

  /// Rebuilds the "second chance?" state for a question whose first pick was
  /// wrong but which was never settled (e.g. the app was closed).
  factory AnswerResult.pendingRetry({required String firstChoice, required bool granted}) =>
      AnswerResult(
        chosen: firstChoice,
        isCorrect: false,
        status: 'retry_offered',
        firstChoice: firstChoice,
        retryGranted: granted,
      );

  /// Also reads the older progress rows (`chosen`, `correct_option` only),
  /// which are always final.
  factory AnswerResult.fromMap(Map<String, dynamic> map) {
    final chosen = map['chosen'] as String;
    final correct = map['correct_option'] as String?;
    return AnswerResult(
      chosen: chosen,
      correctOption: correct,
      isCorrect: (map['is_correct'] as bool?) ?? (correct != null && chosen == correct),
      status: (map['status'] as String?) ?? 'final',
      firstChoice: map['first_choice'] as String?,
      secondChanceUsed: (map['second_chance_used'] as bool?) ?? false,
      retryGranted: (map['retry_granted'] as bool?) ?? false,
    );
  }
}
