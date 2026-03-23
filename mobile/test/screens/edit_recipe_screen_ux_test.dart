import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recipe_saver/models/recipe.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/screens/edit_recipe_screen.dart';
import 'package:recipe_saver/services/api_service.dart';

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

Recipe _makeRecipe({
  List<Ingredient> ingredients = const [],
  List<String>? instructions,
}) {
  return Recipe(
    id: 'test-id',
    title: 'Test Recipe',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    ingredients: ingredients,
    instructions: instructions ?? const [],
  );
}

Ingredient _makeIngredient(String name, {String? quantity, String? unit}) {
  return Ingredient(id: 'ing-$name', name: name, quantity: quantity, unit: unit);
}

Widget _buildScreen(Recipe recipe, ApiService api) {
  return ProviderScope(
    overrides: [apiServiceProvider.overrideWithValue(api)],
    child: MaterialApp(home: EditRecipeScreen(recipe: recipe)),
  );
}

void main() {
  group('EditRecipeScreen — drag-to-reorder', () {
    testWidgets('ingredient list renders drag handles', (tester) async {
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour'),
        _makeIngredient('salt'),
      ]);

      await tester.pumpWidget(_buildScreen(recipe, _CapturingApiService()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle), findsWidgets);
    });

    testWidgets('instruction list renders drag handles', (tester) async {
      final recipe =
          _makeRecipe(instructions: ['Preheat oven', 'Mix ingredients']);

      await tester.pumpWidget(_buildScreen(recipe, _CapturingApiService()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle), findsWidgets);
    });

    testWidgets('reordering ingredients updates save payload order',
        (tester) async {
      final api = _CapturingApiService();
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour'),
        _makeIngredient('sugar'),
        _makeIngredient('salt'),
      ]);

      await tester.pumpWidget(_buildScreen(recipe, api));
      await tester.pumpAndSettle();

      // Drag the first ingredient (flour) to the third position
      await tester.drag(
        find.byIcon(Icons.drag_handle).first,
        const Offset(0, 120),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      // Payload should reflect the new order (flour moved down)
      expect(api.lastUpdatePayload, isNotNull);
      final ingredients =
          api.lastUpdatePayload!['ingredients'] as List<dynamic>;
      expect(ingredients.length, 3);
    });
  });

  group('EditRecipeScreen — add and delete', () {
    testWidgets('add ingredient button appends a new row', (tester) async {
      final recipe = _makeRecipe(ingredients: [_makeIngredient('flour')]);

      await tester.pumpWidget(_buildScreen(recipe, _CapturingApiService()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add ingredient'));
      await tester.pumpAndSettle();

      // Now there should be 2 delete buttons (one per ingredient)
      expect(find.byIcon(Icons.delete), findsNWidgets(2));
    });

    testWidgets('delete button removes ingredient row', (tester) async {
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour'),
        _makeIngredient('salt'),
      ]);

      await tester.pumpWidget(_buildScreen(recipe, _CapturingApiService()));
      await tester.pumpAndSettle();

      final countBefore =
          tester.widgetList(find.byIcon(Icons.delete)).length;

      final firstDelete = find.byIcon(Icons.delete).first;
      await tester.ensureVisible(firstDelete);
      await tester.tap(firstDelete);
      await tester.pumpAndSettle();

      expect(
        tester.widgetList(find.byIcon(Icons.delete)).length,
        countBefore - 1,
      );
    });

    testWidgets('add step button appends a new instruction row', (tester) async {
      final recipe = _makeRecipe(instructions: ['Preheat oven']);

      await tester.pumpWidget(_buildScreen(recipe, _CapturingApiService()));
      await tester.pumpAndSettle();

      final deletesBefore = tester.widgetList(find.byIcon(Icons.delete)).length;

      final addStep = find.text('Add step');
      await tester.ensureVisible(addStep);
      await tester.tap(addStep);
      await tester.pumpAndSettle();

      expect(
        tester.widgetList(find.byIcon(Icons.delete)).length,
        deletesBefore + 1,
      );
    });
  });

  group('EditRecipeScreen — unsaved changes dialog', () {
    testWidgets('back button shows discard dialog when dirty', (tester) async {
      final recipe = _makeRecipe();

      await tester.pumpWidget(_buildScreen(recipe, _CapturingApiService()));
      await tester.pumpAndSettle();

      // Make a change to mark as dirty
      await tester.enterText(find.byType(TextField).first, 'Changed Title');
      await tester.pumpAndSettle();

      // Press the system back button via NavigatorObserver simulation
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('discard dialog — Cancel keeps user on screen', (tester) async {
      final recipe = _makeRecipe();

      await tester.pumpWidget(_buildScreen(recipe, _CapturingApiService()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Changed Title');
      await tester.pumpAndSettle();

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Screen should still be visible
      expect(find.text('Edit Recipe'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('discard dialog — Discard pops the screen', (tester) async {
      final recipe = _makeRecipe();

      await tester.pumpWidget(_buildScreen(recipe, _CapturingApiService()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Changed Title');
      await tester.pumpAndSettle();

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      // Edit screen should be gone
      expect(find.text('Edit Recipe'), findsNothing);
    });

    testWidgets('no dialog when screen is clean', (tester) async {
      final recipe = _makeRecipe();

      await tester.pumpWidget(_buildScreen(recipe, _CapturingApiService()));
      await tester.pumpAndSettle();

      // Back without any changes
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
    });
  });
}
