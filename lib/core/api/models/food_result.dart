import 'package:meta/meta.dart';

class FoodResult {
  final String name;
  final String servingLabel;
  final double servingQuantity;
  final String servingUnit;
  final double caloriesPerServing;
  final double proteinPerServing;
  final double carbsPerServing;
  final double fatPerServing;
  final String? barcode;
  final String? brand;
  final String source;

  FoodResult({
    required this.name,
    required this.servingLabel,
    this.servingQuantity = 1.0,
    this.servingUnit = 'serving',
    required this.caloriesPerServing,
    required this.proteinPerServing,
    required this.carbsPerServing,
    required this.fatPerServing,
    this.barcode,
    this.brand,
    this.source = 'open_food_facts',
  });

  factory FoodResult.fromJson(Map<String, dynamic> json) {
    final nutriments = json['nutriments'] as Map<String, dynamic>? ?? {};
    final rawServingSize = json['serving_size'] as String?;

    final calServing = _toDouble(nutriments['energy-kcal_serving']);
    final protServing = _toDouble(nutriments['proteins_serving']);
    final carbServing = _toDouble(nutriments['carbohydrates_serving']);
    final fatServing = _toDouble(nutriments['fat_serving']);

    final hasServingFields = calServing != null &&
        protServing != null &&
        carbServing != null &&
        fatServing != null;

    String servingLabel;
    double servingQuantity = 1.0;
    String servingUnit = 'serving';
    double calories, protein, carbs, fat;

    if (hasServingFields) {
      servingLabel = rawServingSize ?? '100g';
      if (rawServingSize != null) {
        final parsed = parseServingInfo(rawServingSize);
        servingQuantity = parsed.quantity;
        servingUnit = parsed.unit;
      }
      calories = calServing;
      protein = protServing;
      carbs = carbServing;
      fat = fatServing;
    } else {
      servingLabel = '100g';
      servingQuantity = 100;
      servingUnit = 'g';
      calories = _toDouble(nutriments['energy-kcal_100g']) ?? 0;
      protein = _toDouble(nutriments['proteins_100g']) ?? 0;
      carbs = _toDouble(nutriments['carbohydrates_100g']) ?? 0;
      fat = _toDouble(nutriments['fat_100g']) ?? 0;
    }

    return FoodResult(
      name: json['product_name'] as String? ?? 'Unknown',
      servingLabel: servingLabel,
      servingQuantity: servingQuantity,
      servingUnit: servingUnit,
      caloriesPerServing: calories,
      proteinPerServing: protein,
      carbsPerServing: carbs,
      fatPerServing: fat,
      barcode: json['code'] as String?,
      brand: json['brands'] as String?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @visibleForTesting
  static ({double quantity, String unit}) parseServingInfo(String label) {
    final s = label.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return (quantity: 1, unit: 'serving');

    final parenMatch = RegExp(r'\(([^)]*)\)').firstMatch(s);
    String mainText = s;
    String? parenContent;
    if (parenMatch != null) {
      parenContent = parenMatch.group(1)!.trim();
      mainText = s.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    }

    if (parenContent != null && parenContent.isNotEmpty) {
      final parenGrams =
          RegExp(r'^(\d+(?:\.\d+)?)\s*g(?:rams?)?$')
              .firstMatch(parenContent);
      if (parenGrams != null) {
        return (quantity: double.parse(parenGrams.group(1)!), unit: 'g');
      }

      final parenOz =
          RegExp(r'^(\d+(?:\.\d+)?)\s*oz$').firstMatch(parenContent);
      if (parenOz != null) {
        final grams = double.parse(parenOz.group(1)!) * 28.35;
        return (quantity: grams.roundToDouble(), unit: 'g');
      }

      final parenVolume = RegExp(
        r'^(\d+(?:\.\d+)?)\s*(ml|milliliters?|millilitres?|liters?|litres?)$',
      ).firstMatch(parenContent);
      if (parenVolume != null) {
        final qty = double.parse(parenVolume.group(1)!);
        final unit = parenVolume.group(2)!;
        return (quantity: qty, unit: unit.startsWith('ml') || unit.startsWith('milli') ? 'ml' : 'l');
      }
    }

    final mainGrams =
        RegExp(r'(\d+(?:\.\d+)?)\s*g(?:rams?)?$').firstMatch(mainText);
    if (mainGrams != null) {
      return (quantity: double.parse(mainGrams.group(1)!), unit: 'g');
    }

    final mainVolume = RegExp(
      r'(\d+(?:\.\d+)?)\s*(ml|milliliters?|millilitres?|liters?|litres?)$',
    ).firstMatch(mainText);
    if (mainVolume != null) {
      final qty = double.parse(mainVolume.group(1)!);
      final unit = mainVolume.group(2)!;
      return (quantity: qty, unit: unit.startsWith('ml') || unit.startsWith('milli') ? 'ml' : 'l');
    }

    final mainOz = RegExp(r'(\d+(?:\.\d+)?)\s*oz$').firstMatch(mainText);
    if (mainOz != null) {
      final grams = double.parse(mainOz.group(1)!) * 28.35;
      return (quantity: grams.roundToDouble(), unit: 'g');
    }

    final qtyUnit =
        RegExp(r'^(\d[\d./]*)\s+(.+)$').firstMatch(mainText);
    if (qtyUnit != null) {
      double qty;
      try {
        qty = _parseFraction(qtyUnit.group(1)!);
      } catch (_) {
        return (quantity: 1, unit: 'serving');
      }
      String unit = qtyUnit.group(2)!.trim();
      if (unit == 'grams' || unit == 'gram') unit = 'g';
      return (quantity: qty, unit: unit);
    }

    final justNumber = RegExp(r'^(\d+(?:\.\d+)?)$').firstMatch(mainText);
    if (justNumber != null) {
      return (quantity: double.parse(justNumber.group(1)!), unit: 'g');
    }

    return (quantity: 1, unit: 'serving');
  }

  static double _parseFraction(String s) {
    if (s.contains('/')) {
      final parts = s.split('/');
      return double.parse(parts[0]) / double.parse(parts[1]);
    }
    return double.parse(s);
  }
}
