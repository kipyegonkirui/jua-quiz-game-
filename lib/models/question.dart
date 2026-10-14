class Question {
  final String id;
  final String text;
  final Map<String, String> options; // keys: 'a', 'b', 'c', 'd'
  final int position;
  final String? difficulty;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.position,
    this.difficulty,
  });

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as String,
      text: map['question_text'] as String,
      position: (map['position'] as num).toInt(),
      difficulty: map['difficulty'] as String?,
      options: {
        'a': map['option_a'] as String,
        'b': map['option_b'] as String,
        'c': map['option_c'] as String,
        'd': map['option_d'] as String,
      },
    );
  }
}
