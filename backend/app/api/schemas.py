"""Pydantic schemas for API request/response validation."""

from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, HttpUrl


# ============ Ingredient Schemas ============

class IngredientBase(BaseModel):
    """Base ingredient fields."""
    name: str
    quantity: Optional[str] = None
    unit: Optional[str] = None
    preparation: Optional[str] = None
    raw_text: Optional[str] = None


class IngredientCreate(IngredientBase):
    """Schema for creating an ingredient."""
    pass


class IngredientResponse(IngredientBase):
    """Schema for ingredient in API responses."""
    id: str
    sort_order: int = 0

    class Config:
        from_attributes = True


# ============ Category Schemas ============

class CategoryResponse(BaseModel):
    """Schema for category in API responses."""
    id: str
    name: str
    type: str

    class Config:
        from_attributes = True


class CategoryGroupResponse(BaseModel):
    """Grouped categories by type."""
    dietary: list[CategoryResponse] = []
    protein: list[CategoryResponse] = []
    course: list[CategoryResponse] = []
    cuisine: list[CategoryResponse] = []
    method: list[CategoryResponse] = []
    season: list[CategoryResponse] = []
    difficulty: list[CategoryResponse] = []
    time: list[CategoryResponse] = []


# ============ Tag Schemas ============

class TagResponse(BaseModel):
    """Schema for tag in API responses."""
    id: str
    tag: str
    source: Optional[str] = None

    class Config:
        from_attributes = True


# ============ Recipe Schemas ============

class RecipeBase(BaseModel):
    """Base recipe fields."""
    title: str
    description: Optional[str] = None
    instructions: Optional[list[str]] = None
    prep_time_mins: Optional[int] = None
    cook_time_mins: Optional[int] = None
    total_time_mins: Optional[int] = None
    servings: Optional[str] = None
    difficulty: Optional[str] = None


class RecipeCreate(RecipeBase):
    """Schema for manually creating a recipe."""
    ingredients: list[IngredientCreate] = []
    category_ids: list[str] = []
    tags: list[str] = []
    video_url: Optional[str] = None
    recipe_page_url: Optional[str] = None
    thumbnail_url: Optional[str] = None


class RecipeUpdate(BaseModel):
    """Schema for updating a recipe."""
    title: Optional[str] = None
    description: Optional[str] = None
    instructions: Optional[list[str]] = None
    prep_time_mins: Optional[int] = None
    cook_time_mins: Optional[int] = None
    total_time_mins: Optional[int] = None
    servings: Optional[str] = None
    difficulty: Optional[str] = None
    ingredients: Optional[list[IngredientCreate]] = None
    category_ids: Optional[list[str]] = None
    tags: Optional[list[str]] = None


class RecipeSummary(BaseModel):
    """Brief recipe info for list views."""
    id: str
    title: str
    description: Optional[str] = None
    thumbnail_url: Optional[str] = None
    total_time_mins: Optional[int] = None
    difficulty: Optional[str] = None
    source_platform: Optional[str] = None
    recipe_site_name: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class RecipeDetail(RecipeBase):
    """Full recipe details."""
    id: str
    ingredients: list[IngredientResponse] = []
    categories: list[CategoryResponse] = []
    tags: list[TagResponse] = []

    # Source info
    video_url: Optional[str] = None
    video_platform: Optional[str] = None
    recipe_page_url: Optional[str] = None
    recipe_site_name: Optional[str] = None
    original_caption: Optional[str] = None
    thumbnail_url: Optional[str] = None
    author_name: Optional[str] = None

    # Metadata
    extraction_method: Optional[str] = None
    extraction_confidence: Optional[float] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ============ Extraction Schemas ============

class ExtractionRequest(BaseModel):
    """Request to extract a recipe from a URL."""
    url: str = Field(..., description="YouTube, Instagram, or recipe page URL")
    manual_caption: Optional[str] = Field(None, description="Manual caption text (for Instagram)")
    manual_recipe_url: Optional[str] = Field(None, description="Direct recipe URL if known")


class ExtractionStatusResponse(BaseModel):
    """Response for extraction status."""
    success: bool
    method: str
    confidence: float
    error: Optional[str] = None

    # The extracted/created recipe
    recipe: Optional[RecipeDetail] = None

    # URLs found during extraction (user can select if multiple)
    found_recipe_urls: list[str] = []

    # Message for the user
    message: str


# ============ Search Schemas ============

class SearchRequest(BaseModel):
    """Search parameters."""
    query: Optional[str] = Field(None, description="Text search query")
    ingredients: Optional[list[str]] = Field(None, description="Filter by ingredients")
    categories: Optional[list[str]] = Field(None, description="Filter by category names")
    tags: Optional[list[str]] = Field(None, description="Filter by tags")
    difficulty: Optional[str] = Field(None, description="Filter by difficulty")
    max_time_mins: Optional[int] = Field(None, description="Max total time")


class SearchResponse(BaseModel):
    """Search results."""
    recipes: list[RecipeSummary]
    total: int
    query: Optional[str] = None


# ============ Pagination ============

class PaginatedRecipes(BaseModel):
    """Paginated list of recipes."""
    recipes: list[RecipeSummary]
    total: int
    page: int
    page_size: int
    total_pages: int
