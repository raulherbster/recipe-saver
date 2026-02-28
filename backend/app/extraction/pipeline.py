"""Main extraction pipeline that orchestrates all extraction methods."""

from typing import Optional
from dataclasses import dataclass, field
from enum import Enum

from app.extraction.youtube import (
    extract_youtube_content,
    YouTubeContent,
    extract_urls_from_text,
    extract_recipe_links_from_patterns,
)
from app.extraction.recipe_sites import (
    filter_recipe_urls,
    expand_and_filter_recipe_urls,
    fetch_and_parse_recipe_url,
    SchemaRecipe,
    ParsedIngredient,
)
from app.extraction.llm_extractor import (
    extract_recipe_with_llm,
    CATEGORY_TAXONOMY,
)
from app.extraction.url_utils import preprocess_share_url
from app.extraction.recipe_search import search_recipe_sites
from app.config import get_settings


class ExtractionMethod(str, Enum):
    SCHEMA_ORG = "schema_org"
    LLM_TRANSCRIPT = "llm_transcript"
    MANUAL = "manual"
    FAILED = "failed"


class SourcePlatform(str, Enum):
    YOUTUBE = "youtube"
    INSTAGRAM = "instagram"
    DIRECT_URL = "direct_url"
    MANUAL = "manual"


@dataclass
class ExtractionResult:
    """Complete result of the extraction pipeline."""
    success: bool
    method: ExtractionMethod
    recipe: Optional[SchemaRecipe] = None

    # Source info
    source_platform: Optional[SourcePlatform] = None
    video_url: Optional[str] = None
    recipe_page_url: Optional[str] = None
    recipe_site_name: Optional[str] = None
    thumbnail_url: Optional[str] = None
    original_caption: Optional[str] = None
    author_name: Optional[str] = None

    # Categories and tags (from LLM or inferred)
    categories: dict[str, list[str]] = field(default_factory=dict)
    tags: list[str] = field(default_factory=list)

    # Metadata
    confidence: float = 0.0
    raw_data: Optional[str] = None
    error: Optional[str] = None

    # URLs found during extraction
    found_recipe_urls: list[str] = field(default_factory=list)


def detect_platform(url: str) -> SourcePlatform:
    """Detect the source platform from URL."""
    url_lower = url.lower()
    if "youtube.com" in url_lower or "youtu.be" in url_lower:
        return SourcePlatform.YOUTUBE
    elif "instagram.com" in url_lower:
        return SourcePlatform.INSTAGRAM
    else:
        return SourcePlatform.DIRECT_URL


def extract_hashtags(text: Optional[str]) -> list[str]:
    """Extract hashtags from text."""
    if not text:
        return []

    import re
    hashtags = re.findall(r'#(\w+)', text)
    return [f"#{tag}" for tag in hashtags]


async def try_schema_extraction(
    recipe_url: str,
    yt_content: YouTubeContent,
    hashtags: list[str],
    url: str,
    confidence: float,
    all_found_urls: list[str],
) -> Optional[ExtractionResult]:
    """Helper to try schema.org extraction from a URL."""
    parsed = await fetch_and_parse_recipe_url(recipe_url)
    if parsed and parsed.ingredients:
        return ExtractionResult(
            success=True,
            method=ExtractionMethod.SCHEMA_ORG,
            recipe=parsed,
            source_platform=SourcePlatform.YOUTUBE,
            video_url=url,
            recipe_page_url=recipe_url,
            recipe_site_name=parsed.site_name,
            thumbnail_url=yt_content.metadata.thumbnail_url,
            original_caption=yt_content.metadata.description,
            author_name=parsed.author or yt_content.metadata.channel_name,
            tags=hashtags,
            confidence=confidence,
            found_recipe_urls=all_found_urls,
        )
    return None


