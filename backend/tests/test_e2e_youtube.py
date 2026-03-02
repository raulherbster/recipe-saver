"""End-to-end tests for YouTube recipe extraction.

These tests make real network requests to YouTube and recipe sites.
Run them explicitly with:

    pytest -m e2e

They are intentionally excluded from the fast unit-test suite.
"""

import pytest
from app.extraction.pipeline import extract_from_youtube, ExtractionMethod, SourcePlatform


pytestmark = pytest.mark.e2e


# ---------------------------------------------------------------------------
# Case 1: Recipe URL embedded in the video description
# ---------------------------------------------------------------------------
# Video: "Marry Me Chicken" by Natashas Kitchen (regular long-form video).
# The description contains a direct link to the recipe page on natashaskitchen.com.
# Expected extraction path: step 2 (URLs from description) → SCHEMA_ORG.
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_recipe_url_in_description():
    url = "https://www.youtube.com/watch?v=X9lSvOYvs_M"
    result = await extract_from_youtube(url)

    assert result.success, f"Extraction failed: {result.error}"
    assert result.source_platform == SourcePlatform.YOUTUBE
    assert result.method == ExtractionMethod.SCHEMA_ORG, (
        f"Expected SCHEMA_ORG (URL from description) but got {result.method}"
    )
    assert result.recipe is not None
    assert len(result.recipe.ingredients) >= 5, (
        f"Expected at least 5 ingredients, got {len(result.recipe.ingredients)}"
    )
    assert result.recipe_page_url is not None, "Expected a recipe page URL"
    assert result.video_url == url


# ---------------------------------------------------------------------------
# Case 2: Recipe URL in the video owner's comment (YouTube Shorts)
# ---------------------------------------------------------------------------
# Video: a Short where the channel author posted a pinned comment with
# the recipe link (e.g. "Grab the recipe here: https://...").
# Expected extraction path: step 4 (author comments, pattern match) → SCHEMA_ORG.
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_recipe_url_in_author_comment():
    url = "https://www.youtube.com/shorts/0cH6qL3H21Y"
    result = await extract_from_youtube(url)

    assert result.success, f"Extraction failed: {result.error}"
    assert result.source_platform == SourcePlatform.YOUTUBE
    assert result.method == ExtractionMethod.SCHEMA_ORG, (
        f"Expected SCHEMA_ORG (URL from author comment) but got {result.method}"
    )
    assert result.recipe is not None
    assert len(result.recipe.ingredients) >= 3, (
        f"Expected at least 3 ingredients, got {len(result.recipe.ingredients)}"
    )
    assert result.recipe_page_url is not None, "Expected a recipe page URL"
    assert result.video_url == url


# ---------------------------------------------------------------------------
# Case 3: Full recipe (ingredients) embedded in the video description
# ---------------------------------------------------------------------------
# Video: Claire Saffitz pumpkin pie — no external recipe link, but the
# description contains an "Ingredients:" section with the full ingredient list.
# Expected extraction path: step 6 (parse_recipe_from_description) → DESCRIPTION_PARSED.
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_recipe_embedded_in_description():
    url = "https://www.youtube.com/watch?v=vT4Kk9v3B5Y"
    result = await extract_from_youtube(url)

    assert result.success, f"Extraction failed: {result.error}"
    assert result.source_platform == SourcePlatform.YOUTUBE
    assert result.method == ExtractionMethod.DESCRIPTION_PARSED, (
        f"Expected DESCRIPTION_PARSED but got {result.method}"
    )
    assert result.recipe is not None
    assert len(result.recipe.ingredients) >= 5, (
        f"Expected at least 5 ingredients, got {len(result.recipe.ingredients)}"
    )
    # No external recipe page for this case
    assert result.recipe_page_url is None
    assert result.video_url == url
