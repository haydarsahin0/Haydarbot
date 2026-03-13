# Haydarbot

Haydarbot, AI ve teknoloji alanındaki viral tweetleri otomatik olarak bulan ve bu tweetlere Türkçe yorum yapan bir Twitter botudur.

## Özellikler

- 🔍 **Viral Tweet Arama** – Twitter API v2 aracılığıyla AI/teknoloji tweetlerini gerçek zamanlı tarar
- 🤖 **Akıllı Yorum Üretimi** – OpenAI GPT ile bağlama uygun yorumlar üretir; anahtar yoksa hazır şablonlara düşer
- ♻️ **Tekrar Yorum Yapmaz** – Her tweet yalnızca bir kez yanıtlanır (`replied_ids.json` ile takip edilir)
- ⏰ **Otomatik Zamanlama** – İstenen aralıkta (varsayılan: 30 dakika) tekrar çalışır

## Kurulum

### Gereksinimler

- Python 3.10+
- [Twitter Developer hesabı](https://developer.twitter.com/) (OAuth 1.0a kullanıcı kimlik bilgileri + Bearer Token)
- *(Opsiyonel)* [OpenAI API anahtarı](https://platform.openai.com/api-keys) – daha akıllı yorumlar için

### Adımlar

```bash
# 1. Bağımlılıkları yükle
pip install -r requirements.txt

# 2. Ortam değişkenlerini oluştur
cp .env.example .env
# .env dosyasını açıp gerçek kimlik bilgilerini gir

# 3. Botu çalıştır
python bot.py
```

## Yapılandırma (`.env`)

| Değişken | Açıklama |
|---|---|
| `TWITTER_API_KEY` | Twitter uygulamasının API Key |
| `TWITTER_API_SECRET` | Twitter uygulamasının API Secret |
| `TWITTER_ACCESS_TOKEN` | Kullanıcı Access Token |
| `TWITTER_ACCESS_TOKEN_SECRET` | Kullanıcı Access Token Secret |
| `TWITTER_BEARER_TOKEN` | Tweet aramak için kullanılan Bearer Token |
| `OPENAI_API_KEY` | *(Opsiyonel)* OpenAI API key |
| `RUN_INTERVAL_MINUTES` | Bot çalışma sıklığı (dakika), varsayılan: `30` |
| `MAX_REPLIES_PER_RUN` | Her çalışmada maksimum yanıt sayısı, varsayılan: `5` |
| `MIN_LIKES_THRESHOLD` | Viral kabul için minimum beğeni sayısı, varsayılan: `100` |

## Proje Yapısı

```
Haydarbot/
├── bot.py            # Ana çalıştırıcı ve zamanlayıcı
├── search.py         # Viral tweet arama modülü
├── commenter.py      # Yorum üretim modülü (OpenAI + şablon)
├── config.py         # Arama sorguları ve sabitler
├── requirements.txt  # Python bağımlılıkları
├── .env.example      # Ortam değişkeni şablonu
├── replied_ids.json  # Yanıtlanan tweet ID'leri (otomatik oluşturulur)
└── tests/
    └── test_bot.py   # Birim testler
```

## Testleri Çalıştırma

```bash
pytest tests/ -v
```

## Notlar

- Twitter API v2 ücretsiz katmanında arama kısıtlamaları olabilir; ücretli katmana geçmeyi değerlendirin.
- Bot, Twitter'ın oran limitlerini (rate limit) otomatik olarak bekler (`wait_on_rate_limit=True`).
- `replied_ids.json` dosyası her çalışmada güncellenir; silmek yeniden yorum yapılmasına yol açar.
