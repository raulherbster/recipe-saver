"""Tests for recipe search module."""

import pytest
from app.extraction.recipe_search import (
    normalize_text,
    extract_recipe_keywords,
    calculate_title_similarity,
    build_search_query,
    SearchResult,
)


class TestNormalizeText:
    """Tests for text normalization."""

    def test_lowercase(self):
        """Test text is lowercased."""
        assert normalize_text("HELLO World") == "hello world"

    def test_removes_special_chars(self):
        """Test special characters are removed."""
        assert normalize_text("Hello! World?") == "hello world"

    def test_normalizes_whitespace(self):
        """Test whitespace is normalized."""
        assert normalize_text("hello   world") == "hello world"

    def test_empty_string(self):
        """Test empty string."""
        assert normalize_text("") == ""
        assert normalize_text(None) == ""


class TestExtractRecipeKeywords:
    """Tests for recipe keyword extraction."""

    def test_removes_stop_words(self):
        """Test stop words are removed."""
        keywords = extract_recipe_keywords("The Best Pasta Recipe")
        assert "pasta" in keywords
        assert "the" not in keywords
        assert "best" not in keywords
        assert "recipe" not in keywords

    def test_extracts_food_words(self):
        """Test food words are extracted."""
        keywords = extract_recipe_keywords("Chicken Tikka Masala")
        assert "chicken" in keywords
        assert "tikka" in keywords
        assert "masala" in keywords

    def test_empty_after_stop_words(self):
        """Test handling when all words are stop words."""
        keywords = extract_recipe_keywords("The Best Easy Recipe")
        assert len(keywords) == 0


class TestCalculateTitleSimilarity:
    """Tests for title similarity calculation."""

    def test_identical_titles(self):
        """Test identical titles have high similarity."""
        similarity = calculate_title_similarity(
            "Chicken Tikka Masala",
            "Chicken Tikka Masala"
        )
        assert similarity == 1.0

    def test_similar_titles(self):
        """Test similar titles have good similarity."""
        similarity = calculate_title_similarity(
            "Chicken Tikka Masala Recipe",
            "Easy Chicken Tikka Masala"
        )
        # Should have high overlap: chicken, tikka, masala
        assert similarity >= 0.7

    def test_different_titles(self):
        """Test different titles have low similarity."""
        similarity = calculate_title_similarity(
            "Chocolate Cake",
            "Chicken Stir Fry"
        )
        assert similarity < 0.3

    def test_partial_overlap(self):
        """Test partial title overlap."""
        similarity = calculate_title_similarity(
            "Pasta Carbonara",
            "Spaghetti Carbonara"
        )
        # Should have some overlap: carbonara
        assert 0.3 <= similarity <= 0.7

    def test_empty_titles(self):
        """Test empty titles."""
        assert calculate_title_similarity("", "Pasta") == 0.0
        assert calculate_title_similarity("Pasta", "") == 0.0


class TestBuildSearchQuery:
    """Tests for search query building."""

    def test_simple_title(self):
        """Test simple title query."""
        query = build_search_query("Pasta Carbonara")
        assert "pasta" in query.lower()
        assert "carbonara" in query.lower()

    def test_removes_hashtags(self):
        """Test hashtags are removed."""
        query = build_search_query("Pasta #shorts #cooking")
        assert "#" not in query
        assert "shorts" not in query.lower()

    def test_removes_pipe_suffix(self):
        """Test pipe suffix is removed."""
        query = build_search_query("Pasta Carbonara | Chef John")
        assert "chef john" not in query.lower()

    def test_with_author(self):
        """Test adding author to query."""
        query = build_search_query("Pasta Carbonara", author="Chef John")
        assert "pasta" in query.lower()
        assert "carbonara" in query.lower()
        assert "chef john" in query.lower()

    def test_cleans_emojis(self):
        """Test emojis are removed."""
        query = build_search_query("Pasta 🍝 Recipe")
        assert "🍝" not in query


class TestSearchResult:
    """Tests for SearchResult dataclass."""

    def test_creation(self):
        """Test SearchResult creation."""
        result = SearchResult(
            url="https://example.com/recipe",
            title="Pasta Carbonara",
            site_name="AllRecipes",
            similarity_score=0.85,
        )
        assert result.url == "https://example.com/recipe"
        assert result.title == "Pasta Carbonara"
        assert result.site_name == "AllRecipes"
        assert result.similarity_score == 0.85

    def test_sorting(self):
        """Test SearchResults can be sorted by similarity."""
        results = [
            SearchResult("url1", "Title 1", "Site 1", 0.5),
            SearchResult("url2", "Title 2", "Site 2", 0.9),
            SearchResult("url3", "Title 3", "Site 3", 0.7),
        ]
        sorted_results = sorted(results, key=lambda r: r.similarity_score, reverse=True)
        assert sorted_results[0].similarity_score == 0.9
        assert sorted_results[1].similarity_score == 0.7
        assert sorted_results[2].similarity_score == 0.5
