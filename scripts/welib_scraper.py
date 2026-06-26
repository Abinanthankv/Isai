"""
WeLib Audiobook Scraper
=======================
Fetch audiobook metadata, chapters, and audio streams from welib.st.

API Endpoints (directly accessible):
  - JSON chapters: https://welib.st/audiobooks/{md5}.json
  - MP3 audio:     https://ca.welib.st/audiobooks/{md5}.mp3

Main site (behind Cloudflare, blocked from automation):
  - https://welib.st/audiobooks/{md5}  (book landing page)
"""

from __future__ import annotations

import json
import logging
import os
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

import requests
from bs4 import BeautifulSoup

logger = logging.getLogger("welib")

WELIB_HOST = "https://welib.st"
CDN_HOST = "https://ca.welib.st"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/148.0.0.0 Safari/537.36"
)

HEADERS = {
    "User-Agent": USER_AGENT,
    "Accept": "text/html,application/json,*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": f"{WELIB_HOST}/",
}


# ── Data models ─────────────────────────────────────────────────

@dataclass
class ChapterSegment:
    start: float
    end: float
    text: str

@dataclass
class Audiobook:
    md5: str
    title: str = ""
    author: str = ""
    description: str = ""
    cover_url: str = ""
    duration_seconds: float = 0.0
    chapters: list[ChapterSegment] = field(default_factory=list)
    language: str = ""

    @property
    def mp3_url(self) -> str:
        return f"{CDN_HOST}/audiobooks/{self.md5}.mp3"

    @property
    def json_url(self) -> str:
        return f"{WELIB_HOST}/audiobooks/{self.md5}.json"

    @property
    def page_url(self) -> str:
        return f"{WELIB_HOST}/audiobooks/{self.md5}"

    def total_segments(self) -> int:
        return len(self.chapters)

    def duration_str(self) -> str:
        total_s = int(self.duration_seconds)
        h, rem = divmod(total_s, 3600)
        m, s = divmod(rem, 60)
        if h:
            return f"{h}h {m}m {s}s"
        return f"{m}m {s}s"


# ── Client ───────────────────────────────────────────────────────

