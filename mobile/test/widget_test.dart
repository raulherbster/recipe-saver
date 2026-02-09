import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/screens/home_screen.dart';
import 'package:recipe_saver/services/api_service.dart';
import 'package:recipe_saver/models/recipe.dart';

/// Mock API service that returns empty/mock data
class MockApiService extends ApiService {
  MockApiService() : super(baseUrl: 'http://localhost:8000');

  @override
  Future<PaginatedRecipes> getRecipes({int page = 1, int pageSize = 20}) async {
    return PaginatedRecipes(
      recipes: [],
      total: 0,
      page: 1,
      pageSize: 20,
      totalPages: 0,
    );
  }

  @override
  Future<void> deleteRecipe(String id) async {
    // No-op for testing
  }
}

void main() {
  testWidgets('Home screen shows correct title', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(MockApiService()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    // Wait for async operations to complete
    await tester.pumpAndSettle();

    expect(find.text('Recipe Saver'), findsOneWidget);
  });

  testWidgets('Home screen shows Add Recipe FAB', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(MockApiService()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Add Recipe'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Home screen shows search icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(MockApiService()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('Home screen shows empty state when no recipes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(MockApiService()),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No recipes yet'), findsOneWidget);
    expect(find.text('Tap the button below to add your first recipe'),
        findsOneWidget);
  });
}
