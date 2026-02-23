"""URL preprocessing utilities for handling share intent URLs."""

import re
from urllib.parse import urlparse, parse_qs, urlencode, urlunparse
from typing import Optional


def extract_url_from_share_text(text: str) -> Optional[str]:
    """
    Extract a URL from share intent text.

    Mobile share intents often include extra text around the URL.
    For example:
    - "Check out this recipe! https://youtu.be/abc123"
    - "https://www.instagram.com/reel/abc123/?igsh=xyz Sent from Instagram"

    Returns the first valid URL found, or None if no URL is found.
    """
    if not text:
        return None

    # Clean up whitespace
    text = text.strip()

    # URL pattern that matches http/https URLs
    url_pattern = r'https?://[^\s<>"\']+[^\s<>"\'\.,;:!?\)\]]'
    matches = re.findall(url_pattern, text)

    if matches:
        # Return the first match, cleaned up
        return clean_url(matches[0])

    # If no match with http/https, check if the whole text looks like a URL
    if re.match(r'^[\w\-\.]+\.[a-z]{2,}', text, re.IGNORECASE):
        # Might be a URL without protocol
        return f"https://{text}"

    return None


def clean_url(url: str) -> str:
    """
    Clean and normalize a URL.

    - Strips whitespace
    - Removes tracking parameters
    - Normalizes the URL format
    """
    if not url:
        return url

    # Strip whitespace
    url = url.strip()

    # Remove common trailing characters that aren't part of URLs
    url = url.rstrip('.,;:!?)\'\"')

    try:
        parsed = urlparse(url)

        # Get query parameters
        params = parse_qs(parsed.query, keep_blank_values=False)

        # Remove common tracking parameters
        tracking_params = {
            # UTM parameters
            'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
            # Social media tracking
            'igsh', 'igshid',  # Instagram
            'si', 'feature',  # YouTube
            'fbclid',  # Facebook
            'ref', 'ref_src', 'ref_url',
            # General tracking
            'source', 'mc_cid', 'mc_eid',
        }

        # Filter out tracking parameters
        filtered_params = {
            k: v for k, v in params.items()
            if k.lower() not in tracking_params
        }

        # Rebuild query string
        new_query = urlencode(filtered_params, doseq=True) if filtered_params else ''

        # Rebuild URL
        cleaned = urlunparse((
            parsed.scheme,
            parsed.netloc,
            parsed.path,
            parsed.params,
            new_query,
            ''  # Remove fragment
        ))

        return cleaned

    except Exception:
        # If parsing fails, return original URL
        return url


def normalize_youtube_url(url: str) -> str:
    """
    Normalize YouTube URLs to a standard format.

    Converts:
    - m.youtube.com -> www.youtube.com
    - youtu.be/ID -> youtube.com/watch?v=ID
    """
    if not url:
        return url

    try:
        parsed = urlparse(url)
        host = parsed.netloc.lower()

        # Handle youtu.be short URLs
        if 'youtu.be' in host:
            video_id = parsed.path.lstrip('/')
            if video_id:
                return f"https://www.youtube.com/watch?v={video_id}"

        # Normalize mobile URLs
        if host == 'm.youtube.com':
            return url.replace('m.youtube.com', 'www.youtube.com')

        return url

    except Exception:
        return url


def normalize_instagram_url(url: str) -> str:
    """
    Normalize Instagram URLs.

    Handles various Instagram URL formats from share intents:
    - instagram.com/p/ID (posts)
    - instagram.com/reel/ID (reels)
    - instagram.com/reels/ID (alternate reels format)
    - www.instagram.com variants
    """
    if not url:
        return url

    try:
        # Clean tracking parameters first
        url = clean_url(url)

        parsed = urlparse(url)
        host = parsed.netloc.lower()

        # Ensure www prefix for consistency
        if host == 'instagram.com':
            url = url.replace('://instagram.com', '://www.instagram.com', 1)

        return url

    except Exception:
        return url


def preprocess_share_url(url: str) -> str:
    """
    Main preprocessing function for URLs from mobile share intents.

    This function:
    1. Extracts the URL if embedded in share text
    2. Cleans tracking parameters
    3. Normalizes platform-specific URL formats

    Args:
        url: The raw URL or share text from the mobile app

    Returns:
        A cleaned and normalized URL ready for extraction
    """
    if not url:
        return url

    # First, try to extract URL if it's embedded in share text
    extracted = extract_url_from_share_text(url)
    if extracted:
        url = extracted
    else:
        # If no URL found, assume the input is the URL
        url = url.strip()

    # Clean tracking parameters
    url = clean_url(url)

    # Platform-specific normalization
    url_lower = url.lower()
    if 'youtube.com' in url_lower or 'youtu.be' in url_lower:
        url = normalize_youtube_url(url)
    elif 'instagram.com' in url_lower:
        url = normalize_instagram_url(url)

    return url
