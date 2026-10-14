import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/widgets/game_effects.dart';

void main() {
  testWidgets('tactile widget renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: JuaTactile(
          onTap: null,
          child: Text('Play'),
        ),
      ),
    );

    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('speed pressure bar renders at zero and full pressure', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            SpeedPressureBar(value: 1),
            SpeedPressureBar(value: 0.2),
          ],
        ),
      ),
    );

    expect(find.byType(SpeedPressureBar), findsNWidgets(2));
  });
}
