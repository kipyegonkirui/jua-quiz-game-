import '../models/guess_it.dart';
import 'supabase_service.dart';

class GuessItService {
  const GuessItService._();

  static Future<String> startRound() => SupabaseService.instance.startGuessItRound();

  static Future<List<GuessItQuestion>> getQuestions(String roundId) =>
      SupabaseService.instance.getGuessItQuestions(roundId);

  static Future<GuessItAnswerResult> answer({
    required String roundId,
    required String questionId,
    required String choice,
    required int timeMs,
  }) => SupabaseService.instance.answerGuessItQuestion(
        roundId: roundId,
        questionId: questionId,
        choice: choice,
        timeMs: timeMs,
      );

  static Future<GuessItHintResult> useHint({
    required String roundId,
    required String questionId,
  }) => SupabaseService.instance.useGuessItHint(
        roundId: roundId,
        questionId: questionId,
      );

  static Future<GuessItGameResult> submit(String roundId) =>
      SupabaseService.instance.submitGuessItRound(roundId);
}
