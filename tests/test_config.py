import os
import sys

import pytest

# Proje kök dizinini Python yoluna ekle
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


class TestConfig:
    """Config sınıfı için birim testleri."""

    def test_default_values(self, monkeypatch):
        """Varsayılan değerlerin doğru yüklendiğini doğrular."""
        monkeypatch.delenv("TWEET_INTERVAL_MINUTES", raising=False)
        monkeypatch.delenv("COMMENT_INTERVAL_MINUTES", raising=False)
        monkeypatch.delenv("MIN_LIKES_FOR_VIRAL", raising=False)
        monkeypatch.delenv("MIN_RETWEETS_FOR_VIRAL", raising=False)

        # Config'i yeniden yükle
        import importlib

        import config

        importlib.reload(config)
        from config import Config

        assert Config.TWEET_INTERVAL_MINUTES == 60
        assert Config.COMMENT_INTERVAL_MINUTES == 30
        assert Config.MIN_LIKES_FOR_VIRAL == 100
        assert Config.MIN_RETWEETS_FOR_VIRAL == 50

    def test_custom_values(self, monkeypatch):
        """Özel değerlerin doğru yüklendiğini doğrular."""
        monkeypatch.setenv("TWEET_INTERVAL_MINUTES", "120")
        monkeypatch.setenv("COMMENT_INTERVAL_MINUTES", "45")
        monkeypatch.setenv("MIN_LIKES_FOR_VIRAL", "200")
        monkeypatch.setenv("MIN_RETWEETS_FOR_VIRAL", "100")

        import importlib

        import config

        importlib.reload(config)
        from config import Config

        assert Config.TWEET_INTERVAL_MINUTES == 120
        assert Config.COMMENT_INTERVAL_MINUTES == 45
        assert Config.MIN_LIKES_FOR_VIRAL == 200
        assert Config.MIN_RETWEETS_FOR_VIRAL == 100

    def test_validate_missing_keys(self, monkeypatch):
        """Eksik yapılandırma anahtarları için hata fırlatıldığını doğrular."""
        monkeypatch.setenv("TWITTER_API_KEY", "")
        monkeypatch.setenv("OPENAI_API_KEY", "")

        import importlib

        import config

        importlib.reload(config)
        from config import Config

        with pytest.raises(ValueError, match="Eksik yapılandırma değerleri"):
            Config.validate()

    def test_validate_all_present(self, monkeypatch):
        """Tüm anahtarlar mevcut olduğunda hata fırlatılmadığını doğrular."""
        monkeypatch.setenv("TWITTER_API_KEY", "test_key")
        monkeypatch.setenv("TWITTER_API_SECRET", "test_secret")
        monkeypatch.setenv("TWITTER_ACCESS_TOKEN", "test_token")
        monkeypatch.setenv("TWITTER_ACCESS_TOKEN_SECRET", "test_token_secret")
        monkeypatch.setenv("TWITTER_BEARER_TOKEN", "test_bearer")
        monkeypatch.setenv("OPENAI_API_KEY", "test_openai")

        import importlib

        import config

        importlib.reload(config)
        from config import Config

        Config.validate()  # Hata fırlatmamalı

    def test_search_keywords_not_empty(self):
        """Arama anahtar kelimelerinin boş olmadığını doğrular."""
        from config import Config

        assert len(Config.SEARCH_KEYWORDS) > 0
        assert "AI" in Config.SEARCH_KEYWORDS
        assert "yapay zeka" in Config.SEARCH_KEYWORDS
