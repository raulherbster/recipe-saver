"""Recipe site URL detection and schema.org/Recipe parsing."""

import re
import json
from typing import Optional
from dataclasses import dataclass, field
from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup


# Known recipe domains that typically have schema.org/Recipe
KNOWN_RECIPE_DOMAINS = [
    # Major recipe sites
    "cooking.nytimes.com",
    "nytimes.com",
    "seriouseats.com",
    "bonappetit.com",
    "epicurious.com",
    "food52.com",
    "allrecipes.com",
    "foodnetwork.com",
    "delish.com",
    "thekitchn.com",
    "simplyrecipes.com",
    "budgetbytes.com",
    "smittenkitchen.com",
    "minimalistbaker.com",
    "halfbakedharvest.com",
    "pinchofyum.com",
    "cookieandkate.com",
    "loveandlemons.com",
    "skinnytaste.com",
    "recipetineats.com",
    "sallysbakingaddiction.com",
    "hostthetoast.com",
    "justonecookbook.com",
    "davidlebovitz.com",
    "kingarthurbaking.com",
    "jocooks.com",
    "gimmesomeoven.com",
    "cafedelites.com",
    "damndelicious.net",
    "therecipecritic.com",
    "tasteofhome.com",
    "myrecipes.com",
    "eatingwell.com",
    "marthastewart.com",
    "tasty.co",
    # International
    "bbcgoodfood.com",
    "bbc.co.uk",
    "ricardocuisine.com",
    "marmiton.org",
    "chefkoch.de",
    # Food blogs often have recipes
    "themediterraneandish.com",
    "feelgoodfoodie.net",
    "wellplated.com",
]

# Patterns that indicate a recipe URL
RECIPE_PATH_PATTERNS = [
    r'/recipe[s]?/',
    r'/recette[s]?/',
    r'/rezept[e]?/',
]


@dataclass
class ParsedIngredient:
    """Parsed ingredient with components."""
    raw_text: str
    name: str
    quantity: Optional[str] = None
    unit: Optional[str] = None
    preparation: Optional[str] = None


@dataclass
class SchemaRecipe:
    """Recipe extracted from schema.org/Recipe."""
    title: str
    description: Optional[str] = None
    ingredients: list[ParsedIngredient] = field(default_factory=list)
    instructions: list[str] = field(default_factory=list)
    prep_time_mins: Optional[int] = None
    cook_time_mins: Optional[int] = None
    total_time_mins: Optional[int] = None
    servings: Optional[str] = None
    cuisine: Optional[str] = None
    category: Optional[str] = None
    image_url: Optional[str] = None
    author: Optional[str] = None
    source_url: Optional[str] = None
    site_name: Optional[str] = None


def is_recipe_url(url: str) -> bool:
    """Check if a URL is likely a recipe page."""
    try:
        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        path = parsed.path.lower()

        # Remove www. prefix
        if domain.startswith("www."):
            domain = domain[4:]

        # Check known domains
        for known in KNOWN_RECIPE_DOMAINS:
            if known in domain:
                return True

        # Check path patterns
        for pattern in RECIPE_PATH_PATTERNS:
            if re.search(pattern, path):
                return True

        return False
    except Exception:
        return False


def filter_recipe_urls(urls: list[str]) -> list[str]:
    """Filter a list of URLs to only include likely recipe pages."""
    return [url for url in urls if is_recipe_url(url)]