class WelibClient:
    """Client for accessing welib.st audiobooks.

    Direct endpoints (JSON chapters + MP3 audio) work without 
    Cloudflare bypass. Search and browsing requires the main
    website which is Cloudflare-protected.
    """

    def __init__(self, use_cloudscraper: bool = False):
        self.session = requests.Session()
        self.session.headers.update(HEADERS)
        self._cloudscraper = None

        if use_cloudscraper:
            self._init_cloudscraper()

    def _init_cloudscraper(self):
        try:
            import cloudscraper
            self._cloudscraper = cloudscraper.create_scraper(
                browser={"browser": "chrome", "platform": "windows",
                         "desktop": True, "mobile": False},
                delay=15,
            )
            logger.info("cloudscraper initialised")
        except ImportError:
            logger.warning("cloudscraper not installed — search will be limited")

    def _cf_request(self, url: str, **kwargs) -> requests.Response:
        """Try to bypass Cloudflare, falling back to regular requests."""
        if self._cloudscraper:
            try:
                return self._cloudscraper.get(url, timeout=kwargs.pop("timeout", 30), **kwargs)
            except Exception as e:
                logger.warning(f"cloudscraper failed: {e}")
        return self.session.get(url, **kwargs)

    # ── Audiobook by MD5 ─────────────────────────────────────

    def get_audiobook(self, md5: str) -> Audiobook:
        """Fetch audiobook metadata and chapters by MD5 hash.

        Uses the public JSON and MP3 endpoints which are directly
        accessible (no Cloudflare).
        """
        book = Audiobook(md5=md5)

        # 1. Fetch chapter segments from JSON
        json_resp = self.session.get(book.json_url, timeout=30)
        json_resp.raise_for_status()
        segments_data = json_resp.json()

        chapters = []
        for seg in segments_data:
            chapters.append(ChapterSegment(
                start=seg.get("start", 0.0),
                end=seg.get("end", 0.0),
                text=seg.get("text", ""),
            ))
        book.chapters = chapters

        if chapters:
            book.duration_seconds = chapters[-1].end

        # 2. Try to get metadata from the book page (may fail behind Cloudflare)
        try:
            self._enrich_metadata(book)
        except Exception as e:
            logger.debug(f"Could not enrich metadata: {e}")

        return book

    def _enrich_metadata(self, book: Audiobook):
        """Try to scrape title/author/cover from the book page.

        This may fail if Cloudflare blocks the request. The book
        object will still be usable with just the MD5 hash.
        """
        resp = self._cf_request(book.page_url, timeout=20)
        if resp.status_code != 200:
            logger.info(f"Metadata page blocked (status {resp.status_code}), using MD5-only")
            return
        if "Just a moment" in resp.text:
            logger.info("Cloudflare challenge on metadata page")
            return

        soup = BeautifulSoup(resp.text, "lxml")
        book.title = self._extract_text(soup, [
            "meta[property='og:title']", "meta[name='twitter:title']",
            "h1", "title",
        ], attr="content")
        book.author = self._extract_text(soup, [
            "meta[property='book:author']", "meta[name='author']",
            ".author", "[itemprop='author']",
        ], attr="content")
        book.description = self._extract_text(soup, [
            "meta[property='og:description']", "meta[name='description']",
            ".description", "[itemprop='description']",
        ], attr="content")
        cover = self._extract_text(soup, [
            "meta[property='og:image']", "meta[name='twitter:image']",
            "link[rel='image_src']",
        ], attr="content")
        if cover:
            book.cover_url = cover

        logger.info(f"Enriched metadata: {book.title} by {book.author}")

    @staticmethod
    def _extract_text(soup: BeautifulSoup, selectors: list[str],
                      attr: str = "content") -> str:
        for sel in selectors:
            tag = soup.select_one(sel)
            if tag:
                val = tag.get(attr) or tag.get_text(strip=True)
                if val:
                    return val
        return ""

    # ── Search (behind Cloudflare) ────────────────────────────

    def search(self, query: str, max_results: int = 20) -> list[Audiobook]:
        """Search for audiobooks on welib.st.

        Cloudflare blocks automated requests, so this method
        will likely return an empty list unless a bypass is
        available via cloudscraper.
        """
        results = []

        # The search endpoint may be at /search?q=query or similar
        search_urls = [
            f"{WELIB_HOST}/search",
            f"{WELIB_HOST}/search.php",
            f"{WELIB_HOST}/audiobooks",
        ]

        for url in search_urls:
            try:
                resp = self._cf_request(url, params={"q": query, "type": "audiobook"}, timeout=20)
                if resp.status_code != 200:
                    continue
                if "Just a moment" in resp.text:
                    logger.warning("Cloudflare blocks search — try providing MD5 hashes directly")
                    continue

                soup = BeautifulSoup(resp.text, "lxml")
                found = self._parse_search_results(soup, max_results)
                results.extend(found)
                if results:
                    break
            except Exception as e:
                logger.debug(f"Search failed on {url}: {e}")

        return results[:max_results]

    def _parse_search_results(self, soup: BeautifulSoup,
                              max_results: int) -> list[Audiobook]:
        """Parse search results from the HTML page.

        This is a best-effort parser and may need adjustment
        if the site's HTML structure changes.
        """
        books = []
        for link in soup.select("a[href*='/audiobooks/']"):
            href = link.get("href", "")
            if href.startswith("/audiobooks/") and len(href) > 20:
                md5 = href.split("/")[-1].split(".")[0]
                if md5 and len(md5) == 32 and all(c in "0123456789abcdef" for c in md5.lower()):
                    title = link.get_text(strip=True) or ""
                    book = Audiobook(md5=md5, title=title)
                    books.append(book)
                    if len(books) >= max_results:
                        break
        return books

    # ── Audio download ───────────────────────────────────────

    def download_mp3(self, md5: str, dest: str | os.PathLike,
                     progress: bool = True) -> Path:
        """Download the full MP3 for an audiobook to disk.

        Args:
            md5: Audiobook MD5 hash.
            dest: Directory or file path to save to.
            progress: Show a progress bar (requires tqdm).

        Returns:
            Path to the downloaded MP3 file.
        """
        url = f"{CDN_HOST}/audiobooks/{md5}.mp3"
        dest = Path(dest)
        if dest.is_dir():
            dest = dest / f"{md5}.mp3"

        logger.info(f"Downloading {url} -> {dest}")
        with self.session.get(url, stream=True, timeout=120) as r:
            r.raise_for_status()
            total = int(r.headers.get("content-length", 0))
            downloaded = 0
            t0 = time.time()

            if progress and total > 0:
                try:
                    from tqdm import tqdm
                    pbar = tqdm(total=total, unit="B", unit_scale=True,
                                desc=dest.name)
                except ImportError:
                    pbar = None
            else:
                pbar = None

            with open(dest, "wb") as f:
                for chunk in r.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        if pbar:
                            pbar.update(len(chunk))

            if pbar:
                pbar.close()

        elapsed = time.time() - t0
        rate = downloaded / elapsed / 1024 / 1024 if elapsed > 0 else 0
        logger.info(f"Downloaded {downloaded/1024/1024:.1f}MB in "
                    f"{elapsed:.1f}s ({rate:.1f} MB/s)")
        return dest

    def stream_url(self, md5: str) -> str:
        """Get the streaming URL for an audiobook (for use with audio players)."""
        return f"{CDN_HOST}/audiobooks/{md5}.mp3"


