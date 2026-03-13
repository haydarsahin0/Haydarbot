"""
Configuration constants and search keywords for Haydarbot.
"""

# Search queries to find viral AI/tech tweets
SEARCH_QUERIES = [
    "#AI OR #ArtificialIntelligence OR #MachineLearning",
    "#ChatGPT OR #GPT4 OR #LLM",
    "#DeepLearning OR #NeuralNetwork",
    "#AINews OR #TechNews",
    "#OpenAI OR #GoogleAI OR #MicrosoftAI",
    "#Robotics OR #Automation OR #AITools",
    "#GenerativeAI OR #GenAI",
    "#TechTrends OR #FutureTech",
]

# Comment templates used when OpenAI is unavailable or as a fallback
COMMENT_TEMPLATES = [
    "Bu konu hakkında gerçekten çok şey düşünmek gerekiyor. Yapay zekanın bu alandaki gelişimi inanılmaz! 🤖",
    "Harika bir paylaşım! AI ve teknoloji alanındaki gelişmeleri yakından takip etmek çok önemli. 🚀",
    "Bu gelişme sektörü tamamen değiştirebilir. Yapay zeka her geçen gün daha da güçleniyor! 💡",
    "Teknolojinin bu kadar hızlı ilerlemesi gerçekten şaşırtıcı. Bu konuyu takip etmeye devam edeceğim! 🔬",
    "Yapay zeka alanındaki bu yenilik çok ilgi çekici. Gelecekte neler göreceğiz acaba? 🌟",
    "Bu tür içerikleri paylaşmak için teşekkürler! AI ve tech dünyasında çok önemli bir gelişme. 👏",
    "İnanılmaz! Bu teknoloji, birçok sektörde devrim yaratacak potansiyele sahip. 🎯",
    "Yapay zeka ve teknoloji tutkunları için harika bir paylaşım. Bu alandaki gelişmeleri kaçırmamak lazım! 🧠",
]

# OpenAI model to use for comment generation
OPENAI_MODEL = "gpt-3.5-turbo"

# System prompt for OpenAI comment generation
OPENAI_SYSTEM_PROMPT = (
    "Sen bir AI ve teknoloji içerik üreticisisin. "
    "Verilen tweet'e Türkçe, samimi, pozitif ve bilgilendirici bir yorum yaz. "
    "Yorum 1-2 cümle olsun, emoji kullan, hashtag ekleme. "
    "Yorum doğal ve insan gibi görünmeli."
)
