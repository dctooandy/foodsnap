import 'package:cloud_firestore/cloud_firestore.dart';

import 'recipe.dart';

/// A recipe saved under users/{uid}/entries/{entryId}.
class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.recipe,
    required this.viewCount,
    required this.isFamiliar,
    required this.createdAt,
  });

  factory HistoryEntry.fromFirestore(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return HistoryEntry(
      id: id,
      recipe: Recipe.fromJson(data),
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 1,
      isFamiliar: data['isFamiliar'] as bool? ?? false,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  final String id;
  final Recipe recipe;
  final int viewCount;
  final bool isFamiliar;
  final DateTime createdAt;

  String get category => recipe.category;

  Map<String, dynamic> toNewEntryJson() {
    return {
      ...recipe.toJson(),
      'viewCount': 1,
      'isFamiliar': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
