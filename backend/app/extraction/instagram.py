"""Instagram Reels metadata extraction via yt-dlp."""

import json
import re
import subprocess
from dataclasses import dataclass, field
from typing import Optional

from app.extraction.youtube import (
    _yt_dlp_cmd,
    extract_recipe_links_from_patterns,
    extract_urls_from_text,
)
from app.extraction.recipe_sites import (
    fetch_and_parse_recipe_url,
    is_non_recipe_platform,
    is_shortened_url,
    expand_shortened_url,
    parse_recipe_from_description,
)
from app.extraction.llm_extractor import extract_recipe_with_llm


@dataclass
class InstagramContent:
    """Extracted Instagram Reel metadata."""
    title: str                          # from yt-dlp 'title' or caption first line
    caption: str                        # full post caption (description in yt-dlp JSON)
    thumbnail_url: Optional[str]
    author_name: Optional[str]
    hashtags: list[str] = field(default_factory=list)  # extracted from caption (#tag)


def is_instagram_reel(url: str) -> bool:
    """Return True only for instagram.com/reel/... URLs."""
    return bool(re.search(r'instagram\.com/reel/', url, re.IGNORECASE))


async def fetch_instagram_metadata(url: str) -> Optional[InstagramContent]:
    """Fetch Instagram Reel metadata using yt-dlp --dump-json --no-download."""
    try:
        result = subprocess.run(
            [
                _yt_dlp_cmd(),
                "--dump-json",
                "--no-download",
                url,
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )

        if result.returncode != 0:
            return None

        data = json.loads(result.stdout)

        caption = data.get("description", "") or ""
        title = data.get("title", "") or ""

        # If title is missing or generic, use the first line of the caption
        if not title and caption:
            title = caption.splitlines()[0].strip()

        # Extract hashtags from caption
        hashtags = [f"#{tag}" for tag in re.findall(r'#(\w+)', caption)]

        return InstagramContent(
            title=title,
            caption=caption,
            thumbnail_url=data.get("thumbnail"),
            author_name=data.get("uploader") or data.get("channel"),
            hashtags=hashtags,
        )

    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error fetching Instagram metadata: {e}")
        return None


async def extract_from_instagram(url: str) -> "ExtractionResult":
    """
    Extract recipe from an Instagram Reel URL using yt-dlp.

    Uses multiple heuristics in order of confidence:
    1. Pattern-matched recipe URLs from caption (confidence: 0.95)
    2. Bare URLs from caption -> schema.org (confidence: 0.90)
    3. Parse recipe directly from caption (confidence: 0.75)
    4. LLM extraction from caption (confidence: 0.30-0.60 fallback)
    """
    # Import here to avoid circular imports
    from app.extraction.pipeline import ExtractionResult, ExtractionMethod, SourcePlatform

    # Step 1: Fetch metadata via yt-dlp
    content = await fetch_instagram_metadata(url)
    if not content:
        return ExtractionResult(
            success=False,
            method=ExtractionMethod.FAILED,
            source_platform=SourcePlatform.INSTAGRAM,
            video_url=url,
            error="Could not fetch Instagram Reel metadata",
        )

    caption = content.caption
    hashtags = content.hashtags

    # Collect all found URLs for reporting
    all_found_urls: list[str] = []

    # Step 2: Pattern-matched URLs from caption -> schema.org (confidence: 0.95)
    pattern_urls = extract_recipe_links_from_patterns(caption)
    all_found_urls.extend(pattern_urls)

    for recipe_url in pattern_urls:
        parsed = await fetch_and_parse_recipe_url(recipe_url)
        if parsed and parsed.ingredients:
            return ExtractionResult(
                success=True,
                method=ExtractionMethod.SCHEMA_ORG,
                recipe=parsed,
                source_platform=SourcePlatform.INSTAGRAM,
                video_url=url,
                recipe_page_url=recipe_url,
                recipe_site_name=parsed.site_name,
                thumbnail_url=content.thumbnail_url,
                original_caption=caption,
                author_name=parsed.author or content.author_name,
                tags=hashtags,
                confidence=0.95,
                found_recipe_urls=list(set(all_found_urls)),
            )

    # Step 3: Bare URLs from caption -> schema.org (confidence: 0.90)
    bare_urls = extract_urls_from_text(caption)
    already_tried = set(pattern_urls)

    for recipe_url in bare_urls:
        if recipe_url in already_tried:
            continue
        if is_non_recipe_platform(recipe_url):
            continue

        # Expand shortened URLs before attempting extraction
        if is_shortened_url(recipe_url):
            expanded = await expand_shortened_url(recipe_url)
            recipe_url = expanded or recipe_url

        all_found_urls.append(recipe_url)
        parsed = await fetch_and_parse_recipe_url(recipe_url)
        if parsed and parsed.ingredients:
            return ExtractionResult(
                success=True,
                method=ExtractionMethod.SCHEMA_ORG,
                recipe=parsed,
                source_platform=SourcePlatform.INSTAGRAM,
                video_url=url,
                recipe_page_url=recipe_url,
                recipe_site_name=parsed.site_name,
                thumbnail_url=content.thumbnail_url,
                original_caption=caption,
                author_name=parsed.author or content.author_name,
                tags=hashtags,
                confidence=0.90,
                found_recipe_urls=list(set(all_found_urls)),
            )

    # Step 4: Parse recipe directly from caption (confidence: 0.75)
    if caption:
        description_recipe = parse_recipe_from_description(caption, content.title)
        if description_recipe and description_recipe.ingredients:
            return ExtractionResult(
                success=True,
                method=ExtractionMethod.DESCRIPTION_PARSED,
                recipe=description_recipe,
                source_platform=SourcePlatform.INSTAGRAM,
                video_url=url,
                thumbnail_url=content.thumbnail_url,
                original_caption=caption,
                author_name=content.author_name,
                tags=hashtags,
                confidence=0.75,
                found_recipe_urls=list(set(all_found_urls)),
            )

    # Step 5: LLM extraction from caption (confidence: 0.30-0.60 fallback)
    if caption:
        llm_result = await extract_recipe_with_llm(
            title=content.title or "Instagram Recipe",
            description=caption,
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
                thumbnail_url=content.thumbnail_url,
                original_caption=caption,
                author_name=content.author_name,
                categories=llm_result.categories,
                tags=all_tags,
                confidence=llm_result.confidence,
                raw_data=llm_result.raw_response,
                found_recipe_urls=list(set(all_found_urls)),
            )

    # Extraction failed
    return ExtractionResult(
        success=False,
        method=ExtractionMethod.FAILED,
        source_platform=SourcePlatform.INSTAGRAM,
        video_url=url,
        thumbnail_url=content.thumbnail_url,
        original_caption=caption,
        author_name=content.author_name,
        error="Could not extract recipe from Instagram Reel",
        found_recipe_urls=list(set(all_found_urls)),
        tags=hashtags,
    )
