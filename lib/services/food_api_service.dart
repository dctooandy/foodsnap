import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/dish_name_candidate.dart';
import '../models/food_item.dart';
import '../models/recipe.dart';

/// Wraps calls to the `analyzeFood` and `generateRecipe` Cloud Functions.
class FoodApiService {
  FoodApiService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<AnalyzeFoodResult> analyzeFood({
    required Uint8List imageBytes,
    required String mediaType,
    String? targetLanguage,
  }) async {
    final callable = _functions.httpsCallable(
      'analyzeFood',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    final result = await callable.call<Map<String, dynamic>>({
      'imageBase64': base64Encode(imageBytes),
      'mediaType': mediaType,
      'targetLanguage': ?targetLanguage,
    });

    return AnalyzeFoodResult.fromJson(Map<String, dynamic>.from(result.data));
  }

  Future<Recipe> generateRecipe({
    required List<FoodItem> items,
    String? targetLanguage,
    String? dishName,
  }) async {
    final callable = _functions.httpsCallable(
      'generateRecipe',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    final result = await callable.call<Map<String, dynamic>>({
      'items': items
          .map((item) => {
                'name': item.nameTranslated,
                'grams': item.estimatedGrams,
              })
          .toList(),
      'targetLanguage': ?targetLanguage,
      'dishName': ?dishName,
    });

    return Recipe.fromJson(Map<String, dynamic>.from(result.data));
  }

  Future<SuggestDishNamesResult> suggestDishNames({
    required List<FoodItem> items,
    String? targetLanguage,
  }) async {
    final callable = _functions.httpsCallable(
      'suggestDishNames',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );

    final result = await callable.call<Map<String, dynamic>>({
      'items': items
          .map((item) => {
                'name': item.nameTranslated,
                'grams': item.estimatedGrams,
              })
          .toList(),
      'targetLanguage': ?targetLanguage,
    });

    return SuggestDishNamesResult.fromJson(Map<String, dynamic>.from(result.data));
  }
}
