import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/services/extraction_service.dart';
import 'package:recipe_saver/services/local_db_service.dart';
import 'package:recipe_saver/models/recipe.dart';

class MockExtractionService extends Mock implements ExtractionService {}

class MockLocalDbService extends Mock implements LocalDbService {}

class _FakeRecipe extends Fake implements Recipe {}

void main() {
  late MockExtractionService mockExtractor;
  late MockLocalDbService mockDb;
  late ExtractionNotifier notifier;

  setUpAll(() {
    registerFallbackValue(_FakeRecipe());
  });

  setUp(() {
    mockExtractor = MockExtractionService();
    mockDb = MockLocalDbService();
    notifier = ExtractionNotifier(mockExtractor, mockDb);
    when(() => mockDb.insertRecipe(any())).thenAnswer((_) async {});
  });

  group('ExtractionNotifier', () {
    test('initial state is not extracting', () {
      expect(notifier.state.isExtracting, false);
      expect(notifier.state.result, isNull);
      expect(notifier.state.error, isNull);
    });

    group('extractRecipe', () {
      test('successful extraction sets result and saves recipe to DB', () async {
        final recipe = Recipe(
          id: 'recipe-1',
          title: 'Extracted Recipe',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(() => mockExtractor.extract('https://allrecipes.com/recipe/1'))
            .thenAnswer((_) async => ExtractionResult.ok(recipe, 'schema_org'));

        await notifier.extractRecipe(url: 'https://allrecipes.com/recipe/1');

        expect(notifier.state.isExtracting, false);
        expect(notifier.state.result, isNotNull);
        expect(notifier.state.result!.success, true);
        expect(notifier.state.result!.recipe!.title, 'Extracted Recipe');
        expect(notifier.state.error, isNull);
        verify(() => mockDb.insertRecipe(recipe)).called(1);
      });

      test('sets loading state during extraction', () async {
        when(() => mockExtractor.extract(any())).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return ExtractionResult.fail('No recipe found', 'unknown');
        });

        final future = notifier.extractRecipe(url: 'https://youtube.com/shorts/abc');

        expect(notifier.state.isExtracting, true);

        await future;

        expect(notifier.state.isExtracting, false);
      });

      test('does not call insertRecipe on failed extraction', () async {
        when(() => mockExtractor.extract(any())).thenAnswer(
          (_) async => ExtractionResult.fail('No recipe found', 'unknown'),
        );

        await notifier.extractRecipe(url: 'https://youtube.com/shorts/abc');

        expect(notifier.state.result!.success, false);
        expect(notifier.state.error, 'No recipe found');
        verifyNever(() => mockDb.insertRecipe(any()));
      });

      test('sets error from failed extraction result', () async {
        when(() => mockExtractor.extract(any())).thenAnswer(
          (_) async =>
              ExtractionResult.fail('Could not extract recipe from video', 'youtube'),
        );

        await notifier.extractRecipe(url: 'https://youtube.com/watch?v=invalid');

        expect(notifier.state.isExtracting, false);
        expect(notifier.state.result!.success, false);
        expect(notifier.state.error, 'Could not extract recipe from video');
      });
    });

    group('reset', () {
      test('clears state to initial values', () async {
        final recipe = Recipe(
          id: 'r1',
          title: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        when(() => mockExtractor.extract(any()))
            .thenAnswer((_) async => ExtractionResult.ok(recipe, 'schema_org'));

        await notifier.extractRecipe(url: 'https://allrecipes.com/recipe/1');
        expect(notifier.state.result, isNotNull);

        notifier.reset();

        expect(notifier.state.isExtracting, false);
        expect(notifier.state.result, isNull);
        expect(notifier.state.error, isNull);
      });
    });
  });
}
