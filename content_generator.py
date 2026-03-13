import logging

from openai import OpenAI

from config import Config

logger = logging.getLogger(__name__)


class ContentGenerator:
    """OpenAI kullanarak AI ve teknoloji alanında içerik üreten modül."""

    TWEET_SYSTEM_PROMPT = (
        "Sen bir AI ve teknoloji alanında uzman sosyal medya içerik üreticisisin. "
        "Twitter için kısa, ilgi çekici ve bilgilendirici tweetler yazıyorsun. "
        "Tweetlerin Türkçe olmalı, maksimum 270 karakter olmalı, "
        "ilgili hashtagler içermeli ve etkileşim alacak şekilde yazılmalı. "
        "Emoji kullanarak tweetleri daha ilgi çekici hale getir."
    )

    REPLY_SYSTEM_PROMPT = (
        "Sen bir AI ve teknoloji alanında uzman sosyal medya yorumcususun. "
        "Twitter'da viral tweetlere akıllı, değer katan ve etkileşim yaratan "
        "yanıtlar yazıyorsun. Yanıtların Türkçe olmalı, maksimum 270 karakter "
        "olmalı ve orijinal tweete değer katmalı. "
        "Saygılı ve profesyonel ol, emoji kullan."
    )

    def __init__(self):
        self.openai_client = OpenAI(api_key=Config.OPENAI_API_KEY)

    def generate_tweet(self, topic=None):
        """AI ve teknoloji alanında yeni bir tweet oluşturur.

        Args:
            topic: Opsiyonel konu. Belirtilmezse genel AI/teknoloji içeriği üretir.

        Returns:
            Oluşturulan tweet metni veya hata durumunda None.
        """
        if topic:
            user_prompt = (
                f"'{topic}' konusunda ilgi çekici bir tweet yaz. "
                "Güncel bilgiler ve trend hashtagler kullan."
            )
        else:
            user_prompt = (
                "AI, yapay zeka veya teknoloji alanında güncel ve ilgi çekici "
                "bir tweet yaz. Trend hashtagler kullan."
            )

        try:
            response = self.openai_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": self.TWEET_SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt},
                ],
                max_tokens=150,
                temperature=0.8,
            )
            tweet_text = response.choices[0].message.content.strip()
            # Tırnak işaretlerini kaldır (varsa)
            tweet_text = tweet_text.strip('"').strip("'")
            logger.info("Tweet içeriği oluşturuldu: %s", tweet_text[:50])
            return tweet_text[:280]
        except Exception:
            logger.exception("Tweet içeriği oluşturulurken hata oluştu")
            return None

    def generate_reply(self, original_tweet_text):
        """Viral bir tweet'e akıllı yanıt oluşturur.

        Args:
            original_tweet_text: Yanıtlanacak orijinal tweet metni.

        Returns:
            Oluşturulan yanıt metni veya hata durumunda None.
        """
        user_prompt = (
            f"Aşağıdaki viral tweet'e akıllı ve değer katan bir yanıt yaz:\n\n"
            f'"{original_tweet_text}"\n\n'
            "Yanıtın bilgilendirici, saygılı ve etkileşim yaratan bir yorum olsun."
        )

        try:
            response = self.openai_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": self.REPLY_SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt},
                ],
                max_tokens=150,
                temperature=0.7,
            )
            reply_text = response.choices[0].message.content.strip()
            reply_text = reply_text.strip('"').strip("'")
            logger.info("Yanıt içeriği oluşturuldu: %s", reply_text[:50])
            return reply_text[:280]
        except Exception:
            logger.exception("Yanıt içeriği oluşturulurken hata oluştu")
            return None
