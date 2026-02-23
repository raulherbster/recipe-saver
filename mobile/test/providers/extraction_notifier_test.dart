import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recipe_saver/providers/providers.dart';
import 'package:recipe_saver/services/api_service.dart';
import 'package:recipe_saver/models/recipe.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late ExtractionNotifier notifier;

  setUp(() {
    mockApiService = MockApiService();
    notifier = ExtractionNotifier(mockApiService);
  });

  group('ExtractionNotifier', () {
    test('initial state is not extracting', () {
      expect(notifier.state.isExtracting, false);
      expect(notifier.state.response, isNull);
      expect(notifier.state.error, isNull);
    });

    group('extractRecipe', () {
      test('successful extraction sets response', () async {
        final recipe = Recipe(
          id: 'recipe-1',
          title: 'Extracted Recipe',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(() => mockApiService.extractRecipe(
              url: 'https://youtube.com/watch?v=123',
              manualCaption: null,
              manualRecipeUrl: null,
            )).thenAnswer(
          (_) async => ExtractionResponse(
            success: true,
            method: 'youtube',
            confidence: 0.95,
            recipe: recipe,
            message: 'Recipe extracted successfully',
          ),
        );

        await notifier.extractRecipe(url: 'https://youtube.com/watch?v=123');

        expect(notifier.state.isExtracting, false);
        expect(notifier.state.response, isNotNull);
        expect(notifier.state.response!.success, true);
        expect(notifier.state.response!.recipe!.title, 'Extracted Recipe');
        expect(notifier.state.error, isNull);
      });

      test('sets loading state during extraction', () async {
        when(() => mockApiService.extractRecipe(
              url: any(named: 'url'),
              manualCaption: any(named: 'manualCaption'),
              manualRecipeUrl: any(named: 'manualRecipeUrl'),
            )).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return ExtractionResponse(
            success: true,
            method: 'youtube',
            confidence: 0.9,
            message: 'Done',
          );
        });

        final future = notifier.extractRecipe(url: 'https://youtube.com/watch?v=123');

        expect(notifier.state.isExtracting, true);

        await future;

        expect(notifier.state.isExtracting, false);
      });

      test('passes manual caption for Instagram', () async {
        when(() => mockApiService.extractRecipe(
              url: 'https://instagram.com/p/123',
              manualCaption: 'Recipe instructions here',
              manualRecipeUrl: null,
            )).thenAnswer(
          (_) async => ExtractionResponse(
            success: true,
            method: 'instagram',
            confidence: 0.8,
            message: 'Extracted from caption',
          ),
        );

        await notifier.extractRecipe(
          url: 'https://instagram.com/p/123',
          manualCaption: 'Recipe instructions here',
        );

        verify(() => mockApiService.extractRecipe(
              url: 'https://instagram.com/p/123',
              manualCaption: 'Recipe instructions here',
              manualRecipeUrl: null,
            )).called(1);
      });

      test('passes manual recipe URL', () async {
        when(() => mockApiService.extractRecipe(
              url: 'https://youtube.com/watch?v=123',
              manualCaption: null,
              manualRecipeUrl: 'https://example.com/recipe',
            )).thenAnswer(
          (_) async => ExtractionResponse(
            success: true,
            method: 'recipe_site',
            confidence: 0.95,
            message: 'Extracted from recipe site',
          ),
        );

        await notifier.extractRecipe(
          url: 'https://youtube.com/watch?v=123',
          manualRecipeUrl: 'https://example.com/recipe',
        );

        verify(() => mockApiService.extractRecipe(
              url: 'https://youtube.com/watch?v=123',
              manualCaption: null,
              manualRecipeUrl: 'https://example.com/recipe',
            )).called(1);
      });

      test('sets error from failed extraction response', () async {
        when(() => mockApiService.extractRecipe(
              url: any(named: 'url'),
              manualCaption: any(named: 'manualCaption'),
              manualRecipeUrl: any(named: 'manualRecipeUrl'),
            )).thenAnswer(
          (_) async => ExtractionResponse(
            success: false,
            method: 'unknown',
            confidence: 0.0,
            error: 'Could not extract recipe from video',
            message: 'Extraction failed',
          ),
        );

        await notifier.extractRecipe(url: 'https://youtube.com/watch?v=invalid');

        expect(notifier.state.isExtracting, false);
        expect(notifier.state.response, isNotNull);
        expect(notifier.state.response!.success, false);
        expect(notifier.state.error, 'Could not extract recipe from video');
      });

      test('sets error on exception', () async {
        when(() => mockApiService.extractRecipe(
              url: any(named: 'url'),
              manualCaption: any(named: 'manualCaption'),
              manualRecipeUrl: any(named: 'manualRecipeUrl'),
            )).thenThrow(Exception('Network error'));

        await notifier.extractRecipe(url: 'https://youtube.com/watch?v=123');

        expect(notifier.state.isExtracting, false);
        expect(notifier.state.error, contains('Network error'));
      });
    });

    group('reset', () {
      test('clears state to initial values', () async {
        when(() => mockApiService.extractRecipe(
              url: any(named: 'url'),
              manualCaption: any(named: 'manualCaption'),
              manualRecipeUrl: any(named: 'manualRecipeUrl'),
            )).thenAnswer(
          (_) async => ExtractionResponse(
            success: true,
            method: 'youtube',
            confidence: 0.9,
            message: 'Done',
          ),
        );

        await notifier.extractRecipe(url: 'https://youtube.com/watch?v=123');
        expect(notifier.state.response, isNotNull);

        notifier.reset();

        expect(notifier.state.isExtracting, false);
        expect(notifier.state.response, isNull);
        expect(notifier.state.error, isNull);
      });
    });
  });
}
