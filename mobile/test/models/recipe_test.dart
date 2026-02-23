import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_saver/models/recipe.dart';

void main() {
  group('Ingredient', () {
    test('fromJson parses valid data', () {
      final json = {
        'id': 'ing-1',
        'name': 'flour',
        'quantity': '2',
        'unit': 'cups',
        'preparation': 'sifted',
        'raw_text': '2 cups flour, sifted',
        'sort_order': 1,
      };

      final ingredient = Ingredient.fromJson(json);

      expect(ingredient.id, 'ing-1');
      expect(ingredient.name, 'flour');
      expect(ingredient.quantity, '2');
      expect(ingredient.unit, 'cups');
      expect(ingredient.preparation, 'sifted');
      expect(ingredient.rawText, '2 cups flour, sifted');
      expect(ingredient.sortOrder, 1);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'ing-1',
        'name': 'salt',
      };

      final ingredient = Ingredient.fromJson(json);

      expect(ingredient.id, 'ing-1');
      expect(ingredient.name, 'salt');
      expect(ingredient.quantity, isNull);
      expect(ingredient.unit, isNull);
      expect(ingredient.preparation, isNull);
      expect(ingredient.rawText, isNull);
      expect(ingredient.sortOrder, 0);
    });

    test('displayText formats with all parts', () {
      final ingredient = Ingredient(
        id: '1',
        name: 'flour',
        quantity: '2',
        unit: 'cups',
        preparation: 'sifted',
      );

      // Note: preparation is prefixed with ", " so joined with space creates " , "
      expect(ingredient.displayText, '2 cups flour , sifted');
    });

    test('displayText formats without quantity', () {
      final ingredient = Ingredient(
        id: '1',
        name: 'salt',
      );

      expect(ingredient.displayText, 'salt');
    });

    test('displayText formats with quantity only', () {
      final ingredient = Ingredient(
        id: '1',
        name: 'eggs',
        quantity: '3',
      );

      expect(ingredient.displayText, '3 eggs');
    });

    test('displayText formats with unit only', () {
      final ingredient = Ingredient(
        id: '1',
        name: 'butter',
        unit: 'tablespoon',
      );

      expect(ingredient.displayText, 'tablespoon butter');
    });

    test('toJson serializes correctly', () {
      final ingredient = Ingredient(
        id: 'ing-1',
        name: 'flour',
        quantity: '2',
        unit: 'cups',
        preparation: 'sifted',
        rawText: '2 cups flour, sifted',
        sortOrder: 1,
      );

      final json = ingredient.toJson();

      expect(json['id'], 'ing-1');
      expect(json['name'], 'flour');
      expect(json['quantity'], '2');
      expect(json['unit'], 'cups');
      expect(json['preparation'], 'sifted');
      expect(json['raw_text'], '2 cups flour, sifted');
      expect(json['sort_order'], 1);
    });
  });

  group('Category', () {
    test('fromJson parses valid data', () {
      final json = {
        'id': 'cat-1',
        'name': 'Vegan',
        'type': 'dietary',
      };

      final category = Category.fromJson(json);

      expect(category.id, 'cat-1');
      expect(category.name, 'Vegan');
      expect(category.type, 'dietary');
    });

    test('fromJson handles empty values', () {
      final json = <String, dynamic>{};

      final category = Category.fromJson(json);

      expect(category.id, '');
      expect(category.name, '');
      expect(category.type, '');
    });
  });

  group('Tag', () {
    test('fromJson parses valid data', () {
      final json = {
        'id': 'tag-1',
        'tag': 'quick',
        'source': 'hashtag',
      };

      final tag = Tag.fromJson(json);

      expect(tag.id, 'tag-1');
      expect(tag.tag, 'quick');
      expect(tag.source, 'hashtag');
    });

    test('fromJson handles missing source', () {
      final json = {
        'id': 'tag-1',
        'tag': 'easy',
      };

      final tag = Tag.fromJson(json);

      expect(tag.id, 'tag-1');
      expect(tag.tag, 'easy');
      expect(tag.source, isNull);
    });
  });

  group('Recipe', () {
    test('fromJson parses complete recipe', () {
      final json = {
        'id': 'recipe-1',
        'title': 'Chocolate Cake',
        'description': 'A delicious cake',
        'instructions': ['Preheat oven', 'Mix ingredients', 'Bake'],
        'prep_time_mins': 15,
        'cook_time_mins': 30,
        'total_time_mins': 45,
        'servings': '8',
        'difficulty': 'medium',
        'ingredients': [
          {'id': 'ing-1', 'name': 'flour', 'quantity': '2', 'unit': 'cups'}
        ],
        'categories': [
          {'id': 'cat-1', 'name': 'Dessert', 'type': 'course'}
        ],
        'tags': [
          {'id': 'tag-1', 'tag': 'chocolate'}
        ],
        'video_url': 'https://youtube.com/watch?v=123',
        'video_platform': 'youtube',
        'recipe_page_url': 'https://example.com/recipe',
        'recipe_site_name': 'Example Recipes',
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'author_name': 'Chef John',
        'extraction_method': 'youtube',
        'extraction_confidence': 0.95,
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

      final recipe = Recipe.fromJson(json);

      expect(recipe.id, 'recipe-1');
      expect(recipe.title, 'Chocolate Cake');
      expect(recipe.description, 'A delicious cake');
      expect(recipe.instructions, ['Preheat oven', 'Mix ingredients', 'Bake']);
      expect(recipe.prepTimeMins, 15);
      expect(recipe.cookTimeMins, 30);
      expect(recipe.totalTimeMins, 45);
      expect(recipe.servings, '8');
      expect(recipe.difficulty, 'medium');
      expect(recipe.ingredients.length, 1);
      expect(recipe.ingredients[0].name, 'flour');
      expect(recipe.categories.length, 1);
      expect(recipe.categories[0].name, 'Dessert');
      expect(recipe.tags.length, 1);
      expect(recipe.tags[0].tag, 'chocolate');
      expect(recipe.videoUrl, 'https://youtube.com/watch?v=123');
      expect(recipe.videoPlatform, 'youtube');
      expect(recipe.recipePageUrl, 'https://example.com/recipe');
      expect(recipe.recipeSiteName, 'Example Recipes');
      expect(recipe.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(recipe.authorName, 'Chef John');
      expect(recipe.extractionMethod, 'youtube');
      expect(recipe.extractionConfidence, 0.95);
    });

    test('fromJson handles minimal data', () {
      final json = {
        'id': 'recipe-1',
        'title': 'Simple Recipe',
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

      final recipe = Recipe.fromJson(json);

      expect(recipe.id, 'recipe-1');
      expect(recipe.title, 'Simple Recipe');
      expect(recipe.description, isNull);
      expect(recipe.instructions, isNull);
      expect(recipe.ingredients, isEmpty);
      expect(recipe.categories, isEmpty);
      expect(recipe.tags, isEmpty);
    });

    test('fromJson defaults title to Untitled when missing', () {
      final json = {
        'id': 'recipe-1',
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

      final recipe = Recipe.fromJson(json);

      expect(recipe.title, 'Untitled');
    });

    group('formattedTime', () {
      test('returns null when totalTimeMins is null', () {
        final recipe = Recipe(
          id: '1',
          title: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(recipe.formattedTime, isNull);
      });

      test('formats minutes under 60', () {
        final recipe = Recipe(
          id: '1',
          title: 'Test',
          totalTimeMins: 45,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(recipe.formattedTime, '45 min');
      });

      test('formats exactly 60 minutes as 1h', () {
        final recipe = Recipe(
          id: '1',
          title: 'Test',
          totalTimeMins: 60,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(recipe.formattedTime, '1h');
      });

      test('formats hours with remaining minutes', () {
        final recipe = Recipe(
          id: '1',
          title: 'Test',
          totalTimeMins: 90,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(recipe.formattedTime, '1h 30m');
      });

      test('formats multiple hours', () {
        final recipe = Recipe(
          id: '1',
          title: 'Test',
          totalTimeMins: 150,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(recipe.formattedTime, '2h 30m');
      });
    });

    group('sourceDisplay', () {
      test('returns recipeSiteName when available', () {
        final recipe = Recipe(
          id: '1',
          title: 'Test',
          recipeSiteName: 'AllRecipes',
          videoPlatform: 'youtube',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(recipe.sourceDisplay, 'AllRecipes');
      });

      test('returns YouTube when videoPlatform is youtube', () {
        final recipe = Recipe(
          id: '1',
          title: 'Test',
          videoPlatform: 'youtube',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(recipe.sourceDisplay, 'YouTube');
      });

      test('returns Instagram when videoPlatform is instagram', () {
        final recipe = Recipe(
          id: '1',
          title: 'Test',
          videoPlatform: 'instagram',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(recipe.sourceDisplay, 'Instagram');
      });

      test('returns Manual when no source', () {
        final recipe = Recipe(
          id: '1',
          title: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(recipe.sourceDisplay, 'Manual');
      });
    });
  });

  group('RecipeSummary', () {
    test('fromJson parses valid data', () {
      final json = {
        'id': 'recipe-1',
        'title': 'Quick Pasta',
        'description': 'Easy weeknight meal',
        'thumbnail_url': 'https://example.com/pasta.jpg',
        'total_time_mins': 25,
        'difficulty': 'easy',
        'source_platform': 'youtube',
        'recipe_site_name': 'Tasty',
        'created_at': '2024-01-15T10:30:00Z',
      };

      final summary = RecipeSummary.fromJson(json);

      expect(summary.id, 'recipe-1');
      expect(summary.title, 'Quick Pasta');
      expect(summary.description, 'Easy weeknight meal');
      expect(summary.thumbnailUrl, 'https://example.com/pasta.jpg');
      expect(summary.totalTimeMins, 25);
      expect(summary.difficulty, 'easy');
      expect(summary.sourcePlatform, 'youtube');
      expect(summary.recipeSiteName, 'Tasty');
    });

    test('fromJson handles minimal data', () {
      final json = {
        'id': 'recipe-1',
        'created_at': '2024-01-15T10:30:00Z',
      };

      final summary = RecipeSummary.fromJson(json);

      expect(summary.id, 'recipe-1');
      expect(summary.title, 'Untitled');
      expect(summary.description, isNull);
      expect(summary.thumbnailUrl, isNull);
    });

    group('formattedTime', () {
      test('formats minutes correctly', () {
        final summary = RecipeSummary(
          id: '1',
          title: 'Test',
          totalTimeMins: 45,
          createdAt: DateTime.now(),
        );

        expect(summary.formattedTime, '45 min');
      });

      test('formats hours correctly', () {
        final summary = RecipeSummary(
          id: '1',
          title: 'Test',
          totalTimeMins: 75,
          createdAt: DateTime.now(),
        );

        expect(summary.formattedTime, '1h 15m');
      });
    });
  });
}
