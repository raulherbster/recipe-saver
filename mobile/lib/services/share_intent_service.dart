import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Service to handle incoming share intents (URLs shared from YouTube/Instagram)
class ShareIntentService {
  StreamSubscription? _subscription;
  Function(String url)? _onUrlReceived;

  /// Initialize the share intent listener
  void init({required Function(String url) onUrlReceived}) {
    _onUrlReceived = onUrlReceived;

    // Handle intent when app is opened from share
    ReceiveSharingIntent.instance.getInitialText().then((String? text) {
      if (text != null) {
        _handleSharedText(text);
      }
    });

    // Handle intent when app is already running
    _subscription = ReceiveSharingIntent.instance.getTextStream().listen(
      (String? text) {
        if (text != null) {
          _handleSharedText(text);
        }
      },
      onError: (err) {
        print('Share intent error: $err');
      },
    );
  }

  void _handleSharedText(String text) {
    // Extract URL from shared text
    final url = _extractUrl(text);
    if (url != null && _onUrlReceived != null) {
      _onUrlReceived!(url);
    }
  }

  /// Extract URL from shared text (may contain extra text)
  String? _extractUrl(String text) {
    // YouTube URL patterns
    final youtubePatterns = [
      RegExp(r'https?://(?:www\.)?youtube\.com/watch\?v=[\w-]+'),
      RegExp(r'https?://youtu\.be/[\w-]+'),
      RegExp(r'https?://(?:www\.)?youtube\.com/shorts/[\w-]+'),
    ];

    // Instagram URL patterns
    final instagramPatterns = [
      RegExp(r'https?://(?:www\.)?instagram\.com/p/[\w-]+'),
      RegExp(r'https?://(?:www\.)?instagram\.com/reel/[\w-]+'),
    ];

    // Try to find YouTube URL
    for (final pattern in youtubePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }

    // Try to find Instagram URL
    for (final pattern in instagramPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }

    // If the whole text looks like a URL, return it
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text.split(RegExp(r'\s')).first;
    }

    return null;
  }

  /// Dispose of the subscription
  void dispose() {
    _subscription?.cancel();
  }
}
