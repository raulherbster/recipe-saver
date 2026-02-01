"""Tests for recipe site parsing module."""

import pytest
from app.extraction.recipe_sites import (
    is_recipe_url,
    filter_recipe_urls,
    parse_iso_duration,
    parse_ingredient_text,
    parse_schema_recipe,
    find_schema_recipe,
)


class TestIsRecipeUrl:
    """Tests for recipe URL detection."""

    def test_known_recipe_sites(self):
        """Test known recipe site domains."""
        assert is_recipe_url("https://cooking.nytimes.com/recipes/1234")
        assert is_recipe_url("https://www.seriouseats.com/pasta-recipe")
        assert is_recipe_url("https://www.bonappetit.com/recipe/chicken")
        assert is_recipe_url("https://www.allrecipes.com/recipe/12345")
        assert is_recipe_url("https://www.budgetbytes.com/easy-pasta/")

    def test_recipe_path_pattern(self):
        """Test URLs with /recipe/ or /recipes/ in path."""
        assert is_recipe_url("https://unknown-blog.com/recipe/my-pasta")
        assert is_recipe_url("https://chef-blog.com/recipes/soup")

    def test_non_recipe_urls(self):
        """Test non-recipe URLs return False."""
        assert not is_recipe_url("https://www.google.com")
        assert not is_recipe_url("https://www.youtube.com/watch?v=123")
        assert not is_recipe_url("https://www.instagram.com/p/abc")
        assert not is_recipe_url("https://twitter.com/chef")

    def test_edge_cases(self):
        """Test edge cases."""
        assert not is_recipe_url("")
        assert not is_recipe_url("not a url")


class TestFilterRecipeUrls:
    """Tests for filtering recipe URLs from a list."""

    def test_filter_mixed_urls(self):
        """Test filtering a mixed list of URLs."""
        urls = [
            "https://www.seriouseats.com/recipe/pasta",
            "https://www.youtube.com/watch?v=123",
            "https://cooking.nytimes.com/recipes/456",
            "https://www.instagram.com/p/abc",
            "https://random-blog.com/recipe/soup",
        ]
        filtered = filter_recipe_urls(urls)
        assert len(filtered) == 3
        assert "https://www.youtube.com/watch?v=123" not in filtered
        assert "https://www.instagram.com/p/abc" not in filtered

    def test_empty_list(self):
        """Test empty list returns empty."""
        assert filter_recipe_urls([]) == []


class TestParseIsoDuration:
    """Tests for ISO 8601 duration parsing."""

    def test_hours_and_minutes(self):
        """Test parsing hours and minutes."""
        assert parse_iso_duration("PT1H30M") == 90
        assert parse_iso_duration("PT2H15M") == 135

    def test_minutes_only(self):
        """Test parsing minutes only."""
        assert parse_iso_duration("PT45M") == 45
        assert parse_iso_duration("PT15M") == 15

    def test_hours_only(self):
        """Test parsing hours only."""
        assert parse_iso_duration("PT2H") == 120

    def test_with_seconds(self):
        """Test parsing with seconds (rounded down)."""
        assert parse_iso_duration("PT30M30S") == 30

    def test_invalid_format(self):
        """Test invalid format returns None."""
        assert parse_iso_duration("invalid") is None
        assert parse_iso_duration("1 hour") is None
        assert parse_iso_duration(None) is None
        assert parse_iso_duration("") is None


class TestParseIngredientText:
    """Tests for ingredient text parsing."""

    def test_standard_ingredient(self):
        """Test standard ingredient format."""
        result = parse_ingredient_text("2 cups flour")
        assert result.quantity == "2"
        assert result.unit == "cups"
        assert result.name == "flour"

    def test_ingredient_with_preparation(self):
        """Test ingredient with preparation notes."""
        result = parse_ingredient_text("4 cloves garlic, minced")
        assert result.quantity == "4"
        assert result.name == "garlic"
        assert result.preparation == "minced"

    def test_fractional_quantity(self):
        """Test fractional quantities."""
        result = parse_ingredient_text("1/2 cup sugar")
        assert result.quantity == "1/2"
        assert result.unit == "cup"
        assert result.name == "sugar"

    def test_ingredient_no_quantity(self):
        """Test ingredient without quantity."""
        result = parse_ingredient_text("Fresh basil leaves")
        assert result.name == "Fresh basil leaves"

    def test_preserves_raw_text(self):
        """Test that raw text is preserved."""
        raw = "2 lbs chicken breast, diced"
        result = parse_ingredient_text(raw)
        assert result.raw_text == raw


