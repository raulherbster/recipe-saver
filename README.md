# Recipe Saver

Save recipes from YouTube videos, Instagram posts, and recipe websites. Paste a link and the app automatically extracts ingredients and instructions — no account or internet connection required after the initial fetch.

## Features

- **Smart URL Extraction**: Paste a YouTube video URL and the app scans the description for recipe website links
- **Schema.org Parsing**: Automatically parses structured recipe data from 40+ recipe websites
- **Direct Recipe URLs**: Paste a recipe site URL directly to extract without going through YouTube
- **Offline-First**: All recipes stored locally on-device via SQLite — no backend required
- **Google Drive Backup**: Back up and restore your recipe collection via Google Drive
- **Search**: Find recipes by title or ingredient
- **Edit & Reorder**: Edit any recipe, drag to reorder ingredients and steps

## How It Works

```
User pastes URL (YouTube, recipe site, or Instagram)
         │
         ▼
┌─────────────────────────────────┐
│ On-device ExtractionService     │
│  - YouTube: scan description    │
│    for recipe site links        │
│  - Recipe site: fetch & parse   │
│    schema.org/Recipe JSON-LD    │
│  - Instagram: parse og:desc     │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│ LocalDbService (SQLite)         │
│  - Insert / update / delete     │
│  - Search by title/ingredient   │
└─────────────────────────────────┘
```

## Project Structure

```
recipe-saver/
└── mobile/                  # Flutter Android/iOS app
    ├── lib/
    │   ├── constants/       # Category taxonomy
    │   ├── models/          # Recipe, Ingredient, etc.
    │   ├── providers/       # Riverpod state management
    │   ├── screens/         # UI screens
    │   └── services/        # ExtractionService, LocalDbService, BackupService
    └── test/                # Unit and widget tests
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Mobile | Flutter (Android & iOS) |
| Local Storage | SQLite (sqflite) |
| State Management | Riverpod |
| Recipe Parsing | schema.org/Recipe JSON-LD (html package) |
| YouTube | youtube_explode_dart |
| Backup | Google Drive (googleapis + google_sign_in) |

## Getting Started

### Prerequisites

- Flutter SDK 3.x
- Android Studio or Xcode

### Run the app

```bash
cd mobile
flutter pub get
flutter run
```

### Run tests

```bash
cd mobile
flutter test
```

## Supported Recipe Sites

The schema.org parser supports 40+ recipe websites including:

- NYT Cooking, Serious Eats, Bon Appétit, Epicurious
- AllRecipes, Food Network, Delish, Taste of Home
- Budget Bytes, Minimalist Baker, Half Baked Harvest
- BBC Good Food, Simply Recipes, Sally's Baking Addiction
- And many more...

## Category Taxonomy

Recipes are tagged with:

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

## Roadmap

- [x] On-device recipe extraction (YouTube, recipe sites, Instagram)
- [x] Local SQLite storage — fully offline
- [x] Share intent support (share from YouTube/Instagram directly)
- [x] Google Drive backup & restore
- [ ] Ingredient synonym search (chickpea = garbanzo)
- [ ] "What should I cook?" natural language recommendations
- [ ] iOS App Store release

## Privacy

- All recipes stored locally on your device
- No data sent to any server except during extraction (direct fetch from recipe sites / YouTube) and optional Google Drive backup
- No account required

## License

MIT
