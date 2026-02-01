"""Tests for LLM extractor module."""

import pytest
from app.extraction.llm_extractor import (
    parse_llm_response,
    convert_llm_to_schema_recipe,
    calculate_extraction_confidence,
    build_extraction_prompt,
    CATEGORY_TAXONOMY,
)
from app.extraction.recipe_sites import SchemaRecipe, ParsedIngredient


class TestParseLlmResponse:
    """Tests for parsing LLM JSON responses."""

    def test_parse_valid_json(self):
        """Test parsing valid JSON."""
        response = '{"title": "Test Recipe", "ingredients": []}'
        result = parse_llm_response(response)
        assert result is not None
        assert result["title"] == "Test Recipe"

    def test_parse_json_in_markdown(self):
        """Test parsing JSON wrapped in markdown code block."""
        response = """Here's the recipe:
        ```json
        {"title": "Test Recipe", "ingredients": []}
        ```
        """
        result = parse_llm_response(response)
        assert result is not None
        assert result["title"] == "Test Recipe"

    def test_parse_json_in_markdown_no_lang(self):
        """Test parsing JSON in markdown without language specifier."""
        response = """
        ```
        {"title": "Test Recipe"}
        ```
        """
        result = parse_llm_response(response)
        assert result is not None
        assert result["title"] == "Test Recipe"

    def test_parse_json_with_surrounding_text(self):
        """Test parsing JSON with surrounding text."""
        response = """I found a recipe! Here it is:
        {"title": "Test Recipe", "ingredients": ["flour", "sugar"]}
        Hope that helps!"""
        result = parse_llm_response(response)
        assert result is not None
        assert result["title"] == "Test Recipe"

    def test_parse_invalid_json(self):
        """Test parsing invalid JSON returns None."""
        response = "This is not JSON at all"
        result = parse_llm_response(response)
        assert result is None

    def test_parse_malformed_json(self):
        """Test parsing malformed JSON returns None."""
        response = '{"title": "Missing closing brace"'
        result = parse_llm_response(response)
        assert result is None


class TestConvertLlmToSchemaRecipe:
    """Tests for converting LLM output to SchemaRecipe."""

    def test_convert_full_recipe(self):
        """Test converting a complete recipe."""
        data = {
            "title": "Test Pasta",
            "description": "A delicious pasta dish",
            "ingredients": [
                {"raw_text": "2 cups flour", "name": "flour", "quantity": "2", "unit": "cups"},
                {"raw_text": "1 egg", "name": "egg", "quantity": "1"},
            ],
            "instructions": ["Mix ingredients", "Cook pasta"],
            "prep_time_mins": 15,
            "cook_time_mins": 20,
            "total_time_mins": 35,
            "servings": "4",
        }

        recipe = convert_llm_to_schema_recipe(data)

        assert recipe.title == "Test Pasta"
        assert recipe.description == "A delicious pasta dish"
        assert len(recipe.ingredients) == 2
        assert recipe.ingredients[0].name == "flour"
        assert recipe.ingredients[0].quantity == "2"
        assert len(recipe.instructions) == 2
        assert recipe.prep_time_mins == 15
        assert recipe.servings == "4"

    def test_convert_minimal_recipe(self):
        """Test converting a recipe with minimal data."""
        data = {"title": "Simple Recipe"}

        recipe = convert_llm_to_schema_recipe(data)

        assert recipe.title == "Simple Recipe"
        assert recipe.ingredients == []
        assert recipe.instructions == []

    def test_convert_missing_title(self):
        """Test converting recipe with missing title uses default."""
        data = {"ingredients": [{"name": "flour"}]}

        recipe = convert_llm_to_schema_recipe(data)

        assert recipe.title == "Untitled Recipe"

    def test_convert_string_ingredients(self):
        """Test converting ingredients as plain strings."""
        data = {
            "title": "Test",
            "ingredients": ["2 cups flour", "1 egg"],
        }

        recipe = convert_llm_to_schema_recipe(data)

        assert len(recipe.ingredients) == 2
        assert recipe.ingredients[0].raw_text == "2 cups flour"
        assert recipe.ingredients[0].name == "2 cups flour"

    def test_convert_string_instructions(self):
        """Test converting instructions as single string."""
        data = {
            "title": "Test",
            "instructions": "Mix everything together.\nBake for 30 minutes.",
        }

        recipe = convert_llm_to_schema_recipe(data)

        assert len(recipe.instructions) == 2


