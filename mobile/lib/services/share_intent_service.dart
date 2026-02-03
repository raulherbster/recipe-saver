import 'dart:async';

/// Service to handle incoming share intents (URLs shared from YouTube/Instagram)
///
/// Note: Share intent functionality temporarily disabled due to package compatibility issues.
/// TODO: Re-enable with a compatible package or native implementation.
class ShareIntentService {
  Function(String url)? _onUrlReceived;

  /// Initialize the share intent listener
  void init({required Function(String url) onUrlReceived}) {
    _onUrlReceived = onUrlReceived;
    // Share intent handling disabled for now
    // Will be re-enabled with a compatible solution
  }

  /// Dispose of the subscription
  void dispose() {
    // Nothing to dispose
  }
}
