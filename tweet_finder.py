import logging
import random

from config import Config

logger = logging.getLogger(__name__)


class TweetFinder:
    """AI ve teknoloji alanındaki viral tweetleri bulan modül."""

    def __init__(self, twitter_client):
        """
        Args:
            twitter_client: TwitterClient örneği.
        """
        self.twitter_client = twitter_client
        self.seen_tweet_ids = set()

    def build_search_query(self, keyword):
        """Viral tweet aramak için sorgu oluşturur.

        Args:
            keyword: Arama anahtar kelimesi.

        Returns:
            Twitter arama sorgusu.
        """
        min_likes = Config.MIN_LIKES_FOR_VIRAL
        min_retweets = Config.MIN_RETWEETS_FOR_VIRAL
        query = (
            f"{keyword} min_faves:{min_likes} min_retweets:{min_retweets} "
            f"lang:en -is:retweet -is:reply"
        )
        return query

    def find_viral_tweets(self, max_results_per_keyword=10):
        """AI ve teknoloji alanındaki viral tweetleri bulur.

        Args:
            max_results_per_keyword: Her anahtar kelime için maksimum sonuç.

        Returns:
            Viral tweetlerin listesi (beğeni sayısına göre sıralı).
        """
        all_tweets = []
        keywords = random.sample(
            Config.SEARCH_KEYWORDS,
            min(5, len(Config.SEARCH_KEYWORDS)),
        )

        for keyword in keywords:
            query = self.build_search_query(keyword)
            tweets = self.twitter_client.search_recent_tweets(
                query=query,
                max_results=max_results_per_keyword,
            )
            for tweet in tweets:
                if tweet.id not in self.seen_tweet_ids:
                    all_tweets.append(tweet)
                    self.seen_tweet_ids.add(tweet.id)

        # Beğeni sayısına göre sırala
        all_tweets.sort(
            key=lambda t: t.public_metrics.get("like_count", 0)
            if t.public_metrics
            else 0,
            reverse=True,
        )

        logger.info("Toplam %d viral tweet bulundu.", len(all_tweets))
        return all_tweets

    def get_top_viral_tweets(self, count=5):
        """En popüler viral tweetleri döndürür.

        Args:
            count: Döndürülecek tweet sayısı.

        Returns:
            En popüler viral tweetlerin listesi.
        """
        tweets = self.find_viral_tweets()
        top_tweets = tweets[:count]
        logger.info("En popüler %d viral tweet seçildi.", len(top_tweets))
        return top_tweets
