"""Recipe service - business logic for recipe operations."""

import json
from typing import Optional
from sqlalchemy import select, or_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Recipe, Ingredient, Category, Tag, recipe_categories
from app.extraction import (
    extract_recipe,
    ExtractionResult,
    ExtractionMethod,
    SchemaRecipe,
    ParsedIngredient,
)
from app.api.schemas import (
    RecipeCreate,
    RecipeUpdate,
    IngredientCreate,
    ExtractionRequest,
)


async def get_or_create_categories(
    db: AsyncSession,
    category_names: list[str],
) -> list[Category]:
    """Get categories by name, creating them if needed."""
    if not category_names:
        return []

    # Fetch existing categories
    result = await db.execute(
        select(Category).where(Category.name.in_(category_names))
    )
    existing = {c.name: c for c in result.scalars().all()}

    categories = []
    for name in category_names:
        if name in existing:
            categories.append(existing[name])
        # If not found, skip (categories should be pre-seeded)

    return categories


async def create_recipe_from_extraction(
    db: AsyncSession,
    extraction: ExtractionResult,
) -> Recipe:
    """Create a recipe from extraction result."""

    # Convert instructions to JSON if it's a list
    instructions_json = None
    if extraction.recipe and extraction.recipe.instructions:
        instructions_json = json.dumps(extraction.recipe.instructions)

    # Create recipe
    recipe = Recipe(
        title=extraction.recipe.title if extraction.recipe else "Untitled",
        description=extraction.recipe.description if extraction.recipe else None,
        instructions=instructions_json,
        prep_time_mins=extraction.recipe.prep_time_mins if extraction.recipe else None,
        cook_time_mins=extraction.recipe.cook_time_mins if extraction.recipe else None,
        total_time_mins=extraction.recipe.total_time_mins if extraction.recipe else None,
        servings=extraction.recipe.servings if extraction.recipe else None,
        video_url=extraction.video_url,
        video_platform=extraction.source_platform.value if extraction.source_platform else None,
        recipe_page_url=extraction.recipe_page_url,
        recipe_site_name=extraction.recipe_site_name,
        original_caption=extraction.original_caption,
        thumbnail_url=extraction.thumbnail_url or (extraction.recipe.image_url if extraction.recipe else None),
        author_name=extraction.author_name,
        extraction_method=extraction.method.value,
        extraction_confidence=extraction.confidence,
        raw_extraction=extraction.raw_data,
    )

    db.add(recipe)
    await db.flush()  # Get recipe.id

    # Add ingredients
    if extraction.recipe and extraction.recipe.ingredients:
        for i, ing in enumerate(extraction.recipe.ingredients):
            ingredient = Ingredient(
                recipe_id=recipe.id,
                name=ing.name,
                quantity=ing.quantity,
                unit=ing.unit,
                preparation=ing.preparation,
                raw_text=ing.raw_text,
                sort_order=i,
            )
            db.add(ingredient)

    # Add tags
    for tag_text in extraction.tags:
        tag = Tag(
            recipe_id=recipe.id,
            tag=tag_text,
            source="hashtag" if tag_text.startswith("#") else "keyword",
        )
        db.add(tag)

    # Add categories
    category_names = []
    for cat_type, values in extraction.categories.items():
        category_names.extend(values)

    if category_names:
        categories = await get_or_create_categories(db, category_names)
        recipe.categories = categories

    await db.commit()
    await db.refresh(recipe, ["ingredients", "tags", "categories"])

    return recipe


async def create_recipe_manual(
    db: AsyncSession,
    data: RecipeCreate,
) -> Recipe:
    """Create a recipe manually."""

    instructions_json = json.dumps(data.instructions) if data.instructions else None

    recipe = Recipe(
        title=data.title,
        description=data.description,
        instructions=instructions_json,
        prep_time_mins=data.prep_time_mins,
        cook_time_mins=data.cook_time_mins,
        total_time_mins=data.total_time_mins,
        servings=data.servings,
        difficulty=data.difficulty,
        video_url=data.video_url,
        recipe_page_url=data.recipe_page_url,
        thumbnail_url=data.thumbnail_url,
        extraction_method="manual",
        extraction_confidence=1.0,
    )

    db.add(recipe)
    await db.flush()

    # Add ingredients
    for i, ing in enumerate(data.ingredients):
        ingredient = Ingredient(
            recipe_id=recipe.id,
            name=ing.name,
            quantity=ing.quantity,
            unit=ing.unit,
            preparation=ing.preparation,
            raw_text=ing.raw_text,
            sort_order=i,
        )
        db.add(ingredient)

    # Add tags
    for tag_text in data.tags:
        tag = Tag(
            recipe_id=recipe.id,
            tag=tag_text,
            source="manual",
        )
        db.add(tag)

    # Add categories
    if data.category_ids:
        result = await db.execute(
            select(Category).where(Category.id.in_(data.category_ids))
        )
        categories = result.scalars().all()
        recipe.categories = list(categories)

    await db.commit()
    await db.refresh(recipe, ["ingredients", "tags", "categories"])

    return recipe


