import logging
import time

from auto_commenter import AutoCommenter
from config import Config
from content_generator import ContentGenerator
from scheduler import Scheduler
from tweet_finder import TweetFinder
from twitter_client import TwitterClient

# Loglama yapılandırması
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("bot.log", encoding="utf-8"),
    ],
)
logger = logging.getLogger(__name__)


class HaydarBot:
    """Ana bot sınıfı. Tüm modülleri koordine eder."""

    def __init__(self):
        Config.validate()
        self.twitter_client = TwitterClient()
        self.content_generator = ContentGenerator()
        self.tweet_finder = TweetFinder(self.twitter_client)
        self.auto_commenter = AutoCommenter(
            self.twitter_client,
            self.tweet_finder,
            self.content_generator,
        )
        self.scheduler = Scheduler(
            Config.TWEET_INTERVAL_MINUTES,
            Config.COMMENT_INTERVAL_MINUTES,
        )

    def post_ai_tweet(self):
        """AI/teknoloji alanında otomatik tweet atar."""
        logger.info("Otomatik tweet oluşturuluyor...")
        tweet_text = self.content_generator.generate_tweet()
        if tweet_text:
            result = self.twitter_client.post_tweet(tweet_text)
            if result:
                logger.info("Otomatik tweet başarıyla atıldı.")
            else:
                logger.error("Otomatik tweet atılamadı.")
        else:
            logger.error("Tweet içeriği oluşturulamadı.")

    def comment_on_viral(self):
        """Viral tweetlere otomatik yorum yapar."""
        logger.info("Viral tweetlere yorum yapılıyor...")
        results = self.auto_commenter.comment_on_viral_tweets(max_comments=3)
        logger.info("%d viral tweet'e yorum yapıldı.", len(results))

    def run(self):
        """Botu başlatır ve zamanlanmış görevleri çalıştırır."""
        logger.info("=" * 50)
        logger.info("HaydarBot başlatılıyor...")
        logger.info("Tweet aralığı: %d dakika", Config.TWEET_INTERVAL_MINUTES)
        logger.info("Yorum aralığı: %d dakika", Config.COMMENT_INTERVAL_MINUTES)
        logger.info("=" * 50)

        # İlk çalıştırmada hemen bir tweet at ve yorum yap
        self.post_ai_tweet()
        self.comment_on_viral()

        # Zamanlanmış görevleri ayarla
        self.scheduler.schedule_tweet(self.post_ai_tweet)
        self.scheduler.schedule_comments(self.comment_on_viral)

        logger.info("Bot çalışıyor. Durdurmak için Ctrl+C tuşlarına basın.")

        try:
            while True:
                self.scheduler.run_pending()
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("Bot durduruluyor...")
            self.scheduler.clear_all()
            logger.info("Bot durduruldu.")


def main():
    """Ana giriş noktası."""
    bot = HaydarBot()
    bot.run()


if __name__ == "__main__":
    main()
