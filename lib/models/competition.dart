int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

/// One player's progress in one competition.
class CompetitionEntry {
  final String status; // 'playing' | 'finished'
  final String? finishReason; // completed | out_of_lives | forfeited
  final int livesLeft;
  final int answered;
  final int correct;
  final int totalTimeMs;
  final int totalQuestions;
  final int? rank; // only once results are settled
  final int coinsAwarded;

  const CompetitionEntry({
    required this.status,
    this.finishReason,
    required this.livesLeft,
    required this.answered,
    required this.correct,
    required this.totalTimeMs,
    required this.totalQuestions,
    this.rank,
    required this.coinsAwarded,
  });

  bool get isFinished => status == 'finished';

  factory CompetitionEntry.fromMap(Map<String, dynamic> m) => CompetitionEntry(
        status: m['status'] as String,
        finishReason: m['finish_reason'] as String?,
        livesLeft: _i(m['lives_left']),
        answered: _i(m['answered']),
        correct: _i(m['correct']),
        totalTimeMs: _i(m['total_time_ms']),
        totalQuestions: _i(m['total_questions']),
        rank: (m['rank'] as num?)?.toInt(),
        coinsAwarded: _i(m['coins_awarded']),
      );
}

class PrizeTier {
  final int from;
  final int to;
  final int coins;
  const PrizeTier(this.from, this.to, this.coins);

  factory PrizeTier.fromMap(Map<String, dynamic> m) =>
      PrizeTier(_i(m['from']), _i(m['to']), _i(m['coins']));
}

