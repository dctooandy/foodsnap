class FoodItem {
  FoodItem({
    required this.nameOriginal,
    required this.nameTranslated,
    required this.estimatedGrams,
    required this.calories,
    required this.confidence,
  });

  /// A user-typed ingredient with no AI recognition behind it — no original
  /// (source-language) name and no estimated calories.
  factory FoodItem.manual({required String name, double estimatedGrams = 100}) {
    return FoodItem(
      nameOriginal: '',
      nameTranslated: name,
      estimatedGrams: estimatedGrams,
      calories: 0,
      confidence: 'manual',
    );
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      nameOriginal: json['name_original'] as String,
      nameTranslated: json['name_translated'] as String,
      estimatedGrams: (json['estimated_grams'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      confidence: json['confidence'] as String,
    );
  }

  final String nameOriginal;
  final String nameTranslated;
  double estimatedGrams;
  double calories;
  final String confidence;

  FoodItem copyWith({
    String? nameTranslated,
    double? estimatedGrams,
    double? calories,
  }) {
    return FoodItem(
      nameOriginal: nameOriginal,
      nameTranslated: nameTranslated ?? this.nameTranslated,
      estimatedGrams: estimatedGrams ?? this.estimatedGrams,
      calories: calories ?? this.calories,
      confidence: confidence,
    );
  }
}

class AnalyzeFoodResult {
  AnalyzeFoodResult({
    required this.targetLanguage,
    required this.items,
    required this.totalCalories,
  });

  factory AnalyzeFoodResult.fromJson(Map<String, dynamic> json) {
    return AnalyzeFoodResult(
      targetLanguage: json['target_language'] as String,
      items: (json['items'] as List)
          .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalCalories: (json['total_calories'] as num).toDouble(),
    );
  }

  final String targetLanguage;
  final List<FoodItem> items;
  final double totalCalories;
}
