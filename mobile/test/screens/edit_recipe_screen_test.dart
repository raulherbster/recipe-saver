import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recipe_saver/models/recipe.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/screens/edit_recipe_screen.dart';
import 'package:recipe_saver/services/api_service.dart';

/// Captures the last payload passed to updateRecipe for assertion.
class _CapturingApiService extends ApiService {
  Map<String, dynamic>? lastUpdatePayload;

  _CapturingApiService() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<Recipe> updateRecipe(String id, Map<String, dynamic> updates) async {
    lastUpdatePayload = updates;
    return Recipe(
      id: id,
      title: updates['title'] ?? 'Updated',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

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
  group('EditRecipeScreen', () {
    testWidgets('sends ingredients as objects with name and raw_text',
        (WidgetTester tester) async {
      final api = _CapturingApiService();
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour', quantity: '2', unit: 'cups'),
        _makeIngredient('salt', quantity: '1', unit: 'tsp'),
      ]);

      await tester.pumpWidget(ProviderScope(
        overrides: [apiServiceProvider.overrideWithValue(api)],
        child: MaterialApp(home: EditRecipeScreen(recipe: recipe)),
      ));
      await tester.pumpAndSettle();

      // Tap the save button in the AppBar
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(api.lastUpdatePayload, isNotNull);
      final ingredients =
          api.lastUpdatePayload!['ingredients'] as List<dynamic>;

      // Each ingredient must be a map — not a plain string
      for (final item in ingredients) {
        expect(item, isA<Map<String, dynamic>>(),
            reason: 'ingredient must be an object, not a String');
        expect((item as Map<String, dynamic>).containsKey('name'), isTrue);
        expect(item.containsKey('raw_text'), isTrue);
        expect(item['name'], isA<String>());
        expect(item['raw_text'], isA<String>());
      }

      expect(ingredients.length, 2);
    });

    testWidgets('ingredient object name matches display text',
        (WidgetTester tester) async {
      final api = _CapturingApiService();
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour', quantity: '2', unit: 'cups'),
      ]);

      await tester.pumpWidget(ProviderScope(
        overrides: [apiServiceProvider.overrideWithValue(api)],
        child: MaterialApp(home: EditRecipeScreen(recipe: recipe)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      final ingredients =
          api.lastUpdatePayload!['ingredients'] as List<dynamic>;
      final first = ingredients.first as Map<String, dynamic>;

      // The display text is "2 cups flour" — name and raw_text should match
      expect(first['name'], '2 cups flour');
      expect(first['raw_text'], '2 cups flour');
    });

    testWidgets('pre-fills ingredient text fields from recipe',
        (WidgetTester tester) async {
      final api = _CapturingApiService();
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('butter', quantity: '100', unit: 'g'),
      ]);

      await tester.pumpWidget(ProviderScope(
        overrides: [apiServiceProvider.overrideWithValue(api)],
        child: MaterialApp(home: EditRecipeScreen(recipe: recipe)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('100 g butter'), findsOneWidget);
    });
  });
}
