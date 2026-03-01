"""YouTube video metadata and transcript extraction."""

import re
import json
import subprocess
from typing import Optional
from dataclasses import dataclass

from youtube_transcript_api import YouTubeTranscriptApi
from youtube_transcript_api._errors import TranscriptsDisabled, NoTranscriptFound


@dataclass
class YouTubeMetadata:
    """Extracted YouTube video metadata."""
    video_id: str
    title: str
    description: str
    channel_name: str
    channel_url: Optional[str]
    thumbnail_url: Optional[str]
    duration: Optional[int]  # seconds
    upload_date: Optional[str]
    pinned_comment: Optional[str] = None


@dataclass
class YouTubeContent:
    """Full content extracted from a YouTube video."""
    metadata: YouTubeMetadata
    transcript: Optional[str]
    extracted_urls: list[str]
    # Enhanced comment data
    comments: list["YouTubeComment"] = None
    author_comments: list[str] = None
    pattern_matched_urls: list[str] = None
    has_link_in_bio: bool = False

    def __post_init__(self):
        if self.comments is None:
            self.comments = []
        if self.author_comments is None:
            self.author_comments = []
        if self.pattern_matched_urls is None:
            self.pattern_matched_urls = []


def extract_video_id(url: str) -> Optional[str]:
    """Extract YouTube video ID from various URL formats.

    Supports:
    - youtube.com/watch?v=VIDEO_ID (desktop)
    - m.youtube.com/watch?v=VIDEO_ID (mobile)
    - youtu.be/VIDEO_ID (short links)
    - youtube.com/embed/VIDEO_ID (embeds)
    - youtube.com/shorts/VIDEO_ID (shorts)
    - youtube.com/v/VIDEO_ID (old format)
    - youtube.com/live/VIDEO_ID (live streams)
    """
    patterns = [
        # Standard watch URLs (desktop and mobile)
        r'(?:(?:www\.|m\.)?youtube\.com/watch\?v=)([a-zA-Z0-9_-]{11})',
        # Short URLs
        r'youtu\.be/([a-zA-Z0-9_-]{11})',
        # Embed URLs
        r'(?:www\.)?youtube\.com/embed/([a-zA-Z0-9_-]{11})',
        # Shorts
        r'(?:www\.)?youtube\.com/shorts/([a-zA-Z0-9_-]{11})',
        # Old format
        r'(?:www\.)?youtube\.com/v/([a-zA-Z0-9_-]{11})',
        # Live streams
        r'(?:www\.)?youtube\.com/live/([a-zA-Z0-9_-]{11})',
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None


def fetch_youtube_metadata(video_id: str) -> Optional[YouTubeMetadata]:
    """Fetch video metadata using yt-dlp."""
    try:
        result = subprocess.run(
            [
                "yt-dlp",
                "--dump-json",
                "--no-download",
                "--no-playlist",
                f"https://www.youtube.com/watch?v={video_id}",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )

        if result.returncode != 0:
            return None

        data = json.loads(result.stdout)

        return YouTubeMetadata(
            video_id=video_id,
            title=data.get("title", ""),
            description=data.get("description", ""),
            channel_name=data.get("channel", data.get("uploader", "")),
            channel_url=data.get("channel_url", data.get("uploader_url")),
            thumbnail_url=data.get("thumbnail"),
            duration=data.get("duration"),
            upload_date=data.get("upload_date"),
        )
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error fetching YouTube metadata: {e}")
        return None


@dataclass
class YouTubeComment:
    """A YouTube comment with metadata."""
    text: str
    author_id: str
    author_name: str
    is_channel_owner: bool
    is_pinned: bool = False


def fetch_top_comments(video_id: str, limit: int = 20) -> tuple[list[YouTubeComment], Optional[str]]:
    """
    Fetch top N comments from a video.

    Returns:
        Tuple of (list of comments, channel_id)
    """
    try:
        result = subprocess.run(
            [
                "yt-dlp",
                "--dump-json",
                "--no-download",
                "--no-playlist",
                "--write-comments",
                "--extractor-args", f"youtube:comment_sort=top;max_comments={limit}",
                f"https://www.youtube.com/watch?v={video_id}",
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

        if result.returncode != 0:
            return [], None

        data = json.loads(result.stdout)
        raw_comments = data.get("comments", [])
        channel_id = data.get("channel_id")

        comments = []
        for i, comment in enumerate(raw_comments[:limit]):
            author_id = comment.get("author_id", "")
            is_owner = author_id == channel_id if channel_id else False

            comments.append(YouTubeComment(
                text=comment.get("text", ""),
                author_id=author_id,
                author_name=comment.get("author", ""),
                is_channel_owner=is_owner,
                # First comment from channel owner in top sort is usually pinned
                is_pinned=is_owner and i < 3,
            ))

        return comments, channel_id
    except Exception:
        return [], None


def get_author_comments(comments: list[YouTubeComment]) -> list[str]:
    """Filter comments to only those from the channel owner."""
    return [c.text for c in comments if c.is_channel_owner]


def get_pinned_comment(comments: list[YouTubeComment]) -> Optional[str]:
    """Get the pinned comment if available."""
    for comment in comments:
        if comment.is_pinned:
            return comment.text
    return None


def fetch_pinned_comment(video_id: str) -> Optional[str]:
    """Fetch the pinned comment if available (often contains recipe links).

    Note: This is a convenience wrapper around fetch_top_comments for backwards compatibility.
    """
    comments, _ = fetch_top_comments(video_id, limit=5)
    return get_pinned_comment(comments)


def fetch_transcript(video_id: str, max_length: int = 15000) -> Optional[str]:
    """Fetch video transcript/captions."""
    try:
        ytt_api = YouTubeTranscriptApi()

        # Try to get English transcript first
        try:
            transcript = ytt_api.fetch(video_id, languages=['en', 'en-US', 'en-GB'])
        except Exception:
            # Fall back to any available transcript
            try:
                transcript = ytt_api.fetch(video_id)
            except Exception:
                return None

        if not transcript:
            return None

        # Combine transcript segments - new API returns FetchedTranscript object
        # which has snippets with .text attribute
        full_text = " ".join(snippet.text for snippet in transcript.snippets)

        # Truncate if too long
        if len(full_text) > max_length:
            full_text = full_text[:max_length] + "..."

        return full_text

    except (TranscriptsDisabled, NoTranscriptFound):
        return None
    except Exception as e:
        print(f"Error fetching transcript: {e}")
        return None


def extract_urls_from_text(text: str) -> list[str]:
    """Extract all URLs from text."""
    if not text:
        return []

    # URL pattern
    url_pattern = r'https?://[^\s<>"\')\]]+[^\s<>"\')\].,;:!?]'
    urls = re.findall(url_pattern, text)

    # Clean up URLs (remove trailing punctuation that might have been captured)
    cleaned_urls = []
    for url in urls:
        # Remove common trailing chars that aren't part of URLs
        url = url.rstrip('.,;:!?)\'\"')
        if url:
            cleaned_urls.append(url)

    return list(set(cleaned_urls))  # Deduplicate


# Patterns for extracting recipe URLs from common phrases.
# SEP matches common separators (colon, dash, arrow, !, .) and is optional
# when the phrase already contains a directional word like "here" or "at".
_SEP = r'[:\-→➡!.]?\s*'
_SEP_REQUIRED = r'[:\-→➡]\s*'

RECIPE_LINK_PATTERNS = [
    # "find the full recipe here! URL" / "get the recipe here: URL"
    r'(?:(?:find|get)\s+)?(?:the\s+)?(?:full\s+)?recipe\s+here' + _SEP + r'(https?://[^\s<>"\']+)',
    # "recipe link: URL" / "recipe link → URL"
    r'recipe\s+link\s*' + _SEP_REQUIRED + r'(https?://[^\s<>"\']+)',
    # "full recipe: URL" / "full recipe → URL"
    r'full\s+recipe\s*' + _SEP_REQUIRED + r'(https?://[^\s<>"\']+)',
    # "written recipe: URL"
    r'written\s+recipe\s*' + _SEP_REQUIRED + r'(https?://[^\s<>"\']+)',
    # "link to recipe: URL"
    r'link\s+to\s+(?:the\s+)?recipe\s*' + _SEP_REQUIRED + r'(https?://[^\s<>"\']+)',
    # "find the recipe at URL" / "recipe at URL"
    r'(?:find\s+)?(?:the\s+)?recipe\s+(?:at|on)\s+(https?://[^\s<>"\']+)',
    # "check out the recipe: URL"
    r'(?:check\s+out\s+)?(?:the\s+)?recipe\s*' + _SEP_REQUIRED + r'(https?://[^\s<>"\']+)',
]


def extract_recipe_links_from_patterns(text: str) -> list[str]:
    """
    Extract URLs that follow recipe-related phrases.

    This catches common patterns like:
    - "Get the recipe here: https://..."
    - "Full recipe: https://..."
    - "Recipe link → https://..."
    """
    if not text:
        return []

    urls = []
    text_lower = text.lower()

    for pattern in RECIPE_LINK_PATTERNS:
        matches = re.finditer(pattern, text, re.IGNORECASE)
        for match in matches:
            url = match.group(1)
            # Clean up the URL
            url = url.rstrip('.,;:!?)\'\"')
            if url:
                urls.append(url)

    return list(set(urls))  # Deduplicate


def check_for_link_in_bio(text: str) -> bool:
    """
    Check if text mentions recipe is in bio/profile.

    Returns True if patterns like "recipe in bio", "link in bio" are found.
    """
    if not text:
        return False

    bio_patterns = [
        r'recipe\s+(?:is\s+)?in\s+(?:my\s+)?bio',
        r'link\s+(?:is\s+)?in\s+(?:my\s+)?bio',
        r'check\s+(?:my\s+)?bio\s+for\s+(?:the\s+)?recipe',
        r'bio\s+for\s+(?:the\s+)?(?:full\s+)?recipe',
    ]

    for pattern in bio_patterns:
        if re.search(pattern, text, re.IGNORECASE):
            return True

    return False


async def extract_youtube_content(url: str, max_transcript_length: int = 15000) -> Optional[YouTubeContent]:
    """Extract all available content from a YouTube video."""
    video_id = extract_video_id(url)
    if not video_id:
        return None

    # Fetch metadata
    metadata = fetch_youtube_metadata(video_id)
    if not metadata:
        return None

    # Fetch transcript
    transcript = fetch_transcript(video_id, max_transcript_length)

    # Fetch top comments (including pinned and author comments)
    comments, _ = fetch_top_comments(video_id, limit=20)

    # Get pinned comment for backwards compatibility
    pinned_comment = get_pinned_comment(comments)
    if pinned_comment:
        metadata.pinned_comment = pinned_comment

    # Get author's comments (often contain recipe links)
    author_comments = get_author_comments(comments)

    # Combine all text sources for URL extraction
    all_comment_text = "\n".join(c.text for c in comments)
    all_text = "\n".join(filter(None, [
        metadata.description,
        all_comment_text,
    ]))

    # Extract URLs using both methods
    extracted_urls = extract_urls_from_text(all_text)
    pattern_matched_urls = extract_recipe_links_from_patterns(all_text)

    # Check if recipe is mentioned to be in bio
    has_link_in_bio = check_for_link_in_bio(all_text)

    return YouTubeContent(
        metadata=metadata,
        transcript=transcript,
        extracted_urls=extracted_urls,
        comments=comments,
        author_comments=author_comments,
        pattern_matched_urls=pattern_matched_urls,
        has_link_in_bio=has_link_in_bio,
    )
