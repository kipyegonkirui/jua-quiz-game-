import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/engine/game_controller.dart';
import 'package:jua_quiz/game/engine/game_session.dart';
import 'package:jua_quiz/game/models/game_answer.dart';
import 'package:jua_quiz/game/models/game_answer_resolution.dart';
import 'package:jua_quiz/game/models/game_mode.dart';
import 'package:jua_quiz/game/models/game_question.dart';
import 'package:jua_quiz/game/models/game_rules.dart';
import 'package:jua_quiz/game/scoring/game_scorer.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12);
  final questions = [
    const GameQuestion(id: 'q1', text: 'One?', options: {'a': 'A', 'b': 'B'}),
    const GameQuestion(id: 'q2', text: 'Two?', options: {'a': 'A', 'b': 'B'}),
  ];

  GameSession session() => GameSession(
        id: 's1',
        mode: GameMode.practice,
        questions: questions,
        startedAt: now,
        questionStartedAt: now,
      ).start(now: now);

  test('settled answer is recorded and controller can advance', () async {
    final controller = GameController(
      session: session(),
      resolveAnswer: ({required question, required chosenOption, required timeTaken}) async =>
          GameAnswerResolution.settled(
        GameAnswer(
          questionId: question.id,
          chosenOption: chosenOption,
          isCorrect: chosenOption == 'a',
          correctOption: 'a',
          answeredAt: now.add(timeTaken),
          timeTaken: timeTaken,
        ),
      ),
    );

    controller.selectOption('a');
    final resolution = await controller.submitSelected(now: now.add(const Duration(seconds: 2)));

    expect(resolution?.isSettled, isTrue);
    expect(controller.session.answeredCount, 1);
    expect(controller.session.status, GameSessionStatus.answerPending);
    expect(controller.session.selectedOption, isNull);

    controller.advance(now: now.add(const Duration(seconds: 3)));
    expect(controller.session.currentIndex, 1);
    expect(controller.session.status, GameSessionStatus.inProgress);
  });

  test('retry offer leaves question unsettled and allows a second pick', () async {
    var attempts = 0;
    final controller = GameController(
      session: session(),
      resolveAnswer: ({required question, required chosenOption, required timeTaken}) async {
        attempts++;
        if (attempts == 1) {
          return GameAnswerResolution.retryOffered(
            firstChoice: chosenOption,
            retryGranted: true,
          );
        }
        return GameAnswerResolution.settled(
          GameAnswer(
            questionId: question.id,
            chosenOption: chosenOption,
            isCorrect: true,
            correctOption: chosenOption,
            answeredAt: now.add(timeTaken),
            timeTaken: timeTaken,
            firstChoice: 'b',
            secondChanceUsed: true,
          ),
        );
      },
    );

    controller.selectOption('b');
    final offered = await controller.submitSelected(now: now.add(const Duration(seconds: 1)));

    expect(offered?.isRetryOffered, isTrue);
    expect(controller.hasRetryPending, isTrue);
    expect(controller.session.answeredCount, 0);
    expect(controller.session.selectedOption, isNull);

    controller.selectOption('a');
    expect(controller.canSubmit, isTrue);
    final settled = await controller.submitSelected(now: now.add(const Duration(seconds: 2)));

    expect(settled?.isSettled, isTrue);
    expect(controller.session.answeredCount, 1);
    expect(controller.session.answers.single.secondChanceUsed, isTrue);
  });

  test('advance is ignored while a retry is pending', () async {
    final controller = GameController(
      session: session(),
      resolveAnswer: ({required question, required chosenOption, required timeTaken}) async =>
          GameAnswerResolution.retryOffered(
        firstChoice: chosenOption,
        retryGranted: true,
      ),
    );

    controller.selectOption('b');
    await controller.submitSelected(now: now.add(const Duration(seconds: 1)));
    controller.advance(now: now.add(const Duration(seconds: 2)));

    expect(controller.session.currentIndex, 0);
    expect(controller.hasRetryPending, isTrue);
  });
  test('controller can clear selection and record a settled server answer', () {
    final controller = GameController(
      session: session(),
      resolveAnswer: ({required question, required chosenOption, required timeTaken}) async =>
          throw StateError('resolver should not be called'),
    );

    controller.selectOption('a');
    expect(controller.session.selectedOption, 'a');
    controller.clearSelection();
    expect(controller.session.selectedOption, isNull);

    controller.selectOption('b');
    controller.recordSettledAnswer(
      GameAnswer(
        questionId: 'q1',
        chosenOption: 'b',
        isCorrect: false,
        correctOption: 'a',
        answeredAt: now,
      ),
    );
    expect(controller.session.answeredCount, 1);
    expect(controller.session.status, GameSessionStatus.answerPending);
    expect(controller.session.selectedOption, isNull);
  });

  test('complete marks the session completed', () {
    final controller = GameController(
      session: session(),
      resolveAnswer: ({required question, required chosenOption, required timeTaken}) async =>
          throw StateError('resolver should not be called'),
    );

    controller.complete();
    expect(controller.session.status, GameSessionStatus.completed);
  });

  test('restoreRetryPending puts a resumed session into retry state', () {
    final controller = GameController(
      session: session(),
      resolveAnswer: ({required question, required chosenOption, required timeTaken}) async =>
          throw StateError('resolver should not be called'),
    );

    controller.selectOption('b');
    controller.restoreRetryPending();

    expect(controller.hasRetryPending, isTrue);
    expect(controller.session.selectedOption, isNull);
    expect(controller.canSubmit, isFalse);
  });


test('local scoring is exposed only when the mode opts in', () async {
  final controller = GameController(
    session: session(),
    rules: const GameRules(
      mode: GameMode.speedQuiz,
      localScoring: true,
    ),
    scorer: const GameScorer(basePoints: 100),
    resolveAnswer: ({required question, required chosenOption, required timeTaken}) async =>
        GameAnswerResolution.settled(
      GameAnswer(
        questionId: question.id,
        chosenOption: chosenOption,
        isCorrect: chosenOption == 'a',
        correctOption: 'a',
        answeredAt: now.add(timeTaken),
        timeTaken: timeTaken,
      ),
    ),
  );

  controller.selectOption('a');
  await controller.submitSelected(now: now.add(const Duration(seconds: 2)));

  expect(controller.localScore, 100);
  expect(controller.lastScore?.total, 100);
});

  test('timeout resolver settles a missed question', () async {
    final controller = GameController(
      session: session(),
      resolveAnswer: ({required question, required chosenOption, required timeTaken}) async =>
          throw StateError('answer resolver should not run on timeout'),
      resolveTimeout: ({required question, required timeTaken}) async =>
          GameAnswerResolution.settled(
        GameAnswer(
          questionId: question.id,
          chosenOption: '',
          isCorrect: false,
          correctOption: 'a',
          answeredAt: now.add(timeTaken),
          timeTaken: timeTaken,
          timedOut: true,
        ),
      ),
    );

    final resolution = await controller.submitTimeout(
      now: now.add(const Duration(seconds: 11)),
    );

    expect(resolution?.isSettled, isTrue);
    expect(controller.session.answeredCount, 1);
    expect(controller.session.answers.single.timedOut, isTrue);
    expect(controller.session.status, GameSessionStatus.answerPending);
  });


}
