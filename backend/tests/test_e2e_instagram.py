"""End-to-end tests for Instagram Reel recipe extraction.

These tests make real network requests to Instagram via yt-dlp.
Run them explicitly with:

    pytest -m e2e

They are intentionally excluded from the fast unit-test suite.
"""

import pytest
from app.extraction.instagram import extract_from_instagram
from app.extraction.pipeline import ExtractionMethod, SourcePlatform


pytestmark = pytest.mark.e2e


# ---------------------------------------------------------------------------
# Case 1: Recipe extractable from Reel (via caption link or caption text)
# ---------------------------------------------------------------------------
# The pipeline may use SCHEMA_ORG (if a recipe URL is found in the caption)
# or DESCRIPTION_PARSED (if the recipe is embedded directly in the caption).
# Either is a valid success — we just assert the recipe was extracted.
# ---------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_recipe_embedded_in_reel_caption():
    url = "https://www.instagram.com/reel/Cx8Nf5-OLoX/"
    result = await extract_from_instagram(url)
    assert result.success, f"Extraction failed: {result.error}"
    assert result.source_platform == SourcePlatform.INSTAGRAM
    assert result.method in (ExtractionMethod.DESCRIPTION_PARSED, ExtractionMethod.SCHEMA_ORG)
    assert result.recipe is not None
    assert len(result.recipe.ingredients) >= 3
    assert result.video_url == url
