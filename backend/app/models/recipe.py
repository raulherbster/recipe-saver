"""Recipe and related database models."""

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Text, Integer, Float, DateTime, ForeignKey, Table, Column, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.database import Base


def generate_uuid() -> str:
    return str(uuid.uuid4())


# Association table for recipe <-> category many-to-many
recipe_categories = Table(
    "recipe_categories",
    Base.metadata,
    Column("recipe_id", String, ForeignKey("recipes.id", ondelete="CASCADE"), primary_key=True),
    Column("category_id", String, ForeignKey("categories.id", ondelete="CASCADE"), primary_key=True),
    Column("confidence", Float, default=1.0),
)


class Recipe(Base):
    """Main recipe entity."""

    __tablename__ = "recipes"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    instructions: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # JSON array of steps

    # Time and servings
    prep_time_mins: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    cook_time_mins: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    total_time_mins: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    servings: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    difficulty: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Source tracking
    video_url: Mapped[Optional[str]] = mapped_column(String(2000), nullable=True)
    video_platform: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    recipe_page_url: Mapped[Optional[str]] = mapped_column(String(2000), nullable=True)
    recipe_site_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    original_caption: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    thumbnail_url: Mapped[Optional[str]] = mapped_column(String(2000), nullable=True)
    author_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)

    # Extraction metadata
    extraction_method: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    extraction_confidence: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    raw_extraction: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # JSON

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    ingredients: Mapped[list["Ingredient"]] = relationship(
        "Ingredient", back_populates="recipe", cascade="all, delete-orphan", order_by="Ingredient.sort_order"
    )
    tags: Mapped[list["Tag"]] = relationship(
        "Tag", back_populates="recipe", cascade="all, delete-orphan"
    )
    categories: Mapped[list["Category"]] = relationship(
        "Category", secondary=recipe_categories, back_populates="recipes"
    )


class Ingredient(Base):
    """Recipe ingredient with parsed components."""

    __tablename__ = "ingredients"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    recipe_id: Mapped[str] = mapped_column(String, ForeignKey("recipes.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    quantity: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    unit: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    preparation: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    raw_text: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    recipe: Mapped["Recipe"] = relationship("Recipe", back_populates="ingredients")


class Category(Base):
    """Recipe category (dietary, cuisine, course, etc.)."""

    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    type: Mapped[str] = mapped_column(String(50), nullable=False)  # dietary, protein, course, cuisine, method, season, time, difficulty

    recipes: Mapped[list["Recipe"]] = relationship(
        "Recipe", secondary=recipe_categories, back_populates="categories"
    )

    __table_args__ = (
        # Unique constraint on name + type
        {"sqlite_autoincrement": True},
    )


class Tag(Base):
    """Free-form tags including hashtags."""

    __tablename__ = "tags"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    recipe_id: Mapped[str] = mapped_column(String, ForeignKey("recipes.id", ondelete="CASCADE"))
    tag: Mapped[str] = mapped_column(String(200), nullable=False)
    source: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)  # hashtag, keyword, manual

    recipe: Mapped["Recipe"] = relationship("Recipe", back_populates="tags")


class RecipeSite(Base):
    """Known recipe websites for smart URL detection."""

    __tablename__ = "recipe_sites"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=generate_uuid)
    domain: Mapped[str] = mapped_column(String(200), unique=True, nullable=False)
    name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    has_schema: Mapped[bool] = mapped_column(Boolean, default=True)
    parser_type: Mapped[str] = mapped_column(String(50), default="schema")
