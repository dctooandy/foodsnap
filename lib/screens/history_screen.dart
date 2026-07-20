import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../services/history_service.dart';
import 'recipe_screen.dart';

class HistoryScreen extends StatelessWidget {
  HistoryScreen({super.key});

  final _historyService = HistoryService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的紀錄')),
      body: StreamBuilder<List<HistoryEntry>>(
        stream: _historyService.watchEntries(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗：${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('還沒有存過任何食譜'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                child: ListTile(
                  title: Text(entry.recipe.title),
                  subtitle: Text(
                    '${entry.category} · 看過 ${entry.viewCount} 次'
                    '${entry.isFamiliar ? ' · 已熟悉 ⭐' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => RecipeScreen(
                          recipe: entry.recipe,
                          entryId: entry.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
