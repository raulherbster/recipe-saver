import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/services/api_service.dart';
import 'package:recipe_saver/models/recipe.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late SearchNotifier notifier;

  setUp(() {
    mockApiService = MockApiService();
    notifier = SearchNotifier(mockApiService);
  });

  group('SearchNotifier', () {
    test('initial state is empty', () {
      expect(notifier.state.query, '');
      expect(notifier.state.selectedCategories, isEmpty);
      expect(notifier.state.results, isEmpty);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, isNull);
    });

    group('setQuery', () {
      test('updates query in state', () {
        notifier.setQuery('pasta');

        expect(notifier.state.query, 'pasta');
      });

      test('allows empty query', () {
        notifier.setQuery('something');
        notifier.setQuery('');

        expect(notifier.state.query, '');
      });
    });

    group('toggleCategory', () {
      test('adds category when not selected', () {
        notifier.toggleCategory('Vegan');

        expect(notifier.state.selectedCategories, ['Vegan']);
      });

      test('removes category when already selected', () {
        notifier.toggleCategory('Vegan');
        notifier.toggleCategory('Vegan');

        expect(notifier.state.selectedCategories, isEmpty);
      });

      test('can toggle multiple categories', () {
        notifier.toggleCategory('Vegan');
        notifier.toggleCategory('Quick');
        notifier.toggleCategory('Italian');

        expect(notifier.state.selectedCategories, ['Vegan', 'Quick', 'Italian']);

        notifier.toggleCategory('Quick');

        expect(notifier.state.selectedCategories, ['Vegan', 'Italian']);
      });
    });

    group('clearFilters', () {
      test('resets query and categories', () {
        notifier.setQuery('pizza');
        notifier.toggleCategory('Italian');
        notifier.toggleCategory('Quick');

        notifier.clearFilters();

        expect(notifier.state.query, '');
        expect(notifier.state.selectedCategories, isEmpty);
      });
    });

    group('search', () {
      test('clears results when query and categories are empty', () async {
        await notifier.search();

        expect(notifier.state.results, isEmpty);
        verifyNever(() => mockApiService.searchRecipes());
      });

      test('searches with query only', () async {
        final results = [
          RecipeSummary(id: '1', title: 'Pasta Carbonara', createdAt: DateTime.now()),
        ];

        when(() => mockApiService.searchRecipes(
              query: 'pasta',
              categories: null,
            )).thenAnswer(
          (_) async => SearchResponse(
            recipes: results,
            total: 1,
          ),
        );

        notifier.setQuery('pasta');
        await notifier.search();

        expect(notifier.state.results.length, 1);
        expect(notifier.state.results[0].title, 'Pasta Carbonara');
        expect(notifier.state.isLoading, false);
      });

      test('searches with categories only', () async {
        final results = [
          RecipeSummary(id: '1', title: 'Vegan Curry', createdAt: DateTime.now()),
        ];

        when(() => mockApiService.searchRecipes(
              query: null,
              categories: ['Vegan'],
            )).thenAnswer(
          (_) async => SearchResponse(
            recipes: results,
            total: 1,
          ),
        );

        notifier.toggleCategory('Vegan');
        await notifier.search();

        expect(notifier.state.results.length, 1);
        expect(notifier.state.results[0].title, 'Vegan Curry');
      });

      test('searches with both query and categories', () async {
        final results = [
          RecipeSummary(id: '1', title: 'Vegan Pasta', createdAt: DateTime.now()),
        ];

        when(() => mockApiService.searchRecipes(
              query: 'pasta',
              categories: ['Vegan', 'Italian'],
            )).thenAnswer(
          (_) async => SearchResponse(
            recipes: results,
            total: 1,
          ),
        );

        notifier.setQuery('pasta');
        notifier.toggleCategory('Vegan');
        notifier.toggleCategory('Italian');
        await notifier.search();

        expect(notifier.state.results.length, 1);
        verify(() => mockApiService.searchRecipes(
              query: 'pasta',
              categories: ['Vegan', 'Italian'],
            )).called(1);
      });

      test('sets error state on failure', () async {
        when(() => mockApiService.searchRecipes(
              query: 'test',
              categories: null,
            )).thenThrow(Exception('Search failed'));

        notifier.setQuery('test');
        await notifier.search();

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, contains('Search failed'));
      });

      test('sets loading state during search', () async {
        when(() => mockApiService.searchRecipes(
              query: 'test',
              categories: null,
            )).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return SearchResponse(
            recipes: [],
            total: 0,
          );
        });

        notifier.setQuery('test');
        final searchFuture = notifier.search();

        // Check loading state immediately
        expect(notifier.state.isLoading, true);

        await searchFuture;

        expect(notifier.state.isLoading, false);
      });
    });
  });
}
