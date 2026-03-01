import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Service to handle incoming share intents (URLs shared from YouTube/Instagram)
///
/// Supports both cold start (app launched from share) and warm start (share while app running)
class ShareIntentService {
  Function(String url)? _onUrlReceived;
  StreamSubscription<List<SharedMediaFile>>? _mediaSubscription;

  /// URL patterns to match YouTube and Instagram URLs
  static final _youtubePatterns = [
    RegExp(r'https?://(www\.)?youtube\.com/watch\?v=[\w-]+'),
    RegExp(r'https?://youtu\.be/[\w-]+'),
    RegExp(r'https?://m\.youtube\.com/watch\?v=[\w-]+'),
    RegExp(r'https?://(www\.)?youtube\.com/shorts/[\w-]+'),
  ];

  static final _instagramPatterns = [
    RegExp(r'https?://(www\.)?instagram\.com/p/[\w-]+'),
    RegExp(r'https?://(www\.)?instagram\.com/reel/[\w-]+'),
    RegExp(r'https?://(www\.)?instagram\.com/reels/[\w-]+'),
  ];

  /// Initialize the share intent listener
  ///
  /// [onUrlReceived] is called when a valid YouTube/Instagram URL is received
  void init({required Function(String url) onUrlReceived}) {
    _onUrlReceived = onUrlReceived;

    // Handle cold start - app launched from share intent
    _getInitialSharedData();

    // Handle warm start - share while app is running
    _setupStreamListeners();
  }

  /// Get initial shared data when app is launched from a share intent (cold start)
  Future<void> _getInitialSharedData() async {
    try {
      // Check for shared media files first
      final mediaFiles = await ReceiveSharingIntent.instance.getInitialMedia();
      if (mediaFiles.isNotEmpty) {
        _handleMediaFiles(mediaFiles);
        ReceiveSharingIntent.instance.reset();
        return;
      }

      // No separate text API in v1.8.x — text items arrive via getInitialMedia()
      // with SharedMediaType.text and are handled in _handleMediaFiles above.
    } catch (e) {
      // Log error but don't crash - share intent handling is optional
      print('ShareIntentService: Error getting initial shared data: $e');
    }
  }

  /// Set up stream listeners for warm start scenarios
  void _setupStreamListeners() {
    // Listen for incoming media files (some apps share URLs as media)
    _mediaSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        _handleMediaFiles(files);
        ReceiveSharingIntent.instance.reset();
      },
      onError: (err) {
        print('ShareIntentService: Media stream error: $err');
      },
    );

    // Text items (SharedMediaType.text) are delivered via getMediaStream() in v1.8.x.
  }

  /// Handle shared media files (including text items from SharedMediaType.text)
  void _handleMediaFiles(List<SharedMediaFile> files) {
    for (final file in files) {
      // Text shares (URLs shared as plain text) arrive with type == text;
      // the path field holds the actual text content.
      final content = file.path;
      final url = _extractUrl(content);
      if (url != null) {
        _onUrlReceived?.call(url);
        return;
      }
    }
  }

  /// Extract a valid YouTube or Instagram URL from text
  ///
  /// Returns the first valid URL found, or null if none found
  String? _extractUrl(String text) {
    // First try to find YouTube URLs
    for (final pattern in _youtubePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return _cleanUrl(match.group(0)!);
      }
    }

    // Then try Instagram URLs
    for (final pattern in _instagramPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return _cleanUrl(match.group(0)!);
      }
    }

    // If no specific pattern matched, check if the whole text is a URL
    final urlPattern = RegExp(
      r'https?://[^\s<>"{}|\\^`\[\]]+',
      caseSensitive: false,
    );
    final match = urlPattern.firstMatch(text);
    if (match != null) {
      final url = match.group(0)!;
      // Only return if it's a YouTube or Instagram URL
      if (_isValidRecipeUrl(url)) {
        return _cleanUrl(url);
      }
    }

    return null;
  }

  /// Clean up the URL (remove trailing garbage, tracking parameters for cleaner URLs)
  String _cleanUrl(String url) {
    // Remove common trailing characters that might be attached
    var cleaned = url.replaceAll(RegExp(r"""[)\]}>'",;]+$"""), '');

    // For YouTube URLs, we might want to keep the URL as-is since the backend
    // handles different formats. For Instagram, same applies.
    return cleaned;
  }

  /// Check if URL is a valid YouTube or Instagram URL
  bool _isValidRecipeUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be') ||
        lowerUrl.contains('instagram.com');
  }

  /// Check if a URL is a YouTube URL
  static bool isYouTubeUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be');
  }

  /// Check if a URL is an Instagram URL
  static bool isInstagramUrl(String url) {
    return url.toLowerCase().contains('instagram.com');
  }

  /// Dispose of the subscriptions
  void dispose() {
    _mediaSubscription?.cancel();
    _mediaSubscription = null;
    _onUrlReceived = null;
  }
}
