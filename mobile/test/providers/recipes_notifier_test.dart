import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/services/api_service.dart';
import 'package:recipe_saver/services/local_db_service.dart';
import 'package:recipe_saver/models/recipe.dart';

class MockApiService extends Mock implements ApiService {}

class MockLocalDbService extends Mock implements LocalDbService {}

// Helpers for building test data concisely.
RecipeSummary _summary(String id, {String? title}) => RecipeSummary(
      id: id,
      title: title ?? 'Recipe $id',
      createdAt: DateTime.now(),
    );

PaginatedRecipes _page(
  List<RecipeSummary> recipes, {
  int page = 1,
  int totalPages = 1,
}) =>
    PaginatedRecipes(
      recipes: recipes,
      total: recipes.length,
      page: page,
      pageSize: 20,
      totalPages: totalPages,
    );

void main() {
  late MockApiService mockApiService;
  late MockLocalDbService mockDb;
  late RecipesNotifier notifier;

  setUp(() {
    mockApiService = MockApiService();
    mockDb = MockLocalDbService();
    notifier = RecipesNotifier(mockApiService, mockDb);

    // Default stubs — tests only need to override what they care about.
    when(() => mockDb.getRecipeSummaries()).thenAnswer((_) async => []);
    when(() => mockDb.saveRecipeSummaries(any())).thenAnswer((_) async {});
    when(() => mockDb.deleteRecipe(any())).thenAnswer((_) async {});
  });

  group('RecipesNotifier', () {
    test('initial state is empty with no loading', () {
      expect(notifier.state.recipes, isEmpty);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.hasMore, true);
      expect(notifier.state.currentPage, 0);
      expect(notifier.state.error, isNull);
      expect(notifier.state.isOffline, false);
    });

    group('loadRecipes', () {
      test('loads first page of recipes', () async {
        final recipes = [_summary('1'), _summary('2')];

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenAnswer((_) async => _page(recipes));

        await notifier.loadRecipes(refresh: true);

        expect(notifier.state.recipes.length, 2);
        expect(notifier.state.recipes[0].title, 'Recipe 1');
        expect(notifier.state.currentPage, 1);
        expect(notifier.state.isLoading, false);
        expect(notifier.state.hasMore, false);
        expect(notifier.state.isOffline, false);
        verify(() => mockDb.saveRecipeSummaries(any())).called(1);
      });

      test('seeds UI with cached recipes before API responds on first load', () async {
        final cached = [_summary('cached')];
        when(() => mockDb.getRecipeSummaries()).thenAnswer((_) async => cached);
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenAnswer((_) async => _page([_summary('fresh')]));

        await notifier.loadRecipes(refresh: true);

        // Final state should contain the fresh API data.
        expect(notifier.state.recipes.map((r) => r.id), contains('fresh'));
        expect(notifier.state.isOffline, false);
      });

      test('appends recipes on pagination', () async {
        final page1 = [_summary('1')];
        final page2 = [_summary('2')];

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenAnswer((_) async => _page(page1, totalPages: 2));
        when(() => mockApiService.getRecipes(page: 2, pageSize: 20))
            .thenAnswer((_) async => _page(page2, page: 2));

        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.recipes.length, 1);
        expect(notifier.state.hasMore, true);

        await notifier.loadRecipes();
        expect(notifier.state.recipes.length, 2);
        expect(notifier.state.recipes[1].title, 'Recipe 2');
        expect(notifier.state.hasMore, false);
      });

      test('does not load if already loading', () async {
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return _page([]);
        });

        // Start loading.
        final future1 = notifier.loadRecipes(refresh: true);
        // Try to load again while still loading.
        final future2 = notifier.loadRecipes();

        await Future.wait([future1, future2]);

        // Should only call API once.
        verify(() => mockApiService.getRecipes(page: 1, pageSize: 20)).called(1);
      });

      test('does not load more if hasMore is false', () async {
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenAnswer((_) async => _page([]));

        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.hasMore, false);

        await notifier.loadRecipes();

        verify(() => mockApiService.getRecipes(page: 1, pageSize: 20)).called(1);
        verifyNever(() => mockApiService.getRecipes(page: 2, pageSize: 20));
      });

      test('sets error state on failure when no cache available', () async {
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenThrow(Exception('Network error'));

        await notifier.loadRecipes(refresh: true);

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, contains('Network error'));
        expect(notifier.state.isOffline, false);
      });

      test('sets isOffline when API fails but cached data exists', () async {
        final cached = [_summary('cached')];
        when(() => mockDb.getRecipeSummaries()).thenAnswer((_) async => cached);
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenThrow(Exception('Network error'));

        await notifier.loadRecipes(refresh: true);

        expect(notifier.state.isLoading, false);
        expect(notifier.state.isOffline, true);
        expect(notifier.state.error, isNull);
        expect(notifier.state.recipes.map((r) => r.id), contains('cached'));
      });

      test('clears isOffline on successful refresh after being offline', () async {
        final cached = [_summary('cached')];
        when(() => mockDb.getRecipeSummaries()).thenAnswer((_) async => cached);
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenThrow(Exception('Network error'));

        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.isOffline, true);

        // Network comes back.
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenAnswer((_) async => _page([_summary('fresh')]));

        await notifier.refresh();

        expect(notifier.state.isOffline, false);
        expect(notifier.state.recipes.map((r) => r.id), contains('fresh'));
      });
    });

    group('refresh', () {
      test('resets to page 1 and replaces recipes', () async {
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20)).thenAnswer(
          (_) async => _page([_summary('1', title: 'Old Recipe')]),
        );

        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.recipes[0].title, 'Old Recipe');

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20)).thenAnswer(
          (_) async => _page([_summary('2', title: 'New Recipe')]),
        );

        await notifier.refresh();

        expect(notifier.state.recipes.length, 1);
        expect(notifier.state.recipes[0].title, 'New Recipe');
        expect(notifier.state.currentPage, 1);
      });
    });

    group('removeRecipe', () {
      test('removes recipe from list and calls db.deleteRecipe', () async {
        final recipes = [_summary('1'), _summary('2'), _summary('3')];

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenAnswer((_) async => _page(recipes));

        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.recipes.length, 3);

        await notifier.removeRecipe('2');

        expect(notifier.state.recipes.length, 2);
        expect(notifier.state.recipes.map((r) => r.id), ['1', '3']);
        verify(() => mockDb.deleteRecipe('2')).called(1);
      });

      test('calls db.deleteRecipe even if recipe id not in list', () async {
        final recipes = [_summary('1')];

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenAnswer((_) async => _page(recipes));

        await notifier.loadRecipes(refresh: true);

        await notifier.removeRecipe('non-existent');

        expect(notifier.state.recipes.length, 1);
        verify(() => mockDb.deleteRecipe('non-existent')).called(1);
      });
    });
  });
}
