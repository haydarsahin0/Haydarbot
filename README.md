# 🤖 HaydarBot - AI & Teknoloji Twitter Botu

AI ve teknoloji alanında otomatik tweet atan ve viral tweetlere akıllı yorumlar yapan bir Twitter botu.

## ✨ Özellikler

- **Otomatik Tweet**: AI ve teknoloji alanında OpenAI destekli özgün tweetler oluşturur ve paylaşır
- **Viral Tweet Bulma**: AI/teknoloji alanındaki en popüler ve viral tweetleri otomatik olarak bulur
- **Otomatik Yorum**: Viral tweetlere akıllı, değer katan yorumlar yapar
- **Zamanlama**: Belirli aralıklarla otomatik olarak tweet atar ve yorum yapar

## 📋 Gereksinimler

- Python 3.9+
- Twitter Developer hesabı ve API anahtarları
- OpenAI API anahtarı

## 🚀 Kurulum

1. Repoyu klonlayın:
```bash
git clone https://github.com/haydarsahin0/Haydarbot.git
cd Haydarbot
```

2. Sanal ortam oluşturun ve aktifleştirin:
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows
```

3. Bağımlılıkları yükleyin:
```bash
pip install -r requirements.txt
```

4. Ortam değişkenlerini ayarlayın:
```bash
cp .env.example .env
```
`.env` dosyasını düzenleyerek API anahtarlarınızı ekleyin.

## ⚙️ Yapılandırma

`.env` dosyasındaki ayarlar:

| Değişken | Açıklama | Varsayılan |
|---|---|---|
| `TWITTER_API_KEY` | Twitter API anahtarı | - |
| `TWITTER_API_SECRET` | Twitter API gizli anahtarı | - |
| `TWITTER_ACCESS_TOKEN` | Twitter erişim tokeni | - |
| `TWITTER_ACCESS_TOKEN_SECRET` | Twitter erişim token gizli anahtarı | - |
| `TWITTER_BEARER_TOKEN` | Twitter Bearer tokeni | - |
| `OPENAI_API_KEY` | OpenAI API anahtarı | - |
| `TWEET_INTERVAL_MINUTES` | Tweet atma aralığı (dakika) | 60 |
| `COMMENT_INTERVAL_MINUTES` | Yorum yapma aralığı (dakika) | 30 |
| `MIN_LIKES_FOR_VIRAL` | Viral tweet için minimum beğeni | 100 |
| `MIN_RETWEETS_FOR_VIRAL` | Viral tweet için minimum retweet | 50 |

## 🏃 Kullanım

Botu başlatmak için:
```bash
python main.py
```

Bot başlatıldığında:
1. İlk olarak AI/teknoloji alanında bir tweet atar
2. Viral tweetleri bulur ve yorum yapar
3. Belirlenen aralıklarla bu işlemleri tekrar eder

Durdurmak için `Ctrl+C` tuşlarına basın.

## 🧪 Testler

Testleri çalıştırmak için:
```bash
pytest tests/ -v
```

## 📁 Proje Yapısı

```
Haydarbot/
├── main.py               # Ana giriş noktası
├── config.py             # Yapılandırma ayarları
├── twitter_client.py     # Twitter API istemcisi
├── tweet_finder.py       # Viral tweet bulucu
├── content_generator.py  # AI içerik üretici
├── auto_commenter.py     # Otomatik yorumcu
├── scheduler.py          # Görev zamanlayıcı
├── requirements.txt      # Python bağımlılıkları
├── .env.example          # Örnek ortam değişkenleri
└── tests/                # Birim testleri
    ├── test_config.py
    ├── test_tweet_finder.py
    ├── test_content_generator.py
    └── test_auto_commenter.py
```

## 📄 Lisans

MIT