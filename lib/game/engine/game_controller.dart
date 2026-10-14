import '../models/game_answer.dart';
import '../models/game_answer_resolution.dart';
import '../models/game_question.dart';
import '../models/game_rules.dart';
import '../scoring/game_score.dart';
import '../scoring/game_scorer.dart';
import 'game_session.dart';

/// Produces a server/local verdict for the selected answer.
///
/// The resolver is deliberately independent of Supabase. Practice and Daily
/// can call their existing RPCs here, while future modes can calculate their
/// answer locally and return a settled [GameAnswerResolution].
typedef GameAnswerResolver = Future<GameAnswerResolution> Function({
  required GameQuestion question,
  required String chosenOption,
  required Duration timeTaken,
});

/// Resolves a question whose time limit expired without a client-selected answer.
/// The backend should determine the authoritative elapsed time.
typedef GameTimeoutResolver = Future<GameAnswerResolution> Function({
  required GameQuestion question,
  required Duration timeTaken,
});

/// Orchestrates a [GameSession] without depending on Flutter or a backend.
///
/// Screens can listen to [session] changes by calling the imperative methods
/// and updating their own state. Backend-specific work stays inside the
/// supplied [GameAnswerResolver].
class GameController {
  GameSession _session;
  final GameAnswerResolver _resolveAnswer;
  final GameRules rules;
  final GameTimeoutResolver? _resolveTimeout;
  final GameScorer? scorer;
  GameScoreBreakdown? _lastScore;
  int _localScore = 0;
  bool _submitting = false;

  GameController({
    required GameSession session,
    required GameAnswerResolver resolveAnswer,
    GameRules? rules,
    this.scorer,
    GameTimeoutResolver? resolveTimeout,
  })  : _session = session,
        _resolveAnswer = resolveAnswer,
        _resolveTimeout = resolveTimeout,
        rules = rules ?? GameRules(mode: session.mode);

  GameSession get session => _session;
  bool get isSubmitting => _submitting;
  bool get hasSelection => _session.selectedOption != null;
  bool get canSubmit => !_submitting && _session.selectedOption != null;
  bool get hasRetryPending =>
      _session.status == GameSessionStatus.retryPending;
  GameScoreBreakdown? get lastScore => _lastScore;
  int get localScore => _localScore;

  void selectOption(String option) {
    _session = _session.selectOption(option);
  }

  void clearSelection() {
    _session = _session.copyWith(clearSelectedOption: true);
  }

  /// Restores a persisted second-chance offer when a round is reopened.
  void restoreRetryPending() {
    _session = _session.copyWith(
      clearSelectedOption: true,
      status: GameSessionStatus.retryPending,
    );
  }

  /// Records a settled answer that was finalized by a separate server RPC,
  /// such as declining a second chance.
  void recordSettledAnswer(GameAnswer answer) {
    _recordSettled(answer);
  }

  /// Marks the session complete after the backend has finalized the round.
  void complete() {
    _session = _session.copyWith(status: GameSessionStatus.completed);
  }

  /// Resolves the current selection and updates the session state.
  ///
  /// A settled answer is recorded immediately. A retry offer moves the session
  /// to [GameSessionStatus.retryPending] so the UI can collect the second pick
  /// without prematurely counting the question as answered.
  Future<GameAnswerResolution?> submitSelected({DateTime? now}) async {
    if (!canSubmit) return null;
    final question = _session.currentQuestion;
    final selected = _session.selectedOption;
    if (question == null || selected == null) return null;

    final answeredAt = now ?? DateTime.now();
    final timeTaken = answeredAt.difference(_session.questionStartedAt);
    _submitting = true;

    try {
      final resolution = await _resolveAnswer(
        question: question,
        chosenOption: selected,
        timeTaken: timeTaken,
      );

      if (resolution.isRetryOffered) {
        _session = _session.copyWith(
          clearSelectedOption: true,
          status: GameSessionStatus.retryPending,
        );
      } else {
        final answer = resolution.answer;
        if (answer == null) {
          throw StateError('A settled answer resolution must include an answer.');
        }
        _recordSettled(answer);
      }

      return resolution;
    } finally {
      _submitting = false;
    }
  }

  void _recordSettled(GameAnswer answer) {
    _session = _session.recordAnswer(answer);
    final localScorer = scorer;
    if (localScorer != null && rules.localScoring) {
      final question = _session.questions.firstWhere(
        (candidate) => candidate.id == answer.questionId,
      );
      _lastScore = localScorer.score(
        question: question,
        answer: answer,
        mode: rules.mode,
      );
      _localScore += _lastScore!.total;
    } else {
      _lastScore = null;
    }
  }

  /// Settles the current question as a timeout.
  ///
  /// Speed-style modes provide a timeout resolver so the backend can measure
  /// the real server-side elapsed time and record the missed question.
  Future<GameAnswerResolution?> submitTimeout({DateTime? now}) async {
    if (_submitting) return null;
    final resolveTimeout = _resolveTimeout;
    if (resolveTimeout == null) return null;
    final question = _session.currentQuestion;
    if (question == null || _session.status != GameSessionStatus.inProgress) return null;

    final answeredAt = now ?? DateTime.now();
    final timeTaken = answeredAt.difference(_session.questionStartedAt);
    _submitting = true;
    try {
      final resolution = await resolveTimeout(
        question: question,
        timeTaken: timeTaken,
      );
      if (resolution.isRetryOffered) {
        throw StateError('A timeout cannot offer a retry in this game mode.');
      }
      final answer = resolution.answer;
      if (answer == null) {
        throw StateError('A timeout resolution must include an answer.');
      }
      _recordSettled(answer);
      return resolution;
    } finally {
      _submitting = false;
    }
  }

  /// Advances only after the current question has been settled.
  void advance({DateTime? now}) {
    _session = _session.advance(now: now);
  }

  /// Replaces the entire session, useful when reconstructing a saved round
  /// from Supabase after the app is reopened.
  void replaceSession(GameSession session) {
    _session = session;
  }
}
