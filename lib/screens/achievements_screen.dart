import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/history_service.dart';

/// Star thresholds for each badge tier, in ascending order.
const List<({int threshold, String label, IconData icon, Color color})> kBadgeTiers = [
  (threshold: 30, label: '金牌', icon: Icons.emoji_events, color: Color(0xFFFFD700)),
  (threshold: 15, label: '銀牌', icon: Icons.emoji_events, color: Color(0xFFC0C0C0)),
  (threshold: 5, label: '銅牌', icon: Icons.emoji_events, color: Color(0xFFCD7F32)),
];

class AchievementsScreen extends StatelessWidget {
  AchievementsScreen({super.key});

  final _historyService = HistoryService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('成就')),
      body: StreamBuilder<Map<String, int>>(
        stream: _historyService.watchBadges(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('讀取失敗：${snapshot.error}'));
          }
          final stars = snapshot.data ?? {for (final c in kRecipeCategories) c: 0};
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: kRecipeCategories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final category = kRecipeCategories[index];
              final count = stars[category] ?? 0;

              ({int threshold, String label, IconData icon, Color color})? currentTier;
              for (final tier in kBadgeTiers) {
                if (count >= tier.threshold) {
                  currentTier = tier;
                  break;
                }
              }
              ({int threshold, String label, IconData icon, Color color})? nextTier;
              for (final tier in kBadgeTiers.reversed) {
                if (count < tier.threshold) {
                  nextTier = tier;
                  break;
                }
              }

              return Card(
                child: ListTile(
                  leading: Icon(
                    currentTier?.icon ?? Icons.star_border,
                    color: currentTier?.color,
                  ),
                  title: Text(category),
                  subtitle: Text(
                    nextTier == null
                        ? '${currentTier!.label} · $count 顆星（已達最高等級）'
                        : currentTier == null
                            ? '$count / ${nextTier.threshold} 顆星，集滿解鎖${nextTier.label}'
                            : '${currentTier.label} · $count / ${nextTier.threshold} 顆星，集滿解鎖${nextTier.label}',
                  ),
                  trailing: Text('⭐ $count'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
