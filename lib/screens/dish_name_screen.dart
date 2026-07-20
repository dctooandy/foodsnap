import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/dish_name_candidate.dart';
import '../models/food_item.dart';
import '../services/food_api_service.dart';
import 'recipe_screen.dart';

class DishNameScreen extends StatefulWidget {
  const DishNameScreen({
    super.key,
    required this.items,
    required this.candidates,
  });

  final List<FoodItem> items;
  final List<DishNameCandidate> candidates;

  @override
  State<DishNameScreen> createState() => _DishNameScreenState();
}

class _DishNameScreenState extends State<DishNameScreen> {
  final _api = FoodApiService();
  bool _generating = false;

  Future<void> _openVideoSearch(String dishName) async {
    final uri = Uri.https('www.youtube.com', '/results', {
      'search_query': '$dishName 做法',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法開啟 YouTube')),
      );
    }
  }

  Future<void> _generateRecipe(String dishName) async {
    Navigator.of(context).pop(); // close the action sheet
    setState(() => _generating = true);
    try {
      final recipe = await _api.generateRecipe(
        items: widget.items,
        dishName: dishName,
      );
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

  Future<void> _showActions(DishNameCandidate candidate) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                candidate.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.smart_display_outlined),
                label: const Text('看影片參考'),
                onPressed: () => _openVideoSearch(candidate.title),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.menu_book),
                label: const Text('生成完整食譜'),
                onPressed: () => _generateRecipe(candidate.title),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('選擇菜色')),
      body: Stack(
        children: [
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.candidates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final candidate = widget.candidates[index];
              return Card(
                child: ListTile(
                  title: Text(candidate.title),
                  subtitle: Text(candidate.description),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _generating ? null : () => _showActions(candidate),
                ),
              );
            },
          ),
          if (_generating)
            const ColoredBox(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