class TestCalculateExtractionConfidence:
    """Tests for extraction confidence calculation."""

    def test_complete_recipe_high_confidence(self):
        """Test complete recipe has high confidence."""
        recipe = SchemaRecipe(
            title="Complete Recipe",
            description="A full description",
            ingredients=[
                ParsedIngredient(raw_text="1 cup flour", name="flour"),
                ParsedIngredient(raw_text="2 eggs", name="eggs"),
                ParsedIngredient(raw_text="1 cup sugar", name="sugar"),
            ],
            instructions=["Step 1", "Step 2", "Step 3"],
            total_time_mins=30,
            servings="4",
        )

        confidence = calculate_extraction_confidence(recipe)
        assert confidence >= 0.9

    def test_minimal_recipe_lower_confidence(self):
        """Test minimal recipe has lower confidence."""
        recipe = SchemaRecipe(
            title="Minimal Recipe",
            ingredients=[ParsedIngredient(raw_text="flour", name="flour")],
            instructions=["Cook it"],
        )

        confidence = calculate_extraction_confidence(recipe)
        assert 0.3 <= confidence <= 0.7

    def test_untitled_recipe_low_confidence(self):
        """Test untitled recipe has low confidence."""
        recipe = SchemaRecipe(
            title="Untitled Recipe",
            ingredients=[],
            instructions=[],
        )

        confidence = calculate_extraction_confidence(recipe)
        assert confidence < 0.3

    def test_confidence_bounds(self):
        """Test confidence is always between 0 and 1."""
        # Empty recipe
        empty_recipe = SchemaRecipe(title="Untitled Recipe")
        assert 0 <= calculate_extraction_confidence(empty_recipe) <= 1

        # Full recipe
        full_recipe = SchemaRecipe(
            title="Full",
            description="Desc",
            ingredients=[ParsedIngredient(raw_text=f"ing{i}", name=f"ing{i}") for i in range(10)],
            instructions=[f"Step {i}" for i in range(10)],
            total_time_mins=60,
            servings="8",
        )
        assert 0 <= calculate_extraction_confidence(full_recipe) <= 1


class TestBuildExtractionPrompt:
    """Tests for extraction prompt building."""

    def test_prompt_includes_title(self):
        """Test prompt includes the video title."""
        prompt = build_extraction_prompt("My Recipe Video", None, None)
        assert "My Recipe Video" in prompt

    def test_prompt_includes_categories(self):
        """Test prompt includes category taxonomy."""
        prompt = build_extraction_prompt("Test", "Desc", "Transcript")

        # Check some category values are included
        assert "vegetarian" in prompt
        assert "italian" in prompt
        assert "easy" in prompt

    def test_prompt_handles_none_values(self):
        """Test prompt handles None description and transcript."""
        prompt = build_extraction_prompt("Title", None, None)
        assert "(none)" in prompt

    def test_prompt_includes_transcript(self):
        """Test prompt includes transcript when provided."""
        transcript = "Today we're making a delicious pasta..."
        prompt = build_extraction_prompt("Pasta Recipe", "Quick pasta", transcript)
        assert transcript in prompt


class TestCategoryTaxonomy:
    """Tests for category taxonomy."""

    def test_taxonomy_has_required_types(self):
        """Test taxonomy has all required category types."""
        required_types = ["dietary", "protein", "course", "cuisine", "method", "season", "difficulty", "time"]
        for cat_type in required_types:
            assert cat_type in CATEGORY_TAXONOMY
            assert len(CATEGORY_TAXONOMY[cat_type]) > 0

    def test_dietary_categories(self):
        """Test dietary categories include expected values."""
        dietary = CATEGORY_TAXONOMY["dietary"]
        assert "vegetarian" in dietary
        assert "vegan" in dietary
        assert "gluten-free" in dietary

    def test_cuisine_categories(self):
        """Test cuisine categories include expected values."""
        cuisine = CATEGORY_TAXONOMY["cuisine"]
        assert "italian" in cuisine
        assert "mexican" in cuisine
        assert "japanese" in cuisine
