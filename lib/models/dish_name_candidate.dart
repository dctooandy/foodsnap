class DishNameCandidate {
  DishNameCandidate({required this.title, required this.description});

  factory DishNameCandidate.fromJson(Map<String, dynamic> json) {
    return DishNameCandidate(
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }

  final String title;
  final String description;
}

class SuggestDishNamesResult {
  SuggestDishNamesResult({required this.candidates});

  factory SuggestDishNamesResult.fromJson(Map<String, dynamic> json) {
    return SuggestDishNamesResult(
      candidates: (json['candidates'] as List)
          .map((e) => DishNameCandidate.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  final List<DishNameCandidate> candidates;
}
