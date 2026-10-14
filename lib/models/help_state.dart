/// Hints and second chances for one round / daily challenge, as the server
/// sees them. Never contains the correct answer.
class QuestionHelp {
  /// Options hidden by a hint (always wrong ones). Empty = no hint used.
  Set<String> hintWrong;

  /// A hint video was watched but the hint hasn't been used yet.
  bool hintGranted;

  /// A second-chance video was watched but hasn't been used yet.
  bool retryGranted;

  /// Set while the player got this question wrong and hasn't decided about a
  /// second chance yet.
  String? pendingFirstChoice;

  QuestionHelp({
    Set<String>? hintWrong,
    this.hintGranted = false,
    this.retryGranted = false,
    this.pendingFirstChoice,
  }) : hintWrong = hintWrong ?? <String>{};

  factory QuestionHelp.fromMap(Map<String, dynamic> map) => QuestionHelp(
        hintWrong: ((map['hint_wrong'] as List?) ?? const []).map((e) => e as String).toSet(),
        hintGranted: (map['hint_granted'] as bool?) ?? false,
        retryGranted: (map['retry_granted'] as bool?) ?? false,
        pendingFirstChoice: map['pending_first_choice'] as String?,
      );
}

class HelpState {
  int hintsLeft;
  int retriesLeft;

  /// Coin balance and the price of a hint, so the hint button knows whether
  /// "pay with coins" is possible. (The server still checks.)
  int coins;
  int hintPrice;
  final Map<String, QuestionHelp> questions;

  HelpState({
    this.hintsLeft = 0,
    this.retriesLeft = 0,
    this.coins = 0,
    this.hintPrice = 20,
    Map<String, QuestionHelp>? questions,
  })
      : questions = questions ?? <String, QuestionHelp>{};

  /// Used if the server call fails: no hints offered, nothing pending.
  factory HelpState.empty() => HelpState();

  QuestionHelp of(String questionId) =>
      questions.putIfAbsent(questionId, () => QuestionHelp());

  factory HelpState.fromMap(Map<String, dynamic> map) {
    final raw = (map['questions'] as Map<String, dynamic>?) ?? const {};
    return HelpState(
      hintsLeft: (map['hints_left'] as num?)?.toInt() ?? 0,
      retriesLeft: (map['retries_left'] as num?)?.toInt() ?? 0,
      coins: (map['coins'] as num?)?.toInt() ?? 0,
      hintPrice: (map['hint_price'] as num?)?.toInt() ?? 20,
      questions: {
        for (final e in raw.entries)
          e.key: QuestionHelp.fromMap(e.value as Map<String, dynamic>),
      },
    );
  }
}
