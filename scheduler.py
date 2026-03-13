import logging

import schedule

logger = logging.getLogger(__name__)


class Scheduler:
    """Bot görevlerini zamanlayan modül."""

    def __init__(self, tweet_interval_minutes, comment_interval_minutes):
        """
        Args:
            tweet_interval_minutes: Tweet atma aralığı (dakika).
            comment_interval_minutes: Yorum yapma aralığı (dakika).
        """
        self.tweet_interval = tweet_interval_minutes
        self.comment_interval = comment_interval_minutes
        self._tweet_job = None
        self._comment_job = None

    def schedule_tweet(self, tweet_func):
        """Tweet atma görevini zamanlar.

        Args:
            tweet_func: Çağrılacak tweet fonksiyonu.
        """
        self._tweet_job = (
            schedule.every(self.tweet_interval).minutes.do(tweet_func)
        )
        logger.info(
            "Tweet görevi her %d dakikada bir çalışacak şekilde zamanlandı.",
            self.tweet_interval,
        )

    def schedule_comments(self, comment_func):
        """Yorum yapma görevini zamanlar.

        Args:
            comment_func: Çağrılacak yorum fonksiyonu.
        """
        self._comment_job = (
            schedule.every(self.comment_interval).minutes.do(comment_func)
        )
        logger.info(
            "Yorum görevi her %d dakikada bir çalışacak şekilde zamanlandı.",
            self.comment_interval,
        )

    @staticmethod
    def run_pending():
        """Bekleyen görevleri çalıştırır."""
        schedule.run_pending()

    @staticmethod
    def clear_all():
        """Tüm zamanlanmış görevleri temizler."""
        schedule.clear()
        logger.info("Tüm zamanlanmış görevler temizlendi.")
