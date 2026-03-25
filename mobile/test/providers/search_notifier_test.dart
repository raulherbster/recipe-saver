import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/services/local_db_service.dart';
import 'package:recipe_saver/models/recipe.dart';

class MockLocalDbService extends Mock implements LocalDbService {}

void main() {
  late MockLocalDbService mockDb;
  late SearchNotifier notifier;

  setUp(() {
    mockDb = MockLocalDbService();
    notifier = SearchNotifier(mockDb);
    when(() => mockDb.searchRecipes(any())).thenAnswer((_) async => []);
  });

  group('SearchNotifier', () {
    test('initial state is empty', () {
      expect(notifier.state.query, '');
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

    group('clearFilters', () {
      test('resets query and results', () {
        notifier.setQuery('pizza');
        notifier.clearFilters();
        expect(notifier.state.query, '');
        expect(notifier.state.results, isEmpty);
      });
    });

    group('search', () {
      test('clears results when query is empty', () async {
        await notifier.search();
        expect(notifier.state.results, isEmpty);
        verifyNever(() => mockDb.searchRecipes(any()));
      });

      test('searches with query', () async {
        final results = [
          RecipeSummary(id: '1', title: 'Pasta Carbonara', createdAt: DateTime.now()),
        ];

        when(() => mockDb.searchRecipes('pasta'))
            .thenAnswer((_) async => results);

        notifier.setQuery('pasta');
        await notifier.search();

        expect(notifier.state.results.length, 1);
        expect(notifier.state.results[0].title, 'Pasta Carbonara');
        expect(notifier.state.isLoading, false);
      });

      test('sets error state on failure', () async {
        when(() => mockDb.searchRecipes('test'))
            .thenThrow(Exception('Search failed'));

        notifier.setQuery('test');
        await notifier.search();

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, contains('Search failed'));
      });

      test('sets loading state during search', () async {
        when(() => mockDb.searchRecipes('test')).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return [];
        });

        notifier.setQuery('test');
        final searchFuture = notifier.search();

        expect(notifier.state.isLoading, true);

        await searchFuture;

        expect(notifier.state.isLoading, false);
      });
    });
  });
}