async def extract_from_youtube(url: str) -> ExtractionResult:
    """
    Extract recipe from a YouTube video URL.

    Uses multiple heuristics in order of confidence:
    1. URLs from description (confidence: 0.95)
    2. Pattern-matched URLs ("recipe here:", etc.) (confidence: 0.90)
    3. URLs from author's comments (confidence: 0.85)
    4. Web search by title + author (confidence: 0.70-0.80)
    5. LLM extraction from transcript (confidence: 0.30-0.60)
    """
    settings = get_settings()

    # Step 1: Fetch YouTube content (includes comments now)
    yt_content = await extract_youtube_content(url, settings.max_transcript_length)

    if not yt_content:
        return ExtractionResult(
            success=False,
            method=ExtractionMethod.FAILED,
            source_platform=SourcePlatform.YOUTUBE,
            video_url=url,
            error="Could not fetch YouTube video metadata",
        )

    # Extract hashtags from description
    hashtags = extract_hashtags(yt_content.metadata.description)

    # Collect all URLs found for reporting
    all_found_urls = list(set(
        yt_content.extracted_urls +
        (yt_content.pattern_matched_urls or [])
    ))

    # Step 2: Try URLs from description/pinned comment (existing behavior)
    recipe_urls = await expand_and_filter_recipe_urls(yt_content.extracted_urls)

    for recipe_url in recipe_urls:
        result = await try_schema_extraction(
            recipe_url, yt_content, hashtags, url,
            confidence=0.95, all_found_urls=all_found_urls
        )
        if result:
            return result

    # Step 3: Try pattern-matched URLs ("get the recipe here:", etc.)
    if yt_content.pattern_matched_urls:
        pattern_recipe_urls = await expand_and_filter_recipe_urls(
            yt_content.pattern_matched_urls
        )
        for recipe_url in pattern_recipe_urls:
            result = await try_schema_extraction(
                recipe_url, yt_content, hashtags, url,
                confidence=0.90, all_found_urls=all_found_urls
            )
            if result:
                return result

    # Step 4: Try URLs from author's comments
    if yt_content.author_comments:
        for comment in yt_content.author_comments:
            comment_urls = extract_urls_from_text(comment)
            # Also check for pattern matches in author comments
            comment_urls.extend(extract_recipe_links_from_patterns(comment))

            author_recipe_urls = await expand_and_filter_recipe_urls(comment_urls)
            for recipe_url in author_recipe_urls:
                result = await try_schema_extraction(
                    recipe_url, yt_content, hashtags, url,
                    confidence=0.85, all_found_urls=all_found_urls
                )
                if result:
                    return result

    # Step 5: Try web search by title + author (for Shorts with minimal description)
    try:
        search_results = await search_recipe_sites(
            title=yt_content.metadata.title,
            author=yt_content.metadata.channel_name,
            min_similarity=0.4,  # Require reasonable title match
            max_results=5,
        )

        for search_result in search_results:
            # Higher similarity = higher confidence
            confidence = 0.80 if search_result.similarity_score > 0.7 else 0.70
            result = await try_schema_extraction(
                search_result.url, yt_content, hashtags, url,
                confidence=confidence, all_found_urls=all_found_urls
            )
            if result:
                return result
    except Exception as e:
        # Web search is optional - don't fail if it errors
        print(f"Web search failed: {e}")

    # Step 6: Fall back to LLM extraction from transcript
    if yt_content.transcript or yt_content.metadata.description:
        llm_result = await extract_recipe_with_llm(
            title=yt_content.metadata.title,
            description=yt_content.metadata.description,
            transcript=yt_content.transcript,
            source_url=url,
        )

        if llm_result.recipe and llm_result.confidence > 0.3:
            # Merge hashtags with LLM tags
            all_tags = list(set(hashtags + llm_result.tags))

            return ExtractionResult(
                success=True,
                method=ExtractionMethod.LLM_TRANSCRIPT,
                recipe=llm_result.recipe,
                source_platform=SourcePlatform.YOUTUBE,
                video_url=url,
                thumbnail_url=yt_content.metadata.thumbnail_url,
                original_caption=yt_content.metadata.description,
                author_name=yt_content.metadata.channel_name,
                categories=llm_result.categories,
                tags=all_tags,
                confidence=llm_result.confidence,
                raw_data=llm_result.raw_response,
                found_recipe_urls=all_found_urls,
            )

    # Step 7: Extraction failed
    error_msg = "Could not extract recipe - no recipe link found and transcript parsing failed"
    if yt_content.has_link_in_bio:
        error_msg += " (Note: creator mentioned recipe is in their bio/profile)"

    return ExtractionResult(
        success=False,
        method=ExtractionMethod.FAILED,
        source_platform=SourcePlatform.YOUTUBE,
        video_url=url,
        thumbnail_url=yt_content.metadata.thumbnail_url,
        original_caption=yt_content.metadata.description,
        author_name=yt_content.metadata.channel_name,
        error=error_msg,
        found_recipe_urls=all_found_urls,
        tags=hashtags,
    )


