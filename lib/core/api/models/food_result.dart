class FoodResult {
  final String name;
  final String servingLabel;
  final double? servingSizeGrams;
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
    double calories, protein, carbs, fat;

    if (hasServingFields) {
      servingLabel = rawServingSize ?? '100g';
      if (rawServingSize != null) {
        servingSizeGrams = _parseServingGrams(rawServingSize);
      }
      calories = calServing;
      protein = protServing;
      carbs = carbServing;
      fat = fatServing;
    } else {
      servingLabel = '100g';
      servingSizeGrams = 100;
      calories = _toDouble(nutriments['energy-kcal_100g']) ?? 0;
      protein = _toDouble(nutriments['proteins_100g']) ?? 0;
      carbs = _toDouble(nutriments['carbohydrates_100g']) ?? 0;
      fat = _toDouble(nutriments['fat_100g']) ?? 0;
    }

    return FoodResult(
      name: json['product_name'] as String? ?? 'Unknown',
      servingLabel: servingLabel,
      servingSizeGrams: servingSizeGrams,
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

  static double? _parseServingGrams(String servingSize) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*g').firstMatch(servingSize);
    if (match != null) return double.parse(match.group(1)!);
    return null;
  }
}
