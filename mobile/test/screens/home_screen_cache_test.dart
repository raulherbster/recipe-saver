/// E2E widget tests for the SQLite caching layer on the HomeScreen.
///
/// These tests exercise the full widget → provider → LocalDbService chain
/// using mocktail mocks so that all interactions with the local database are
/// observable without touching disk.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:recipe_saver/models/recipe.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/screens/home_screen.dart';
import 'package:recipe_saver/services/api_service.dart';
import 'package:recipe_saver/services/local_db_service.dart';

class _MockApiService extends Mock implements ApiService {}

class _MockLocalDbService extends Mock implements LocalDbService {}

// ─── Helpers ────────────────────────────────────────────────────────────────

RecipeSummary _summary({String id = '1', String title = 'Test Recipe'}) =>
    RecipeSummary(id: id, title: title, createdAt: DateTime(2024, 6, 1));

PaginatedRecipes _page(List<RecipeSummary> recipes) => PaginatedRecipes(
      recipes: recipes,
      total: recipes.length,
      page: 1,
      pageSize: 20,
      totalPages: 1,
    );

// ─── Test suite ─────────────────────────────────────────────────────────────

void main() {
  late _MockApiService mockApi;
  late _MockLocalDbService mockDb;

  setUp(() {
    mockApi = _MockApiService();
    mockDb = _MockLocalDbService();
  });

  /// Builds the HomeScreen with both services replaced by mocks.
  Widget buildApp() => ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(mockApi),
          localDbServiceProvider.overrideWithValue(mockDb),
        ],
        child: const MaterialApp(home: HomeScreen()),
      );

  group('HomeScreen SQLite cache – E2E', () {
    // ── ADD ─────────────────────────────────────────────────────────────────
    testWidgets(
      'adding a recipe: API response is shown in the UI and persisted to the local cache',
      (tester) async {
        // The API returns one recipe; the local DB starts empty.
        final recipe =
            _summary(id: '42', title: 'Brown Butter Banana Bread');

        when(() => mockDb.getRecipeSummaries()).thenAnswer((_) async => []);
        when(() => mockDb.saveRecipeSummaries(any()))
            .thenAnswer((_) async {});
        when(() => mockApi.getRecipes(page: 1, pageSize: 20))
            .thenAnswer((_) async => _page([recipe]));

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // ── Assert: recipe is visible in the UI
        expect(
          find.text('Brown Butter Banana Bread'),
          findsOneWidget,
          reason: 'recipe returned by the API should appear in the list',
        );

        // ── Assert: recipe was persisted to SQLite
        final calls =
            verify(() => mockDb.saveRecipeSummaries(captureAny())).captured;
        final savedList = calls.last as List<RecipeSummary>;
        expect(
          savedList.any((r) => r.id == '42'),
          isTrue,
          reason:
              'saveRecipeSummaries must be called with the newly added recipe '
              'so it is available offline on the next launch',
        );
      },
    );

    // ── REMOVE ───────────────────────────────────────────────────────────────
    testWidgets(
      'removing a recipe: it disappears from the UI and is deleted from the local cache',
      (tester) async {
        // The API returns one recipe.
        final recipe = _summary(id: '1', title: 'Pasta Carbonara');

        when(() => mockDb.getRecipeSummaries()).thenAnswer((_) async => []);
        when(() => mockDb.saveRecipeSummaries(any()))
            .thenAnswer((_) async {});
        when(() => mockDb.deleteRecipe(any())).thenAnswer((_) async {});
        when(() => mockApi.getRecipes(page: 1, pageSize: 20))
            .thenAnswer((_) async => _page([recipe]));
        when(() => mockApi.deleteRecipe('1')).thenAnswer((_) async {});

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Verify the recipe is on screen before deleting.
        expect(find.text('Pasta Carbonara'), findsOneWidget);

        // Swipe the card to the left to trigger the dismiss gesture
        // (endToStart direction; −500 px is well past the 40 % threshold).
        await tester.drag(
          find.byType(Dismissible).first,
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        // The confirmation dialog must appear.
        expect(
          find.text('Delete Recipe'),
          findsOneWidget,
          reason: 'swipe should open the delete-confirmation dialog',
        );

        // Tap the red "Delete" button to confirm.
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        // ── Assert: recipe is gone from the UI
        expect(
          find.text('Pasta Carbonara'),
          findsNothing,
          reason: 'deleted recipe should be removed from the list',
        );

        // ── Assert: recipe was deleted from SQLite
        verify(() => mockDb.deleteRecipe('1')).called(1);
      },
    );
  });
}
