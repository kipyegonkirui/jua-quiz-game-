import '../models/game_answer.dart';
import '../models/game_mode.dart';
import '../models/game_question.dart';

/// Lifecycle state for a playable question session.
enum GameSessionStatus {
  ready,
  inProgress,
  answerPending,
  retryPending,
  completed,
}

/// Pure in-memory state for one game session.
///
/// This class deliberately contains no Flutter or Supabase dependencies. A
/// mode controller/screen can own it and translate server responses into
/// [GameAnswer] objects without coupling the engine to a particular backend.
class GameSession {
  final String id;
  final GameMode mode;
  final List<GameQuestion> questions;
  final List<GameAnswer> answers;
  final int currentIndex;
  final String? selectedOption;
  final GameSessionStatus status;
  final DateTime startedAt;
  final DateTime questionStartedAt;

  const GameSession({
    required this.id,
    required this.mode,
    required this.questions,
    this.answers = const <GameAnswer>[],
    this.currentIndex = 0,
    this.selectedOption,
    this.status = GameSessionStatus.ready,
    required this.startedAt,
    required this.questionStartedAt,
  });

  GameQuestion? get currentQuestion {
    if (currentIndex < 0 || currentIndex >= questions.length) return null;
    return questions[currentIndex];
  }

  bool get hasQuestions => questions.isNotEmpty;
  bool get isFirstQuestion => currentIndex == 0;
  bool get isLastQuestion => hasQuestions && currentIndex == questions.length - 1;
  bool get isComplete => status == GameSessionStatus.completed;
  int get answeredCount => answers.length;
  int get remainingCount => questions.length - answeredCount;
  int get correctCount => answers.where((answer) => answer.isCorrect).length;
  Duration? get currentQuestionElapsed =>
      DateTime.now().difference(questionStartedAt);

  GameSession start({DateTime? now}) {
    final started = now ?? DateTime.now();
    return copyWith(
      status: hasQuestions ? GameSessionStatus.inProgress : GameSessionStatus.completed,
      startedAt: started,
      questionStartedAt: started,
      currentIndex: 0,
      selectedOption: null,
    );
  }

  GameSession selectOption(String option) {
    if (status != GameSessionStatus.inProgress &&
        status != GameSessionStatus.retryPending) {
      return this;
    }
    if (currentQuestion == null) return this;
    if (answers.any((answer) => answer.questionId == currentQuestion!.id)) return this;

    return copyWith(selectedOption: option);
  }

  GameSession recordAnswer(GameAnswer answer) {
    if (status == GameSessionStatus.completed || currentQuestion == null) return this;
    if (answer.questionId != currentQuestion!.id) {
      throw ArgumentError.value(
        answer.questionId,
        'answer.questionId',
        'must match the current question id',
      );
    }
    if (answers.any((existing) => existing.questionId == answer.questionId)) return this;

    return copyWith(
      answers: [...answers, answer],
      clearSelectedOption: true,
      status: GameSessionStatus.answerPending,
    );
  }

  GameSession advance({DateTime? now}) {
    if (status != GameSessionStatus.answerPending) return this;
    final nextIndex = currentIndex + 1;
    if (nextIndex >= questions.length) {
      return copyWith(
        currentIndex: questions.isEmpty ? 0 : questions.length - 1,
        selectedOption: null,
        status: GameSessionStatus.completed,
      );
    }

    final nextTime = now ?? DateTime.now();
    return copyWith(
      currentIndex: nextIndex,
      selectedOption: null,
      questionStartedAt: nextTime,
      status: GameSessionStatus.inProgress,
    );
  }

  GameSession copyWith({
    String? id,
    GameMode? mode,
    List<GameQuestion>? questions,
    List<GameAnswer>? answers,
    int? currentIndex,
    String? selectedOption,
    bool clearSelectedOption = false,
    GameSessionStatus? status,
    DateTime? startedAt,
    DateTime? questionStartedAt,
  }) {
    return GameSession(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedOption: clearSelectedOption ? null : (selectedOption ?? this.selectedOption),
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      questionStartedAt: questionStartedAt ?? this.questionStartedAt,
    );
  }
}