async def update_recipe(
    db: AsyncSession,
    recipe_id: str,
    data: RecipeUpdate,
) -> Optional[Recipe]:
    """Update an existing recipe."""

    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients),
            selectinload(Recipe.tags),
            selectinload(Recipe.categories),
        )
        .where(Recipe.id == recipe_id)
    )
    recipe = result.scalar_one_or_none()

    if not recipe:
        return None

    # Update scalar fields
    if data.title is not None:
        recipe.title = data.title
    if data.description is not None:
        recipe.description = data.description
    if data.instructions is not None:
        recipe.instructions = json.dumps(data.instructions)
    if data.prep_time_mins is not None:
        recipe.prep_time_mins = data.prep_time_mins
    if data.cook_time_mins is not None:
        recipe.cook_time_mins = data.cook_time_mins
    if data.total_time_mins is not None:
        recipe.total_time_mins = data.total_time_mins
    if data.servings is not None:
        recipe.servings = data.servings
    if data.difficulty is not None:
        recipe.difficulty = data.difficulty

    # Update ingredients (replace all)
    if data.ingredients is not None:
        # Delete existing
        for ing in recipe.ingredients:
            await db.delete(ing)

        # Add new
        for i, ing in enumerate(data.ingredients):
            ingredient = Ingredient(
                recipe_id=recipe.id,
                name=ing.name,
                quantity=ing.quantity,
                unit=ing.unit,
                preparation=ing.preparation,
                raw_text=ing.raw_text,
                sort_order=i,
            )
            db.add(ingredient)

    # Update tags (replace all)
    if data.tags is not None:
        for tag in recipe.tags:
            await db.delete(tag)

        for tag_text in data.tags:
            tag = Tag(
                recipe_id=recipe.id,
                tag=tag_text,
                source="manual",
            )
            db.add(tag)

    # Update categories
    if data.category_ids is not None:
        result = await db.execute(
            select(Category).where(Category.id.in_(data.category_ids))
        )
        categories = result.scalars().all()
        recipe.categories = list(categories)

    await db.commit()
    await db.refresh(recipe, ["ingredients", "tags", "categories"])

    return recipe


async def get_recipe(db: AsyncSession, recipe_id: str) -> Optional[Recipe]:
    """Get a recipe by ID with all relations."""
    result = await db.execute(
        select(Recipe)
        .options(
            selectinload(Recipe.ingredients),
            selectinload(Recipe.tags),
            selectinload(Recipe.categories),
        )
        .where(Recipe.id == recipe_id)
    )
    return result.scalar_one_or_none()


async def get_recipes(
    db: AsyncSession,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[Recipe], int]:
    """Get paginated list of recipes."""
    # Count total
    count_result = await db.execute(select(func.count(Recipe.id)))
    total = count_result.scalar() or 0

    # Fetch page
    offset = (page - 1) * page_size
    result = await db.execute(
        select(Recipe)
        .options(selectinload(Recipe.categories))
        .order_by(Recipe.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    recipes = result.scalars().all()

    return list(recipes), total


async def delete_recipe(db: AsyncSession, recipe_id: str) -> bool:
    """Delete a recipe."""
    result = await db.execute(select(Recipe).where(Recipe.id == recipe_id))
    recipe = result.scalar_one_or_none()

    if not recipe:
        return False

    await db.delete(recipe)
    await db.commit()
    return True


async def search_recipes(
    db: AsyncSession,
    query: Optional[str] = None,
    ingredients: Optional[list[str]] = None,
    categories: Optional[list[str]] = None,
    tags: Optional[list[str]] = None,
    difficulty: Optional[str] = None,
    max_time_mins: Optional[int] = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[Recipe], int]:
    """Search recipes with filters."""

    # Base query
    stmt = select(Recipe).options(selectinload(Recipe.categories))

    # Text search
    if query:
        search_pattern = f"%{query}%"
        stmt = stmt.outerjoin(Ingredient, Recipe.id == Ingredient.recipe_id)
        stmt = stmt.outerjoin(Tag, Recipe.id == Tag.recipe_id)
        stmt = stmt.where(
            or_(
                Recipe.title.ilike(search_pattern),
                Recipe.description.ilike(search_pattern),
                Ingredient.name.ilike(search_pattern),
                Tag.tag.ilike(search_pattern),
            )
        )

    # Ingredient filter
    if ingredients:
        # Must contain ALL specified ingredients
        for ing in ingredients:
            ing_subq = select(Ingredient.recipe_id).where(
                Ingredient.name.ilike(f"%{ing}%")
            )
            stmt = stmt.where(Recipe.id.in_(ing_subq))

    # Category filter
    if categories:
        for cat in categories:
            cat_subq = (
                select(recipe_categories.c.recipe_id)
                .join(Category, recipe_categories.c.category_id == Category.id)
                .where(Category.name == cat)
            )
            stmt = stmt.where(Recipe.id.in_(cat_subq))

    # Tag filter
    if tags:
        for tag in tags:
            tag_subq = select(Tag.recipe_id).where(Tag.tag.ilike(f"%{tag}%"))
            stmt = stmt.where(Recipe.id.in_(tag_subq))

    # Difficulty filter
    if difficulty:
        stmt = stmt.where(Recipe.difficulty == difficulty)

    # Time filter
    if max_time_mins:
        stmt = stmt.where(Recipe.total_time_mins <= max_time_mins)

    # Deduplicate (due to joins)
    stmt = stmt.distinct()

    # Count total (before pagination)
    count_stmt = select(func.count()).select_from(stmt.subquery())
    count_result = await db.execute(count_stmt)
    total = count_result.scalar() or 0

    # Apply pagination
    offset = (page - 1) * page_size
    stmt = stmt.order_by(Recipe.created_at.desc()).offset(offset).limit(page_size)

    result = await db.execute(stmt)
    recipes = result.scalars().all()

    return list(recipes), total


async def get_all_categories(db: AsyncSession) -> list[Category]:
    """Get all categories."""
    result = await db.execute(select(Category).order_by(Category.type, Category.name))
    return list(result.scalars().all())
