import logging

import tweepy

from config import Config

logger = logging.getLogger(__name__)


class TwitterClient:
    """Twitter API istemcisi. Kimlik doğrulama ve temel işlemleri yönetir."""

    def __init__(self):
        self._client = None
        self._api = None

    @property
    def client(self):
        """Tweepy Client (API v2) örneğini döndürür."""
        if self._client is None:
            self._client = tweepy.Client(
                bearer_token=Config.TWITTER_BEARER_TOKEN,
                consumer_key=Config.TWITTER_API_KEY,
                consumer_secret=Config.TWITTER_API_SECRET,
                access_token=Config.TWITTER_ACCESS_TOKEN,
                access_token_secret=Config.TWITTER_ACCESS_TOKEN_SECRET,
                wait_on_rate_limit=True,
            )
            logger.info("Twitter API v2 bağlantısı kuruldu.")
        return self._client

    @property
    def api(self):
        """Tweepy API (API v1.1) örneğini döndürür."""
        if self._api is None:
            auth = tweepy.OAuth1UserHandler(
                consumer_key=Config.TWITTER_API_KEY,
                consumer_secret=Config.TWITTER_API_SECRET,
                access_token=Config.TWITTER_ACCESS_TOKEN,
                access_token_secret=Config.TWITTER_ACCESS_TOKEN_SECRET,
            )
            self._api = tweepy.API(auth, wait_on_rate_limit=True)
            logger.info("Twitter API v1.1 bağlantısı kuruldu.")
        return self._api

    def post_tweet(self, text):
        """Yeni bir tweet atar.

        Args:
            text: Tweet metni (maksimum 280 karakter).

        Returns:
            Oluşturulan tweet verisi veya hata durumunda None.
        """
        try:
            response = self.client.create_tweet(text=text[:280])
            tweet_id = response.data["id"]
            logger.info("Tweet atıldı: %s (ID: %s)", text[:50], tweet_id)
            return response.data
        except tweepy.TweepyException:
            logger.exception("Tweet atılırken hata oluştu")
            return None

    def reply_to_tweet(self, text, tweet_id):
        """Bir tweet'e yanıt verir.

        Args:
            text: Yanıt metni (maksimum 280 karakter).
            tweet_id: Yanıtlanacak tweet'in ID'si.

        Returns:
            Oluşturulan yanıt verisi veya hata durumunda None.
        """
        try:
            response = self.client.create_tweet(
                text=text[:280],
                in_reply_to_tweet_id=tweet_id,
            )
            reply_id = response.data["id"]
            logger.info(
                "Yanıt verildi: %s (Tweet ID: %s, Yanıt ID: %s)",
                text[:50],
                tweet_id,
                reply_id,
            )
            return response.data
        except tweepy.TweepyException:
            logger.exception("Tweet'e yanıt verilirken hata oluştu")
            return None

    def search_recent_tweets(self, query, max_results=10):
        """Son tweetleri arar.

        Args:
            query: Arama sorgusu.
            max_results: Maksimum sonuç sayısı (10-100).

        Returns:
            Tweet listesi veya hata durumunda boş liste.
        """
        try:
            response = self.client.search_recent_tweets(
                query=query,
                max_results=max(10, min(max_results, 100)),
                tweet_fields=["public_metrics", "created_at", "author_id", "lang"],
                expansions=["author_id"],
            )
            if response.data:
                logger.info(
                    "'%s' sorgusu için %d tweet bulundu.",
                    query,
                    len(response.data),
                )
                return response.data
            logger.info("'%s' sorgusu için tweet bulunamadı.", query)
            return []
        except tweepy.TweepyException:
            logger.exception("Tweet aranırken hata oluştu")
            return []
