import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/widgets/jua_exit_dialog.dart';

void main() {
  testWidgets('Jua exit dialog renders distinct actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showJuaExitDialog(
                    context: context,
                    title: 'Exit practice?',
                    message: 'Your answered questions are saved.',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    // The dialog contains an intentional repeating pulse animation, so
    // pumpAndSettle() would wait forever. Advance through the entrance
    // animation for a deterministic snapshot instead.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Exit practice?'), findsOneWidget);
    expect(find.text('KEEP PLAYING'), findsOneWidget);
    expect(find.text('EXIT'), findsOneWidget);
  });
}
