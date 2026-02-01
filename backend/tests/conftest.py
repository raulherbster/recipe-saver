"""Pytest configuration and fixtures."""

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from httpx import AsyncClient, ASGITransport

from app.models.database import Base
from app.models import Category
from app.main import app
from app.extraction.llm_extractor import CATEGORY_TAXONOMY


# Test database URL (in-memory SQLite)
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture
async def test_engine():
    """Create a test database engine."""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture
async def test_db(test_engine):
    """Create a test database session."""
    async_session = async_sessionmaker(
        test_engine, class_=AsyncSession, expire_on_commit=False
    )
    async with async_session() as session:
        # Seed categories
        for cat_type, values in CATEGORY_TAXONOMY.items():
            for name in values:
                category = Category(name=name, type=cat_type)
                session.add(category)
        await session.commit()
        yield session


@pytest_asyncio.fixture
async def client(test_db):
    """Create a test client with database dependency override."""
    from app.models import get_db

    async def override_get_db():
        yield test_db

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test"
    ) as ac:
        yield ac

    app.dependency_overrides.clear()


# Sample HTML with schema.org/Recipe for testing
SAMPLE_RECIPE_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>Test Recipe</title>
    <script type="application/ld+json">
    {
        "@context": "https://schema.org/",
        "@type": "Recipe",
        "name": "Classic Tomato Pasta",
        "description": "A simple and delicious tomato pasta recipe.",
        "author": {
            "@type": "Person",
            "name": "Test Chef"
        },
        "prepTime": "PT15M",
        "cookTime": "PT20M",
        "totalTime": "PT35M",
        "recipeYield": "4 servings",
        "recipeCategory": "Dinner",
        "recipeCuisine": "Italian",
        "recipeIngredient": [
            "400g spaghetti",
            "2 cans crushed tomatoes",
            "4 cloves garlic, minced",
            "1/4 cup olive oil",
            "1 tsp salt",
            "Fresh basil leaves"
        ],
        "recipeInstructions": [
            {
                "@type": "HowToStep",
                "text": "Bring a large pot of salted water to boil. Cook pasta according to package directions."
            },
            {
                "@type": "HowToStep",
                "text": "In a large pan, heat olive oil over medium heat. Add garlic and cook until fragrant."
            },
            {
                "@type": "HowToStep",
                "text": "Add crushed tomatoes and salt. Simmer for 15 minutes."
            },
            {
                "@type": "HowToStep",
                "text": "Toss pasta with sauce. Garnish with fresh basil and serve."
            }
        ],
        "image": "https://example.com/pasta.jpg"
    }
    </script>
</head>
<body>
    <h1>Classic Tomato Pasta</h1>
</body>
</html>
"""

SAMPLE_RECIPE_HTML_WITH_GRAPH = """
<!DOCTYPE html>
<html>
<head>
    <script type="application/ld+json">
    {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "WebPage",
                "name": "Recipe Page"
            },
            {
                "@type": "Recipe",
                "name": "Chocolate Chip Cookies",
                "description": "Crispy on the outside, chewy on the inside.",
                "prepTime": "PT20M",
                "cookTime": "PT12M",
                "recipeYield": "24 cookies",
                "recipeIngredient": [
                    "2 1/4 cups flour",
                    "1 cup butter, softened",
                    "3/4 cup sugar",
                    "2 eggs",
                    "2 cups chocolate chips"
                ],
                "recipeInstructions": "Mix ingredients. Scoop onto baking sheet. Bake at 375F for 12 minutes."
            }
        ]
    }
    </script>
</head>
<body></body>
</html>
"""


@pytest.fixture
def sample_recipe_html():
    """Sample HTML with schema.org/Recipe."""
    return SAMPLE_RECIPE_HTML


@pytest.fixture
def sample_recipe_html_graph():
    """Sample HTML with schema.org/Recipe in @graph format."""
    return SAMPLE_RECIPE_HTML_WITH_GRAPH


@pytest.fixture
def sample_youtube_description():
    """Sample YouTube video description with recipe link."""
    return """
    Today I'm making the BEST tomato pasta you've ever had! 🍝

    Get the full recipe here: https://www.seriouseats.com/pasta-tomato-sauce-recipe

    INGREDIENTS:
    - Pasta
    - Tomatoes
    - Garlic
    - Olive oil

    Follow me on Instagram: @testchef

    #pasta #italianfood #cooking #recipe
    """


@pytest.fixture
def sample_youtube_description_no_link():
    """Sample YouTube description without recipe link."""
    return """
    Making my grandmother's secret pasta recipe!

    Don't forget to like and subscribe!

    Follow me:
    Instagram: @chef
    TikTok: @chef

    #cooking #homemade #pasta
    """
