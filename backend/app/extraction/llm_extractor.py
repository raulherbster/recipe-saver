"""LLM-based recipe extraction for when schema.org is not available."""

import json
from typing import Optional
from dataclasses import dataclass, field

from openai import AsyncOpenAI

from app.config import get_settings
from app.extraction.recipe_sites import ParsedIngredient, SchemaRecipe


# Categories taxonomy
CATEGORY_TAXONOMY = {
    "dietary": ["vegetarian", "vegan", "pescatarian", "gluten-free", "dairy-free", "keto", "paleo"],
    "protein": ["chicken", "beef", "pork", "fish", "seafood", "tofu", "legumes", "eggs"],
    "course": ["breakfast", "lunch", "dinner", "snack", "dessert", "appetizer", "side-dish", "drink"],
    "cuisine": [
        "italian", "mexican", "indian", "thai", "japanese", "chinese", "korean",
        "mediterranean", "middle-eastern", "french", "american", "greek", "vietnamese"
    ],
    "method": ["baking", "grilling", "frying", "slow-cooker", "one-pot", "air-fryer", "instant-pot", "no-cook", "stir-fry"],
    "season": ["spring", "summer", "fall", "winter"],
    "difficulty": ["easy", "medium", "hard"],
    "time": ["under-15m", "15-30m", "30-60m", "over-60m"],
}

EXTRACTION_PROMPT = """Extract a structured recipe from the following content. The content may be a video transcript, description, or caption.

Return ONLY valid JSON matching this exact schema (no markdown, no explanation):

{{
  "title": "string - recipe name",
  "description": "string - 1-2 sentence description, or null",
  "ingredients": [
    {{
      "raw_text": "original text",
      "name": "ingredient name",
      "quantity": "amount or null",
      "unit": "unit or null",
      "preparation": "prep notes or null"
    }}
  ],
  "instructions": ["Step 1...", "Step 2..."],
  "prep_time_mins": "number or null",
  "cook_time_mins": "number or null",
  "total_time_mins": "number or null",
  "servings": "string or null",
  "difficulty": "easy|medium|hard",
  "categories": {{
    "dietary": ["vegetarian", ...],
    "protein": ["chicken", ...],
    "course": ["dinner", ...],
    "cuisine": ["italian", ...],
    "method": ["baking", ...],
    "season": ["summer", ...],
    "time": ["30-60m", ...]
  }},
  "tags": ["#hashtag1", "keyword2", ...]
}}

ALLOWED CATEGORY VALUES:
- dietary: {dietary}
- protein: {protein}
- course: {course}
- cuisine: {cuisine}
- method: {method}
- season: {season}
- difficulty: {difficulty}
- time: {time}

RULES:
1. If ingredients aren't explicitly listed, infer from context
2. If instructions aren't step-by-step, create logical steps from the content
3. If info is missing, use null (don't guess times or servings)
4. Extract any #hashtags as tags
5. Only use categories from the allowed values above
6. For "time" category, estimate based on prep+cook time

---
CONTENT TO PARSE:

Video/Post Title: {title}

Description/Caption:
{description}

Transcript/Additional Text:
{transcript}
---

Return ONLY the JSON object:"""


@dataclass
class LLMExtractionResult:
    """Result from LLM extraction."""
    recipe: Optional[SchemaRecipe] = None
    categories: dict[str, list[str]] = field(default_factory=dict)
    tags: list[str] = field(default_factory=list)
    raw_response: Optional[str] = None
    confidence: float = 0.0
    error: Optional[str] = None


def build_extraction_prompt(
    title: str,
    description: Optional[str],
    transcript: Optional[str],
) -> str:
    """Build the extraction prompt with category values filled in."""
    return EXTRACTION_PROMPT.format(
        title=title or "Unknown",
        description=description or "(none)",
        transcript=transcript or "(none)",
        dietary=", ".join(CATEGORY_TAXONOMY["dietary"]),
        protein=", ".join(CATEGORY_TAXONOMY["protein"]),
        course=", ".join(CATEGORY_TAXONOMY["course"]),
        cuisine=", ".join(CATEGORY_TAXONOMY["cuisine"]),
        method=", ".join(CATEGORY_TAXONOMY["method"]),
        season=", ".join(CATEGORY_TAXONOMY["season"]),
        difficulty=", ".join(CATEGORY_TAXONOMY["difficulty"]),
        time=", ".join(CATEGORY_TAXONOMY["time"]),
    )


def parse_llm_response(response_text: str) -> Optional[dict]:
    """Parse JSON from LLM response, handling common issues."""
    # Try direct parse first
    try:
        return json.loads(response_text)
    except json.JSONDecodeError:
        pass

    # Try to extract JSON from markdown code block
    import re
    json_match = re.search(r'```(?:json)?\s*([\s\S]*?)\s*```', response_text)
    if json_match:
        try:
            return json.loads(json_match.group(1))
        except json.JSONDecodeError:
            pass

    # Try to find JSON object in text
    json_match = re.search(r'\{[\s\S]*\}', response_text)
    if json_match:
        try:
            return json.loads(json_match.group(0))
        except json.JSONDecodeError:
            pass

    return None


