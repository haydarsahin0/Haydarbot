"""
Haydarbot – main bot runner.

Usage
-----
    python bot.py

The bot runs immediately on start, then repeats every RUN_INTERVAL_MINUTES
minutes (default 30).  It searches for viral AI/tech tweets and replies to
each one with a contextual comment.

A simple JSON file (replied_ids.json) is kept on disk so that the bot never
replies to the same tweet twice.
"""

import json
import logging
import os
import time
from pathlib import Path

import schedule
import tweepy
from dotenv import load_dotenv

from commenter import generate_comment
from search import build_client, search_viral_tweets

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s – %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Paths & state
# ---------------------------------------------------------------------------
REPLIED_IDS_FILE = Path(__file__).parent / "replied_ids.json"


def _load_replied_ids() -> set[str]:
    """Load the set of tweet IDs that have already been replied to."""
    if REPLIED_IDS_FILE.exists():
        with REPLIED_IDS_FILE.open() as fh:
            data = json.load(fh)
        return set(data)
    return set()


def _save_replied_ids(ids: set[str]) -> None:
    """Persist the set of replied tweet IDs to disk."""
    with REPLIED_IDS_FILE.open("w") as fh:
        json.dump(list(ids), fh, indent=2)


# ---------------------------------------------------------------------------
# Core bot logic
# ---------------------------------------------------------------------------

def run_bot() -> None:
    """Single bot execution cycle: search → comment → save state."""
    load_dotenv()

    bearer_token = os.getenv("TWITTER_BEARER_TOKEN", "")
    api_key = os.getenv("TWITTER_API_KEY", "")
    api_secret = os.getenv("TWITTER_API_SECRET", "")
    access_token = os.getenv("TWITTER_ACCESS_TOKEN", "")
    access_token_secret = os.getenv("TWITTER_ACCESS_TOKEN_SECRET", "")
    openai_api_key = os.getenv("OPENAI_API_KEY", "")

    min_likes = int(os.getenv("MIN_LIKES_THRESHOLD", "100"))
    max_replies = int(os.getenv("MAX_REPLIES_PER_RUN", "5"))

    if not all([bearer_token, api_key, api_secret, access_token, access_token_secret]):
        logger.error(
            "Twitter credentials are missing. "
            "Please copy .env.example to .env and fill in your credentials."
        )
        return

    # Read-only client for searching
    search_client = build_client(bearer_token)

    # Read/write client for posting replies
    write_client = tweepy.Client(
        consumer_key=api_key,
        consumer_secret=api_secret,
        access_token=access_token,
        access_token_secret=access_token_secret,
        wait_on_rate_limit=True,
    )

    replied_ids = _load_replied_ids()
    tweets = search_viral_tweets(search_client, min_likes=min_likes, max_results=20)

    replies_sent = 0
    for tweet in tweets:
        if replies_sent >= max_replies:
            break

        tweet_id = tweet["id"]
        if tweet_id in replied_ids:
            logger.debug("Skipping already-replied tweet %s", tweet_id)
            continue

        comment = generate_comment(tweet["text"], openai_api_key or None)

        try:
            write_client.create_tweet(
                text=comment,
                in_reply_to_tweet_id=tweet_id,
            )
            logger.info(
                "Replied to tweet %s (%d likes): %.60s…",
                tweet_id,
                tweet["like_count"],
                tweet["text"],
            )
            replied_ids.add(tweet_id)
            replies_sent += 1
        except tweepy.TweepyException as exc:
            logger.error("Failed to reply to tweet %s: %s", tweet_id, exc)

    _save_replied_ids(replied_ids)
    logger.info("Run complete. Replies sent this cycle: %d", replies_sent)


# ---------------------------------------------------------------------------
# Scheduler entry point
# ---------------------------------------------------------------------------

def main() -> None:
    interval = int(os.getenv("RUN_INTERVAL_MINUTES", "30"))
    logger.info("Haydarbot starting. Running every %d minute(s).", interval)

    # Run once immediately, then schedule
    run_bot()
    schedule.every(interval).minutes.do(run_bot)

    while True:
        schedule.run_pending()
        time.sleep(10)


if __name__ == "__main__":
    load_dotenv()
    main()