String ordinal(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

class Competition {
  final String id;
  final String title;
  final DateTime startsAt; // already in the phone's local time
  final DateTime endsAt;
  final int questionCount;
  final int lives;
  final int secondsPerQuestion;
  final int participationCoins;
  final List<PrizeTier> prizeTiers;

  /// As the server saw it when the list was loaded:
  /// upcoming | open | closed | settled.
  final String phase;
  final int entrants;
  final CompetitionEntry? myEntry;

  const Competition({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.questionCount,
    required this.lives,
    required this.secondsPerQuestion,
    required this.participationCoins,
    required this.prizeTiers,
    required this.phase,
    required this.entrants,
    this.myEntry,
  });

  /// Phase re-worked from the clock so countdowns flip without a reload. The
  /// server still has the final say on every action.
  String phaseAt(DateTime now) {
    if (phase == 'settled') return 'settled';
    if (now.isBefore(startsAt)) return 'upcoming';
    if (now.isBefore(endsAt)) return 'open';
    return 'closed';
  }

  /// e.g. "1st: 100 · 2nd–3rd: 50 · Everyone who plays: +10"
  String get prizeSummary {
    final parts = <String>[];
    for (final t in prizeTiers) {
      final label = t.from == t.to ? ordinal(t.from) : '${ordinal(t.from)}–${ordinal(t.to)}';
      parts.add('$label: ${t.coins}');
    }
    if (participationCoins > 0) parts.add('Everyone who plays: +$participationCoins');
    return parts.join(' · ');
  }

  factory Competition.fromMap(Map<String, dynamic> m) => Competition(
        id: m['id'] as String,
        title: m['title'] as String,
        startsAt: DateTime.parse(m['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(m['ends_at'] as String).toLocal(),
        questionCount: _i(m['question_count']),
        lives: _i(m['lives']),
        secondsPerQuestion: _i(m['seconds_per_question']),
        participationCoins: _i(m['participation_coins']),
        prizeTiers: ((m['prize_tiers'] as List?) ?? const [])
            .map((e) => PrizeTier.fromMap(e as Map<String, dynamic>))
            .toList(),
        phase: m['phase'] as String,
        entrants: _i(m['entrants']),
        myEntry: m['my_entry'] == null
            ? null
            : CompetitionEntry.fromMap(m['my_entry'] as Map<String, dynamic>),
      );
}

/// What the server hands back when asked for "my current question".
/// Never contains the right answer.
class CompetitionQuestionState {
  final bool finished;
  final CompetitionEntry? summary; // when finished

  final String questionId;
  final String text;
  final Map<String, String> options; // a, b, c, d
  final int position;
  final int total;
  final int livesLeft;
  final int correct;
  final int secondsPerQuestion;
  final int secondsLeft;

  const CompetitionQuestionState({
    required this.finished,
    this.summary,
    this.questionId = '',
    this.text = '',
    this.options = const {},
    this.position = 0,
    this.total = 0,
    this.livesLeft = 0,
    this.correct = 0,
    this.secondsPerQuestion = 0,
    this.secondsLeft = 0,
  });

  factory CompetitionQuestionState.fromMap(Map<String, dynamic> m) {
    if (m['status'] == 'finished') {
      return CompetitionQuestionState(
        finished: true,
        summary: CompetitionEntry.fromMap(m['summary'] as Map<String, dynamic>),
      );
    }
    final q = m['question'] as Map<String, dynamic>;
    final opts = q['options'] as Map<String, dynamic>;
    return CompetitionQuestionState(
      finished: false,
      questionId: q['id'] as String,
      text: q['text'] as String,
      options: {for (final e in opts.entries) e.key: e.value as String},
      position: _i(m['position']),
      total: _i(m['total']),
      livesLeft: _i(m['lives_left']),
      correct: _i(m['correct']),
      secondsPerQuestion: _i(m['seconds_per_question']),
      secondsLeft: _i(m['seconds_left']),
    );
  }
}

class CompetitionAnswerResult {
  final bool isCorrect;
  final bool timedOut;
  final int livesLeft;
  final int correct;
  final bool finished;
  final String? finishReason;

  const CompetitionAnswerResult({
    required this.isCorrect,
    required this.timedOut,
    required this.livesLeft,
    required this.correct,
    required this.finished,
    this.finishReason,
  });

  factory CompetitionAnswerResult.fromMap(Map<String, dynamic> m) => CompetitionAnswerResult(
        isCorrect: m['is_correct'] as bool,
        timedOut: (m['timed_out'] as bool?) ?? false,
        livesLeft: _i(m['lives_left']),
        correct: _i(m['correct']),
        finished: (m['finished'] as bool?) ?? false,
        finishReason: m['finish_reason'] as String?,
      );
}

class CompetitionStanding {
  final int rank;
  final String username;
  final int correct;
  final int livesLeft;
  final int totalTimeMs;
  final int coinsAwarded;
  final bool isMe;

  const CompetitionStanding({
    required this.rank,
    required this.username,
    required this.correct,
    required this.livesLeft,
    required this.totalTimeMs,
    required this.coinsAwarded,
    required this.isMe,
  });

  factory CompetitionStanding.fromMap(Map<String, dynamic> m) => CompetitionStanding(
        rank: _i(m['rank']),
        username: m['username'] as String,
        correct: _i(m['correct']),
        livesLeft: _i(m['lives_left']),
        totalTimeMs: _i(m['total_time_ms']),
        coinsAwarded: _i(m['coins_awarded']),
        isMe: (m['is_me'] as bool?) ?? false,
      );
}

class CompetitionResults {
  final String title;
  final List<CompetitionStanding> top;
  final CompetitionEntry? me;
  final int players;

  const CompetitionResults({
    required this.title,
    required this.top,
    this.me,
    required this.players,
  });

  factory CompetitionResults.fromMap(Map<String, dynamic> m) => CompetitionResults(
        title: m['title'] as String,
        top: ((m['top'] as List?) ?? const [])
            .map((e) => CompetitionStanding.fromMap(e as Map<String, dynamic>))
            .toList(),
        me: m['me'] == null ? null : CompetitionEntry.fromMap(m['me'] as Map<String, dynamic>),
        players: _i(m['players']),
      );
}