def convert_llm_to_schema_recipe(data: dict, source_url: Optional[str] = None) -> SchemaRecipe:
    """Convert LLM extraction result to SchemaRecipe format."""
    # Parse ingredients
    ingredients = []
    for ing in data.get("ingredients", []):
        if isinstance(ing, dict):
            ingredients.append(ParsedIngredient(
                raw_text=ing.get("raw_text", ""),
                name=ing.get("name", ""),
                quantity=ing.get("quantity"),
                unit=ing.get("unit"),
                preparation=ing.get("preparation"),
            ))
        elif isinstance(ing, str):
            ingredients.append(ParsedIngredient(
                raw_text=ing,
                name=ing,
            ))

    # Parse instructions
    instructions = data.get("instructions", [])
    if isinstance(instructions, str):
        instructions = [s.strip() for s in instructions.split('\n') if s.strip()]

    return SchemaRecipe(
        title=data.get("title", "Untitled Recipe"),
        description=data.get("description"),
        ingredients=ingredients,
        instructions=instructions,
        prep_time_mins=data.get("prep_time_mins"),
        cook_time_mins=data.get("cook_time_mins"),
        total_time_mins=data.get("total_time_mins"),
        servings=data.get("servings"),
        source_url=source_url,
    )


async def extract_recipe_with_llm(
    title: str,
    description: Optional[str],
    transcript: Optional[str],
    source_url: Optional[str] = None,
) -> LLMExtractionResult:
    """Use LLM to extract recipe from unstructured text."""
    settings = get_settings()

    if not settings.openai_api_key:
        return LLMExtractionResult(
            error="OpenAI API key not configured",
            confidence=0.0,
        )

    # Build prompt
    prompt = build_extraction_prompt(title, description, transcript)

    try:
        client = AsyncOpenAI(api_key=settings.openai_api_key)

        response = await client.chat.completions.create(
            model=settings.openai_model,
            messages=[
                {
                    "role": "system",
                    "content": "You are a recipe extraction assistant. Extract structured recipe data from video transcripts and descriptions. Always respond with valid JSON only."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            temperature=0.2,
            max_tokens=4000,
        )

        response_text = response.choices[0].message.content
        if not response_text:
            return LLMExtractionResult(
                error="Empty response from LLM",
                confidence=0.0,
            )

        # Parse response
        data = parse_llm_response(response_text)
        if not data:
            return LLMExtractionResult(
                error="Could not parse JSON from LLM response",
                raw_response=response_text,
                confidence=0.0,
            )

        # Convert to recipe
        recipe = convert_llm_to_schema_recipe(data, source_url)

        # Calculate confidence based on completeness
        confidence = calculate_extraction_confidence(recipe)

        # Extract categories and tags
        categories = data.get("categories", {})
        # Validate categories against taxonomy
        validated_categories = {}
        for cat_type, values in categories.items():
            if cat_type in CATEGORY_TAXONOMY:
                valid_values = [v for v in values if v in CATEGORY_TAXONOMY[cat_type]]
                if valid_values:
                    validated_categories[cat_type] = valid_values

        tags = data.get("tags", [])
        if isinstance(tags, str):
            tags = [tags]

        return LLMExtractionResult(
            recipe=recipe,
            categories=validated_categories,
            tags=tags,
            raw_response=response_text,
            confidence=confidence,
        )

    except Exception as e:
        return LLMExtractionResult(
            error=f"LLM extraction failed: {str(e)}",
            confidence=0.0,
        )


def calculate_extraction_confidence(recipe: SchemaRecipe) -> float:
    """Calculate confidence score based on recipe completeness."""
    score = 0.0
    max_score = 0.0

    # Title (required)
    max_score += 1.0
    if recipe.title and recipe.title != "Untitled Recipe":
        score += 1.0

    # Ingredients (important)
    max_score += 2.0
    if recipe.ingredients:
        if len(recipe.ingredients) >= 3:
            score += 2.0
        elif len(recipe.ingredients) >= 1:
            score += 1.0

    # Instructions (important)
    max_score += 2.0
    if recipe.instructions:
        if len(recipe.instructions) >= 3:
            score += 2.0
        elif len(recipe.instructions) >= 1:
            score += 1.0

    # Times (nice to have)
    max_score += 1.0
    if recipe.total_time_mins or (recipe.prep_time_mins and recipe.cook_time_mins):
        score += 1.0

    # Servings (nice to have)
    max_score += 0.5
    if recipe.servings:
        score += 0.5

    # Description (nice to have)
    max_score += 0.5
    if recipe.description:
        score += 0.5

    return round(score / max_score, 2) if max_score > 0 else 0.0
