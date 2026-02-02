# Recipe Saver - Mobile App

Flutter Android app for the Recipe Saver project.

## Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.2.0+)
- Android Studio or VS Code with Flutter extension
- Android device or emulator

### Installation

```bash
cd mobile

# Get dependencies
flutter pub get

# Run the app
flutter run
```

### Configuration

The app connects to the backend API. Update the API URL in `lib/providers/providers.dart`:

```dart
// For Android emulator (connects to host machine's localhost)
const String apiBaseUrl = 'http://10.0.2.2:8000';

// For iOS simulator
const String apiBaseUrl = 'http://localhost:8000';

// For production
const String apiBaseUrl = 'https://your-api.com';
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/
│   └── recipe.dart        # Data models
├── providers/
│   └── providers.dart     # Riverpod state management
├── screens/
│   ├── home_screen.dart   # Recipe list
│   ├── add_recipe_screen.dart  # URL extraction
│   ├── recipe_detail_screen.dart
│   └── search_screen.dart
├── services/
│   ├── api_service.dart   # Backend API client
│   └── share_intent_service.dart  # Handle shared URLs
└── widgets/
    └── recipe_card.dart   # Recipe card component
```

## Features

- **Add recipes**: Paste YouTube/Instagram URLs
- **Smart extraction**: Finds recipe links in video descriptions
- **Browse**: View all saved recipes
- **Search**: Find recipes by name, ingredient, or category
- **Share intent**: Share directly from YouTube/Instagram app

## Share Intent

The app registers as a share target for text content. When you share a YouTube or Instagram link from another app, Recipe Saver will open and start extracting the recipe.

### Supported URL patterns:
- `https://youtube.com/watch?v=...`
- `https://youtu.be/...`
- `https://youtube.com/shorts/...`
- `https://instagram.com/p/...`
- `https://instagram.com/reel/...`

## Building

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle
```

## Dependencies

- `flutter_riverpod` - State management
- `dio` - HTTP client
- `sqflite` - Local database (for offline support, future)
- `cached_network_image` - Image caching
- `receive_sharing_intent` - Handle share intents
- `url_launcher` - Open external URLs
