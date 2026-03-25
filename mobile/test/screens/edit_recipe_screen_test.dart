import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:recipe_saver/models/recipe.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/screens/edit_recipe_screen.dart';
import 'package:recipe_saver/services/local_db_service.dart';

class _MockLocalDbService extends Mock implements LocalDbService {}

class _FakeRecipe extends Fake implements Recipe {}

Recipe _makeRecipe({List<Ingredient> ingredients = const []}) {
  return Recipe(
    id: 'test-id',
    title: 'Test Recipe',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    ingredients: ingredients,
    instructions: const [],
  );
}

Ingredient _makeIngredient(String name, {String? quantity, String? unit}) {
  return Ingredient(
    id: 'ing-$name',
    name: name,
    quantity: quantity,
    unit: unit,
  );
}

void main() {
  late _MockLocalDbService mockDb;

  setUpAll(() {
    registerFallbackValue(_FakeRecipe());
  });

  setUp(() {
    mockDb = _MockLocalDbService();
    when(() => mockDb.updateRecipe(any())).thenAnswer((_) async {});
  });

  Widget _buildScreen(Recipe recipe) => ProviderScope(
        overrides: [
          localDbServiceProvider.overrideWithValue(mockDb),
        ],
        child: MaterialApp(home: EditRecipeScreen(recipe: recipe)),
      );

  group('EditRecipeScreen', () {
    testWidgets('saves ingredients as Ingredient objects with name',
        (WidgetTester tester) async {
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour', quantity: '2', unit: 'cups'),
        _makeIngredient('salt', quantity: '1', unit: 'tsp'),
      ]);

      await tester.pumpWidget(_buildScreen(recipe));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      final captured = verify(() => mockDb.updateRecipe(captureAny()))
          .captured
          .single as Recipe;

      expect(captured.ingredients.length, 2);
      for (final ing in captured.ingredients) {
        expect(ing.name, isNotEmpty,
            reason: 'ingredient must have a non-empty name');
      }
    });

    testWidgets('ingredient name matches display text',
        (WidgetTester tester) async {
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour', quantity: '2', unit: 'cups'),
      ]);

      await tester.pumpWidget(_buildScreen(recipe));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      final captured = verify(() => mockDb.updateRecipe(captureAny()))
          .captured
          .single as Recipe;

      // Display text is "2 cups flour" — name should match
      expect(captured.ingredients.first.name, '2 cups flour');
    });

    testWidgets('pre-fills ingredient text fields from recipe',
        (WidgetTester tester) async {
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('butter', quantity: '100', unit: 'g'),
      ]);

      await tester.pumpWidget(_buildScreen(recipe));
      await tester.pumpAndSettle();

      expect(find.text('100 g butter'), findsOneWidget);
    });
  });
}
