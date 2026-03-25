/// End-to-end persistence and edit round-trip tests.
///
/// Verifies that recipes extracted from real URLs survive a simulated
/// app restart (file-based SQLite closed and reopened) and that edits
/// are correctly persisted.
///
/// Run with:
///   flutter test test/e2e/ --tags e2e
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:recipe_saver/models/recipe.dart';
import 'package:recipe_saver/services/extraction_service.dart';
import 'package:recipe_saver/services/local_db_service.dart';

// Mirrors the schema in LocalDbService._onCreate.
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

Future<LocalDbService> _openDb(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(version: 1, onCreate: _createSchema),
  );
  LocalDbService.injectDatabase(db);
  return LocalDbService();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late String dbPath;

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('recipe_e2e_');
    dbPath = p.join(dir.path, 'test.db');
  });

  tearDown(() async {
    // Close and delete the temp DB after each test.
    final file = File(dbPath);
    if (file.existsSync()) file.deleteSync();
  });

  // ── Persistence across restart ────────────────────────────────────────────

  group('SQLite persistence', () {
    test('recipe survives a simulated app restart (close + reopen DB)', () async {
      final service = ExtractionService();
      final result = await service.extract(
        'https://justinesnacks.com/brown-butter-banana-bread/',
      );
      expect(result.success, isTrue, reason: result.error);
      final recipe = result.recipe!;

      // Session 1 — write.
      final db1 = await _openDb(dbPath);
      await db1.insertRecipe(recipe);

      // Close session 1 by injecting a new connection to the same file.
      final db2 = await _openDb(dbPath);

      // Session 2 — read back.
      final retrieved = await db2.getRecipeDetail(recipe.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, recipe.title);
      expect(retrieved.ingredients.length, recipe.ingredients.length);
    });

    test('recipe list survives a simulated app restart', () async {
      final service = ExtractionService();
      final result = await service.extract(
        'https://justinesnacks.com/brown-butter-banana-bread/',
      );
      expect(result.success, isTrue, reason: result.error);

      final db1 = await _openDb(dbPath);
      await db1.insertRecipe(result.recipe!);

      final db2 = await _openDb(dbPath);
      final summaries = await db2.getRecipeSummaries();
      expect(summaries, hasLength(1));
      expect(summaries.first.title, result.recipe!.title);
    });
  });

  // ── Edit round-trip ───────────────────────────────────────────────────────

  group('Edit round-trip', () {
    test('title change is persisted and retrievable', () async {
      final service = ExtractionService();
      final result = await service.extract(
        'https://justinesnacks.com/brown-butter-banana-bread/',
      );
      expect(result.success, isTrue, reason: result.error);
      final original = result.recipe!;

      final db = await _openDb(dbPath);
      await db.insertRecipe(original);

      // Simulate the user editing the title.
      final edited = Recipe(
        id: original.id,
        title: 'My Banana Bread',
        description: original.description,
        ingredients: original.ingredients,
        instructions: original.instructions,
        servings: original.servings,
        difficulty: original.difficulty,
        prepTimeMins: original.prepTimeMins,
        cookTimeMins: original.cookTimeMins,
        totalTimeMins: original.totalTimeMins,
        recipePageUrl: original.recipePageUrl,
        recipeSiteName: original.recipeSiteName,
        thumbnailUrl: original.thumbnailUrl,
        extractionMethod: original.extractionMethod,
        extractionConfidence: original.extractionConfidence,
        createdAt: original.createdAt,
        updatedAt: DateTime.now(),
      );
      await db.updateRecipe(edited);

      final retrieved = await db.getRecipeDetail(original.id);
      expect(retrieved!.title, 'My Banana Bread');
      // Original data still intact.
      expect(retrieved.ingredients.length, original.ingredients.length);
    });

    test('adding an ingredient is persisted', () async {
      final service = ExtractionService();
      final result = await service.extract(
        'https://justinesnacks.com/brown-butter-banana-bread/',
      );
      expect(result.success, isTrue, reason: result.error);
      final original = result.recipe!;

      final db = await _openDb(dbPath);
      await db.insertRecipe(original);

      final newIngredient = Ingredient(
        id: 'extra-1',
        name: 'pinch of sea salt',
        sortOrder: original.ingredients.length,
      );
      final edited = Recipe(
        id: original.id,
        title: original.title,
        ingredients: [...original.ingredients, newIngredient],
        instructions: original.instructions,
        createdAt: original.createdAt,
        updatedAt: DateTime.now(),
      );
      await db.updateRecipe(edited);

      final retrieved = await db.getRecipeDetail(original.id);
      expect(retrieved!.ingredients.length, original.ingredients.length + 1);
      expect(retrieved.ingredients.last.name, 'pinch of sea salt');
    });

    test('reordered ingredients are persisted in new order', () async {
      final service = ExtractionService();
      final result = await service.extract(
        'https://justinesnacks.com/brown-butter-banana-bread/',
      );
      expect(result.success, isTrue, reason: result.error);
      final original = result.recipe!;
      expect(original.ingredients.length, greaterThanOrEqualTo(2));

      final db = await _openDb(dbPath);
      await db.insertRecipe(original);

      // Reverse the ingredient order.
      final reversed = original.ingredients.reversed.toList();
      final edited = Recipe(
        id: original.id,
        title: original.title,
        ingredients: reversed,
        instructions: original.instructions,
        createdAt: original.createdAt,
        updatedAt: DateTime.now(),
      );
      await db.updateRecipe(edited);

      final retrieved = await db.getRecipeDetail(original.id);
      expect(retrieved!.ingredients.first.name, original.ingredients.last.name);
      expect(retrieved.ingredients.last.name, original.ingredients.first.name);
    });
  });
}
