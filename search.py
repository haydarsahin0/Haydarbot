"""
Tweet search module – finds recent viral AI/technology tweets via Twitter API v2.
"""

import logging
from typing import Optional

import tweepy

from config import SEARCH_QUERIES

logger = logging.getLogger(__name__)


def build_client(bearer_token: str) -> tweepy.Client:
    """Return a read-only Tweepy v2 client used for searching tweets."""
    return tweepy.Client(bearer_token=bearer_token, wait_on_rate_limit=True)


def search_viral_tweets(
    client: tweepy.Client,
    min_likes: int = 100,
    max_results: int = 10,
) -> list[dict]:
    """Search for recent viral AI/tech tweets.

    Parameters
    ----------
    client:
        An authenticated :class:`tweepy.Client` instance.
    min_likes:
        Minimum public_metrics.like_count a tweet must have to be included.
    max_results:
        Maximum number of tweets to return in total across all queries.

    Returns
    -------
    list[dict]
        Deduplicated list of tweet dicts with keys ``id``, ``text``,
        ``author_id``, and ``like_count``.
    """
    seen_ids: set[str] = set()
    viral_tweets: list[dict] = []

    for query in SEARCH_QUERIES:
        if len(viral_tweets) >= max_results:
            break

        # Exclude retweets to focus on original content
        full_query = f"({query}) -is:retweet lang:en"

        try:
            response = client.search_recent_tweets(
                query=full_query,
                max_results=10,
                tweet_fields=["public_metrics", "author_id", "created_at"],
                sort_order="relevancy",
            )
        except tweepy.TweepyException as exc:
            logger.warning("Search failed for query '%s': %s", query, exc)
            continue

        if not response.data:
            continue

        for tweet in response.data:
            if tweet.id in seen_ids:
                continue
            seen_ids.add(tweet.id)

            like_count = (tweet.public_metrics or {}).get("like_count", 0)
            if like_count < min_likes:
                continue

            viral_tweets.append(
                {
                    "id": str(tweet.id),
                    "text": tweet.text,
                    "author_id": str(tweet.author_id),
                    "like_count": like_count,
                }
            )

            if len(viral_tweets) >= max_results:
                break

    # Sort by engagement (most liked first)
    viral_tweets.sort(key=lambda t: t["like_count"], reverse=True)
    logger.info("Found %d viral tweet(s).", len(viral_tweets))
    return viral_tweets
