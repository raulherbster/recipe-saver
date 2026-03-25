# Recipe Saver - Implementation Plan

> Last updated: 2026-03-23

## Project Overview

A recipe-saving app where users paste YouTube/Instagram links and the app automatically extracts recipe details by:
1. Finding recipe website links in video descriptions (NYT Cooking, Serious Eats, etc.)
2. Parsing schema.org/Recipe structured data from those pages
3. Falling back to LLM extraction from transcripts when no recipe link is found

**Primary interface:** Android app (Flutter)

---

## Progress Status

### Completed
- [x] Backend project structure (FastAPI + SQLAlchemy)
- [x] Extraction pipeline (YouTube → Recipe URL → Schema.org → LLM fallback)
- [x] Database models (Recipe, Ingredient, Category, Tag)
- [x] REST API endpoints (extract, CRUD, search)
- [x] Category taxonomy seeding
- [x] README documentation
- [x] Backend tests (unit + integration)

### Completed (continued)
- [x] Flutter Android app structure
- [x] Mobile screens (Home, Add Recipe, Detail, Search, Edit)
- [x] Share intent support (share from YouTube/Instagram directly to app)
- [x] Local SQLite caching in mobile app
- [x] Offline support

### Pending
- [ ] Digital asset links (assetlinks.json on server) for deep link auto-verification

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Backend | Python 3.11+, FastAPI, SQLAlchemy, SQLite |
| YouTube | yt-dlp, youtube-transcript-api |
| Recipe Parsing | BeautifulSoup, schema.org/Recipe |
| LLM | OpenAI API (gpt-4o-mini) |
| Mobile | Flutter (Dart), Riverpod, Dio, sqflite |

---

## Architecture

```
User shares YouTube URL
         │
         ▼
┌─────────────────────────────────┐
│ 1. Fetch video metadata (yt-dlp)│
└────────────┬────────────────────┘
             ▼
┌─────────────────────────────────┐
│ 2. Scan description for recipe  │
│    URLs (NYT, Serious Eats...)  │
└────────────┬────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
 Found URL?       No URL
    │                 │
    ▼                 ▼
┌──────────────┐ ┌──────────────┐
│ 3a. Parse    │ │ 3b. Fetch    │
│ schema.org   │ │ transcript,  │
│ /Recipe      │ │ use LLM      │
└──────┬───────┘ └──────┬───────┘
       └────────┬───────┘
                ▼
┌─────────────────────────────────┐
│ 4. Normalize, categorize, save  │
└─────────────────────────────────┘
```

---

## API Endpoints (Backend)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/extract` | Extract recipe from URL |
| GET | `/api/recipes` | List recipes (paginated) |
| GET | `/api/recipes/{id}` | Get recipe details |
| POST | `/api/recipes` | Create recipe manually |
| PATCH | `/api/recipes/{id}` | Update recipe |
| DELETE | `/api/recipes/{id}` | Delete recipe |
| GET | `/api/recipes/search` | Search with filters |
| GET | `/api/categories` | Get all categories |

---

## Mobile App Screens (TODO)

### 1. Home / Recipe List
- Grid/list of saved recipes with thumbnails
- Search bar at top
- Category filter chips
- FAB to add new recipe

### 2. Add Recipe
- URL input field
- "Paste from clipboard" button
- Extraction progress indicator
- Preview of extracted recipe before saving
- Manual edit option

### 3. Recipe Detail
- Full recipe with ingredients and instructions
- Source links (video + recipe page)
- Category tags
- Edit button
- Share button

### 4. Search/Filter
- Text search
- Category multi-select filters
- Ingredient filter
- Time filter

---

## Mobile App Dependencies (Flutter)

```yaml
dependencies:
  flutter_riverpod: ^2.4.9      # State management
  dio: ^5.4.0                    # HTTP client
  sqflite: ^2.3.2               # Local database
  cached_network_image: ^3.3.1  # Image caching
  receive_sharing_intent: ^1.6.7 # Share intent
  url_launcher: ^6.2.4          # Open URLs
  shimmer: ^3.0.0               # Loading skeletons
  flutter_markdown: ^0.6.18     # Render instructions
```

---

## Category Taxonomy

| Type | Values |
|------|--------|
| dietary | vegetarian, vegan, pescatarian, gluten-free, dairy-free, keto, paleo |
| protein | chicken, beef, pork, fish, seafood, tofu, legumes, eggs |
| course | breakfast, lunch, dinner, snack, dessert, appetizer, side-dish, drink |
| cuisine | italian, mexican, indian, thai, japanese, chinese, korean, mediterranean, french, american, greek, vietnamese |
| method | baking, grilling, frying, slow-cooker, one-pot, air-fryer, instant-pot, no-cook, stir-fry |
| season | spring, summer, fall, winter |
| difficulty | easy, medium, hard |
| time | under-15m, 15-30m, 30-60m, over-60m |

---

## Version Roadmap

### MVP (Current)
- [x] Backend extraction pipeline
- [ ] Android app with basic CRUD
- [ ] Share intent support

### V1
- [ ] Ingredient synonym search (chickpea = garbanzo)
- [ ] Recipe editing with better UX
- [ ] iOS app
- [ ] Cloud sync

### V2
- [ ] "What should I cook?" NL recommendations
- [ ] Embedding-based semantic search
- [ ] Meal planning
- [ ] Browser extension for Instagram

---

## Running Locally

### Backend
```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env  # Add OPENAI_API_KEY
uvicorn app.main:app --reload
```

### Tests
```bash
cd backend
pytest -v
```

### Mobile (TODO)
```bash
cd mobile
flutter pub get
flutter run
```

---

## Files Structure

```
recipe-saver/
├── README.md
├── PLAN.md                      # This file
├── .gitignore
│
├── backend/
│   ├── pyproject.toml
│   ├── .env.example
│   ├── app/
│   │   ├── main.py              # FastAPI app
│   │   ├── config.py            # Settings
│   │   ├── api/
│   │   │   ├── routes.py        # API endpoints
│   │   │   └── schemas.py       # Pydantic models
│   │   ├── extraction/
│   │   │   ├── pipeline.py      # Main orchestrator
│   │   │   ├── youtube.py       # yt-dlp + transcripts
│   │   │   ├── recipe_sites.py  # Schema.org parsing
│   │   │   └── llm_extractor.py # OpenAI fallback
│   │   ├── models/
│   │   │   ├── database.py      # SQLAlchemy setup
│   │   │   └── recipe.py        # DB models
│   │   └── services/
│   │       └── recipe_service.py # Business logic
│   └── tests/
│       ├── conftest.py
│       ├── test_youtube.py
│       ├── test_recipe_sites.py
│       ├── test_llm_extractor.py
│       └── test_api.py
│
└── mobile/                      # TODO: Flutter app
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart
    │   ├── models/
    │   ├── services/
    │   ├── providers/
    │   └── screens/
    └── android/
```

---

## Next Steps

1. **Create Flutter project structure**
   - Initialize with `flutter create`
   - Add dependencies to pubspec.yaml
   - Set up project architecture (providers, models, services)

2. **Implement core mobile features**
   - API client service
   - Local database with sqflite
   - Recipe list screen
   - Add recipe screen with extraction
   - Recipe detail screen

3. **Add share intent**
   - Configure Android manifest
   - Handle incoming shared URLs
   - Auto-trigger extraction

4. **Polish and test**
   - Error handling
   - Loading states
   - Offline support
   - Widget tests