def parse_iso_duration(duration: Optional[str]) -> Optional[int]:
    """Parse ISO 8601 duration to minutes."""
    if not duration:
        return None

    # Pattern: PT1H30M, PT45M, PT2H, etc.
    match = re.match(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?', duration)
    if not match:
        return None

    hours = int(match.group(1) or 0)
    minutes = int(match.group(2) or 0)
    seconds = int(match.group(3) or 0)

    total_minutes = hours * 60 + minutes + (seconds // 60)
    return total_minutes if total_minutes > 0 else None


def extract_image_url(image_data) -> Optional[str]:
    """Extract image URL from various schema.org formats."""
    if not image_data:
        return None

    if isinstance(image_data, str):
        return image_data

    if isinstance(image_data, list):
        # Take the first image
        if len(image_data) > 0:
            return extract_image_url(image_data[0])
        return None

    if isinstance(image_data, dict):
        return image_data.get("url") or image_data.get("contentUrl")

    return None


def extract_author_name(author_data) -> Optional[str]:
    """Extract author name from various schema.org formats."""
    if not author_data:
        return None

    if isinstance(author_data, str):
        return author_data

    if isinstance(author_data, list):
        if len(author_data) > 0:
            return extract_author_name(author_data[0])
        return None

    if isinstance(author_data, dict):
        return author_data.get("name")

    return None


def parse_schema_instructions(instructions_data) -> list[str]:
    """Parse recipe instructions from various schema.org formats."""
    if not instructions_data:
        return []

    if isinstance(instructions_data, str):
        # Split by common delimiters
        steps = re.split(r'\n+|\.\s+(?=[A-Z])', instructions_data)
        return [s.strip() for s in steps if s.strip()]

    if isinstance(instructions_data, list):
        steps = []
        for item in instructions_data:
            if isinstance(item, str):
                steps.append(item.strip())
            elif isinstance(item, dict):
                if item.get("@type") == "HowToSection":
                    # Section with multiple steps
                    section_name = item.get("name", "")
                    section_steps = parse_schema_instructions(item.get("itemListElement", []))
                    if section_name:
                        steps.append(f"**{section_name}**")
                    steps.extend(section_steps)
                elif item.get("@type") == "HowToStep":
                    text = item.get("text", "")
                    if text:
                        steps.append(text.strip())
        return steps

    return []


def parse_ingredient_text(raw_text: str) -> ParsedIngredient:
    """Parse a raw ingredient string into components."""
    # Basic parsing - can be enhanced with NLP
    raw_text = raw_text.strip()

    # Common patterns: "2 cups flour", "1/2 tsp salt", "3 large eggs"
    # This is a simplified parser; LLM can do better for complex cases

    quantity = None
    unit = None
    name = raw_text
    preparation = None

    # Extract quantity at the beginning
    quantity_match = re.match(r'^([\d½¼¾⅓⅔⅛/\-\s]+)', raw_text)
    if quantity_match:
        quantity = quantity_match.group(1).strip()
        remaining = raw_text[len(quantity_match.group(0)):].strip()
    else:
        remaining = raw_text

    # Common units
    units = [
        "cups?", "cup", "tablespoons?", "tbsp", "teaspoons?", "tsp",
        "pounds?", "lbs?", "lb", "ounces?", "oz",
        "grams?", "g", "kilograms?", "kg", "ml", "liters?", "l",
        "pieces?", "slices?", "cloves?", "heads?", "bunches?", "cans?",
        "packages?", "pinch(?:es)?", "dash(?:es)?", "large", "medium", "small"
    ]

    unit_pattern = rf'^({"|".join(units)})\s+'
    unit_match = re.match(unit_pattern, remaining, re.IGNORECASE)
    if unit_match:
        unit = unit_match.group(1).lower()
        name = remaining[len(unit_match.group(0)):].strip()
    else:
        name = remaining

    # Check for preparation notes (after comma or in parentheses)
    prep_match = re.search(r',\s*(.+)$|\(([^)]+)\)$', name)
    if prep_match:
        preparation = (prep_match.group(1) or prep_match.group(2)).strip()
        name = name[:prep_match.start()].strip()

    return ParsedIngredient(
        raw_text=raw_text,
        name=name,
        quantity=quantity,
        unit=unit,
        preparation=preparation,
    )


def parse_schema_ingredients(ingredients_data: list) -> list[ParsedIngredient]:
    """Parse recipe ingredients from schema.org format."""
    ingredients = []

    for item in ingredients_data:
        if isinstance(item, str):
            ingredients.append(parse_ingredient_text(item))
        elif isinstance(item, dict):
            # Some sites use nested structures
            text = item.get("text") or item.get("name") or str(item)
            ingredients.append(parse_ingredient_text(text))

    return ingredients


def find_schema_recipe(html: str) -> Optional[dict]:
    """Find schema.org/Recipe JSON-LD in HTML."""
    soup = BeautifulSoup(html, "lxml")

    # Look for JSON-LD script tags
    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string)

            # Handle @graph arrays
            if isinstance(data, dict) and "@graph" in data:
                for item in data["@graph"]:
                    if isinstance(item, dict) and item.get("@type") == "Recipe":
                        return item

            # Handle arrays
            if isinstance(data, list):
                for item in data:
                    if isinstance(item, dict) and item.get("@type") == "Recipe":
                        return item

            # Handle direct Recipe
            if isinstance(data, dict) and data.get("@type") == "Recipe":
                return data

        except json.JSONDecodeError:
            continue

    return None


def parse_schema_recipe(html: str, source_url: str) -> Optional[SchemaRecipe]:
    """Parse schema.org/Recipe from HTML page."""
    schema = find_schema_recipe(html)
    if not schema:
        return None

    # Extract site name from URL
    parsed_url = urlparse(source_url)
    site_name = parsed_url.netloc.replace("www.", "")

    return SchemaRecipe(
        title=schema.get("name", "Untitled Recipe"),
        description=schema.get("description"),
        ingredients=parse_schema_ingredients(schema.get("recipeIngredient", [])),
        instructions=parse_schema_instructions(schema.get("recipeInstructions")),
        prep_time_mins=parse_iso_duration(schema.get("prepTime")),
        cook_time_mins=parse_iso_duration(schema.get("cookTime")),
        total_time_mins=parse_iso_duration(schema.get("totalTime")),
        servings=schema.get("recipeYield") if isinstance(schema.get("recipeYield"), str)
                 else str(schema.get("recipeYield", [None])[0]) if isinstance(schema.get("recipeYield"), list)
                 else None,
        cuisine=schema.get("recipeCuisine") if isinstance(schema.get("recipeCuisine"), str)
                else schema.get("recipeCuisine", [None])[0] if isinstance(schema.get("recipeCuisine"), list)
                else None,
        category=schema.get("recipeCategory") if isinstance(schema.get("recipeCategory"), str)
                 else schema.get("recipeCategory", [None])[0] if isinstance(schema.get("recipeCategory"), list)
                 else None,
        image_url=extract_image_url(schema.get("image")),
        author=extract_author_name(schema.get("author")),
        source_url=source_url,
        site_name=site_name,
    )


async def fetch_and_parse_recipe_url(url: str) -> Optional[SchemaRecipe]:
    """Fetch a URL and attempt to parse schema.org/Recipe."""
    try:
        async with httpx.AsyncClient(
            follow_redirects=True,
            timeout=30.0,
            headers={
                "User-Agent": "Mozilla/5.0 (compatible; RecipeSaver/1.0; +https://github.com/recipe-saver)"
            }
        ) as client:
            response = await client.get(url)
            response.raise_for_status()

            return parse_schema_recipe(response.text, str(response.url))

    except httpx.HTTPError as e:
        print(f"Error fetching recipe URL {url}: {e}")
        return None
    except Exception as e:
        print(f"Error parsing recipe from {url}: {e}")
        return None
