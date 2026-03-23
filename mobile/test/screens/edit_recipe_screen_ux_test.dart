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

/// Pumps the screen with an expanded viewport (800×2000) so that all form
/// fields — including ingredients and instructions below the 7 fixed fields —
/// are on-screen and hittable without scrolling.
Future<void> _pumpScreen(
  WidgetTester tester,
  Recipe recipe,
  ApiService api,
) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildScreen(recipe, api));
  await tester.pumpAndSettle();
}

Future<void> _makeDirtyViaText(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'Changed Title');
  await tester.pumpAndSettle();
}

Future<void> _triggerBack(WidgetTester tester) async {
  final NavigatorState navigator = tester.state(find.byType(Navigator));
  navigator.maybePop();
  await tester.pumpAndSettle();
}

void main() {
  group('EditRecipeScreen — drag-to-reorder', () {
    // Each recipe with N ingredients also has 1 empty instruction row (and vice
    // versa), so the total drag handle count is always N + 1.
    testWidgets('ingredient list renders one drag handle per row', (tester) async {
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour'),
        _makeIngredient('salt'),
      ]);

      await _pumpScreen(tester, recipe, _CapturingApiService());

      // 2 ingredient rows + 1 empty instruction row = 3 drag handles
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    });

    testWidgets('instruction list renders one drag handle per row', (tester) async {
      final recipe =
          _makeRecipe(instructions: ['Preheat oven', 'Mix ingredients']);

      await _pumpScreen(tester, recipe, _CapturingApiService());

      // 1 empty ingredient row + 2 instruction rows = 3 drag handles
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    });

    testWidgets('reordering ingredients reflects new order in save payload',
        (tester) async {
      final api = _CapturingApiService();
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour'),
        _makeIngredient('sugar'),
      ]);

      await _pumpScreen(tester, recipe, api);

      // Ensure the first drag handle is visible before dragging
      final firstHandle = find.byIcon(Icons.drag_handle).first;
      await tester.ensureVisible(firstHandle);
      await tester.pumpAndSettle();

      // Drag flour (index 0) well past sugar (index 1).
      // Use timedDrag so intermediate PointerMove events are generated, which
      // is required for ReorderableListView to recognise the reorder gesture.
      await tester.timedDrag(
        firstHandle,
        const Offset(0, 200),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(api.lastUpdatePayload, isNotNull);
      final ingredients =
          api.lastUpdatePayload!['ingredients'] as List<dynamic>;
      expect(ingredients.length, 2);
      // flour was dragged below sugar — order should now be [sugar, flour]
      expect((ingredients[0] as Map)['name'], 'sugar');
      expect((ingredients[1] as Map)['name'], 'flour');
    });

    testWidgets('reordering instructions reflects new order in save payload',
        (tester) async {
      final api = _CapturingApiService();
      final recipe = _makeRecipe(instructions: ['preheat', 'mix']);

      await _pumpScreen(tester, recipe, api);

      // The instruction drag handles come after the ingredient drag handle.
      // find.byIcon(Icons.drag_handle).at(1) is the first instruction handle.
      final firstInstructionHandle = find.byIcon(Icons.drag_handle).at(1);
      await tester.ensureVisible(firstInstructionHandle);
      await tester.pumpAndSettle();

      await tester.timedDrag(
        firstInstructionHandle,
        const Offset(0, 200),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      final saveBtn = find.byIcon(Icons.save);
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(api.lastUpdatePayload, isNotNull);
      final instructions =
          api.lastUpdatePayload!['instructions'] as List<dynamic>;
      expect(instructions.length, 2);
      // 'preheat' dragged below 'mix' — order should now be [mix, preheat]
      expect(instructions[0], 'mix');
      expect(instructions[1], 'preheat');
    });

    testWidgets('reordering marks form dirty', (tester) async {
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour'),
        _makeIngredient('sugar'),
      ]);

      await _pumpScreen(tester, recipe, _CapturingApiService());

      final firstHandle = find.byIcon(Icons.drag_handle).first;
      await tester.ensureVisible(firstHandle);
      await tester.pumpAndSettle();

      await tester.timedDrag(
        firstHandle,
        const Offset(0, 200),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      await _triggerBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  group('EditRecipeScreen — add and delete', () {
    testWidgets('add ingredient button appends a new row', (tester) async {
      final recipe = _makeRecipe(ingredients: [_makeIngredient('flour')]);

      await _pumpScreen(tester, recipe, _CapturingApiService());

      final countBefore =
          tester.widgetList(find.byIcon(Icons.delete)).length;

      final addIngredient = find.text('Add ingredient');
      await tester.ensureVisible(addIngredient);
      await tester.tap(addIngredient);
      await tester.pumpAndSettle();

      expect(
        tester.widgetList(find.byIcon(Icons.delete)).length,
        countBefore + 1,
      );
    });

    testWidgets('adding an ingredient marks form dirty', (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingApiService());

      final addIngredient = find.text('Add ingredient');
      await tester.ensureVisible(addIngredient);
      await tester.tap(addIngredient);
      await tester.pumpAndSettle();

      await _triggerBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('delete button removes ingredient row', (tester) async {
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour'),
        _makeIngredient('salt'),
      ]);

      await _pumpScreen(tester, recipe, _CapturingApiService());

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

    testWidgets('deleting an ingredient marks form dirty', (tester) async {
      final recipe = _makeRecipe(
        ingredients: [_makeIngredient('flour'), _makeIngredient('salt')],
      );

      await _pumpScreen(tester, recipe, _CapturingApiService());

      final firstDelete = find.byIcon(Icons.delete).first;
      await tester.ensureVisible(firstDelete);
      await tester.tap(firstDelete);
      await tester.pumpAndSettle();

      await _triggerBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('add step button appends a new instruction row', (tester) async {
      final recipe = _makeRecipe(instructions: ['Preheat oven']);

      await _pumpScreen(tester, recipe, _CapturingApiService());

      final deletesBefore =
          tester.widgetList(find.byIcon(Icons.delete)).length;

      final addStep = find.text('Add step');
      await tester.ensureVisible(addStep);
      await tester.tap(addStep);
      await tester.pumpAndSettle();

      expect(
        tester.widgetList(find.byIcon(Icons.delete)).length,
        deletesBefore + 1,
      );
    });

    testWidgets('adding a step marks form dirty', (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingApiService());

      final addStep = find.text('Add step');
      await tester.ensureVisible(addStep);
      await tester.tap(addStep);
      await tester.pumpAndSettle();

      await _triggerBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  group('EditRecipeScreen — unsaved changes dialog', () {
    testWidgets('back button shows discard dialog when dirty', (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingApiService());

      await _makeDirtyViaText(tester);
      await _triggerBack(tester);

      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('discard dialog — Cancel keeps user on screen', (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingApiService());

      await _makeDirtyViaText(tester);
      await _triggerBack(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Recipe'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('discard dialog — Discard pops the screen', (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingApiService());

      await _makeDirtyViaText(tester);
      await _triggerBack(tester);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Recipe'), findsNothing);
    });

    testWidgets('discard dialog — barrier tap keeps user on screen',
        (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingApiService());

      await _makeDirtyViaText(tester);
      await _triggerBack(tester);

      // Tap outside the dialog (top-left corner of the screen)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Barrier dismiss returns null → treated as false → screen stays
      expect(find.text('Edit Recipe'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('no dialog when screen is clean', (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingApiService());

      await _triggerBack(tester);

      expect(find.text('Discard changes?'), findsNothing);
    });
  });
}
