import os
import sys
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from content_generator import ContentGenerator


def _mock_openai_response(text):
    """Sahte OpenAI yanıtı oluşturur."""
    return SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(content=text))]
    )


class TestContentGenerator:
    """ContentGenerator sınıfı için birim testleri."""

    @patch("content_generator.OpenAI")
    def setup_method(self, method, mock_openai_cls):
        self.mock_openai = MagicMock()
        mock_openai_cls.return_value = self.mock_openai
        self.generator = ContentGenerator()

    def test_generate_tweet_returns_text(self):
        """Tweet içeriğinin düzgün oluşturulduğunu doğrular."""
        self.mock_openai.chat.completions.create.return_value = (
            _mock_openai_response("Test tweet 🤖 #AI #Teknoloji")
        )

        result = self.generator.generate_tweet()

        assert result is not None
        assert len(result) <= 280

    def test_generate_tweet_with_topic(self):
        """Konu belirtildiğinde içeriğin oluşturulduğunu doğrular."""
        self.mock_openai.chat.completions.create.return_value = (
            _mock_openai_response("ChatGPT hakkında tweet #ChatGPT")
        )

        result = self.generator.generate_tweet(topic="ChatGPT")

        assert result is not None
        call_args = self.mock_openai.chat.completions.create.call_args
        user_msg = call_args[1]["messages"][1]["content"]
        assert "ChatGPT" in user_msg

    def test_generate_tweet_strips_quotes(self):
        """Tweet metnindeki tırnak işaretlerinin temizlendiğini doğrular."""
        self.mock_openai.chat.completions.create.return_value = (
            _mock_openai_response('"Test tweet tırnak içinde"')
        )

        result = self.generator.generate_tweet()

        assert not result.startswith('"')
        assert not result.endswith('"')

    def test_generate_tweet_truncates_to_280(self):
        """280 karakterden uzun tweetlerin kesildiğini doğrular."""
        long_text = "A" * 300
        self.mock_openai.chat.completions.create.return_value = (
            _mock_openai_response(long_text)
        )

        result = self.generator.generate_tweet()

        assert len(result) <= 280

    def test_generate_tweet_handles_error(self):
        """Hata durumunda None döndürüldüğünü doğrular."""
        self.mock_openai.chat.completions.create.side_effect = Exception("API hatası")

        result = self.generator.generate_tweet()

        assert result is None

    def test_generate_reply_returns_text(self):
        """Yanıt içeriğinin düzgün oluşturulduğunu doğrular."""
        self.mock_openai.chat.completions.create.return_value = (
            _mock_openai_response("Harika bir bakış açısı! 🚀")
        )

        result = self.generator.generate_reply("Orijinal tweet metni")

        assert result is not None
        assert len(result) <= 280

    def test_generate_reply_handles_error(self):
        """Yanıt hatası durumunda None döndürüldüğünü doğrular."""
        self.mock_openai.chat.completions.create.side_effect = Exception("API hatası")

        result = self.generator.generate_reply("Test tweet")

        assert result is None

    def test_generate_reply_includes_original_in_prompt(self):
        """Orijinal tweet metninin prompt'a dahil edildiğini doğrular."""
        self.mock_openai.chat.completions.create.return_value = (
            _mock_openai_response("Yanıt metni")
        )

        self.generator.generate_reply("AI gelecektir!")

        call_args = self.mock_openai.chat.completions.create.call_args
        user_msg = call_args[1]["messages"][1]["content"]
        assert "AI gelecektir!" in user_msg
