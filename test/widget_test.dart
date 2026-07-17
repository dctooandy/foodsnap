// Basic smoke test for a screen that doesn't require Firebase to be
// initialized (RecipeScreen only renders a plain Recipe model). Screens
// that talk to Cloud Functions (CaptureScreen, IngredientReviewScreen)
// need Firebase test mocks to exercise in a widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foodsnap/models/recipe.dart';
import 'package:foodsnap/screens/recipe_screen.dart';

void main() {
  testWidgets('RecipeScreen renders title, ingredients, and steps', (
    WidgetTester tester,
  ) async {
    final recipe = Recipe(
      title: '番茄炒蛋',
      servings: 2,
      ingredients: [
        RecipeIngredient(name: '番茄', amount: '200g'),
        RecipeIngredient(name: '雞蛋', amount: '3顆'),
      ],
      steps: const ['番茄切塊', '蛋液炒熟後加入番茄拌炒'],
      totalCalories: 320,
      notes: '可依口味加鹽調整',
    );

    await tester.pumpWidget(
      MaterialApp(home: RecipeScreen(recipe: recipe)),
    );

    expect(find.text('番茄炒蛋'), findsOneWidget);
    expect(find.text('2 人份'), findsOneWidget);
    expect(find.text('約 320 kcal'), findsOneWidget);
    expect(find.text('番茄'), findsOneWidget);
    expect(find.text('番茄切塊'), findsOneWidget);
  });
}
