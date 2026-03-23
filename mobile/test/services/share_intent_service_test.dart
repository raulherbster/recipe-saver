import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_saver/services/share_intent_service.dart';

void main() {
  group('ShareIntentService — URL classification', () {
    group('isYouTubeUrl', () {
      test('recognizes standard youtube.com/watch URLs', () {
        expect(
          ShareIntentService.isYouTubeUrl(
              'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          isTrue,
        );
        expect(
          ShareIntentService.isYouTubeUrl(
              'https://youtube.com/watch?v=dQw4w9WgXcQ'),
          isTrue,
        );
        expect(
          ShareIntentService.isYouTubeUrl(
              'https://m.youtube.com/watch?v=dQw4w9WgXcQ'),
          isTrue,
        );
      });

      test('recognizes youtu.be short links', () {
        expect(
          ShareIntentService.isYouTubeUrl('https://youtu.be/dQw4w9WgXcQ'),
          isTrue,
        );
      });

      test('recognizes YouTube Shorts URLs', () {
        expect(
          ShareIntentService.isYouTubeUrl(
              'https://www.youtube.com/shorts/abc123'),
          isTrue,
        );
        expect(
          ShareIntentService.isYouTubeUrl(
              'https://youtube.com/shorts/abc123'),
          isTrue,
        );
      });

      test('returns false for Instagram URLs', () {
        expect(
          ShareIntentService.isYouTubeUrl(
              'https://www.instagram.com/reel/abc123'),
          isFalse,
        );
      });

      test('returns false for unrelated URLs', () {
        expect(
          ShareIntentService.isYouTubeUrl('https://example.com'),
          isFalse,
        );
      });
    });

    group('isInstagramUrl', () {
      test('recognizes instagram.com post URLs', () {
        expect(
          ShareIntentService.isInstagramUrl(
              'https://www.instagram.com/p/CxYZ123/'),
          isTrue,
        );
        expect(
          ShareIntentService.isInstagramUrl(
              'https://instagram.com/p/CxYZ123/'),
          isTrue,
        );
      });

      test('recognizes instagram.com reel URLs', () {
        expect(
          ShareIntentService.isInstagramUrl(
              'https://www.instagram.com/reel/CxYZ123/'),
          isTrue,
        );
        expect(
          ShareIntentService.isInstagramUrl(
              'https://instagram.com/reels/CxYZ123/'),
          isTrue,
        );
      });

      test('returns false for YouTube URLs', () {
        expect(
          ShareIntentService.isInstagramUrl(
              'https://www.youtube.com/watch?v=abc'),
          isFalse,
        );
      });

      test('returns false for unrelated URLs', () {
        expect(
          ShareIntentService.isInstagramUrl('https://example.com'),
          isFalse,
        );
      });
    });
  });
}
