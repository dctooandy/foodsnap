import 'package:flutter/material.dart';

import '../models/recipe.dart';

class RecipeScreen extends StatelessWidget {
  const RecipeScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Chip(label: Text('${recipe.servings} 人份')),
              const SizedBox(width: 8),
              Chip(label: Text('約 ${recipe.totalCalories.toStringAsFixed(0)} kcal')),
            ],
          ),
          const SizedBox(height: 24),
          Text('食材', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          ...recipe.ingredients.map(
            (ingredient) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ingredient.name)),
                  Text(ingredient.amount),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('步驟', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          ...recipe.steps.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(entry.value)),
                ],
              ),
            ),
          ),
          if (recipe.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('備註', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(recipe.notes),
          ],
        ],
      ),
    );
  }
}
