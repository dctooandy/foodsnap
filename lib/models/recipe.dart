/// Must stay in sync with `RECIPE_CATEGORIES` in functions/src/types.ts.
const List<String> kRecipeCategories = [
  '台式',
  '中式',
  '日式',
  '韓式',
  '西式',
  '東南亞',
  '甜點烘焙',
  '其他',
];

class RecipeIngredient {
  RecipeIngredient({required this.name, required this.amount});

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] as String,
      amount: json['amount'] as String,
    );
  }

  final String name;
  final String amount;
}

class Recipe {
  Recipe({
    required this.title,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.totalCalories,
    required this.notes,
    required this.category,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      title: json['title'] as String,
      servings: (json['servings'] as num).toInt(),
      ingredients: (json['ingredients'] as List)
          .map((e) => RecipeIngredient.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      steps: (json['steps'] as List).map((e) => e as String).toList(),
      totalCalories: (json['total_calories'] as num).toDouble(),
      notes: json['notes'] as String,
      category: json['category'] as String? ?? kRecipeCategories.last,
    );
  }

  final String title;
  final int servings;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final double totalCalories;
  final String notes;
  final String category;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'servings': servings,
      'ingredients': [
        for (final i in ingredients) {'name': i.name, 'amount': i.amount},
      ],
      'steps': steps,
      'total_calories': totalCalories,
      'notes': notes,
      'category': category,
    };
  }
}
