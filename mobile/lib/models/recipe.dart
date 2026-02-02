/// Recipe and related data models.

class Ingredient {
  final String id;
  final String name;
  final String? quantity;
  final String? unit;
  final String? preparation;
  final String? rawText;
  final int sortOrder;

  Ingredient({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    this.preparation,
    this.rawText,
    this.sortOrder = 0,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'],
      unit: json['unit'],
      preparation: json['preparation'],
      rawText: json['raw_text'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'preparation': preparation,
      'raw_text': rawText,
      'sort_order': sortOrder,
    };
  }

  /// Format ingredient for display (e.g., "2 cups flour, sifted")
  String get displayText {
    final parts = <String>[];
    if (quantity != null) parts.add(quantity!);
    if (unit != null) parts.add(unit!);
    parts.add(name);
    if (preparation != null) parts.add(', $preparation');
    return parts.join(' ');
  }
}

class Category {
  final String id;
  final String name;
  final String type;

  Category({
    required this.id,
    required this.name,
    required this.type,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
    };
  }
}

class Tag {
  final String id;
  final String tag;
  final String? source;

  Tag({
    required this.id,
    required this.tag,
    this.source,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] ?? '',
      tag: json['tag'] ?? '',
      source: json['source'],
    );
  }
}

class Recipe {
  final String id;
  final String title;
  final String? description;
  final List<String>? instructions;
  final int? prepTimeMins;
  final int? cookTimeMins;
  final int? totalTimeMins;
  final String? servings;
  final String? difficulty;
  final List<Ingredient> ingredients;
  final List<Category> categories;
  final List<Tag> tags;
  final String? videoUrl;
  final String? videoPlatform;
  final String? recipePageUrl;
  final String? recipeSiteName;
  final String? originalCaption;
  final String? thumbnailUrl;
  final String? authorName;
  final String? extractionMethod;
  final double? extractionConfidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  Recipe({
    required this.id,
    required this.title,
    this.description,
    this.instructions,
    this.prepTimeMins,
    this.cookTimeMins,
    this.totalTimeMins,
    this.servings,
    this.difficulty,
    this.ingredients = const [],
    this.categories = const [],
    this.tags = const [],
    this.videoUrl,
    this.videoPlatform,
    this.recipePageUrl,
    this.recipeSiteName,
    this.originalCaption,
    this.thumbnailUrl,
    this.authorName,
    this.extractionMethod,
    this.extractionConfidence,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'],
      instructions: json['instructions'] != null
          ? List<String>.from(json['instructions'])
          : null,
      prepTimeMins: json['prep_time_mins'],
      cookTimeMins: json['cook_time_mins'],
      totalTimeMins: json['total_time_mins'],
      servings: json['servings'],
      difficulty: json['difficulty'],
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => Ingredient.fromJson(e))
              .toList() ??
          [],
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => Category.fromJson(e))
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => Tag.fromJson(e))
              .toList() ??
          [],
      videoUrl: json['video_url'],
      videoPlatform: json['video_platform'],
      recipePageUrl: json['recipe_page_url'],
      recipeSiteName: json['recipe_site_name'],
      originalCaption: json['original_caption'],
      thumbnailUrl: json['thumbnail_url'],
      authorName: json['author_name'],
      extractionMethod: json['extraction_method'],
      extractionConfidence: json['extraction_confidence']?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'instructions': instructions,
      'prep_time_mins': prepTimeMins,
      'cook_time_mins': cookTimeMins,
      'total_time_mins': totalTimeMins,
      'servings': servings,
      'difficulty': difficulty,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'video_url': videoUrl,
      'recipe_page_url': recipePageUrl,
      'thumbnail_url': thumbnailUrl,
    };
  }

  /// Format total time for display (e.g., "35 min" or "1h 30m")
  String? get formattedTime {
    final mins = totalTimeMins;
    if (mins == null) return null;
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remaining = mins % 60;
    if (remaining == 0) return '${hours}h';
    return '${hours}h ${remaining}m';
  }

  /// Get the source display name
  String get sourceDisplay {
    if (recipeSiteName != null) return recipeSiteName!;
    if (videoPlatform == 'youtube') return 'YouTube';
    if (videoPlatform == 'instagram') return 'Instagram';
    return 'Manual';
  }
}

class RecipeSummary {
  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final int? totalTimeMins;
  final String? difficulty;
  final String? sourcePlatform;
  final String? recipeSiteName;
  final DateTime createdAt;

  RecipeSummary({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.totalTimeMins,
    this.difficulty,
    this.sourcePlatform,
    this.recipeSiteName,
    required this.createdAt,
  });

  factory RecipeSummary.fromJson(Map<String, dynamic> json) {
    return RecipeSummary(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'],
      thumbnailUrl: json['thumbnail_url'],
      totalTimeMins: json['total_time_mins'],
      difficulty: json['difficulty'],
      sourcePlatform: json['source_platform'],
      recipeSiteName: json['recipe_site_name'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  String? get formattedTime {
    final mins = totalTimeMins;
    if (mins == null) return null;
    if (mins < 60) return '$mins min';
    final hours = mins ~/ 60;
    final remaining = mins % 60;
    if (remaining == 0) return '${hours}h';
    return '${hours}h ${remaining}m';
  }
}
