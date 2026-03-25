import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recipe_saver/models/recipe.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/screens/edit_recipe_screen.dart';
import 'package:recipe_saver/services/local_db_service.dart';

/// Captures the last Recipe passed to updateRecipe for assertion.
class _CapturingLocalDbService extends LocalDbService {
  Recipe? lastSaved;

  @override
  Future<void> updateRecipe(Recipe recipe) async {
    lastSaved = recipe;
  }

  @override
  Future<List<RecipeSummary>> getRecipeSummaries() async => [];

  @override
  Future<Recipe?> getRecipeDetail(String id) async => null;

  @override
  Future<void> insertRecipe(Recipe recipe) async {}

  @override
  Future<void> deleteRecipe(String id) async {}

  @override
  Future<void> clearAll() async {}
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

Widget _buildScreen(Recipe recipe, _CapturingLocalDbService db) {
  return ProviderScope(
    overrides: [localDbServiceProvider.overrideWithValue(db)],
    child: MaterialApp(home: EditRecipeScreen(recipe: recipe)),
  );
}

/// Pumps the screen with an expanded viewport (800×2000) so that all form
/// fields — including ingredients and instructions below the 7 fixed fields —
/// are on-screen and hittable without scrolling.
Future<void> _pumpScreen(
  WidgetTester tester,
  Recipe recipe,
  _CapturingLocalDbService db,
) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildScreen(recipe, db));
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
    testWidgets('ingredient list renders one drag handle per row', (tester) async {
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour'),
        _makeIngredient('salt'),
      ]);

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

      // 2 ingredient rows + 1 empty instruction row = 3 drag handles
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    });

    testWidgets('instruction list renders one drag handle per row', (tester) async {
      final recipe =
          _makeRecipe(instructions: ['Preheat oven', 'Mix ingredients']);

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

      // 1 empty ingredient row + 2 instruction rows = 3 drag handles
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    });

    testWidgets('reordering ingredients reflects new order in save payload',
        (tester) async {
      final db = _CapturingLocalDbService();
      final recipe = _makeRecipe(ingredients: [
        _makeIngredient('flour'),
        _makeIngredient('sugar'),
      ]);

      await _pumpScreen(tester, recipe, db);

      final firstHandle = find.byIcon(Icons.drag_handle).first;
      await tester.ensureVisible(firstHandle);
      await tester.pumpAndSettle();

      await tester.timedDrag(
        firstHandle,
        const Offset(0, 200),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(db.lastSaved, isNotNull);
      final ingredients = db.lastSaved!.ingredients;
      expect(ingredients.length, 2);
      // flour was dragged below sugar — order should now be [sugar, flour]
      expect(ingredients[0].name, 'sugar');
      expect(ingredients[1].name, 'flour');
    });

    testWidgets('reordering instructions reflects new order in save payload',
        (tester) async {
      final db = _CapturingLocalDbService();
      final recipe = _makeRecipe(instructions: ['preheat', 'mix']);

      await _pumpScreen(tester, recipe, db);

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

      expect(db.lastSaved, isNotNull);
      final instructions = db.lastSaved!.instructions!;
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

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

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

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

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

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

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

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

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

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

      final firstDelete = find.byIcon(Icons.delete).first;
      await tester.ensureVisible(firstDelete);
      await tester.tap(firstDelete);
      await tester.pumpAndSettle();

      await _triggerBack(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('add step button appends a new instruction row', (tester) async {
      final recipe = _makeRecipe(instructions: ['Preheat oven']);

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

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

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

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

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

      await _makeDirtyViaText(tester);
      await _triggerBack(tester);

      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('discard dialog — Cancel keeps user on screen', (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

      await _makeDirtyViaText(tester);
      await _triggerBack(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Recipe'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('discard dialog — Discard pops the screen', (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

      await _makeDirtyViaText(tester);
      await _triggerBack(tester);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Recipe'), findsNothing);
    });

    testWidgets('discard dialog — barrier tap keeps user on screen',
        (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

      await _makeDirtyViaText(tester);
      await _triggerBack(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Edit Recipe'), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('no dialog when screen is clean', (tester) async {
      final recipe = _makeRecipe();

      await _pumpScreen(tester, recipe, _CapturingLocalDbService());

      await _triggerBack(tester);

      expect(find.text('Discard changes?'), findsNothing);
    });
  });
}
