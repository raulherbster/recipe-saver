"""Recipe search by title and author across popular recipe sites."""

import re
import asyncio
from typing import Optional
from dataclasses import dataclass
from urllib.parse import quote_plus

import httpx
from bs4 import BeautifulSoup


@dataclass
class SearchResult:
    """A recipe search result from a site."""
    url: str
    title: str
    site_name: str
    similarity_score: float


# Sites with searchable recipe databases
SEARCHABLE_SITES = [
    {
        "name": "AllRecipes",
        "search_url": "https://www.allrecipes.com/search?q={}",
        "result_selector": "a.mntl-card-list-card",
        "title_selector": "span.card__title-text",
        "link_attr": "href",
    },
    {
        "name": "Food Network",
        "search_url": "https://www.foodnetwork.com/search/{}-",
        "result_selector": "div.o-RecipeResult a.o-RecipeResult__a-ResultLink",
        "title_selector": "span.o-RecipeResult__a-ResultTitle",
        "link_attr": "href",
        "base_url": "https://www.foodnetwork.com",
    },
    {
        "name": "Tasty",
        "search_url": "https://tasty.co/search?q={}",
        "result_selector": "a.feed-item",
        "title_selector": "div.feed-item__title",
        "link_attr": "href",
        "base_url": "https://tasty.co",
    },
    {
        "name": "Delish",
        "search_url": "https://www.delish.com/search/?q={}",
        "result_selector": "a.result-link",
        "title_selector": "span.result-title",
        "link_attr": "href",
    },
    {
        "name": "Food.com",
        "search_url": "https://www.food.com/search/{}",
        "result_selector": "article.recipe-card a",
        "title_selector": "h2",
        "link_attr": "href",
        "base_url": "https://www.food.com",
    },
    {
        "name": "Epicurious",
        "search_url": "https://www.epicurious.com/search?q={}",
        "result_selector": "a.view-complete-item",
        "title_selector": "h4",
        "link_attr": "href",
        "base_url": "https://www.epicurious.com",
    },
]


def normalize_text(text: str) -> str:
    """Normalize text for comparison by removing special chars and lowercasing."""
    if not text:
        return ""
    # Remove special characters, keep alphanumeric and spaces
    text = re.sub(r'[^\w\s]', ' ', text.lower())
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def extract_recipe_keywords(title: str) -> set[str]:
    """Extract meaningful keywords from a recipe title."""
    # Common words to ignore
    stop_words = {
        'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
        'of', 'with', 'by', 'from', 'is', 'are', 'was', 'were', 'be', 'been',
        'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
        'could', 'should', 'may', 'might', 'must', 'shall', 'can', 'this',
        'that', 'these', 'those', 'i', 'you', 'he', 'she', 'it', 'we', 'they',
        'my', 'your', 'his', 'her', 'its', 'our', 'their', 'recipe', 'recipes',
        'how', 'make', 'making', 'easy', 'best', 'simple', 'homemade', 'quick',
    }

    normalized = normalize_text(title)
    words = set(normalized.split())
    return words - stop_words


def calculate_title_similarity(title1: str, title2: str) -> float:
    """
    Calculate similarity between two recipe titles.

    Uses token-based Jaccard similarity with keyword extraction.
    Returns a score between 0.0 and 1.0.
    """
    keywords1 = extract_recipe_keywords(title1)
    keywords2 = extract_recipe_keywords(title2)

    if not keywords1 or not keywords2:
        return 0.0

    # Jaccard similarity
    intersection = keywords1 & keywords2
    union = keywords1 | keywords2

    if not union:
        return 0.0

    return len(intersection) / len(union)


