"""API routes for recipe operations."""

import json
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import get_db
from app.api.schemas import (
    ExtractionRequest,
    ExtractionStatusResponse,
    RecipeCreate,
    RecipeUpdate,
    RecipeDetail,
    RecipeSummary,
    PaginatedRecipes,
    CategoryResponse,
    CategoryGroupResponse,
    IngredientResponse,
    TagResponse,
    SearchResponse,
)
from app.services import (
    create_recipe_from_extraction,
    create_recipe_manual,
    update_recipe,
    get_recipe,
    get_recipes,
    delete_recipe,
    search_recipes,
    get_all_categories,
)
from app.extraction import extract_recipe, ExtractionMethod


router = APIRouter(prefix="/api", tags=["recipes"])


def recipe_to_detail(recipe) -> RecipeDetail:
    """Convert Recipe model to RecipeDetail schema."""
    # Parse instructions JSON
    instructions = None
    if recipe.instructions:
        try:
            instructions = json.loads(recipe.instructions)
        except json.JSONDecodeError:
            instructions = [recipe.instructions]

    return RecipeDetail(
        id=recipe.id,
        title=recipe.title,
        description=recipe.description,
        instructions=instructions,
        prep_time_mins=recipe.prep_time_mins,
        cook_time_mins=recipe.cook_time_mins,
        total_time_mins=recipe.total_time_mins,
        servings=recipe.servings,
        difficulty=recipe.difficulty,
        ingredients=[
            IngredientResponse(
                id=ing.id,
                name=ing.name,
                quantity=ing.quantity,
                unit=ing.unit,
                preparation=ing.preparation,
                raw_text=ing.raw_text,
                sort_order=ing.sort_order,
            )
            for ing in recipe.ingredients
        ],
        categories=[
            CategoryResponse(id=cat.id, name=cat.name, type=cat.type)
            for cat in recipe.categories
        ],
        tags=[
            TagResponse(id=tag.id, tag=tag.tag, source=tag.source)
            for tag in recipe.tags
        ],
        video_url=recipe.video_url,
        video_platform=recipe.video_platform,
        recipe_page_url=recipe.recipe_page_url,
        recipe_site_name=recipe.recipe_site_name,
        original_caption=recipe.original_caption,
        thumbnail_url=recipe.thumbnail_url,
        author_name=recipe.author_name,
        extraction_method=recipe.extraction_method,
        extraction_confidence=recipe.extraction_confidence,
        created_at=recipe.created_at,
        updated_at=recipe.updated_at,
    )


def recipe_to_summary(recipe) -> RecipeSummary:
    """Convert Recipe model to RecipeSummary schema."""
    return RecipeSummary(
        id=recipe.id,
        title=recipe.title,
        description=recipe.description,
        thumbnail_url=recipe.thumbnail_url,
        total_time_mins=recipe.total_time_mins,
        difficulty=recipe.difficulty,
        source_platform=recipe.video_platform,
        recipe_site_name=recipe.recipe_site_name,
        created_at=recipe.created_at,
    )


@router.post("/extract", response_model=ExtractionStatusResponse)
async def extract_and_save_recipe(
    request: ExtractionRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Extract a recipe from a URL and save it.

    Supports:
    - YouTube video URLs (extracts from linked recipe pages or transcript)
    - Instagram URLs (requires manual_caption for best results)
    - Direct recipe page URLs (parses schema.org/Recipe)
    """
    # Run extraction
    result = await extract_recipe(
        url=request.url,
        manual_caption=request.manual_caption,
        manual_recipe_url=request.manual_recipe_url,
    )

    if not result.success:
        return ExtractionStatusResponse(
            success=False,
            method=result.method.value,
            confidence=result.confidence,
            error=result.error,
            found_recipe_urls=result.found_recipe_urls,
            message=result.error or "Extraction failed",
        )

    # Save to database
    recipe = await create_recipe_from_extraction(db, result)

    # Build response message
    if result.method == ExtractionMethod.SCHEMA_ORG:
        message = f"Recipe extracted from {result.recipe_site_name or 'recipe page'}"
    elif result.method == ExtractionMethod.LLM_TRANSCRIPT:
        message = "Recipe extracted from video content (AI-powered)"
    else:
        message = "Recipe saved"

    return ExtractionStatusResponse(
        success=True,
        method=result.method.value,
        confidence=result.confidence,
        recipe=recipe_to_detail(recipe),
        found_recipe_urls=result.found_recipe_urls,
        message=message,
    )


@router.post("/recipes", response_model=RecipeDetail)
async def create_recipe(
    data: RecipeCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a recipe manually."""
    recipe = await create_recipe_manual(db, data)
    return recipe_to_detail(recipe)


@router.get("/recipes", response_model=PaginatedRecipes)
async def list_recipes(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """Get paginated list of all recipes."""
    recipes, total = await get_recipes(db, page, page_size)

    total_pages = (total + page_size - 1) // page_size

    return PaginatedRecipes(
        recipes=[recipe_to_summary(r) for r in recipes],
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )


@router.get("/recipes/search", response_model=SearchResponse)
async def search(
    q: Optional[str] = Query(None, description="Text search query"),
    ingredients: Optional[str] = Query(None, description="Comma-separated ingredients"),
    categories: Optional[str] = Query(None, description="Comma-separated category names"),
    tags: Optional[str] = Query(None, description="Comma-separated tags"),
    difficulty: Optional[str] = Query(None, description="Difficulty filter"),
    max_time: Optional[int] = Query(None, description="Max total time in minutes"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """Search recipes with filters."""
    # Parse comma-separated lists
    ingredient_list = [i.strip() for i in ingredients.split(",")] if ingredients else None
    category_list = [c.strip() for c in categories.split(",")] if categories else None
    tag_list = [t.strip() for t in tags.split(",")] if tags else None

    recipes, total = await search_recipes(
        db,
        query=q,
        ingredients=ingredient_list,
        categories=category_list,
        tags=tag_list,
        difficulty=difficulty,
        max_time_mins=max_time,
        page=page,
        page_size=page_size,
    )

    return SearchResponse(
        recipes=[recipe_to_summary(r) for r in recipes],
        total=total,
        query=q,
    )


@router.get("/recipes/{recipe_id}", response_model=RecipeDetail)
async def get_recipe_detail(
    recipe_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get full recipe details."""
    recipe = await get_recipe(db, recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return recipe_to_detail(recipe)


@router.patch("/recipes/{recipe_id}", response_model=RecipeDetail)
async def update_recipe_endpoint(
    recipe_id: str,
    data: RecipeUpdate,
    db: AsyncSession = Depends(get_db),
):
    """Update a recipe."""
    recipe = await update_recipe(db, recipe_id, data)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return recipe_to_detail(recipe)


@router.delete("/recipes/{recipe_id}")
async def delete_recipe_endpoint(
    recipe_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Delete a recipe."""
    success = await delete_recipe(db, recipe_id)
    if not success:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return {"message": "Recipe deleted"}


@router.get("/categories", response_model=CategoryGroupResponse)
async def get_categories(
    db: AsyncSession = Depends(get_db),
):
    """Get all categories grouped by type."""
    categories = await get_all_categories(db)

    # Group by type
    grouped = CategoryGroupResponse()
    for cat in categories:
        cat_response = CategoryResponse(id=cat.id, name=cat.name, type=cat.type)
        if hasattr(grouped, cat.type):
            getattr(grouped, cat.type).append(cat_response)

    return grouped
