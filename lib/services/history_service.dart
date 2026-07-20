import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/history_entry.dart';
import '../models/recipe.dart';

/// Number of times a recipe must be viewed before it's marked "familiar"
/// and earns a star toward its category's badge.
const int kFamiliarViewThreshold = 3;

/// Reads/writes the user's saved recipes (users/{uid}/entries) and their
/// per-category star counts (users/{uid}/stats/badges).
class HistoryService {
  HistoryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('users').doc(_uid).collection('entries');

  DocumentReference<Map<String, dynamic>> get _badgesDoc =>
      _db.collection('users').doc(_uid).collection('stats').doc('badges');

  /// Saves a freshly-generated recipe as a new history entry (view count 1).
  /// Returns the new entry's id.
  Future<String> saveEntry(Recipe recipe) async {
    final entry = HistoryEntry(
      id: '',
      recipe: recipe,
      viewCount: 1,
      isFamiliar: false,
      createdAt: DateTime.now(),
    );
    final doc = await _entries.add(entry.toNewEntryJson());
    return doc.id;
  }

  Stream<List<HistoryEntry>> watchEntries() {
    return _entries
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => [
              for (final doc in snap.docs)
                HistoryEntry.fromFirestore(doc.id, doc.data()),
            ]);
  }

  Stream<Map<String, int>> watchBadges() {
    return _badgesDoc.snapshots().map((snap) {
      final data = snap.data() ?? {};
      return {
        for (final category in kRecipeCategories)
          category: (data[category] as num?)?.toInt() ?? 0,
      };
    });
  }

  /// Records a view of [entryId]. Increments its view count and, if this
  /// view crosses the familiar threshold for the first time, marks it
  /// familiar and awards one star to its category. Returns true if this
  /// call newly crossed the threshold (so the UI can show a celebration).
  Future<bool> recordView(String entryId) async {
    final entryRef = _entries.doc(entryId);
    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(entryRef);
      final data = snap.data();
      if (data == null) return false;

      final currentViews = (data['viewCount'] as num?)?.toInt() ?? 0;
      final wasFamiliar = data['isFamiliar'] as bool? ?? false;
      final newViews = currentViews + 1;
      final newlyFamiliar = !wasFamiliar && newViews >= kFamiliarViewThreshold;

      tx.update(entryRef, {
        'viewCount': newViews,
        if (newlyFamiliar) 'isFamiliar': true,
      });

      if (newlyFamiliar) {
        final category = data['category'] as String? ?? kRecipeCategories.last;
        tx.set(
          _badgesDoc,
          {category: FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      }

      return newlyFamiliar;
    });
  }
}
