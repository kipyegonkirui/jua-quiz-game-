import 'package:flutter_test/flutter_test.dart';

import 'package:jua_quiz/widgets/reward_feedback.dart';

void main() {
  test('XP reward factory formats positive XP', () {
    final reward = RewardFeedbackItem.xp(50);
    expect(reward.label, 'XP');
    expect(reward.value, '+50');
  });

  test('coin reward factory formats positive coins', () {
    final reward = RewardFeedbackItem.coins(125);
    expect(reward.label, 'COINS');
    expect(reward.value, '+125');
  });

  test('generic reward supports custom label and value', () {
    final reward = RewardFeedbackItem.generic(
      label: 'STREAK',
      value: '7 days',
    );
    expect(reward.label, 'STREAK');
    expect(reward.value, '7 days');
  });
}
