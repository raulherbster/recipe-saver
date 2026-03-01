"""Tests for YouTube extraction module."""

import pytest
from app.extraction.youtube import (
    extract_video_id,
    extract_urls_from_text,
    extract_recipe_links_from_patterns,
    check_for_link_in_bio,
    YouTubeComment,
    get_author_comments,
    get_pinned_comment,
)
from app.extraction.url_utils import (
    preprocess_share_url,
    clean_url,
    extract_url_from_share_text,
    normalize_youtube_url,
    normalize_instagram_url,
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


class TestMobileYouTubeUrls:
    """Tests for mobile YouTube URL formats from share intents."""

    def test_mobile_youtube_url(self):
        """Test m.youtube.com URL (mobile app share)."""
        url = "https://m.youtube.com/watch?v=dQw4w9WgXcQ"
        assert extract_video_id(url) == "dQw4w9WgXcQ"

    def test_mobile_youtube_with_params(self):
        """Test mobile YouTube URL with tracking parameters."""
        url = "https://m.youtube.com/watch?v=dQw4w9WgXcQ&si=abc123xyz"
        assert extract_video_id(url) == "dQw4w9WgXcQ"

    def test_youtube_live_url(self):
        """Test YouTube live stream URL format."""
        url = "https://www.youtube.com/live/dQw4w9WgXcQ"
        assert extract_video_id(url) == "dQw4w9WgXcQ"

    def test_youtube_v_url(self):
        """Test old YouTube /v/ URL format."""
        url = "https://www.youtube.com/v/dQw4w9WgXcQ"
        assert extract_video_id(url) == "dQw4w9WgXcQ"

    def test_youtu_be_without_www(self):
        """Test youtu.be URL (common in mobile shares)."""
        url = "https://youtu.be/dQw4w9WgXcQ"
        assert extract_video_id(url) == "dQw4w9WgXcQ"

    def test_youtu_be_with_tracking(self):
        """Test youtu.be URL with tracking parameters."""
        url = "https://youtu.be/dQw4w9WgXcQ?si=tracking123"
        assert extract_video_id(url) == "dQw4w9WgXcQ"


class TestUrlPreprocessing:
    """Tests for URL preprocessing from share intents."""

    def test_extract_url_from_share_text_youtube(self):
        """Test extracting YouTube URL from share text."""
        text = "Check out this recipe video! https://youtu.be/abc12345678"
        url = extract_url_from_share_text(text)
        assert url == "https://youtu.be/abc12345678"

    def test_extract_url_from_share_text_instagram(self):
        """Test extracting Instagram URL from share text."""
        text = "https://www.instagram.com/reel/ABC123/?igsh=xyz Sent via Instagram"
        url = extract_url_from_share_text(text)
        assert "instagram.com/reel/ABC123" in url
        # Tracking param should be removed
        assert "igsh" not in url

    def test_extract_url_plain_url(self):
        """Test when input is already a plain URL."""
        url = "https://www.youtube.com/watch?v=abc12345678"
        result = extract_url_from_share_text(url)
        assert result == url

    def test_clean_url_removes_tracking_params(self):
        """Test that tracking parameters are removed."""
        url = "https://example.com/recipe?id=123&utm_source=share&utm_medium=social"
        cleaned = clean_url(url)
        assert "id=123" in cleaned
        assert "utm_source" not in cleaned
        assert "utm_medium" not in cleaned

    def test_clean_url_removes_instagram_tracking(self):
        """Test Instagram tracking parameters are removed."""
        url = "https://www.instagram.com/reel/ABC123/?igsh=xyz123&igshid=abc"
        cleaned = clean_url(url)
        assert "igsh" not in cleaned
        assert "igshid" not in cleaned

    def test_clean_url_removes_youtube_tracking(self):
        """Test YouTube tracking parameters are removed."""
        url = "https://www.youtube.com/watch?v=abc123&si=tracking&feature=share"
        cleaned = clean_url(url)
        assert "v=abc123" in cleaned
        assert "si=" not in cleaned
        assert "feature=" not in cleaned

    def test_normalize_youtube_mobile_url(self):
        """Test mobile YouTube URL normalization."""
        url = "https://m.youtube.com/watch?v=abc12345678"
        normalized = normalize_youtube_url(url)
        assert "www.youtube.com" in normalized
        assert "m.youtube.com" not in normalized

    def test_normalize_youtu_be_url(self):
        """Test youtu.be URL normalization."""
        url = "https://youtu.be/abc12345678"
        normalized = normalize_youtube_url(url)
        assert normalized == "https://www.youtube.com/watch?v=abc12345678"

    def test_normalize_instagram_url(self):
        """Test Instagram URL normalization."""
        url = "https://instagram.com/reel/ABC123/"
        normalized = normalize_instagram_url(url)
        assert "www.instagram.com" in normalized

    def test_preprocess_share_url_youtube_with_text(self):
        """Test full preprocessing of YouTube share with text."""
        share_text = "Check this out! https://youtu.be/abc12345678?si=tracking"
        processed = preprocess_share_url(share_text)
        # Should extract URL, remove tracking, and normalize
        assert "youtube.com/watch?v=abc12345678" in processed
        assert "si=" not in processed

    def test_preprocess_share_url_instagram_with_text(self):
        """Test full preprocessing of Instagram share with text."""
        share_text = "https://www.instagram.com/reel/ABC123/?igsh=xyz Shared from Instagram"
        processed = preprocess_share_url(share_text)
        assert "instagram.com/reel/ABC123" in processed
        assert "igsh" not in processed

    def test_preprocess_preserves_video_id(self):
        """Test that video IDs are preserved after preprocessing."""
        urls = [
            "https://youtu.be/dQw4w9WgXcQ",
            "https://m.youtube.com/watch?v=dQw4w9WgXcQ&si=abc",
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ&utm_source=share",
        ]
        for url in urls:
            processed = preprocess_share_url(url)
            assert extract_video_id(processed) == "dQw4w9WgXcQ"

    def test_preprocess_empty_string(self):
        """Test preprocessing with empty string."""
        assert preprocess_share_url("") == ""
        assert preprocess_share_url(None) is None


class TestRecipeLinkPatterns:
    """Tests for recipe link pattern extraction."""

    def test_recipe_here_colon(self):
        """Test 'recipe here:' pattern."""
        text = "Get the recipe here: https://example.com/pasta-recipe"
        urls = extract_recipe_links_from_patterns(text)
        assert "https://example.com/pasta-recipe" in urls

    def test_full_recipe_colon(self):
        """Test 'full recipe:' pattern."""
        text = "Full recipe: https://cooking.nytimes.com/recipe/123"
        urls = extract_recipe_links_from_patterns(text)
        assert "https://cooking.nytimes.com/recipe/123" in urls

    def test_get_the_recipe(self):
        """Test 'get the recipe' pattern."""
        text = "Get the recipe → https://seriouseats.com/pizza"
        urls = extract_recipe_links_from_patterns(text)
        assert "https://seriouseats.com/pizza" in urls

    def test_recipe_link(self):
        """Test 'recipe link:' pattern."""
        text = "Recipe link: https://allrecipes.com/recipe/12345"
        urls = extract_recipe_links_from_patterns(text)
        assert "https://allrecipes.com/recipe/12345" in urls

    def test_find_recipe_at(self):
        """Test 'find the recipe at' pattern."""
        text = "Find the recipe at https://myblog.com/carbonara"
        urls = extract_recipe_links_from_patterns(text)
        assert "https://myblog.com/carbonara" in urls

    def test_written_recipe(self):
        """Test 'written recipe:' pattern."""
        text = "Written recipe: https://example.com/chicken"
        urls = extract_recipe_links_from_patterns(text)
        assert "https://example.com/chicken" in urls

    def test_case_insensitive(self):
        """Test case insensitivity."""
        text = "FULL RECIPE: https://example.com/cake"
        urls = extract_recipe_links_from_patterns(text)
        assert "https://example.com/cake" in urls

    def test_multiple_patterns(self):
        """Test multiple patterns in same text."""
        text = """
        Get the recipe here: https://site1.com/recipe1
        Full recipe: https://site2.com/recipe2
        """
        urls = extract_recipe_links_from_patterns(text)
        assert len(urls) == 2

    def test_no_pattern_match(self):
        """Test text without recipe link patterns."""
        text = "Check out my video https://youtube.com/watch?v=123"
        urls = extract_recipe_links_from_patterns(text)
        assert len(urls) == 0

    def test_empty_text(self):
        """Test empty text."""
        assert extract_recipe_links_from_patterns("") == []
        assert extract_recipe_links_from_patterns(None) == []


class TestLinkInBio:
    """Tests for 'link in bio' detection."""

    def test_recipe_in_bio(self):
        """Test 'recipe in bio' pattern."""
        text = "Recipe in bio! 🔗"
        assert check_for_link_in_bio(text) is True

    def test_link_in_bio(self):
        """Test 'link in bio' pattern."""
        text = "Full recipe, link in bio"
        assert check_for_link_in_bio(text) is True

    def test_check_bio_for_recipe(self):
        """Test 'check bio for recipe' pattern."""
        text = "Check my bio for the full recipe"
        assert check_for_link_in_bio(text) is True

    def test_recipe_in_my_bio(self):
        """Test 'recipe in my bio' pattern."""
        text = "Recipe is in my bio!"
        assert check_for_link_in_bio(text) is True

    def test_no_bio_mention(self):
        """Test text without bio mention."""
        text = "Get the recipe here: https://example.com"
        assert check_for_link_in_bio(text) is False

    def test_empty_text(self):
        """Test empty text."""
        assert check_for_link_in_bio("") is False
        assert check_for_link_in_bio(None) is False


class TestCommentHelpers:
    """Tests for comment helper functions."""

    def test_get_author_comments(self):
        """Test filtering to author comments only."""
        comments = [
            YouTubeComment("Great video!", "user1", "User 1", False, False),
            YouTubeComment("Recipe link: https://...", "channel1", "Chef", True, True),
            YouTubeComment("Thanks!", "user2", "User 2", False, False),
            YouTubeComment("More info here", "channel1", "Chef", True, False),
        ]
        author_comments = get_author_comments(comments)
        assert len(author_comments) == 2
        assert "Recipe link: https://..." in author_comments
        assert "More info here" in author_comments

    def test_get_author_comments_none(self):
        """Test when no author comments exist."""
        comments = [
            YouTubeComment("Great!", "user1", "User 1", False, False),
            YouTubeComment("Love it!", "user2", "User 2", False, False),
        ]
        author_comments = get_author_comments(comments)
        assert len(author_comments) == 0

    def test_get_pinned_comment(self):
        """Test getting pinned comment."""
        comments = [
            YouTubeComment("Pinned: Recipe here!", "channel1", "Chef", True, True),
            YouTubeComment("Great video!", "user1", "User 1", False, False),
        ]
        pinned = get_pinned_comment(comments)
        assert pinned == "Pinned: Recipe here!"

    def test_get_pinned_comment_none(self):
        """Test when no pinned comment exists."""
        comments = [
            YouTubeComment("Great!", "user1", "User 1", False, False),
        ]
        pinned = get_pinned_comment(comments)
        assert pinned is None
