# Recipe Saver

Save recipes from YouTube videos and Instagram posts with smart extraction. Paste a link, and the app automatically finds the recipe page, extracts ingredients and instructions, and saves everything in one place.

## Features

- **Smart URL Extraction**: Paste a YouTube video URL and the app scans the description for recipe website links (NYT Cooking, Serious Eats, etc.)
- **Schema.org Parsing**: Automatically parses structured recipe data from 40+ recipe websites
- **LLM Fallback**: When no recipe link is found, uses AI to extract recipes from video transcripts
- **Category Taxonomy**: Recipes are tagged with dietary info, cuisine, course, cooking method, and more
- **Search**: Find recipes by ingredient, category, tag, or free text

## How It Works

```
User pastes YouTube URL
         │
         ▼
┌─────────────────────────────────┐
│ 1. Fetch video metadata (yt-dlp)│
│    - title, description         │
│    - pinned comment             │
└────────────┬────────────────────┘
             │
             ▼
┌─────────────────────────────────┐
│ 2. Scan for recipe URLs         │
│    - Known sites (NYT, etc.)    │
│    - /recipe/ path patterns     │
└────────────┬────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
 Found URL?       No URL
    │                 │
    ▼                 ▼
┌──────────────┐ ┌──────────────┐
│ 3a. Fetch &  │ │ 3b. Fetch    │
│ parse schema │ │ transcript,  │
│ .org/Recipe  │ │ use LLM      │
└──────┬───────┘ └──────┬───────┘
       │                │
       └────────┬───────┘
                │
                ▼
┌─────────────────────────────────┐
│ 4. Normalize, categorize, save  │
└─────────────────────────────────┘
```

## Project Structure

```
recipe-saver/
├── backend/                 # Python FastAPI backend
│   ├── app/
│   │   ├── api/            # REST endpoints
│   │   ├── extraction/     # YouTube, schema.org, LLM extractors
│   │   ├── models/         # SQLAlchemy database models
│   │   └── services/       # Business logic
│   ├── tests/              # Backend tests
│   └── pyproject.toml      # Python dependencies
│
└── mobile/                  # Flutter Android app (coming soon)
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend | Python 3.11+, FastAPI, SQLAlchemy |
| Database | SQLite (dev), PostgreSQL (prod) |
| YouTube | yt-dlp, youtube-transcript-api |
| Recipe Parsing | BeautifulSoup, schema.org/Recipe |
| LLM | OpenAI API (gpt-4o-mini) |
| Mobile | Flutter (Android) |

## Getting Started

### Prerequisites

- Python 3.11+
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) installed and in PATH
- OpenAI API key (for LLM extraction fallback)

### Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # or `.venv\Scripts\activate` on Windows

# Install dependencies
pip install -e ".[dev]"

# Configure environment
cp .env.example .env
# Edit .env and add your OPENAI_API_KEY

# Run the server
uvicorn app.main:app --reload
```

The API will be available at http://localhost:8000

### API Documentation

Once running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API Endpoints

### Extract Recipe
```http
POST /api/extract
Content-Type: application/json

{
  "url": "https://www.youtube.com/watch?v=VIDEO_ID"
}
```

Response:
```json
{
  "success": true,
  "method": "schema_org",
  "confidence": 0.95,
  "message": "Recipe extracted from seriouseats.com",
  "recipe": {
    "id": "uuid",
    "title": "Classic Beef Stew",
    "ingredients": [...],
    "instructions": [...],
    "categories": [...]
  }
}
```

### List Recipes
```http
GET /api/recipes?page=1&page_size=20
```

### Search Recipes
```http
GET /api/recipes/search?q=pasta&categories=italian,easy&max_time=30
```

### Get Recipe Details
```http
GET /api/recipes/{recipe_id}
```

### Update Recipe
```http
PATCH /api/recipes/{recipe_id}
Content-Type: application/json

{
  "title": "Updated Title",
  "ingredients": [...]
}
```

## Category Taxonomy

Recipes are automatically categorized into:

| Type | Values |
|------|--------|
| Dietary | vegetarian, vegan, pescatarian, gluten-free, dairy-free, keto, paleo |
| Protein | chicken, beef, pork, fish, seafood, tofu, legumes, eggs |
| Course | breakfast, lunch, dinner, snack, dessert, appetizer, side-dish, drink |
| Cuisine | italian, mexican, indian, thai, japanese, chinese, korean, mediterranean, french, etc. |
| Method | baking, grilling, frying, slow-cooker, one-pot, air-fryer, instant-pot, no-cook |
| Season | spring, summer, fall, winter |
| Difficulty | easy, medium, hard |
| Time | under-15m, 15-30m, 30-60m, over-60m |

## Supported Recipe Sites

The schema.org parser supports 40+ recipe websites including:

- NYT Cooking, Serious Eats, Bon Appétit, Epicurious
- AllRecipes, Food Network, Delish, Taste of Home
- Budget Bytes, Minimalist Baker, Half Baked Harvest
- BBC Good Food, Simply Recipes, Sally's Baking Addiction
- And many more...

## Running Tests

```bash
cd backend
pytest -v
```

## Roadmap

- [x] MVP Backend with extraction pipeline
- [ ] Flutter Android app
- [ ] Share intent support (share from YouTube/Instagram directly)
- [ ] Ingredient synonym search (chickpea = garbanzo)
- [ ] "What should I cook?" natural language recommendations
- [ ] iOS app
- [ ] Browser extension for Instagram

## Privacy & Legal Notes

- **YouTube**: Uses yt-dlp for metadata and youtube-transcript-api for captions (public data)
- **Recipe Sites**: Respects robots.txt; uses proper User-Agent; caches aggressively
- **Instagram**: Requires manual caption input due to API restrictions
- **Data Storage**: All recipes stored locally; no data shared with third parties
- **OpenAI**: Transcript text sent to OpenAI for LLM extraction (when schema.org unavailable)

## License

MIT
