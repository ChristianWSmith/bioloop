class FoodResult {
  final String name;
  final String servingLabel;
  final double? servingSizeGrams;
  final double servingQuantity;
  final String servingUnit;
  final double caloriesPerServing;
  final double proteinPerServing;
  final double carbsPerServing;
  final double fatPerServing;
  final String? barcode;
  final String source;

  FoodResult({
    required this.name,
    required this.servingLabel,
    this.servingSizeGrams,
    this.servingQuantity = 1.0,
    this.servingUnit = 'serving',
    required this.caloriesPerServing,
    required this.proteinPerServing,
    required this.carbsPerServing,
    required this.fatPerServing,
    this.barcode,
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
    double? servingSizeGrams;
    double servingQuantity = 1.0;
    String servingUnit = 'serving';
    double calories, protein, carbs, fat;

    if (hasServingFields) {
      servingLabel = rawServingSize ?? '100g';
      if (rawServingSize != null) {
        final parsed = _parseServingInfo(rawServingSize);
        if (parsed != null) {
          servingSizeGrams = parsed.gramEquivalent;
          servingQuantity = parsed.quantity;
          servingUnit = parsed.unit;
        }
      }
      calories = calServing;
      protein = protServing;
      carbs = carbServing;
      fat = fatServing;
    } else {
      servingLabel = '100g';
      servingSizeGrams = 100;
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
      servingSizeGrams: servingSizeGrams,
      servingQuantity: servingQuantity,
      servingUnit: servingUnit,
      caloriesPerServing: calories,
      proteinPerServing: protein,
      carbsPerServing: carbs,
      fatPerServing: fat,
      barcode: json['code'] as String?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static ({double quantity, String unit, double? gramEquivalent})? _parseServingInfo(String label) {
    final fullMatch = RegExp(r'^([\d./]+)\s+(\w+)(?:\s*\((\d+(?:\.\d+)?)\s*\w*\))?$').firstMatch(label);
    if (fullMatch != null) {
      final qty = _parseFraction(fullMatch.group(1)!);
      final unit = fullMatch.group(2)!;
      final gramEq = fullMatch.group(3) != null ? double.parse(fullMatch.group(3)!) : null;
      return (quantity: qty, unit: unit, gramEquivalent: gramEq);
    }

    final simpleGrams = RegExp(r'^(\d+(?:\.\d+)?)\s*g$').firstMatch(label);
    if (simpleGrams != null) {
      final qty = double.parse(simpleGrams.group(1)!);
      return (quantity: qty, unit: 'g', gramEquivalent: qty);
    }

    return null;
  }

  static double _parseFraction(String s) {
    if (s.contains('/')) {
      final parts = s.split('/');
      return double.parse(parts[0]) / double.parse(parts[1]);
    }
    return double.parse(s);
  }
}
