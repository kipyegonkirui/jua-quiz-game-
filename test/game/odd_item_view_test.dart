import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/widgets/odd_item_view.dart';

void main() {
  test('plain text and emoji stay text', () {
    final r = OddItemRef.parse('🍎');
    expect(r.isImage, isFalse);
    expect(r.label, '🍎');
  });

  test('img: items resolve to the asset file and label', () {
    final r = OddItemRef.parse('img:fruits_apple|Apple');
    expect(r.isImage, isTrue);
    expect(r.asset, 'assets/odd_one_out/fruits_apple.png');
    expect(r.label, 'Apple');
  });

  test('label is optional', () {
    final r = OddItemRef.parse('img:planets_moon');
    expect(r.asset, 'assets/odd_one_out/planets_moon.png');
    expect(r.label, 'planets_moon');
  });

  test('anyImage detects a picture puzzle', () {
    expect(OddItemRef.anyImage(['Lion', 'img:animals_fish|Fish']), isTrue);
    expect(OddItemRef.anyImage(['Lion', 'Zebra']), isFalse);
  });
}
