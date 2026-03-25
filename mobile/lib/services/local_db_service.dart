import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/recipe.dart';

/// SQLite-backed local cache for recipe data.
///
/// Two tables:
///   - `recipe_summaries` — flat columns for the home-screen list
///   - `recipe_details`   — full recipe stored as a JSON blob
class LocalDbService {
  static Database? _db;

  /// Test seam: inject a pre-opened (e.g. in-memory) database.
  static void injectDatabase(Database db) => _db = db;

  Future<Database> get _database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final path = join(await getDatabasesPath(), 'recipe_saver.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
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

  /// Replace the stored summaries with [summaries] (upsert by id).
  Future<void> saveRecipeSummaries(List<RecipeSummary> summaries) async {
    final db = await _database;
    final batch = db.batch();
    for (final s in summaries) {
      batch.insert(
        'recipe_summaries',
        s.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Return all cached summaries, newest first.
  Future<List<RecipeSummary>> getRecipeSummaries() async {
    final db = await _database;
    final rows =
        await db.query('recipe_summaries', orderBy: 'created_at DESC');
    return rows.map(RecipeSummary.fromJson).toList();
  }

  /// Upsert a full recipe into the detail cache.
  Future<void> saveRecipeDetail(Recipe recipe) async {
    final db = await _database;
    await db.insert(
      'recipe_details',
      {'id': recipe.id, 'json': jsonEncode(recipe.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Return the cached full recipe, or null if not cached.
  Future<Recipe?> getRecipeDetail(String id) async {
    final db = await _database;
    final rows = await db.query(
      'recipe_details',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Recipe.fromJson(
      jsonDecode(rows.first['json'] as String) as Map<String, dynamic>,
    );
  }

  /// Remove a recipe from both cache tables.
  Future<void> deleteRecipe(String id) async {
    final db = await _database;
    await db.delete('recipe_summaries', where: 'id = ?', whereArgs: [id]);
    await db.delete('recipe_details', where: 'id = ?', whereArgs: [id]);
  }

  /// Insert a new recipe into both tables. Uses the recipe's own id.
  Future<void> insertRecipe(Recipe recipe) async {
    final db = await _database;
    final batch = db.batch();
    batch.insert(
      'recipe_summaries',
      _summaryFromRecipe(recipe).toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'recipe_details',
      {'id': recipe.id, 'json': jsonEncode(recipe.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }

  /// Update an existing recipe in both tables.
  Future<void> updateRecipe(Recipe recipe) => insertRecipe(recipe);

  /// Full-text search on title and description (case-insensitive LIKE).
  Future<List<RecipeSummary>> searchRecipes(String query) async {
    if (query.trim().isEmpty) return getRecipeSummaries();
    final db = await _database;
    final pattern = '%${query.trim()}%';
    final rows = await db.query(
      'recipe_summaries',
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: [pattern, pattern],
      orderBy: 'created_at DESC',
    );
    return rows.map(RecipeSummary.fromJson).toList();
  }

  /// Return all full recipe details (used for backup export).
  Future<List<Recipe>> getAllRecipeDetails() async {
    final db = await _database;
    final rows = await db.query('recipe_details');
    return rows.map((row) {
      return Recipe.fromJson(
        jsonDecode(row['json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  /// Bulk upsert from a backup JSON list.
  Future<void> importRecipes(List<Recipe> recipes) async {
    final db = await _database;
    final batch = db.batch();
    for (final recipe in recipes) {
      batch.insert(
        'recipe_summaries',
        _summaryFromRecipe(recipe).toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'recipe_details',
        {'id': recipe.id, 'json': jsonEncode(recipe.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Wipe all cached data (used in tests).
  Future<void> clearAll() async {
    final db = await _database;
    await db.delete('recipe_summaries');
    await db.delete('recipe_details');
  }

  // Build a RecipeSummary from a full Recipe for index storage.
  static RecipeSummary _summaryFromRecipe(Recipe recipe) {
    return RecipeSummary(
      id: recipe.id,
      title: recipe.title,
      description: recipe.description,
      thumbnailUrl: recipe.thumbnailUrl,
      totalTimeMins: recipe.totalTimeMins,
      difficulty: recipe.difficulty,
      sourcePlatform: recipe.videoPlatform,
      recipeSiteName: recipe.recipeSiteName,
      createdAt: recipe.createdAt,
    );
  }
}
