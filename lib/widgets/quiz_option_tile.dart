import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single answer option row. Extracted so practice and daily can share
/// the same look without either owning a private copy.
class QuizOptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const QuizOptionTile({
    super.key,
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.savannaGreen.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.savannaGreen : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: selected ? AppColors.savannaGreen : Colors.black12,
              child: Text(
                letter.toUpperCase(),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black54,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