async def extract_from_instagram(
    url: str,
    manual_caption: Optional[str] = None,
    manual_recipe_url: Optional[str] = None,
) -> ExtractionResult:
    """Extract recipe from Instagram (requires manual assistance)."""

    # If user provided a recipe URL, try that first
    if manual_recipe_url:
        parsed = await fetch_and_parse_recipe_url(manual_recipe_url)
        if parsed and parsed.ingredients:
            hashtags = extract_hashtags(manual_caption)
            return ExtractionResult(
                success=True,
                method=ExtractionMethod.SCHEMA_ORG,
                recipe=parsed,
                source_platform=SourcePlatform.INSTAGRAM,
                video_url=url,
                recipe_page_url=manual_recipe_url,
                recipe_site_name=parsed.site_name,
                original_caption=manual_caption,
                author_name=parsed.author,
                tags=hashtags,
                confidence=0.9,
            )

    # If user provided caption text, extract with LLM
    if manual_caption:
        # Look for URLs in caption
        from app.extraction.youtube import extract_urls_from_text
        urls_in_caption = extract_urls_from_text(manual_caption)
        recipe_urls = filter_recipe_urls(urls_in_caption)

        # Try schema.org from any recipe URLs
        for recipe_url in recipe_urls:
            parsed = await fetch_and_parse_recipe_url(recipe_url)
            if parsed and parsed.ingredients:
                hashtags = extract_hashtags(manual_caption)
                return ExtractionResult(
                    success=True,
                    method=ExtractionMethod.SCHEMA_ORG,
                    recipe=parsed,
                    source_platform=SourcePlatform.INSTAGRAM,
                    video_url=url,
                    recipe_page_url=recipe_url,
                    recipe_site_name=parsed.site_name,
                    original_caption=manual_caption,
                    author_name=parsed.author,
                    tags=hashtags,
                    confidence=0.9,
                    found_recipe_urls=recipe_urls,
                )

        # Fall back to LLM extraction
        hashtags = extract_hashtags(manual_caption)
        llm_result = await extract_recipe_with_llm(
            title="Instagram Recipe",
            description=manual_caption,
            transcript=None,
            source_url=url,
        )

        if llm_result.recipe and llm_result.confidence > 0.3:
            all_tags = list(set(hashtags + llm_result.tags))
            return ExtractionResult(
                success=True,
                method=ExtractionMethod.LLM_TRANSCRIPT,
                recipe=llm_result.recipe,
                source_platform=SourcePlatform.INSTAGRAM,
                video_url=url,
                original_caption=manual_caption,
                categories=llm_result.categories,
                tags=all_tags,
                confidence=llm_result.confidence,
                raw_data=llm_result.raw_response,
                found_recipe_urls=recipe_urls,
            )

    # No data provided
    return ExtractionResult(
        success=False,
        method=ExtractionMethod.FAILED,
        source_platform=SourcePlatform.INSTAGRAM,
        video_url=url,
        error="Instagram requires manual caption or recipe URL",
    )


async def extract_from_direct_url(url: str) -> ExtractionResult:
    """Extract recipe from a direct recipe page URL."""
    parsed = await fetch_and_parse_recipe_url(url)

    if parsed and parsed.ingredients:
        return ExtractionResult(
            success=True,
            method=ExtractionMethod.SCHEMA_ORG,
            recipe=parsed,
            source_platform=SourcePlatform.DIRECT_URL,
            recipe_page_url=url,
            recipe_site_name=parsed.site_name,
            author_name=parsed.author,
            confidence=0.95,
        )

    return ExtractionResult(
        success=False,
        method=ExtractionMethod.FAILED,
        source_platform=SourcePlatform.DIRECT_URL,
        recipe_page_url=url,
        error="Could not extract recipe from URL - no schema.org/Recipe found",
    )


async def extract_recipe(
    url: str,
    manual_caption: Optional[str] = None,
    manual_recipe_url: Optional[str] = None,
) -> ExtractionResult:
    """
    Main extraction entry point.

    Determines the source platform and routes to the appropriate extractor.

    The URL is preprocessed to handle:
    - Mobile share intent text with embedded URLs
    - Tracking parameters (utm_*, igsh, si, etc.)
    - Mobile-specific URL formats (m.youtube.com, youtu.be, etc.)
    """
    # Preprocess the URL to handle share intent formats
    url = preprocess_share_url(url)

    # Also preprocess manual_recipe_url if provided
    if manual_recipe_url:
        manual_recipe_url = preprocess_share_url(manual_recipe_url)

    platform = detect_platform(url)

    if platform == SourcePlatform.YOUTUBE:
        return await extract_from_youtube(url)
    elif platform == SourcePlatform.INSTAGRAM:
        return await extract_from_instagram(url, manual_caption, manual_recipe_url)
    else:
        # Assume it's a direct recipe URL
        return await extract_from_direct_url(url)
