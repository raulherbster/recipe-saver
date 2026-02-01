"""Integration tests for API endpoints."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    """Test health check endpoint."""
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


@pytest.mark.asyncio
async def test_root_endpoint(client: AsyncClient):
    """Test root endpoint."""
    response = await client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "Recipe Saver API"


@pytest.mark.asyncio
async def test_get_categories(client: AsyncClient):
    """Test getting all categories."""
    response = await client.get("/api/categories")
    assert response.status_code == 200

    data = response.json()
    # Check category types exist
    assert "dietary" in data
    assert "protein" in data
    assert "course" in data
    assert "cuisine" in data

    # Check some expected categories
    dietary_names = [c["name"] for c in data["dietary"]]
    assert "vegetarian" in dietary_names
    assert "vegan" in dietary_names

    cuisine_names = [c["name"] for c in data["cuisine"]]
    assert "italian" in cuisine_names
    assert "mexican" in cuisine_names


@pytest.mark.asyncio
async def test_list_recipes_empty(client: AsyncClient):
    """Test listing recipes when empty."""
    response = await client.get("/api/recipes")
    assert response.status_code == 200

    data = response.json()
    assert data["recipes"] == []
    assert data["total"] == 0
    assert data["page"] == 1


@pytest.mark.asyncio
async def test_create_recipe_manual(client: AsyncClient):
    """Test creating a recipe manually."""
    recipe_data = {
        "title": "Test Pasta Recipe",
        "description": "A simple test recipe",
        "instructions": ["Boil water", "Cook pasta", "Add sauce"],
        "prep_time_mins": 10,
        "cook_time_mins": 20,
        "total_time_mins": 30,
        "servings": "4",
        "difficulty": "easy",
        "ingredients": [
            {"name": "pasta", "quantity": "400", "unit": "g"},
            {"name": "tomato sauce", "quantity": "2", "unit": "cups"},
        ],
        "tags": ["#pasta", "#quick"],
    }

    response = await client.post("/api/recipes", json=recipe_data)
    assert response.status_code == 200

    data = response.json()
    assert data["title"] == "Test Pasta Recipe"
    assert data["description"] == "A simple test recipe"
    assert len(data["instructions"]) == 3
    assert len(data["ingredients"]) == 2
    assert data["prep_time_mins"] == 10
    assert data["difficulty"] == "easy"

    # Store recipe ID for later tests
    return data["id"]


@pytest.mark.asyncio
async def test_get_recipe_detail(client: AsyncClient):
    """Test getting recipe details."""
    # First create a recipe
    recipe_data = {
        "title": "Detail Test Recipe",
        "ingredients": [{"name": "flour", "quantity": "2", "unit": "cups"}],
    }
    create_response = await client.post("/api/recipes", json=recipe_data)
    recipe_id = create_response.json()["id"]

    # Get the recipe
    response = await client.get(f"/api/recipes/{recipe_id}")
    assert response.status_code == 200

    data = response.json()
    assert data["id"] == recipe_id
    assert data["title"] == "Detail Test Recipe"
    assert len(data["ingredients"]) == 1
    assert data["ingredients"][0]["name"] == "flour"


@pytest.mark.asyncio
async def test_get_recipe_not_found(client: AsyncClient):
    """Test getting non-existent recipe returns 404."""
    response = await client.get("/api/recipes/nonexistent-id")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_update_recipe(client: AsyncClient):
    """Test updating a recipe."""
    # Create a recipe
    create_response = await client.post("/api/recipes", json={
        "title": "Original Title",
        "description": "Original description",
    })
    recipe_id = create_response.json()["id"]

    # Update the recipe
    update_data = {
        "title": "Updated Title",
        "description": "Updated description",
        "difficulty": "medium",
    }
    response = await client.patch(f"/api/recipes/{recipe_id}", json=update_data)
    assert response.status_code == 200

    data = response.json()
    assert data["title"] == "Updated Title"
    assert data["description"] == "Updated description"
    assert data["difficulty"] == "medium"


@pytest.mark.asyncio
async def test_delete_recipe(client: AsyncClient):
    """Test deleting a recipe."""
    # Create a recipe
    create_response = await client.post("/api/recipes", json={"title": "To Delete"})
    recipe_id = create_response.json()["id"]

    # Delete it
    response = await client.delete(f"/api/recipes/{recipe_id}")
    assert response.status_code == 200

    # Verify it's gone
    get_response = await client.get(f"/api/recipes/{recipe_id}")
    assert get_response.status_code == 404


@pytest.mark.asyncio
async def test_search_recipes(client: AsyncClient):
    """Test searching recipes."""
    # Create some recipes
    await client.post("/api/recipes", json={
        "title": "Chicken Pasta",
        "ingredients": [{"name": "chicken"}, {"name": "pasta"}],
    })
    await client.post("/api/recipes", json={
        "title": "Beef Stew",
        "ingredients": [{"name": "beef"}, {"name": "potatoes"}],
    })
    await client.post("/api/recipes", json={
        "title": "Vegetable Pasta",
        "ingredients": [{"name": "pasta"}, {"name": "tomatoes"}],
    })

    # Search by text
    response = await client.get("/api/recipes/search?q=pasta")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 2
    titles = [r["title"] for r in data["recipes"]]
    assert "Chicken Pasta" in titles
    assert "Vegetable Pasta" in titles

    # Search by ingredient
    response = await client.get("/api/recipes/search?ingredients=chicken")
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert data["recipes"][0]["title"] == "Chicken Pasta"


@pytest.mark.asyncio
async def test_list_recipes_pagination(client: AsyncClient):
    """Test recipe list pagination."""
    # Create 5 recipes
    for i in range(5):
        await client.post("/api/recipes", json={"title": f"Recipe {i}"})

    # Get first page with 2 per page
    response = await client.get("/api/recipes?page=1&page_size=2")
    assert response.status_code == 200
    data = response.json()
    assert len(data["recipes"]) == 2
    assert data["total"] >= 5
    assert data["page"] == 1
    assert data["page_size"] == 2
    assert data["total_pages"] >= 3

    # Get second page
    response = await client.get("/api/recipes?page=2&page_size=2")
    assert response.status_code == 200
    data = response.json()
    assert len(data["recipes"]) == 2
    assert data["page"] == 2


@pytest.mark.asyncio
async def test_extract_invalid_url(client: AsyncClient):
    """Test extraction with invalid URL."""
    response = await client.post("/api/extract", json={
        "url": "not-a-valid-url"
    })
    # Should still return 200 but with success=false
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is False
