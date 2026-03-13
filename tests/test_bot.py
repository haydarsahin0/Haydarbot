"""
Tests for Haydarbot.

These tests do not require real Twitter or OpenAI credentials – all external
calls are mocked.
"""

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

import config
from commenter import _random_template, generate_comment
from search import search_viral_tweets


# ---------------------------------------------------------------------------
# commenter tests
# ---------------------------------------------------------------------------

class TestRandomTemplate:
    def test_returns_non_empty_string(self):
        result = _random_template()
        assert isinstance(result, str)
        assert len(result) > 0

    def test_returns_value_from_templates(self):
        result = _random_template()
        assert result in config.COMMENT_TEMPLATES


class TestGenerateComment:
    def test_falls_back_to_template_without_api_key(self):
        comment = generate_comment("Some tweet text", openai_api_key=None)
        assert isinstance(comment, str)
        assert len(comment) > 0

    def test_falls_back_to_template_when_openai_fails(self):
        with patch("commenter._generate_with_openai", return_value=None):
            comment = generate_comment("Some tweet text", openai_api_key="fake-key")
        assert comment in config.COMMENT_TEMPLATES

    def test_uses_openai_when_available(self):
        with patch("commenter._generate_with_openai", return_value="AI comment") as mock_ai:
            comment = generate_comment("Some tweet text", openai_api_key="fake-key")
        mock_ai.assert_called_once()
        assert comment == "AI comment"

    def test_empty_openai_key_skips_openai(self):
        with patch("commenter._generate_with_openai") as mock_ai:
            generate_comment("Some tweet text", openai_api_key="")
        mock_ai.assert_not_called()


# ---------------------------------------------------------------------------
# search tests
# ---------------------------------------------------------------------------

def make_mock_tweet(tweet_id: str, text: str, like_count: int, author_id: str = "123"):
    tweet = MagicMock()
    tweet.id = tweet_id
    tweet.text = text
    tweet.author_id = author_id
    tweet.public_metrics = {"like_count": like_count}
    return tweet


class TestSearchViralTweets:
    def _make_client(self, tweets):
        client = MagicMock()
        response = MagicMock()
        response.data = tweets
        client.search_recent_tweets.return_value = response
        return client

    def test_returns_tweets_above_min_likes(self):
        tweets = [
            make_mock_tweet("1", "AI tweet", 500),
            make_mock_tweet("2", "Low engagement tweet", 5),
        ]
        client = self._make_client(tweets)
        results = search_viral_tweets(client, min_likes=100, max_results=10)
        ids = [t["id"] for t in results]
        assert "1" in ids
        assert "2" not in ids

    def test_deduplicates_tweets(self):
        # Same tweet returned by two different queries
        tweet = make_mock_tweet("42", "Duplicate tweet", 200)
        client = MagicMock()
        response = MagicMock()
        response.data = [tweet]
        client.search_recent_tweets.return_value = response

        results = search_viral_tweets(client, min_likes=100, max_results=50)
        assert len([t for t in results if t["id"] == "42"]) == 1

    def test_respects_max_results(self):
        tweets = [make_mock_tweet(str(i), f"Tweet {i}", 300) for i in range(10)]
        client = self._make_client(tweets)
        results = search_viral_tweets(client, min_likes=100, max_results=3)
        assert len(results) <= 3

    def test_sorted_by_likes_descending(self):
        tweets = [
            make_mock_tweet("1", "Low", 150),
            make_mock_tweet("2", "High", 900),
            make_mock_tweet("3", "Mid", 500),
        ]
        client = self._make_client(tweets)
        results = search_viral_tweets(client, min_likes=100, max_results=10)
        likes = [t["like_count"] for t in results]
        assert likes == sorted(likes, reverse=True)

    def test_handles_empty_response(self):
        client = MagicMock()
        response = MagicMock()
        response.data = None
        client.search_recent_tweets.return_value = response
        results = search_viral_tweets(client, min_likes=100)
        assert results == []

    def test_handles_api_exception(self):
        import tweepy

        client = MagicMock()
        client.search_recent_tweets.side_effect = tweepy.TweepyException("Rate limit")
        results = search_viral_tweets(client, min_likes=100)
        assert results == []


# ---------------------------------------------------------------------------
# bot state persistence tests
# ---------------------------------------------------------------------------

class TestRepliedIdsPersistence:
    def test_save_and_load_round_trip(self, tmp_path):
        from bot import _load_replied_ids, _save_replied_ids
        import bot

        original_file = bot.REPLIED_IDS_FILE
        bot.REPLIED_IDS_FILE = tmp_path / "replied_ids.json"

        try:
            ids = {"111", "222", "333"}
            _save_replied_ids(ids)
            loaded = _load_replied_ids()
            assert loaded == ids
        finally:
            bot.REPLIED_IDS_FILE = original_file

    def test_load_returns_empty_set_when_file_missing(self, tmp_path):
        from bot import _load_replied_ids
        import bot

        original_file = bot.REPLIED_IDS_FILE
        bot.REPLIED_IDS_FILE = tmp_path / "nonexistent.json"

        try:
            result = _load_replied_ids()
            assert result == set()
        finally:
            bot.REPLIED_IDS_FILE = original_file
