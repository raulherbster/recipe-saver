/// Widget tests for the HomeScreen with a mocked local database.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:recipe_saver/models/recipe.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/screens/home_screen.dart';
import 'package:recipe_saver/services/local_db_service.dart';

class _MockLocalDbService extends Mock implements LocalDbService {}

RecipeSummary _summary({String id = '1', String title = 'Test Recipe'}) =>
    RecipeSummary(id: id, title: title, createdAt: DateTime(2024, 6, 1));

void main() {
  late _MockLocalDbService mockDb;

  setUp(() {
    mockDb = _MockLocalDbService();
    when(() => mockDb.deleteRecipe(any())).thenAnswer((_) async {});
  });

  Widget buildApp() => ProviderScope(
        overrides: [
          localDbServiceProvider.overrideWithValue(mockDb),
        ],
        child: const MaterialApp(home: HomeScreen()),
      );

  group('HomeScreen — local DB', () {
    testWidgets(
      'recipes from the local DB are shown in the UI',
      (tester) async {
        when(() => mockDb.getRecipeSummaries())
            .thenAnswer((_) async => [_summary(id: '42', title: 'Brown Butter Banana Bread')]);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text('Brown Butter Banana Bread'), findsOneWidget);
      },
    );

    testWidgets(
      'removing a recipe: it disappears from the UI and is deleted from the local DB',
      (tester) async {
        when(() => mockDb.getRecipeSummaries())
            .thenAnswer((_) async => [_summary(id: '1', title: 'Pasta Carbonara')]);

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        expect(find.text('Pasta Carbonara'), findsOneWidget);

        await tester.drag(
          find.byType(Dismissible).first,
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        expect(find.text('Delete Recipe'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Pasta Carbonara'), findsNothing);
        verify(() => mockDb.deleteRecipe('1')).called(1);
      },
    );
  });
}
