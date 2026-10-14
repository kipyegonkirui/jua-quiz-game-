/// Mode-agnostic question data consumed by the game layer.
///
/// Not every mode needs every field. For example, [imageUrl] is useful for
/// Guess It / Find the Difference, while [options] is primarily used by
/// multiple-choice modes.
class GameQuestion {
  final String id;
  final String text;
  final Map<String, String> options;
  final int position;
  final String? category;
  final String? difficulty;
  final String? type;
  final String? explanation;
  final String? imageUrl;
  final Duration? timeLimit;
  final int xpValue;

  const GameQuestion({
    required this.id,
    required this.text,
    this.options = const <String, String>{},
    this.position = 0,
    this.category,
    this.difficulty,
    this.type,
    this.explanation,
    this.imageUrl,
    this.timeLimit,
    this.xpValue = 0,
  });

  GameQuestion copyWith({
    String? id,
    String? text,
    Map<String, String>? options,
    int? position,
    String? category,
    String? difficulty,
    String? type,
    String? explanation,
    String? imageUrl,
    Duration? timeLimit,
    int? xpValue,
  }) {
    return GameQuestion(
      id: id ?? this.id,
      text: text ?? this.text,
      options: options ?? this.options,
      position: position ?? this.position,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      type: type ?? this.type,
      explanation: explanation ?? this.explanation,
      imageUrl: imageUrl ?? this.imageUrl,
      timeLimit: timeLimit ?? this.timeLimit,
      xpValue: xpValue ?? this.xpValue,
    );
  }
}
