import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    """Bot yapılandırma ayarları."""

    # Twitter API
    TWITTER_API_KEY = os.getenv("TWITTER_API_KEY", "")
    TWITTER_API_SECRET = os.getenv("TWITTER_API_SECRET", "")
    TWITTER_ACCESS_TOKEN = os.getenv("TWITTER_ACCESS_TOKEN", "")
    TWITTER_ACCESS_TOKEN_SECRET = os.getenv("TWITTER_ACCESS_TOKEN_SECRET", "")
    TWITTER_BEARER_TOKEN = os.getenv("TWITTER_BEARER_TOKEN", "")

    # OpenAI API
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

    # Bot ayarları
    TWEET_INTERVAL_MINUTES = int(os.getenv("TWEET_INTERVAL_MINUTES", "60"))
    COMMENT_INTERVAL_MINUTES = int(os.getenv("COMMENT_INTERVAL_MINUTES", "30"))
    MIN_LIKES_FOR_VIRAL = int(os.getenv("MIN_LIKES_FOR_VIRAL", "100"))
    MIN_RETWEETS_FOR_VIRAL = int(os.getenv("MIN_RETWEETS_FOR_VIRAL", "50"))

    # Arama anahtar kelimeleri (AI ve teknoloji alanı)
    SEARCH_KEYWORDS = [
        "yapay zeka",
        "artificial intelligence",
        "machine learning",
        "deep learning",
        "ChatGPT",
        "OpenAI",
        "AI",
        "teknoloji",
        "tech",
        "LLM",
        "GPT",
        "neural network",
        "robotics",
        "automation",
    ]

    @classmethod
    def validate(cls):
        """Gerekli yapılandırma değerlerinin mevcut olduğunu doğrular."""
        required = {
            "TWITTER_API_KEY": cls.TWITTER_API_KEY,
            "TWITTER_API_SECRET": cls.TWITTER_API_SECRET,
            "TWITTER_ACCESS_TOKEN": cls.TWITTER_ACCESS_TOKEN,
            "TWITTER_ACCESS_TOKEN_SECRET": cls.TWITTER_ACCESS_TOKEN_SECRET,
            "TWITTER_BEARER_TOKEN": cls.TWITTER_BEARER_TOKEN,
            "OPENAI_API_KEY": cls.OPENAI_API_KEY,
        }
        missing = [key for key, value in required.items() if not value]
        if missing:
            raise ValueError(
                f"Eksik yapılandırma değerleri: {', '.join(missing)}. "
                "Lütfen .env dosyasını kontrol edin."
            )
