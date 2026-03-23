import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:recipe_saver/services/local_db_service.dart';
import 'package:recipe_saver/models/recipe.dart';

// Expose the private _onCreate via a helper so we can bootstrap the in-memory
// database with the same schema that LocalDbService uses in production.
Future<void> _createSchema(Database db, int version) async {
  await db.execute('''
    CREATE TABLE recipe_summaries (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      thumbnail_url TEXT,
      total_time_mins INTEGER,
      difficulty TEXT,
      source_platform TEXT,
      recipe_site_name TEXT,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE recipe_details (
      id TEXT PRIMARY KEY,
      json TEXT NOT NULL
    )
  ''');
}

RecipeSummary _makeSummary(String id, {String? title}) => RecipeSummary(
      id: id,
      title: title ?? 'Recipe $id',
      createdAt: DateTime(2024, 1, 1),
    );

Recipe _makeRecipe(String id, {String? title}) => Recipe(
      id: id,
      title: title ?? 'Recipe $id',
      ingredients: const [],
      categories: const [],
      tags: const [],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDbService db;

  setUp(() async {
    final inMemDb = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: _createSchema),
    );
    LocalDbService.injectDatabase(inMemDb);
    db = LocalDbService();
  });

  tearDown(() async => db.clearAll());

  group('recipe_summaries', () {
    test('saveRecipeSummaries then getRecipeSummaries round-trips correctly', () async {
      final summaries = [_makeSummary('1'), _makeSummary('2')];
      await db.saveRecipeSummaries(summaries);

      final result = await db.getRecipeSummaries();

      expect(result.length, 2);
      expect(result.map((s) => s.id), containsAll(['1', '2']));
    });

    test('returns empty list when nothing cached', () async {
      final result = await db.getRecipeSummaries();
      expect(result, isEmpty);
    });

    test('upserts on duplicate id', () async {
      await db.saveRecipeSummaries([_makeSummary('1', title: 'Old')]);
      await db.saveRecipeSummaries([_makeSummary('1', title: 'New')]);

      final result = await db.getRecipeSummaries();
      expect(result.length, 1);
      expect(result.first.title, 'New');
    });

    test('orders results newest-first by created_at', () async {
      final older = RecipeSummary(
        id: 'old',
        title: 'Older Recipe',
        createdAt: DateTime(2023, 1, 1),
      );
      final newer = RecipeSummary(
        id: 'new',
        title: 'Newer Recipe',
        createdAt: DateTime(2024, 6, 1),
      );
      await db.saveRecipeSummaries([older, newer]);

      final result = await db.getRecipeSummaries();
      expect(result.first.id, 'new');
      expect(result.last.id, 'old');
    });
  });

  group('recipe_details', () {
    test('saveRecipeDetail then getRecipeDetail round-trips correctly', () async {
      final recipe = _makeRecipe('42', title: 'Test Recipe');
      await db.saveRecipeDetail(recipe);

      final result = await db.getRecipeDetail('42');
      expect(result, isNotNull);
      expect(result!.id, '42');
      expect(result.title, 'Test Recipe');
    });

    test('returns null for unknown id', () async {
      final result = await db.getRecipeDetail('non-existent');
      expect(result, isNull);
    });

    test('upserts on duplicate id', () async {
      await db.saveRecipeDetail(_makeRecipe('1', title: 'Old'));
      await db.saveRecipeDetail(_makeRecipe('1', title: 'New'));

      final result = await db.getRecipeDetail('1');
      expect(result!.title, 'New');
    });
  });

  group('deleteRecipe', () {
    test('removes from both tables', () async {
      await db.saveRecipeSummaries([_makeSummary('1')]);
      await db.saveRecipeDetail(_makeRecipe('1'));

      await db.deleteRecipe('1');

      expect(await db.getRecipeSummaries(), isEmpty);
      expect(await db.getRecipeDetail('1'), isNull);
    });

    test('is a no-op for unknown id', () async {
      // Should not throw.
      await expectLater(db.deleteRecipe('ghost'), completes);
    });
  });

  group('clearAll', () {
    test('wipes both tables', () async {
      await db.saveRecipeSummaries([_makeSummary('1'), _makeSummary('2')]);
      await db.saveRecipeDetail(_makeRecipe('1'));

      await db.clearAll();

      expect(await db.getRecipeSummaries(), isEmpty);
      expect(await db.getRecipeDetail('1'), isNull);
    });
  });
}
