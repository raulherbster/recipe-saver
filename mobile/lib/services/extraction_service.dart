import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/recipe.dart';

const _uuid = Uuid();

/// Result of an on-device extraction attempt.
class ExtractionResult {
  final bool success;
  final Recipe? recipe;
  final String? error;
  final String method;

  const ExtractionResult._({
    required this.success,
    this.recipe,
    this.error,
    required this.method,
  });

  factory ExtractionResult.ok(Recipe recipe, String method) =>
      ExtractionResult._(success: true, recipe: recipe, method: method);

  factory ExtractionResult.fail(String error, String method) =>
      ExtractionResult._(success: false, error: error, method: method);
}

/// On-device recipe extraction — no backend required.
///
/// Supports:
///   - Recipe websites via JSON-LD schema.org/Recipe parsing
///   - YouTube / Shorts via youtube_explode_dart + JSON-LD on linked pages
///   - Instagram posts/reels via og:description scraping
class ExtractionService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (compatible; RecipeSaverBot/1.0)',
    },
  ));

  Future<ExtractionResult> extract(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return ExtractionResult.fail('Invalid URL', 'parse');

    final host = uri.host.toLowerCase();

    if (_isYouTube(host)) return _extractYouTube(url);
    if (_isInstagram(host)) return _extractInstagram(url);
    return _extractDirectUrl(url);
  }

  // ── URL type detection ──────────────────────────────────────────────────

  bool _isYouTube(String host) =>
      host.contains('youtube.com') || host.contains('youtu.be');

  bool _isInstagram(String host) => host.contains('instagram.com');

  // ── Direct recipe website ───────────────────────────────────────────────

  Future<ExtractionResult> _extractDirectUrl(String url) async {
    try {
      final html = await _fetchHtml(url);
      if (html == null) {
        return ExtractionResult.fail('Could not fetch page', 'direct_url');
      }
      final recipe = _parseJsonLd(html, sourceUrl: url);
      if (recipe != null) return ExtractionResult.ok(recipe, 'schema_org');
      return ExtractionResult.fail(
          'No recipe found on this page. Try entering the recipe manually.',
          'direct_url');
    } catch (e) {
      return ExtractionResult.fail('$e', 'direct_url');
    }
  }

  // ── YouTube ─────────────────────────────────────────────────────────────

  Future<ExtractionResult> _extractYouTube(String url) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final description = video.description;
      final title = video.title;
      final channel = video.author;
      final thumbnail = video.thumbnails.highResUrl;

      // 1. Extract all URLs from description and try JSON-LD on each
      final urls = _extractUrls(description);
      for (final recipeUrl in urls) {
        if (_isLikelyRecipeUrl(recipeUrl)) {
          final html = await _fetchHtml(recipeUrl);
          if (html != null) {
            final recipe = _parseJsonLd(html, sourceUrl: recipeUrl);
            if (recipe != null) {
              return ExtractionResult.ok(
                recipe.copyWith(
                  videoUrl: url,
                  videoPlatform: 'youtube',
                  authorName: channel,
                  thumbnailUrl: recipe.thumbnailUrl ?? thumbnail,
                ),
                'schema_org',
              );
            }
          }
        }
      }

      // 2. Try ALL urls from description (not just recipe-looking ones)
      for (final recipeUrl in urls) {
        if (_isYouTube(Uri.tryParse(recipeUrl)?.host ?? '')) continue;
        if (_isInstagram(Uri.tryParse(recipeUrl)?.host ?? '')) continue;
        final html = await _fetchHtml(recipeUrl);
        if (html != null) {
          final recipe = _parseJsonLd(html, sourceUrl: recipeUrl);
          if (recipe != null) {
            return ExtractionResult.ok(
              recipe.copyWith(
                videoUrl: url,
                videoPlatform: 'youtube',
                authorName: channel,
                thumbnailUrl: recipe.thumbnailUrl ?? thumbnail,
              ),
              'schema_org',
            );
          }
        }
      }

      // 3. Try to parse recipe structure from description text
      final fromDesc = _parseDescriptionAsRecipe(
        description,
        title: title,
        sourceUrl: url,
        videoPlatform: 'youtube',
        authorName: channel,
        thumbnailUrl: thumbnail,
      );
      if (fromDesc != null) {
        return ExtractionResult.ok(fromDesc, 'description_parse');
      }

      // 4. Scan first-page comments for recipe URLs posted by the channel author
      try {
        final comments = await yt.videos.comments.getComments(video);
        if (comments != null) {
          final authorId = video.channelId.value;
          for (final comment in comments) {
            if (comment.channelId.value != authorId) continue;
            final commentUrls = _extractUrls(comment.text);
            for (final recipeUrl in commentUrls) {
              if (_isYouTube(Uri.tryParse(recipeUrl)?.host ?? '')) continue;
              if (_isInstagram(Uri.tryParse(recipeUrl)?.host ?? '')) continue;
              final html = await _fetchHtml(recipeUrl);
              if (html != null) {
                final recipe = _parseJsonLd(html, sourceUrl: recipeUrl);
                if (recipe != null) {
                  return ExtractionResult.ok(
                    recipe.copyWith(
                      videoUrl: url,
                      videoPlatform: 'youtube',
                      authorName: channel,
                      thumbnailUrl: recipe.thumbnailUrl ?? thumbnail,
                    ),
                    'schema_org',
                  );
                }
              }
            }
          }
        }
      } catch (_) {
        // Comment API is unreliable — ignore failures silently.
      }

      return ExtractionResult.fail(
        'No recipe found in the video description or linked pages. '
        'Enter the recipe manually.',
        'youtube',
      );
    } on VideoUnplayableException {
      return ExtractionResult.fail('Video is unavailable or private.', 'youtube');
    } catch (e) {
      return ExtractionResult.fail('$e', 'youtube');
    } finally {
      yt.close();
    }
  }

  // ── Instagram ───────────────────────────────────────────────────────────

  Future<ExtractionResult> _extractInstagram(String url) async {
    try {
      final html = await _fetchHtml(url);
      if (html == null) {
        return ExtractionResult.fail('Could not fetch Instagram page', 'instagram');
      }

      // 1. Try JSON-LD (some food accounts embed it)
      final recipe = _parseJsonLd(html, sourceUrl: url);
      if (recipe != null) {
        return ExtractionResult.ok(
          recipe.copyWith(videoPlatform: 'instagram'),
          'schema_org',
        );
      }

      // 2. Try og:description (contains the caption on public posts)
      final doc = html_parser.parse(html);
      final ogDesc = doc
          .querySelector('meta[property="og:description"]')
          ?.attributes['content'];
      final ogImage = doc
          .querySelector('meta[property="og:image"]')
          ?.attributes['content'];

      if (ogDesc != null && ogDesc.isNotEmpty) {
        final fromCaption = _parseDescriptionAsRecipe(
          ogDesc,
          title: doc.querySelector('meta[property="og:title"]')?.attributes['content'] ?? 'Instagram Recipe',
          sourceUrl: url,
          videoPlatform: 'instagram',
          thumbnailUrl: ogImage,
        );
        if (fromCaption != null) {
          return ExtractionResult.ok(fromCaption, 'description_parse');
        }
      }

      return ExtractionResult.fail(
        'No recipe found in this Instagram post. Enter the recipe manually.',
        'instagram',
      );
    } catch (e) {
      return ExtractionResult.fail('$e', 'instagram');
    }
  }

  // ── JSON-LD parsing ─────────────────────────────────────────────────────

  /// Parse all <script type="application/ld+json"> blocks and return the
  /// first schema.org/Recipe found.
  Recipe? _parseJsonLd(String html, {required String sourceUrl}) {
    final doc = html_parser.parse(html);
    final scripts = doc.querySelectorAll('script[type="application/ld+json"]');

    for (final script in scripts) {
      try {
        final raw = jsonDecode(script.text);
        final recipeJson = _findRecipeInLd(raw);
        if (recipeJson != null) {
          return _mapLdToRecipe(recipeJson, sourceUrl: sourceUrl);
        }
      } catch (_) {
        // malformed JSON-LD — skip
      }
    }
    return null;
  }

  /// Recursively search for a @type: Recipe object in JSON-LD.
  Map<String, dynamic>? _findRecipeInLd(dynamic node) {
    if (node is Map<String, dynamic>) {
      final type = node['@type'];
      if (type == 'Recipe' ||
          (type is List && type.contains('Recipe'))) {
        return node;
      }
      // Handle @graph array
      if (node.containsKey('@graph')) {
        return _findRecipeInLd(node['@graph']);
      }
      for (final value in node.values) {
        final found = _findRecipeInLd(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final item in node) {
        final found = _findRecipeInLd(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  Recipe _mapLdToRecipe(Map<String, dynamic> ld, {required String sourceUrl}) {
    final now = DateTime.now();
    final uri = Uri.tryParse(sourceUrl);
    final siteName = uri?.host.replaceFirst('www.', '');

    return Recipe(
      id: _uuid.v4(),
      title: _ldString(ld['name']) ?? 'Untitled Recipe',
      description: _ldString(ld['description']),
      instructions: _parseInstructions(ld['recipeInstructions']),
      prepTimeMins: _parseIsoDuration(ld['prepTime']),
      cookTimeMins: _parseIsoDuration(ld['cookTime']),
      totalTimeMins: _parseIsoDuration(ld['totalTime']),
      servings: _ldString(ld['recipeYield']),
      ingredients: _parseIngredients(ld['recipeIngredient']),
      thumbnailUrl: _parseThumbnail(ld['image']),
      recipePageUrl: sourceUrl,
      recipeSiteName: siteName,
      extractionMethod: 'schema_org',
      extractionConfidence: 0.9,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Description-based recipe parsing ───────────────────────────────────

  /// Best-effort parse of free-form text that contains Ingredients /
  /// Instructions sections (common in YouTube descriptions and Instagram captions).
  Recipe? _parseDescriptionAsRecipe(
    String text, {
    required String title,
    required String sourceUrl,
    String? videoPlatform,
    String? authorName,
    String? thumbnailUrl,
  }) {
    final ingredientsMatch = RegExp(
      r'(?:^|\n)\s*[*•▪]?\s*ingr[eé]dients?\b[^\n]*\n([\s\S]+?)(?=\n\s*(?:instructions?|directions?|method|steps?|how to|preparation)\s*[:\-]?\s*\n|\n\s*(?:notes?|tips?|storage|nutrition|video breakdown|follow|subscribe|find|about)\b|$)',
      caseSensitive: false,
    ).firstMatch(text);

    if (ingredientsMatch == null) {
      return _parseQuantityLines(
        text,
        title: title,
        sourceUrl: sourceUrl,
        videoPlatform: videoPlatform,
        authorName: authorName,
        thumbnailUrl: thumbnailUrl,
      );
    }

    final instructionsMatch = RegExp(
      r'(?:^|\n)\s*(?:instructions?|directions?|method|steps?|how to|preparation)\s*[:\-]?\s*\n([\s\S]+?)(?=\n\s*(?:notes?|tips?|storage|nutrition)\s*[:\-]?\s*\n|$)',
      caseSensitive: false,
    ).firstMatch(text);

    final ingredientLines = ingredientsMatch
        .group(1)!
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'^[\s•*▪\-]+'), '').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (ingredientLines.isEmpty) {
      // Fallback: no explicit header — look for a run of quantity-prefixed lines.
      return _parseQuantityLines(
        text,
        title: title,
        sourceUrl: sourceUrl,
        videoPlatform: videoPlatform,
        authorName: authorName,
        thumbnailUrl: thumbnailUrl,
      );
    }

    final instructionLines = instructionsMatch
            ?.group(1)
            ?.split('\n')
            .map((l) => l.replaceAll(RegExp(r'^[\s\d]+[.)]\s*'), '').trim())
            .where((l) => l.isNotEmpty)
            .toList() ??
        [];

    final now = DateTime.now();
    return Recipe(
      id: _uuid.v4(),
      title: title,
      ingredients: ingredientLines
          .asMap()
          .entries
          .map((e) => Ingredient(
                id: _uuid.v4(),
                name: e.value,
                rawText: e.value,
                sortOrder: e.key,
              ))
          .toList(),
      instructions: instructionLines.isEmpty ? null : instructionLines,
      videoUrl: videoPlatform != null ? sourceUrl : null,
      videoPlatform: videoPlatform,
      recipePageUrl: videoPlatform == null ? sourceUrl : null,
      authorName: authorName,
      thumbnailUrl: thumbnailUrl,
      extractionMethod: 'description_parse',
      extractionConfidence: 0.5,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Quantity-line fallback ───────────────────────────────────────────────

  /// Detects a recipe embedded without explicit headers by finding a run of
  /// 4+ consecutive lines that start with a number or fraction (e.g. "2 cups
  /// flour", "1/2 tsp salt").  Used for YouTube descriptions like Claire
  /// Saffitz's that list ingredients right after the recipe title.
  Recipe? _parseQuantityLines(
    String text, {
    required String title,
    required String sourceUrl,
    String? videoPlatform,
    String? authorName,
    String? thumbnailUrl,
  }) {
    final quantityPrefix = RegExp(
      r'^[\d½¼¾⅓⅔][\d./ ]*\s*(?:oz|g|cup|cups|tbsp|tsp|lb|lbs|pound|pounds|stick|sticks|tablespoon|tablespoons|teaspoon|teaspoons|ounce|ounces|ml|liter|liters|clove|cloves|small|large|medium|head|bunch|sprig|sprigs|pinch|dash|can|cans)?\s+\S',
      caseSensitive: false,
    );
    final lines = text.split('\n');

    int? runStart;
    int runLen = 0;
    int? bestStart;
    int bestLen = 0;

    for (int i = 0; i < lines.length; i++) {
      if (quantityPrefix.hasMatch(lines[i].trim())) {
        runStart ??= i;
        runLen++;
        if (runLen > bestLen) {
          bestLen = runLen;
          bestStart = runStart;
        }
      } else {
        runStart = null;
        runLen = 0;
      }
    }

    if (bestLen < 4 || bestStart == null) return null;

    final ingredientLines =
        lines.sublist(bestStart, bestStart + bestLen).where((l) => l.trim().isNotEmpty).toList();

    final now = DateTime.now();
    return Recipe(
      id: _uuid.v4(),
      title: title,
      ingredients: ingredientLines
          .asMap()
          .entries
          .map((e) => Ingredient(
                id: _uuid.v4(),
                name: e.value.trim(),
                rawText: e.value.trim(),
                sortOrder: e.key,
              ))
          .toList(),
      instructions: null,
      videoUrl: videoPlatform != null ? sourceUrl : null,
      videoPlatform: videoPlatform,
      recipePageUrl: videoPlatform == null ? sourceUrl : null,
      authorName: authorName,
      thumbnailUrl: thumbnailUrl,
      extractionMethod: 'description_parse',
      extractionConfidence: 0.4,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<String?> _fetchHtml(String url) async {
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  List<String> _extractUrls(String text) {
    final pattern = RegExp(
      "https?://[^\\s\\)\\]>\"']+",
      caseSensitive: false,
    );
    return pattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  bool _isLikelyRecipeUrl(String url) {
    final lower = url.toLowerCase();
    const recipeKeywords = [
      '/recipe', '/recipes', 'allrecipes', 'food.com', 'epicurious',
      'seriouseats', 'bonappetit', 'nytcooking', 'thekitchn', 'delish',
      'tasty', 'yummly', 'cookpad', 'bbc.co.uk/food', 'bbcgoodfood',
    ];
    return recipeKeywords.any((kw) => lower.contains(kw));
  }

  String? _ldString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is List && value.isNotEmpty) return _ldString(value.first);
    return null;
  }

  List<Ingredient> _parseIngredients(dynamic value) {
    if (value == null) return [];
    final items = value is List ? value : [value];
    return items.asMap().entries.map((e) {
      final text = e.value.toString().trim();
      return Ingredient(
        id: _uuid.v4(),
        name: text,
        rawText: text,
        sortOrder: e.key,
      );
    }).toList();
  }

  List<String>? _parseInstructions(dynamic value) {
    if (value == null) return null;
    final items = value is List ? value : [value];
    final steps = <String>[];
    for (final item in items) {
      if (item is String) {
        steps.add(item.trim());
      } else if (item is Map) {
        final text = item['text'] ?? item['name'] ?? '';
        if (text.toString().isNotEmpty) steps.add(text.toString().trim());
      }
    }
    return steps.isEmpty ? null : steps;
  }

  String? _parseThumbnail(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return value['url']?.toString();
    if (value is List && value.isNotEmpty) return _parseThumbnail(value.first);
    return null;
  }

  /// Parse ISO 8601 duration string (e.g. "PT1H30M") to minutes.
  int? _parseIsoDuration(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(s);
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final mins = int.tryParse(match.group(2) ?? '0') ?? 0;
    final total = hours * 60 + mins;
    return total == 0 ? null : total;
  }
}

extension _RecipeCopyWith on Recipe {
  Recipe copyWith({
    String? videoUrl,
    String? videoPlatform,
    String? authorName,
    String? thumbnailUrl,
  }) {
    return Recipe(
      id: id,
      title: title,
      description: description,
      instructions: instructions,
      prepTimeMins: prepTimeMins,
      cookTimeMins: cookTimeMins,
      totalTimeMins: totalTimeMins,
      servings: servings,
      difficulty: difficulty,
      ingredients: ingredients,
      categories: categories,
      tags: tags,
      videoUrl: videoUrl ?? this.videoUrl,
      videoPlatform: videoPlatform ?? this.videoPlatform,
      recipePageUrl: recipePageUrl,
      recipeSiteName: recipeSiteName,
      originalCaption: originalCaption,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      authorName: authorName ?? this.authorName,
      extractionMethod: extractionMethod,
      extractionConfidence: extractionConfidence,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
