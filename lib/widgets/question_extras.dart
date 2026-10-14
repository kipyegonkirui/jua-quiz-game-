import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Shown under the verdict once a question is settled: a "Did you know?" card
/// (when the question has one) and a small "Report this question" link.
/// Everything here is optional, so any failure just hides the card.
class QuestionExtras extends StatefulWidget {
  final String questionId;
  const QuestionExtras({super.key, required this.questionId});

  @override
  State<QuestionExtras> createState() => _QuestionExtrasState();
}

class _QuestionExtrasState extends State<QuestionExtras> {
  String? _fact;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await SupabaseService.instance.getQuestionFact(widget.questionId);
      if (mounted) setState(() => _fact = f);
    } catch (_) {/* optional extra */}
  }

  static const _reasons = <(String, String)>[
    ('wrong_answer', 'The answer is wrong'),
    ('typo', 'Spelling or wording mistake'),
    ('unclear', 'The question is unclear'),
    ('outdated', 'Out of date'),
    ('offensive', 'Offensive or inappropriate'),
    ('other', 'Something else'),
  ];

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('What is wrong with this question?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            for (final r in _reasons)
              ListTile(title: Text(r.$2), onTap: () => Navigator.pop(ctx, r.$1)),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await SupabaseService.instance.reportQuestion(widget.questionId, reason);
      if (!mounted) return;
      setState(() => _reported = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Thanks! We will check this question.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not send the report. Try again later.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_fact != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xE6FFF6D6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.sunGold, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Did you know? ', style: TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: _fact),
                    ]),
                    style: const TextStyle(color: Color(0xFF3A2E00), fontSize: 14, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: _reported ? null : _report,
          icon: const Icon(Icons.flag_outlined, size: 16, color: Colors.white),
          label: Text(_reported ? 'Reported' : 'Report this question',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, shadows: [Shadow(color: Color(0xCC000000), blurRadius: 3)])),
        ),
      ],
    );
  }
}

/// "Did you know?" facts for a finished round (used where answers advance too
/// fast to read a fact mid-game). Shows up to [max] facts; hides if none exist.
class RoundFactsCard extends StatefulWidget {
  final List<String> questionIds;
  final int max;
  const RoundFactsCard({super.key, required this.questionIds, this.max = 3});

  @override
  State<RoundFactsCard> createState() => _RoundFactsCardState();
}

class _RoundFactsCardState extends State<RoundFactsCard> {
  List<String> _facts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final found = <String>[];
    for (final id in widget.questionIds) {
      if (found.length >= widget.max) break;
      try {
        final f = await SupabaseService.instance.getQuestionFact(id);
        if (f != null) found.add(f);
      } catch (_) {/* optional */}
    }
    if (mounted) setState(() => _facts = found);
  }

  @override
  Widget build(BuildContext context) {
    if (_facts.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡 Did you know?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            for (final f in _facts) ...[
              const SizedBox(height: 8),
              Text('• $f', style: const TextStyle(height: 1.3)),
            ],
          ],
        ),
      ),
    );
  }
}
