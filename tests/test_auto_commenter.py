import os
import sys
from types import SimpleNamespace
from unittest.mock import MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from auto_commenter import AutoCommenter


def _make_tweet(tweet_id, text="Viral tweet", like_count=500):
    """Test için sahte tweet nesnesi oluşturur."""
    return SimpleNamespace(
        id=tweet_id,
        text=text,
        public_metrics={"like_count": like_count},
    )


class TestAutoCommenter:
    """AutoCommenter sınıfı için birim testleri."""

    def setup_method(self):
        self.mock_twitter = MagicMock()
        self.mock_finder = MagicMock()
        self.mock_generator = MagicMock()
        self.commenter = AutoCommenter(
            self.mock_twitter, self.mock_finder, self.mock_generator
        )

    def test_comment_on_viral_tweets_success(self):
        """Viral tweetlere başarıyla yorum yapıldığını doğrular."""
        tweets = [_make_tweet(1), _make_tweet(2), _make_tweet(3)]
        self.mock_finder.get_top_viral_tweets.return_value = tweets
        self.mock_generator.generate_reply.return_value = "Harika tweet! 🚀"
        self.mock_twitter.reply_to_tweet.return_value = {"id": "reply_1"}

        results = self.commenter.comment_on_viral_tweets(max_comments=2)

        assert len(results) == 2
        assert self.mock_twitter.reply_to_tweet.call_count == 2

    def test_comment_skips_already_commented(self):
        """Daha önce yorum yapılan tweetlerin atlandığını doğrular."""
        tweets = [_make_tweet(1), _make_tweet(2)]
        self.mock_finder.get_top_viral_tweets.return_value = tweets
        self.mock_generator.generate_reply.return_value = "Yanıt"
        self.mock_twitter.reply_to_tweet.return_value = {"id": "reply"}

        self.commenter.commented_tweet_ids.add(1)
        results = self.commenter.comment_on_viral_tweets(max_comments=2)

        assert len(results) == 1
        assert results[0][0] == 2

    def test_comment_handles_failed_reply_generation(self):
        """Yanıt oluşturma hatası durumunda devam edildiğini doğrular."""
        tweets = [_make_tweet(1), _make_tweet(2)]
        self.mock_finder.get_top_viral_tweets.return_value = tweets
        self.mock_generator.generate_reply.side_effect = [None, "Yanıt 2"]
        self.mock_twitter.reply_to_tweet.return_value = {"id": "reply"}

        results = self.commenter.comment_on_viral_tweets(max_comments=2)

        assert len(results) == 1

    def test_comment_handles_failed_tweet_reply(self):
        """Tweet yanıtlama hatası durumunda devam edildiğini doğrular."""
        tweets = [_make_tweet(1), _make_tweet(2)]
        self.mock_finder.get_top_viral_tweets.return_value = tweets
        self.mock_generator.generate_reply.return_value = "Yanıt"
        self.mock_twitter.reply_to_tweet.side_effect = [None, {"id": "reply"}]

        results = self.commenter.comment_on_viral_tweets(max_comments=2)

        assert len(results) == 1

    def test_comment_respects_max_comments(self):
        """max_comments limitinin saygı gösterildiğini doğrular."""
        tweets = [_make_tweet(i) for i in range(10)]
        self.mock_finder.get_top_viral_tweets.return_value = tweets
        self.mock_generator.generate_reply.return_value = "Yanıt"
        self.mock_twitter.reply_to_tweet.return_value = {"id": "reply"}

        results = self.commenter.comment_on_viral_tweets(max_comments=3)

        assert len(results) == 3

    def test_comment_empty_viral_tweets(self):
        """Viral tweet bulunamadığında boş liste döndürüldüğünü doğrular."""
        self.mock_finder.get_top_viral_tweets.return_value = []

        results = self.commenter.comment_on_viral_tweets()

        assert results == []

    def test_commented_ids_tracked(self):
        """Yorum yapılan tweet ID'lerinin takip edildiğini doğrular."""
        tweets = [_make_tweet(42)]
        self.mock_finder.get_top_viral_tweets.return_value = tweets
        self.mock_generator.generate_reply.return_value = "Yanıt"
        self.mock_twitter.reply_to_tweet.return_value = {"id": "reply"}

        self.commenter.comment_on_viral_tweets()

        assert 42 in self.commenter.commented_tweet_ids
