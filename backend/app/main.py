"""Main FastAPI application."""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from app.config import get_settings
from app.models import init_db, async_session_maker, Category
from app.api import router
from app.extraction.llm_extractor import CATEGORY_TAXONOMY


async def seed_categories():
    """Seed the database with predefined categories."""
    async with async_session_maker() as db:
        # Check if categories already exist
        result = await db.execute(select(Category).limit(1))
        if result.scalar_one_or_none():
            return  # Already seeded

        # Add all categories from taxonomy
        for cat_type, values in CATEGORY_TAXONOMY.items():
            for name in values:
                category = Category(name=name, type=cat_type)
                db.add(category)

        await db.commit()
        print(f"Seeded {sum(len(v) for v in CATEGORY_TAXONOMY.values())} categories")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    # Startup
    await init_db()
    await seed_categories()
    print("Database initialized")
    yield
    # Shutdown
    print("Shutting down")


settings = get_settings()

app = FastAPI(
    title="Recipe Saver API",
    description="Extract and save recipes from YouTube, Instagram, and recipe websites",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(router)


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "status": "ok",
        "service": "Recipe Saver API",
        "version": "0.1.0",
    }


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "healthy"}
