import 'package:flutter_test/flutter_test.dart';
import 'package:bioloop/core/api/models/food_result.dart';

void main() {
  group('_parseServingInfo — parenthetical grams', () {
    test('"0.25 cup (45g)" → grams preferred', () {
      final result = FoodResult.parseServingInfo('0.25 cup (45g)');
      expect(result.quantity, 45);
      expect(result.unit, 'g');
    });

    test('"1 portion (45g)" → grams preferred', () {
      final result = FoodResult.parseServingInfo('1 portion (45g)');
      expect(result.quantity, 45);
      expect(result.unit, 'g');
    });

    test('"14 crackers (30 g)" → grams preferred', () {
      final result = FoodResult.parseServingInfo('14 crackers (30 g)');
      expect(result.quantity, 30);
      expect(result.unit, 'g');
    });

    test('"1 bar (40g)" → grams preferred', () {
      final result = FoodResult.parseServingInfo('1 bar (40g)');
      expect(result.quantity, 40);
      expect(result.unit, 'g');
    });

    test('"1 cup (8oz)" → oz converted to grams', () {
      final result = FoodResult.parseServingInfo('1 cup (8oz)');
      expect(result.quantity, 227);
      expect(result.unit, 'g');
    });

    test('"8 fl oz (240g)" → grams in parens preferred', () {
      final result = FoodResult.parseServingInfo('8 fl oz (240g)');
      expect(result.quantity, 240);
      expect(result.unit, 'g');
    });

    test('"about 1 cup (240g)" → grams in parens preferred', () {
      final result = FoodResult.parseServingInfo('about 1 cup (240g)');
      expect(result.quantity, 240);
      expect(result.unit, 'g');
    });
  });

  group('_parseServingInfo — parenthetical volume', () {
    test('"1 portion (15 ml)" → volume preserved', () {
      final result = FoodResult.parseServingInfo('1 portion (15 ml)');
      expect(result.quantity, 15);
      expect(result.unit, 'ml');
    });

    test('"1 L (1000ml)" → volume from parens', () {
      final result = FoodResult.parseServingInfo('1 L (1000ml)');
      expect(result.quantity, 1000);
      expect(result.unit, 'ml');
    });
  });

  group('_parseServingInfo — simple grams (no parens)', () {
    test('"100g" → pure grams', () {
      final result = FoodResult.parseServingInfo('100g');
      expect(result.quantity, 100);
      expect(result.unit, 'g');
    });

    test('"100.0g" → decimal grams', () {
      final result = FoodResult.parseServingInfo('100.0g');
      expect(result.quantity, 100);
      expect(result.unit, 'g');
    });

    test('"100 grams" → plural normalized', () {
      final result = FoodResult.parseServingInfo('100 grams');
      expect(result.quantity, 100);
      expect(result.unit, 'g');
    });

    test('"4.7 g (1 SLICE)" → grams from main text', () {
      final result = FoodResult.parseServingInfo('4.7 g (1 SLICE)');
      expect(result.quantity, 4.7);
      expect(result.unit, 'g');
    });
  });

  group('_parseServingInfo — simple volume (no parens)', () {
    test('"15 ml" → volume', () {
      final result = FoodResult.parseServingInfo('15 ml');
      expect(result.quantity, 15);
      expect(result.unit, 'ml');
    });
  });

  group('_parseServingInfo — quantity + unit (no parens, no grams)', () {
    test('"1 serving" → plain unit', () {
      final result = FoodResult.parseServingInfo('1 serving');
      expect(result.quantity, 1);
      expect(result.unit, 'serving');
    });

    test('"2 slices" → plain unit', () {
      final result = FoodResult.parseServingInfo('2 slices');
      expect(result.quantity, 2);
      expect(result.unit, 'slices');
    });
  });

  group('_parseServingInfo — edge cases', () {
    test('empty string → fallback', () {
      final result = FoodResult.parseServingInfo('');
      expect(result.quantity, 1);
      expect(result.unit, 'serving');
    });

    test('unparseable → fallback', () {
      final result = FoodResult.parseServingInfo('bunch');
      expect(result.quantity, 1);
      expect(result.unit, 'serving');
    });
  });
}
