import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../services/food_api_service.dart';
import 'recipe_screen.dart';

class IngredientReviewScreen extends StatefulWidget {
  const IngredientReviewScreen({
    super.key,
    required this.initialResult,
    required this.imageBytes,
  });

  final AnalyzeFoodResult initialResult;
  final Uint8List imageBytes;

  @override
  State<IngredientReviewScreen> createState() =>
      _IngredientReviewScreenState();
}

class _IngredientReviewScreenState extends State<IngredientReviewScreen> {
  final _api = FoodApiService();
  late List<FoodItem> _items;
  late Set<int> _included;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialResult.items;
    _included = {for (var i = 0; i < _items.length; i++) i};
  }

  double get _totalCalories {
    double sum = 0;
    for (final i in _included) {
      sum += _items[i].calories;
    }
    return sum;
  }

  Future<void> _generateRecipe() async {
    final chosen = [for (final i in _included) _items[i]];
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請至少選擇一項食材')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final recipe = await _api.generateRecipe(items: chosen);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => RecipeScreen(recipe: recipe)),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = e.code == 'resource-exhausted'
          ? (e.message ?? '今日免費次數已用完，請明天再試或登入解鎖更多次數。')
          : '生成食譜失敗：${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成食譜失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('確認食材')),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final item = _items[index];
                final selected = _included.contains(index);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          if (value ?? false) {
                            _included.add(index);
                          } else {
                            _included.remove(index);
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            initialValue: item.nameTranslated,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                            onChanged: (value) {
                              _items[index] = item.copyWith(
                                nameTranslated: value,
                              );
                            },
                          ),
                          Text(
                            item.nameOriginal,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: TextFormField(
                        initialValue: item.estimatedGrams.toStringAsFixed(0),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(
                          isDense: true,
                          suffixText: 'g',
                        ),
                        onChanged: (value) {
                          final grams = double.tryParse(value);
                          if (grams != null) {
                            _items[index] = item.copyWith(
                              estimatedGrams: grams,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${item.calories.toStringAsFixed(0)} kcal',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '總熱量：${_totalCalories.toStringAsFixed(0)} kcal',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _generating ? null : _generateRecipe,
                    icon: _generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.menu_book),
                    label: const Text('生成食譜'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
