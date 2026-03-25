import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/categories.dart';
import '../models/recipe.dart';
import '../services/backup_service.dart';
import '../services/extraction_service.dart';
import '../services/local_db_service.dart';

/// Local SQLite service — source of truth for all recipe data.
final localDbServiceProvider = Provider<LocalDbService>((ref) {
  return LocalDbService();
});

/// On-device extraction service.
final extractionServiceProvider = Provider<ExtractionService>((ref) {
  return ExtractionService();
});

/// Google Drive backup/restore service.
final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(localDbServiceProvider);
  return BackupService(db);
});

/// Categories — hardcoded taxonomy, no network call needed.
final categoriesProvider = FutureProvider<CategoryGroups>((ref) async {
  return hardcodedCategories;
});

// ── Recipe list ────────────────────────────────────────────────────────────

class RecipesState {
  final List<RecipeSummary> recipes;
  final bool isLoading;
  final String? error;

  RecipesState({
    this.recipes = const [],
    this.isLoading = false,
    this.error,
  });

  RecipesState copyWith({
    List<RecipeSummary>? recipes,
    bool? isLoading,
    String? error,
  }) {
    return RecipesState(
      recipes: recipes ?? this.recipes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RecipesNotifier extends StateNotifier<RecipesState> {
  final LocalDbService _db;

  RecipesNotifier(this._db) : super(RecipesState());

  Future<void> loadRecipes({bool refresh = false}) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final recipes = await _db.getRecipeSummaries();
      state = state.copyWith(recipes: recipes, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => loadRecipes(refresh: true);

  Future<void> removeRecipe(String id) async {
    await _db.deleteRecipe(id);
    state = state.copyWith(
      recipes: state.recipes.where((r) => r.id != id).toList(),
    );
  }
}

final recipesProvider =
    StateNotifierProvider<RecipesNotifier, RecipesState>((ref) {
  final db = ref.watch(localDbServiceProvider);
  return RecipesNotifier(db);
});

// ── Recipe detail ──────────────────────────────────────────────────────────

final recipeDetailProvider =
    FutureProvider.family<Recipe, String>((ref, id) async {
  final db = ref.watch(localDbServiceProvider);
  final recipe = await db.getRecipeDetail(id);
  if (recipe == null) throw Exception('Recipe not found');
  return recipe;
});

// ── Search ─────────────────────────────────────────────────────────────────

class SearchState {
  final String query;
  final List<RecipeSummary> results;
  final bool isLoading;
  final String? error;

  SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<RecipeSummary>? results,
    bool? isLoading,
    String? error,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final LocalDbService _db;

  SearchNotifier(this._db) : super(SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void clearFilters() {
    state = state.copyWith(query: '', results: []);
  }

  Future<void> search() async {
    if (state.query.isEmpty) {
      state = state.copyWith(results: []);
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await _db.searchRecipes(state.query);
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final db = ref.watch(localDbServiceProvider);
  return SearchNotifier(db);
});

// ── Extraction ─────────────────────────────────────────────────────────────

class ExtractionState {
  final bool isExtracting;
  final ExtractionResult? result;
  final String? error;

  ExtractionState({
    this.isExtracting = false,
    this.result,
    this.error,
  });

  ExtractionState copyWith({
    bool? isExtracting,
    ExtractionResult? result,
    String? error,
  }) {
    return ExtractionState(
      isExtracting: isExtracting ?? this.isExtracting,
      result: result ?? this.result,
      error: error,
    );
  }
}

class ExtractionNotifier extends StateNotifier<ExtractionState> {
  final ExtractionService _extractor;
  final LocalDbService _db;

  ExtractionNotifier(this._extractor, this._db) : super(ExtractionState());

  Future<void> extractRecipe({required String url}) async {
    state = ExtractionState(isExtracting: true);
    final result = await _extractor.extract(url);
    if (result.success && result.recipe != null) {
      await _db.insertRecipe(result.recipe!);
    }
    state = ExtractionState(
      isExtracting: false,
      result: result,
      error: result.success ? null : result.error,
    );
  }

  void reset() {
    state = ExtractionState();
  }
}

final extractionProvider =
    StateNotifierProvider<ExtractionNotifier, ExtractionState>((ref) {
  final extractor = ref.watch(extractionServiceProvider);
  final db = ref.watch(localDbServiceProvider);
  return ExtractionNotifier(extractor, db);
});
