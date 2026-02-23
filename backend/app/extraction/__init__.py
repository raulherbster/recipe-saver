"""Recipe extraction services."""

from app.extraction.pipeline import (
    extract_recipe,
    ExtractionResult,
    ExtractionMethod,
    SourcePlatform,
)
from app.extraction.youtube import extract_youtube_content, YouTubeContent
from app.extraction.recipe_sites import (
    fetch_and_parse_recipe_url,
    SchemaRecipe,
    ParsedIngredient,
    is_recipe_url,
    filter_recipe_urls,
)
from app.extraction.llm_extractor import (
    extract_recipe_with_llm,
    CATEGORY_TAXONOMY,
)
from app.extraction.url_utils import (
    preprocess_share_url,
    clean_url,
    extract_url_from_share_text,
)

__all__ = [
    "extract_recipe",
    "ExtractionResult",
    "ExtractionMethod",
    "SourcePlatform",
    "extract_youtube_content",
    "YouTubeContent",
    "fetch_and_parse_recipe_url",
    "SchemaRecipe",
    "ParsedIngredient",
    "is_recipe_url",
    "filter_recipe_urls",
    "extract_recipe_with_llm",
    "CATEGORY_TAXONOMY",
    "preprocess_share_url",
    "clean_url",
    "extract_url_from_share_text",
]
