import os
import sys
from types import SimpleNamespace
from unittest.mock import MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from tweet_finder import TweetFinder


def _make_tweet(tweet_id, text="Test tweet", like_count=500, retweet_count=200):
    """Test için sahte tweet nesnesi oluşturur."""
    return SimpleNamespace(
        id=tweet_id,
        text=text,
        public_metrics={
            "like_count": like_count,
            "retweet_count": retweet_count,
        },
    )


class TestTweetFinder:
    """TweetFinder sınıfı için birim testleri."""

    def setup_method(self):
        self.mock_client = MagicMock()
        self.finder = TweetFinder(self.mock_client)

    def test_build_search_query(self, monkeypatch):
        """Arama sorgusunun doğru oluşturulduğunu doğrular."""
        monkeypatch.setenv("MIN_LIKES_FOR_VIRAL", "100")
        monkeypatch.setenv("MIN_RETWEETS_FOR_VIRAL", "50")

        import importlib

        import config

        importlib.reload(config)

        finder = TweetFinder(self.mock_client)
        query = finder.build_search_query("AI")

        assert "AI" in query
        assert "min_faves:100" in query
        assert "min_retweets:50" in query
        assert "-is:retweet" in query
        assert "-is:reply" in query

    def test_find_viral_tweets_returns_sorted(self):
        """Viral tweetlerin beğeni sayısına göre sıralandığını doğrular."""
        tweets = [
            _make_tweet(1, like_count=100),
            _make_tweet(2, like_count=500),
            _make_tweet(3, like_count=300),
        ]
        self.mock_client.search_recent_tweets.return_value = tweets

        result = self.finder.find_viral_tweets()

        like_counts = [t.public_metrics["like_count"] for t in result]
        assert like_counts == sorted(like_counts, reverse=True)

    def test_find_viral_tweets_deduplicates(self):
        """Tekrar eden tweetlerin filtrelendiğini doğrular."""
        tweets = [
            _make_tweet(1, like_count=500),
            _make_tweet(1, like_count=500),  # Aynı ID
            _make_tweet(2, like_count=300),
        ]
        self.mock_client.search_recent_tweets.return_value = tweets

        result = self.finder.find_viral_tweets()

        ids = [t.id for t in result]
        assert len(ids) == len(set(ids))

    def test_find_viral_tweets_empty_results(self):
        """Boş sonuçlar için boş liste döndürüldüğünü doğrular."""
        self.mock_client.search_recent_tweets.return_value = []

        result = self.finder.find_viral_tweets()

        assert result == []

    def test_get_top_viral_tweets_limits_count(self):
        """get_top_viral_tweets'in belirtilen sayıda tweet döndürdüğünü doğrular."""
        tweets = [_make_tweet(i, like_count=1000 - i * 100) for i in range(10)]
        self.mock_client.search_recent_tweets.return_value = tweets

        result = self.finder.get_top_viral_tweets(count=3)

        assert len(result) <= 3

    def test_seen_tweet_ids_tracked(self):
        """Görülen tweet ID'lerinin takip edildiğini doğrular."""
        tweets = [_make_tweet(1), _make_tweet(2)]
        self.mock_client.search_recent_tweets.return_value = tweets

        self.finder.find_viral_tweets()

        assert 1 in self.finder.seen_tweet_ids
        assert 2 in self.finder.seen_tweet_ids
