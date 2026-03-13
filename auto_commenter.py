import logging

logger = logging.getLogger(__name__)


class AutoCommenter:
    """Viral tweetlere otomatik yorum yapan modül."""

    def __init__(self, twitter_client, tweet_finder, content_generator):
        """
        Args:
            twitter_client: TwitterClient örneği.
            tweet_finder: TweetFinder örneği.
            content_generator: ContentGenerator örneği.
        """
        self.twitter_client = twitter_client
        self.tweet_finder = tweet_finder
        self.content_generator = content_generator
        self.commented_tweet_ids = set()

    def comment_on_viral_tweets(self, max_comments=3):
        """Viral tweetlere otomatik yorum yapar.

        Args:
            max_comments: Maksimum yorum sayısı.

        Returns:
            Yapılan yorumların listesi (tweet_id, reply_text) çiftleri.
        """
        results = []
        viral_tweets = self.tweet_finder.get_top_viral_tweets(count=max_comments * 2)

        comments_made = 0
        for tweet in viral_tweets:
            if comments_made >= max_comments:
                break

            if tweet.id in self.commented_tweet_ids:
                logger.info(
                    "Tweet %s daha önce yorumlanmış, atlanıyor.", tweet.id
                )
                continue

            reply_text = self.content_generator.generate_reply(tweet.text)
            if reply_text is None:
                logger.warning("Tweet %s için yanıt oluşturulamadı.", tweet.id)
                continue

            result = self.twitter_client.reply_to_tweet(reply_text, tweet.id)
            if result is not None:
                self.commented_tweet_ids.add(tweet.id)
                results.append((tweet.id, reply_text))
                comments_made += 1
                logger.info(
                    "Viral tweet %s'e yorum yapıldı: %s",
                    tweet.id,
                    reply_text[:50],
                )
            else:
                logger.warning("Tweet %s'e yorum yapılamadı.", tweet.id)

        logger.info("Toplam %d viral tweet'e yorum yapıldı.", comments_made)
        return results
