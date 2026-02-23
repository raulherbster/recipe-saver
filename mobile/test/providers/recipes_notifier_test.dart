import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/services/api_service.dart';
import 'package:recipe_saver/models/recipe.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late RecipesNotifier notifier;

  setUp(() {
    mockApiService = MockApiService();
    notifier = RecipesNotifier(mockApiService);
  });

  group('RecipesNotifier', () {
    test('initial state is empty with no loading', () {
      expect(notifier.state.recipes, isEmpty);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.hasMore, true);
      expect(notifier.state.currentPage, 0);
      expect(notifier.state.error, isNull);
    });

    group('loadRecipes', () {
      test('loads first page of recipes', () async {
        final recipes = [
          RecipeSummary(
            id: '1',
            title: 'Recipe 1',
            createdAt: DateTime.now(),
          ),
          RecipeSummary(
            id: '2',
            title: 'Recipe 2',
            createdAt: DateTime.now(),
          ),
        ];

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20)).thenAnswer(
          (_) async => PaginatedRecipes(
            recipes: recipes,
            total: 2,
            page: 1,
            pageSize: 20,
            totalPages: 1,
          ),
        );

        await notifier.loadRecipes(refresh: true);

        expect(notifier.state.recipes.length, 2);
        expect(notifier.state.recipes[0].title, 'Recipe 1');
        expect(notifier.state.currentPage, 1);
        expect(notifier.state.isLoading, false);
        expect(notifier.state.hasMore, false);
      });

      test('appends recipes on pagination', () async {
        final page1Recipes = [
          RecipeSummary(id: '1', title: 'Recipe 1', createdAt: DateTime.now()),
        ];
        final page2Recipes = [
          RecipeSummary(id: '2', title: 'Recipe 2', createdAt: DateTime.now()),
        ];

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20)).thenAnswer(
          (_) async => PaginatedRecipes(
            recipes: page1Recipes,
            total: 2,
            page: 1,
            pageSize: 20,
            totalPages: 2,
          ),
        );

        when(() => mockApiService.getRecipes(page: 2, pageSize: 20)).thenAnswer(
          (_) async => PaginatedRecipes(
            recipes: page2Recipes,
            total: 2,
            page: 2,
            pageSize: 20,
            totalPages: 2,
          ),
        );

        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.recipes.length, 1);
        expect(notifier.state.hasMore, true);

        await notifier.loadRecipes();
        expect(notifier.state.recipes.length, 2);
        expect(notifier.state.recipes[1].title, 'Recipe 2');
        expect(notifier.state.hasMore, false);
      });

      test('does not load if already loading', () async {
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20)).thenAnswer(
          (_) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return PaginatedRecipes(
              recipes: [],
              total: 0,
              page: 1,
              pageSize: 20,
              totalPages: 0,
            );
          },
        );

        // Start loading
        final future1 = notifier.loadRecipes(refresh: true);
        // Try to load again while still loading
        final future2 = notifier.loadRecipes();

        await Future.wait([future1, future2]);

        // Should only call API once
        verify(() => mockApiService.getRecipes(page: 1, pageSize: 20)).called(1);
      });

      test('does not load more if hasMore is false', () async {
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20)).thenAnswer(
          (_) async => PaginatedRecipes(
            recipes: [],
            total: 0,
            page: 1,
            pageSize: 20,
            totalPages: 1,
          ),
        );

        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.hasMore, false);

        await notifier.loadRecipes();

        // Should not call API for page 2
        verify(() => mockApiService.getRecipes(page: 1, pageSize: 20)).called(1);
        verifyNever(() => mockApiService.getRecipes(page: 2, pageSize: 20));
      });

      test('sets error state on failure', () async {
        when(() => mockApiService.getRecipes(page: 1, pageSize: 20))
            .thenThrow(Exception('Network error'));

        await notifier.loadRecipes(refresh: true);

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, contains('Network error'));
      });
    });

    group('refresh', () {
      test('resets to page 1 and replaces recipes', () async {
        final initialRecipes = [
          RecipeSummary(id: '1', title: 'Old Recipe', createdAt: DateTime.now()),
        ];
        final refreshedRecipes = [
          RecipeSummary(id: '2', title: 'New Recipe', createdAt: DateTime.now()),
        ];

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20)).thenAnswer(
          (_) async => PaginatedRecipes(
            recipes: initialRecipes,
            total: 1,
            page: 1,
            pageSize: 20,
            totalPages: 1,
          ),
        );

        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.recipes[0].title, 'Old Recipe');

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20)).thenAnswer(
          (_) async => PaginatedRecipes(
            recipes: refreshedRecipes,
            total: 1,
            page: 1,
            pageSize: 20,
            totalPages: 1,
          ),
        );

        await notifier.refresh();

        expect(notifier.state.recipes.length, 1);
        expect(notifier.state.recipes[0].title, 'New Recipe');
        expect(notifier.state.currentPage, 1);
      });
    });

    group('removeRecipe', () {
      test('removes recipe from list by id', () async {
        final recipes = [
          RecipeSummary(id: '1', title: 'Recipe 1', createdAt: DateTime.now()),
          RecipeSummary(id: '2', title: 'Recipe 2', createdAt: DateTime.now()),
          RecipeSummary(id: '3', title: 'Recipe 3', createdAt: DateTime.now()),
        ];

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20)).thenAnswer(
          (_) async => PaginatedRecipes(
            recipes: recipes,
            total: 3,
            page: 1,
            pageSize: 20,
            totalPages: 1,
          ),
        );

        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.recipes.length, 3);

        notifier.removeRecipe('2');

        expect(notifier.state.recipes.length, 2);
        expect(notifier.state.recipes.map((r) => r.id), ['1', '3']);
      });

      test('does nothing if recipe id not found', () async {
        final recipes = [
          RecipeSummary(id: '1', title: 'Recipe 1', createdAt: DateTime.now()),
        ];

        when(() => mockApiService.getRecipes(page: 1, pageSize: 20)).thenAnswer(
          (_) async => PaginatedRecipes(
            recipes: recipes,
            total: 1,
            page: 1,
            pageSize: 20,
            totalPages: 1,
          ),
        );

        await notifier.loadRecipes(refresh: true);

        notifier.removeRecipe('non-existent');

        expect(notifier.state.recipes.length, 1);
      });
    });
  });
}
