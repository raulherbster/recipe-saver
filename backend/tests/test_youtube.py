"""Tests for YouTube extraction module."""

import pytest
from app.extraction.youtube import (
    extract_video_id,
    extract_urls_from_text,
)


class TestExtractVideoId:
    """Tests for YouTube video ID extraction."""

    def test_standard_url(self):
        """Test standard youtube.com/watch URL."""
        url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        assert extract_video_id(url) == "dQw4w9WgXcQ"

    def test_short_url(self):
        """Test youtu.be short URL."""
        url = "https://youtu.be/dQw4w9WgXcQ"
        assert extract_video_id(url) == "dQw4w9WgXcQ"

    def test_embed_url(self):
        """Test embed URL format."""
        url = "https://www.youtube.com/embed/dQw4w9WgXcQ"
        assert extract_video_id(url) == "dQw4w9WgXcQ"

    def test_shorts_url(self):
        """Test YouTube Shorts URL."""
        url = "https://www.youtube.com/shorts/dQw4w9WgXcQ"
        assert extract_video_id(url) == "dQw4w9WgXcQ"

    def test_url_with_extra_params(self):
        """Test URL with additional query parameters."""
        url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=120&list=PLxyz"
        assert extract_video_id(url) == "dQw4w9WgXcQ"

    def test_invalid_url(self):
        """Test non-YouTube URL returns None."""
        url = "https://www.vimeo.com/123456"
        assert extract_video_id(url) is None

    def test_malformed_url(self):
        """Test malformed URL returns None."""
        url = "not a url"
        assert extract_video_id(url) is None


class TestExtractUrls:
    """Tests for URL extraction from text."""

    def test_single_url(self):
        """Test extracting a single URL."""
        text = "Check out this recipe: https://www.seriouseats.com/recipe/pasta"
        urls = extract_urls_from_text(text)
        assert "https://www.seriouseats.com/recipe/pasta" in urls

    def test_multiple_urls(self):
        """Test extracting multiple URLs."""
        text = """
        Recipe: https://cooking.nytimes.com/recipe/123
        My blog: https://myblog.com/about
        """
        urls = extract_urls_from_text(text)
        assert len(urls) == 2
        assert "https://cooking.nytimes.com/recipe/123" in urls
        assert "https://myblog.com/about" in urls

    def test_url_with_trailing_punctuation(self):
        """Test URL followed by punctuation."""
        text = "Get the recipe here: https://example.com/recipe."
        urls = extract_urls_from_text(text)
        assert "https://example.com/recipe" in urls
        # Should not include the trailing period
        assert "https://example.com/recipe." not in urls

    def test_url_in_parentheses(self):
        """Test URL in parentheses."""
        text = "Full recipe (https://example.com/recipe)"
        urls = extract_urls_from_text(text)
        assert "https://example.com/recipe" in urls

    def test_no_urls(self):
        """Test text with no URLs."""
        text = "This is just plain text with no links."
        urls = extract_urls_from_text(text)
        assert urls == []

    def test_empty_text(self):
        """Test empty text."""
        assert extract_urls_from_text("") == []
        assert extract_urls_from_text(None) == []

    def test_deduplication(self):
        """Test that duplicate URLs are removed."""
        text = """
        Link: https://example.com/recipe
        Same link: https://example.com/recipe
        """
        urls = extract_urls_from_text(text)
        assert urls.count("https://example.com/recipe") == 1
