import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'screens/add_recipe_screen.dart';
import 'services/share_intent_service.dart';

void main() {
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

  @override
  void initState() {
    super.initState();
    _shareIntentService.init(
      onUrlReceived: (url) {
        // Navigate to add recipe screen with the shared URL
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => AddRecipeScreen(initialUrl: url),
          ),
        );
      },
    );
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
        cardTheme: CardTheme(
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
