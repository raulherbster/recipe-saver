import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'screens/add_recipe_screen.dart';
import 'services/share_intent_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: RecipeSaverApp(),
    ),
  );
}

/// Global key for navigator to handle share intents
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class RecipeSaverApp extends StatefulWidget {
  const RecipeSaverApp({super.key});

  @override
  State<RecipeSaverApp> createState() => _RecipeSaverAppState();
}

class _RecipeSaverAppState extends State<RecipeSaverApp> {
  final _shareIntentService = ShareIntentService();
  String? _pendingUrl;

  @override
  void initState() {
    super.initState();
    _shareIntentService.init(
      onUrlReceived: (url) {
        _navigateToAddRecipe(url);
      },
    );
  }

  /// Navigate to add recipe screen with the shared URL
  /// Handles both immediate navigation and delayed navigation (if navigator not ready)
  void _navigateToAddRecipe(String url) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      // Navigator is ready, navigate immediately
      navigator.push(
        MaterialPageRoute(
          builder: (_) => AddRecipeScreen(initialUrl: url),
        ),
      );
    } else {
      // Navigator not ready (cold start), save URL and navigate after frame
      _pendingUrl = url;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processPendingUrl();
      });
    }
  }

  /// Process any pending URL after the navigator is ready
  void _processPendingUrl() {
    if (_pendingUrl != null) {
      final url = _pendingUrl!;
      _pendingUrl = null;
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => AddRecipeScreen(initialUrl: url),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _shareIntentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Recipe Saver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