class TestParseSchemaRecipe:
    """Tests for schema.org/Recipe parsing."""

    def test_parse_standard_schema(self, sample_recipe_html):
        """Test parsing standard schema.org/Recipe."""
        recipe = parse_schema_recipe(sample_recipe_html, "https://example.com/recipe")

        assert recipe is not None
        assert recipe.title == "Classic Tomato Pasta"
        assert recipe.description == "A simple and delicious tomato pasta recipe."
        assert recipe.prep_time_mins == 15
        assert recipe.cook_time_mins == 20
        assert recipe.total_time_mins == 35
        assert recipe.servings == "4 servings"
        assert recipe.cuisine == "Italian"
        assert recipe.author == "Test Chef"
        assert len(recipe.ingredients) == 6
        assert len(recipe.instructions) == 4

    def test_parse_graph_format(self, sample_recipe_html_graph):
        """Test parsing schema.org/Recipe in @graph format."""
        recipe = parse_schema_recipe(sample_recipe_html_graph, "https://example.com/cookies")

        assert recipe is not None
        assert recipe.title == "Chocolate Chip Cookies"
        assert recipe.prep_time_mins == 20
        assert recipe.cook_time_mins == 12
        assert len(recipe.ingredients) == 5

    def test_parse_no_schema(self):
        """Test parsing HTML with no schema returns None."""
        html = "<html><body><h1>Just a page</h1></body></html>"
        recipe = parse_schema_recipe(html, "https://example.com")
        assert recipe is None

    def test_ingredients_parsed_correctly(self, sample_recipe_html):
        """Test ingredients are parsed into components."""
        recipe = parse_schema_recipe(sample_recipe_html, "https://example.com/recipe")

        # Check first ingredient
        spaghetti = recipe.ingredients[0]
        assert spaghetti.raw_text == "400g spaghetti"

        # Check ingredient with preparation
        garlic = recipe.ingredients[2]
        assert "garlic" in garlic.name.lower()

    def test_instructions_as_steps(self, sample_recipe_html):
        """Test instructions are extracted as list of steps."""
        recipe = parse_schema_recipe(sample_recipe_html, "https://example.com/recipe")

        assert isinstance(recipe.instructions, list)
        assert len(recipe.instructions) == 4
        assert "pasta" in recipe.instructions[0].lower()

    def test_instructions_as_string(self, sample_recipe_html_graph):
        """Test instructions as single string are split."""
        recipe = parse_schema_recipe(sample_recipe_html_graph, "https://example.com/cookies")

        assert isinstance(recipe.instructions, list)
        assert len(recipe.instructions) >= 1


class TestFindSchemaRecipe:
    """Tests for finding schema.org/Recipe in HTML."""

    def test_find_direct_recipe(self, sample_recipe_html):
        """Test finding directly embedded Recipe."""
        schema = find_schema_recipe(sample_recipe_html)
        assert schema is not None
        assert schema["@type"] == "Recipe"
        assert schema["name"] == "Classic Tomato Pasta"

    def test_find_recipe_in_graph(self, sample_recipe_html_graph):
        """Test finding Recipe in @graph array."""
        schema = find_schema_recipe(sample_recipe_html_graph)
        assert schema is not None
        assert schema["@type"] == "Recipe"
        assert schema["name"] == "Chocolate Chip Cookies"

    def test_no_recipe_found(self):
        """Test no Recipe in HTML."""
        html = """
        <html>
        <head>
            <script type="application/ld+json">
            {"@type": "WebPage", "name": "Test"}
            </script>
        </head>
        </html>
        """
        schema = find_schema_recipe(html)
        assert schema is None
