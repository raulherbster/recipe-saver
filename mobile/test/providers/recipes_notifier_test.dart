import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/services/local_db_service.dart';
import 'package:recipe_saver/models/recipe.dart';

class MockLocalDbService extends Mock implements LocalDbService {}

RecipeSummary _summary(String id, {String? title}) => RecipeSummary(
      id: id,
      title: title ?? 'Recipe $id',
      createdAt: DateTime.now(),
    );

void main() {
  late MockLocalDbService mockDb;
  late RecipesNotifier notifier;

  setUp(() {
    mockDb = MockLocalDbService();
    notifier = RecipesNotifier(mockDb);

    when(() => mockDb.getRecipeSummaries()).thenAnswer((_) async => []);
    when(() => mockDb.deleteRecipe(any())).thenAnswer((_) async {});
  });

  group('RecipesNotifier', () {
    test('initial state is empty with no loading', () {
      expect(notifier.state.recipes, isEmpty);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, isNull);
    });

    group('loadRecipes', () {
      test('loads recipes from local DB', () async {
        final recipes = [_summary('1'), _summary('2')];
        when(() => mockDb.getRecipeSummaries())
            .thenAnswer((_) async => recipes);

        await notifier.loadRecipes(refresh: true);

        expect(notifier.state.recipes.length, 2);
        expect(notifier.state.recipes[0].title, 'Recipe 1');
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNull);
      });

      test('does not reload if already loading', () async {
        when(() => mockDb.getRecipeSummaries()).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return [];
        });

        final future1 = notifier.loadRecipes(refresh: true);
        final future2 = notifier.loadRecipes();

        await Future.wait([future1, future2]);

        verify(() => mockDb.getRecipeSummaries()).called(1);
      });

      test('sets error state on failure', () async {
        when(() => mockDb.getRecipeSummaries())
            .thenThrow(Exception('DB read error'));

        await notifier.loadRecipes(refresh: true);

        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, contains('DB read error'));
      });
    });

    group('removeRecipe', () {
      test('removes recipe from list and calls db.deleteRecipe', () async {
        final recipes = [_summary('1'), _summary('2'), _summary('3')];
        when(() => mockDb.getRecipeSummaries())
            .thenAnswer((_) async => recipes);

        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.recipes.length, 3);

        await notifier.removeRecipe('2');

        expect(notifier.state.recipes.length, 2);
        expect(notifier.state.recipes.map((r) => r.id), ['1', '3']);
        verify(() => mockDb.deleteRecipe('2')).called(1);
      });

      test('calls db.deleteRecipe even if recipe id not in list', () async {
        when(() => mockDb.getRecipeSummaries())
            .thenAnswer((_) async => [_summary('1')]);

        await notifier.loadRecipes(refresh: true);
        await notifier.removeRecipe('non-existent');

        expect(notifier.state.recipes.length, 1);
        verify(() => mockDb.deleteRecipe('non-existent')).called(1);
      });
    });

    group('refresh', () {
      test('reloads from DB', () async {
        when(() => mockDb.getRecipeSummaries())
            .thenAnswer((_) async => [_summary('1', title: 'Old Recipe')]);
        await notifier.loadRecipes(refresh: true);
        expect(notifier.state.recipes[0].title, 'Old Recipe');

        when(() => mockDb.getRecipeSummaries())
            .thenAnswer((_) async => [_summary('2', title: 'New Recipe')]);
        await notifier.refresh();

        expect(notifier.state.recipes.length, 1);
        expect(notifier.state.recipes[0].title, 'New Recipe');
      });
    });
  });
}