def build_search_query(title: str, author: Optional[str] = None) -> str:
    """Build a search query from video title and optional author."""
    # Clean up the title - remove common YouTube title patterns
    query = title

    # Remove common patterns like "| Creator Name" at the end
    query = re.sub(r'\s*\|\s*.*$', '', query)
    # Remove hashtags
    query = re.sub(r'#\w+', '', query)
    # Remove "shorts" indicator
    query = re.sub(r'#?shorts?', '', query, flags=re.IGNORECASE)
    # Remove emojis (basic)
    query = re.sub(r'[^\w\s\-\']', ' ', query)
    # Normalize whitespace
    query = re.sub(r'\s+', ' ', query).strip()

    # Optionally add author name for more specific results
    if author:
        # Clean author name
        clean_author = re.sub(r'[^\w\s]', '', author).strip()
        if clean_author and len(clean_author) > 2:
            query = f"{query} {clean_author}"

    return query


async def search_single_site(
    site_config: dict,
    query: str,
    timeout: float = 10.0
) -> list[SearchResult]:
    """
    Search a single recipe site for matching recipes.

    Returns a list of SearchResult objects.
    """
    results = []

    search_url = site_config["search_url"].format(quote_plus(query))

    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                search_url,
                timeout=timeout,
                headers={
                    "User-Agent": "Mozilla/5.0 (compatible; RecipeSaver/1.0)",
                    "Accept": "text/html,application/xhtml+xml",
                },
                follow_redirects=True,
            )

            if response.status_code != 200:
                return results

            soup = BeautifulSoup(response.text, "html.parser")

            # Find result elements
            result_elements = soup.select(site_config["result_selector"])

            for element in result_elements[:10]:  # Limit to top 10 results
                try:
                    # Get URL
                    if element.name == "a":
                        link = element
                    else:
                        link = element.select_one("a")

                    if not link:
                        continue

                    url = link.get(site_config.get("link_attr", "href"), "")
                    if not url:
                        continue

                    # Make URL absolute if needed
                    if url.startswith("/"):
                        base_url = site_config.get("base_url", "")
                        if base_url:
                            url = base_url + url
                        else:
                            continue

                    # Get title
                    title_elem = element.select_one(site_config["title_selector"])
                    if title_elem:
                        title = title_elem.get_text(strip=True)
                    else:
                        title = link.get_text(strip=True)

                    if not title:
                        continue

                    results.append(SearchResult(
                        url=url,
                        title=title,
                        site_name=site_config["name"],
                        similarity_score=0.0,  # Will be calculated later
                    ))

                except Exception:
                    continue

    except Exception as e:
        print(f"Error searching {site_config['name']}: {e}")

    return results


async def search_recipe_sites(
    title: str,
    author: Optional[str] = None,
    min_similarity: float = 0.3,
    max_results: int = 10,
) -> list[SearchResult]:
    """
    Search multiple recipe sites for recipes matching the given title/author.

    Args:
        title: Video title or recipe name to search for
        author: Optional channel/author name
        min_similarity: Minimum title similarity score (0.0-1.0)
        max_results: Maximum number of results to return

    Returns:
        List of SearchResult objects sorted by similarity score (descending)
    """
    query = build_search_query(title, author)

    if not query or len(query) < 3:
        return []

    # Search all sites concurrently
    tasks = [
        search_single_site(site, query)
        for site in SEARCHABLE_SITES
    ]

    all_results = []
    site_results = await asyncio.gather(*tasks, return_exceptions=True)

    for result in site_results:
        if isinstance(result, list):
            all_results.extend(result)

    # Calculate similarity scores
    for result in all_results:
        result.similarity_score = calculate_title_similarity(title, result.title)

    # Filter by minimum similarity
    filtered_results = [r for r in all_results if r.similarity_score >= min_similarity]

    # Sort by similarity (descending)
    filtered_results.sort(key=lambda r: r.similarity_score, reverse=True)

    # Deduplicate by URL
    seen_urls = set()
    unique_results = []
    for result in filtered_results:
        if result.url not in seen_urls:
            seen_urls.add(result.url)
            unique_results.append(result)

    return unique_results[:max_results]


async def search_recipe_by_title_author(
    title: str,
    author: str,
) -> list[tuple[str, float]]:
    """
    Search for recipes by video title and author.

    Convenience function that returns (url, similarity) tuples.
    """
    results = await search_recipe_sites(title, author)
    return [(r.url, r.similarity_score) for r in results]