# ── CLI ───────────────────────────────────────────────────────

def main():
    import argparse

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )

    parser = argparse.ArgumentParser(
        description="WeLib Audiobook Scraper",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Get info about an audiobook by MD5 hash
  python welib_scraper.py info b424ed507af2feca5f7f830284e3b29c

  # Download an audiobook MP3
  python welib_scraper.py download b424ed507af2feca5f7f830284e3b29c

  # Search for audiobooks (likely blocked by Cloudflare)
  python welib_scraper.py search "harry potter"

  # Export chapters as JSON
  python welib_scraper.py chapters b424ed507af2feca5f7f830284e3b29c
        """,
    )

    sub = parser.add_subparsers(dest="command", required=True)

    # info
    info_p = sub.add_parser("info", help="Show audiobook metadata")
    info_p.add_argument("md5", help="MD5 hash of the audiobook")
    info_p.add_argument("--cloudscraper", action="store_true",
                        help="Use cloudscraper for metadata enrichment")

    # download
    dl_p = sub.add_parser("download", help="Download MP3")
    dl_p.add_argument("md5", help="MD5 hash")
    dl_p.add_argument("-o", "--output", default=".",
                      help="Output directory or file path")
    dl_p.add_argument("--no-progress", action="store_false", dest="progress")

    # chapters
    ch_p = sub.add_parser("chapters", help="Export chapters as JSON")
    ch_p.add_argument("md5", help="MD5 hash")
    ch_p.add_argument("-o", "--output", help="Output JSON file (default: stdout)")

    # search
    search_p = sub.add_parser("search", help="Search audiobooks (may be blocked)")
    search_p.add_argument("query", help="Search query")
    search_p.add_argument("--max", type=int, default=20)
    search_p.add_argument("--cloudscraper", action="store_true")

    # stream URL
    stream_p = sub.add_parser("stream-url", help="Get streaming URL")
    stream_p.add_argument("md5", help="MD5 hash")

    args = parser.parse_args()
    client = WelibClient(use_cloudscraper=getattr(args, "cloudscraper", False))

    if args.command == "info":
        book = client.get_audiobook(args.md5)
        print(f"MD5:        {book.md5}")
        print(f"Title:      {book.title or 'N/A'}")
        print(f"Author:     {book.author or 'N/A'}")
        print(f"Duration:   {book.duration_str()}")
        print(f"Chapters:   {book.total_segments()}")
        print(f"Audio URL:  {book.mp3_url}")
        print(f"Page URL:   {book.page_url}")
        if book.cover_url:
            print(f"Cover:      {book.cover_url}")

    elif args.command == "download":
        dest = client.download_mp3(args.md5, args.output, progress=args.progress)
        print(f"Saved to: {dest}")

    elif args.command == "chapters":
        book = client.get_audiobook(args.md5)
        output = [{"start": c.start, "end": c.end, "text": c.text}
                  for c in book.chapters]
        if args.output:
            Path(args.output).write_text(json.dumps(output, indent=2))
            print(f"Written to: {args.output}")
        else:
            print(json.dumps(output, indent=2))

    elif args.command == "search":
        results = client.search(args.query, max_results=args.max)
        if results:
            print(f"Found {len(results)} results:")
            for b in results:
                print(f"  {b.md5}  {b.title}")
        else:
            print("No results (likely blocked by Cloudflare)")

    elif args.command == "stream-url":
        print(client.stream_url(args.md5))


if __name__ == "__main__":
    main()
