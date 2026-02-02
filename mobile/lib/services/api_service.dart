import 'package:dio/dio.dart';
import '../models/recipe.dart';

/// Response from extraction endpoint
class ExtractionResponse {
  final bool success;
  final String method;
  final double confidence;
  final String? error;
  final Recipe? recipe;
  final List<String> foundRecipeUrls;
  final String message;

  ExtractionResponse({
    required this.success,
    required this.method,
    required this.confidence,
    this.error,
    this.recipe,
    this.foundRecipeUrls = const [],
    required this.message,
  });

  factory ExtractionResponse.fromJson(Map<String, dynamic> json) {
    return ExtractionResponse(
      success: json['success'] ?? false,
      method: json['method'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0).toDouble(),
      error: json['error'],
      recipe: json['recipe'] != null ? Recipe.fromJson(json['recipe']) : null,
      foundRecipeUrls: List<String>.from(json['found_recipe_urls'] ?? []),
      message: json['message'] ?? '',
    );
  }
}

/// Paginated response for recipe lists
class PaginatedRecipes {
  final List<RecipeSummary> recipes;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  PaginatedRecipes({
    required this.recipes,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedRecipes.fromJson(Map<String, dynamic> json) {
    return PaginatedRecipes(
      recipes: (json['recipes'] as List<dynamic>)
          .map((e) => RecipeSummary.fromJson(e))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 20,
      totalPages: json['total_pages'] ?? 1,
    );
  }
}

/// Search response
class SearchResponse {
  final List<RecipeSummary> recipes;
  final int total;
  final String? query;

  SearchResponse({
    required this.recipes,
    required this.total,
    this.query,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      recipes: (json['recipes'] as List<dynamic>)
          .map((e) => RecipeSummary.fromJson(e))
          .toList(),
      total: json['total'] ?? 0,
      query: json['query'],
    );
  }
}

/// Categories grouped by type
class CategoryGroups {
  final List<Category> dietary;
  final List<Category> protein;
  final List<Category> course;
  final List<Category> cuisine;
  final List<Category> method;
  final List<Category> season;
  final List<Category> difficulty;
  final List<Category> time;

  CategoryGroups({
    this.dietary = const [],
    this.protein = const [],
    this.course = const [],
    this.cuisine = const [],
    this.method = const [],
    this.season = const [],
    this.difficulty = const [],
    this.time = const [],
  });

  factory CategoryGroups.fromJson(Map<String, dynamic> json) {
    return CategoryGroups(
      dietary: _parseCategories(json['dietary']),
      protein: _parseCategories(json['protein']),
      course: _parseCategories(json['course']),
      cuisine: _parseCategories(json['cuisine']),
      method: _parseCategories(json['method']),
      season: _parseCategories(json['season']),
      difficulty: _parseCategories(json['difficulty']),
      time: _parseCategories(json['time']),
    );
  }

  static List<Category> _parseCategories(dynamic list) {
    if (list == null) return [];
    return (list as List<dynamic>).map((e) => Category.fromJson(e)).toList();
  }

  List<Category> get all => [
        ...dietary,
        ...protein,
        ...course,
        ...cuisine,
        ...method,
        ...season,
        ...difficulty,
        ...time,
      ];
}

/// API service for communicating with the backend
class ApiService {
  final Dio _dio;
  final String baseUrl;

  ApiService({required this.baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Content-Type': 'application/json',
          },
        ));

  /// Extract recipe from URL
  Future<ExtractionResponse> extractRecipe({
    required String url,
    String? manualCaption,
    String? manualRecipeUrl,
  }) async {
    try {
      final response = await _dio.post('/api/extract', data: {
        'url': url,
        if (manualCaption != null) 'manual_caption': manualCaption,
        if (manualRecipeUrl != null) 'manual_recipe_url': manualRecipeUrl,
      });
      return ExtractionResponse.fromJson(response.data);
    } on DioException catch (e) {
      return ExtractionResponse(
        success: false,
        method: 'failed',
        confidence: 0,
        error: e.message ?? 'Network error',
        message: 'Failed to extract recipe',
      );
    }
  }

  /// Get paginated list of recipes
  Future<PaginatedRecipes> getRecipes({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get('/api/recipes', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
    return PaginatedRecipes.fromJson(response.data);
  }

  /// Get recipe details by ID
  Future<Recipe> getRecipe(String id) async {
    final response = await _dio.get('/api/recipes/$id');
    return Recipe.fromJson(response.data);
  }

  /// Search recipes
  Future<SearchResponse> searchRecipes({
    String? query,
    List<String>? ingredients,
    List<String>? categories,
    List<String>? tags,
    String? difficulty,
    int? maxTime,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get('/api/recipes/search', queryParameters: {
      if (query != null) 'q': query,
      if (ingredients != null && ingredients.isNotEmpty)
        'ingredients': ingredients.join(','),
      if (categories != null && categories.isNotEmpty)
        'categories': categories.join(','),
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      if (difficulty != null) 'difficulty': difficulty,
      if (maxTime != null) 'max_time': maxTime,
      'page': page,
      'page_size': pageSize,
    });
    return SearchResponse.fromJson(response.data);
  }

  /// Delete a recipe
  Future<void> deleteRecipe(String id) async {
    await _dio.delete('/api/recipes/$id');
  }

  /// Update a recipe
  Future<Recipe> updateRecipe(String id, Map<String, dynamic> updates) async {
    final response = await _dio.patch('/api/recipes/$id', data: updates);
    return Recipe.fromJson(response.data);
  }

  /// Get all categories grouped by type
  Future<CategoryGroups> getCategories() async {
    final response = await _dio.get('/api/categories');
    return CategoryGroups.fromJson(response.data);
  }

  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.data['status'] == 'healthy';
    } catch (e) {
      return false;
    }
  }
}
