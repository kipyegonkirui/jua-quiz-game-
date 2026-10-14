/// A single settled answer in a game session.
class GameAnswer {
  final String questionId;
  final String chosenOption;
  final bool isCorrect;
  final String? correctOption;
  final DateTime answeredAt;
  final Duration? timeTaken;
  final String? firstChoice;
  final bool secondChanceUsed;
  final bool timedOut;

  const GameAnswer({
    required this.questionId,
    required this.chosenOption,
    required this.isCorrect,
    this.correctOption,
    required this.answeredAt,
    this.timeTaken,
    this.firstChoice,
    this.secondChanceUsed = false,
    this.timedOut = false,
  });

  GameAnswer copyWith({
    String? questionId,
    String? chosenOption,
    bool? isCorrect,
    String? correctOption,
    DateTime? answeredAt,
    Duration? timeTaken,
    String? firstChoice,
    bool? secondChanceUsed,
    bool? timedOut,
  }) {
    return GameAnswer(
      questionId: questionId ?? this.questionId,
      chosenOption: chosenOption ?? this.chosenOption,
      isCorrect: isCorrect ?? this.isCorrect,
      correctOption: correctOption ?? this.correctOption,
      answeredAt: answeredAt ?? this.answeredAt,
      timeTaken: timeTaken ?? this.timeTaken,
      firstChoice: firstChoice ?? this.firstChoice,
      secondChanceUsed: secondChanceUsed ?? this.secondChanceUsed,
      timedOut: timedOut ?? this.timedOut,
    );
  }
}
