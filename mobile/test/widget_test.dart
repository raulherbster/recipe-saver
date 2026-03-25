import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/screens/home_screen.dart';
import 'package:recipe_saver/services/local_db_service.dart';
import 'package:recipe_saver/models/recipe.dart';

/// Stub local DB that never touches disk.
class StubLocalDbService extends LocalDbService {
  @override
  Future<List<RecipeSummary>> getRecipeSummaries() async => [];

  @override
  Future<void> saveRecipeSummaries(List<RecipeSummary> summaries) async {}

  @override
  Future<void> saveRecipeDetail(Recipe recipe) async {}

  @override
  Future<Recipe?> getRecipeDetail(String id) async => null;

  @override
  Future<void> deleteRecipe(String id) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> insertRecipe(Recipe recipe) async {}

  @override
  Future<void> updateRecipe(Recipe recipe) async {}

  @override
  Future<List<RecipeSummary>> searchRecipes(String query) async => [];
}

Widget _buildApp({Widget home = const HomeScreen()}) {
  return ProviderScope(
    overrides: [
      localDbServiceProvider.overrideWithValue(StubLocalDbService()),
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('Home screen shows correct title', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.text('Recipe Saver'), findsOneWidget);
  });

  testWidgets('Home screen shows Add Recipe FAB', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.text('Add Recipe'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Home screen shows search icon', (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('Home screen shows empty state when no recipes',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();
    expect(find.text('No recipes yet'), findsOneWidget);
    expect(find.text('Tap the button below to add your first recipe'),
        findsOneWidget);
  });
}
