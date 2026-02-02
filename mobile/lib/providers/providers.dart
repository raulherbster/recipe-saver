import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/recipe.dart';

/// API base URL - change this for production
const String apiBaseUrl = 'http://10.0.2.2:8000'; // Android emulator localhost
// const String apiBaseUrl = 'http://localhost:8000'; // iOS simulator
// const String apiBaseUrl = 'https://your-api.com'; // Production

/// API service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(baseUrl: apiBaseUrl);
});

/// Categories provider
final categoriesProvider = FutureProvider<CategoryGroups>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCategories();
});

/// Recipes list state
class RecipesState {
  final List<RecipeSummary> recipes;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  RecipesState({
    this.recipes = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  RecipesState copyWith({
    List<RecipeSummary>? recipes,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return RecipesState(
      recipes: recipes ?? this.recipes,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

/// Recipes list notifier with pagination
class RecipesNotifier extends StateNotifier<RecipesState> {
  final ApiService _api;

  RecipesNotifier(this._api) : super(RecipesState());

  Future<void> loadRecipes({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 1 : state.currentPage + 1;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _api.getRecipes(page: page);

      final newRecipes = refresh ? result.recipes : [...state.recipes, ...result.recipes];

      state = state.copyWith(
        recipes: newRecipes,
        isLoading: false,
        hasMore: page < result.totalPages,
        currentPage: page,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() => loadRecipes(refresh: true);

  void removeRecipe(String id) {
    state = state.copyWith(
      recipes: state.recipes.where((r) => r.id != id).toList(),
    );
  }
}

final recipesProvider = StateNotifierProvider<RecipesNotifier, RecipesState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return RecipesNotifier(api);
});

/// Single recipe detail provider
final recipeDetailProvider = FutureProvider.family<Recipe, String>((ref, id) async {
  final api = ref.watch(apiServiceProvider);
  return api.getRecipe(id);
});

/// Search state
class SearchState {
  final String query;
  final List<String> selectedCategories;
  final List<RecipeSummary> results;
  final bool isLoading;
  final String? error;

  SearchState({
    this.query = '',
    this.selectedCategories = const [],
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<String>? selectedCategories,
    List<RecipeSummary>? results,
    bool? isLoading,
    String? error,
  }) {
    return SearchState(
      query: query ?? this.query,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Search notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final ApiService _api;

  SearchNotifier(this._api) : super(SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void toggleCategory(String category) {
    final categories = List<String>.from(state.selectedCategories);
    if (categories.contains(category)) {
      categories.remove(category);
    } else {
      categories.add(category);
    }
    state = state.copyWith(selectedCategories: categories);
  }

  void clearFilters() {
    state = state.copyWith(selectedCategories: [], query: '');
  }

  Future<void> search() async {
    if (state.query.isEmpty && state.selectedCategories.isEmpty) {
      state = state.copyWith(results: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _api.searchRecipes(
        query: state.query.isNotEmpty ? state.query : null,
        categories: state.selectedCategories.isNotEmpty ? state.selectedCategories : null,
      );

      state = state.copyWith(
        results: result.recipes,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return SearchNotifier(api);
});

/// Extraction state
class ExtractionState {
  final bool isExtracting;
  final ExtractionResponse? response;
  final String? error;

  ExtractionState({
    this.isExtracting = false,
    this.response,
    this.error,
  });

  ExtractionState copyWith({
    bool? isExtracting,
    ExtractionResponse? response,
    String? error,
  }) {
    return ExtractionState(
      isExtracting: isExtracting ?? this.isExtracting,
      response: response ?? this.response,
      error: error,
    );
  }
}

/// Extraction notifier
class ExtractionNotifier extends StateNotifier<ExtractionState> {
  final ApiService _api;

  ExtractionNotifier(this._api) : super(ExtractionState());

  Future<void> extractRecipe({
    required String url,
    String? manualCaption,
    String? manualRecipeUrl,
  }) async {
    state = ExtractionState(isExtracting: true);

    try {
      final response = await _api.extractRecipe(
        url: url,
        manualCaption: manualCaption,
        manualRecipeUrl: manualRecipeUrl,
      );

      state = ExtractionState(
        isExtracting: false,
        response: response,
        error: response.success ? null : response.error,
      );
    } catch (e) {
      state = ExtractionState(
        isExtracting: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = ExtractionState();
  }
}

final extractionProvider = StateNotifierProvider<ExtractionNotifier, ExtractionState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ExtractionNotifier(api);
});
