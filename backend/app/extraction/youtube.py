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


def extract_video_id(url: str) -> Optional[str]:
    """Extract YouTube video ID from various URL formats."""
    patterns = [
        r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})',
        r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})',
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


def fetch_pinned_comment(video_id: str) -> Optional[str]:
    """Fetch the pinned comment if available (often contains recipe links)."""
    try:
        result = subprocess.run(
            [
                "yt-dlp",
                "--dump-json",
                "--no-download",
                "--no-playlist",
                "--write-comments",
                "--extractor-args", "youtube:comment_sort=top;max_comments=5",
                f"https://www.youtube.com/watch?v={video_id}",
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

        if result.returncode != 0:
            return None

        data = json.loads(result.stdout)
        comments = data.get("comments", [])

        # Look for pinned comment (usually first in 'top' sort)
        for comment in comments[:3]:
            # Pinned comments are typically from the channel owner
            if comment.get("author_id") == data.get("channel_id"):
                return comment.get("text", "")

        return None
    except Exception:
        return None


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

    # Fetch pinned comment (often has recipe link)
    pinned_comment = fetch_pinned_comment(video_id)
    if pinned_comment:
        metadata.pinned_comment = pinned_comment

    # Extract URLs from description and pinned comment
    all_text = (metadata.description or "") + "\n" + (pinned_comment or "")
    extracted_urls = extract_urls_from_text(all_text)

    return YouTubeContent(
        metadata=metadata,
        transcript=transcript,
        extracted_urls=extracted_urls,
    )
