import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/recipe.dart';
import '../services/history_service.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key, required this.recipe, this.entryId});

  final Recipe recipe;

  /// Non-null when opened from the history list — the recipe is already
  /// saved, and opening it counts as a view toward its "familiar" badge.
  /// Null means this is a freshly-generated recipe not yet saved.
  final String? entryId;

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  // Created lazily (not as a field initializer) so this screen can still be
  // rendered in tests without Firebase being initialized, as long as the
  // save/view-tracking codepaths that touch Firestore aren't exercised.
  HistoryService get _historyService => HistoryService();
  bool _saving = false;
  String? _savedEntryId;
  final _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _savedEntryId = widget.entryId;
    if (widget.entryId != null) {
      _recordView(widget.entryId!);
    }
  }

  Future<void> _recordView(String entryId) async {
    try {
      final newlyFamiliar = await _historyService.recordView(entryId);
      if (!mounted || !newlyFamiliar) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已熟悉「${widget.recipe.title}」！⭐ ${widget.recipe.category} +1')),
      );
    } catch (_) {
      // Non-critical — viewing the recipe should still work even if this fails.
    }
  }

  Future<void> _saveToHistory() async {
    setState(() => _saving = true);
    try {
      final id = await _historyService.saveEntry(widget.recipe);
      if (!mounted) return;
      setState(() => _savedEntryId = id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已加入我的紀錄')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入紀錄失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _share() {
    final recipe = widget.recipe;
    final buffer = StringBuffer()
      ..writeln('${recipe.title}（${recipe.servings} 人份，約 ${recipe.totalCalories.toStringAsFixed(0)} kcal）')
      ..writeln()
      ..writeln('食材：');
    for (final ingredient in recipe.ingredients) {
      buffer.writeln('- ${ingredient.name} ${ingredient.amount}');
    }
    buffer.writeln();
    buffer.writeln('步驟：');
    for (final (index, step) in recipe.steps.indexed) {
      buffer.writeln('${index + 1}. $step');
    }
    if (recipe.notes.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('備註：${recipe.notes}');
    }

    // Required on iPad/macOS, where the share sheet is an anchored popover —
    // without it, Share.share throws a PlatformException.
    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    Share.share(
      buffer.toString(),
      subject: recipe.title,
      sharePositionOrigin: origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            key: _shareButtonKey,
            icon: const Icon(Icons.share),
            tooltip: '分享',
            onPressed: _share,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('${recipe.servings} 人份')),
              Chip(label: Text('約 ${recipe.totalCalories.toStringAsFixed(0)} kcal')),
              Chip(label: Text(recipe.category)),
            ],
          ),
          const SizedBox(height: 16),
          if (_savedEntryId == null)
            FilledButton.icon(
              onPressed: _saving ? null : _saveToHistory,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_outlined),
              label: const Text('加入我的紀錄'),
            )
          else
            const Chip(
              avatar: Icon(Icons.bookmark, size: 18),
              label: Text('已收藏'),
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
