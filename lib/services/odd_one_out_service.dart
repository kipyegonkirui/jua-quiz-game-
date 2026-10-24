import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/odd_one_out.dart';
import 'supabase_service.dart';

class OddOneOutService {
  const OddOneOutService._();

  static Future<OddOneOutStatus> status() =>
      SupabaseService.instance.getOddOneOutStatus();

  static Future<String> startRound(OddOneOutMode mode) =>
      SupabaseService.instance.startOddOneOutRound(mode);

  static Future<List<OddOneOutPuzzle>> getPuzzles(String roundId) =>
      SupabaseService.instance.getOddOneOutPuzzles(roundId);

  static Future<OddOneOutAnswerResult> answer({
    required String roundId,
    required String puzzleId,
    required String choice,
    required int timeMs,
  }) => SupabaseService.instance.answerOddOneOutPuzzle(
        roundId: roundId,
        puzzleId: puzzleId,
        choice: choice,
        timeMs: timeMs,
      );

  static Future<OddOneOutHintResult> useHint({
    required String roundId,
    required String puzzleId,
  }) => SupabaseService.instance.useOddOneOutHint(
        roundId: roundId,
        puzzleId: puzzleId,
      );

  static Future<OddOneOutHintResult> useWatchHint({
    required String roundId,
    required String puzzleId,
  }) async {
    final res = await Supabase.instance.client.rpc('use_odd_one_out_watch_hint', params: {
      'p_round_id': roundId,
      'p_puzzle_id': puzzleId,
    });
    return OddOneOutHintResult.fromMap(Map<String, dynamic>.from(res as Map));
  }

  static Future<OddOneOutResult> submit(String roundId) =>
      SupabaseService.instance.submitOddOneOutRound(roundId);
}
