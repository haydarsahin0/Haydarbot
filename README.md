# Günlük

Kağıt defter hissi veren bir iOS günlük uygulaması. Günler açık bir defterin
sayfaları gibi duruyor; parmakla kaydırınca sayfa sırtın etrafında dönerek
çevriliyor. Bir güne dokununca o gün açılıyor: serbestçe yazabiliyor ve günü
1-100 arasında kaydırmalı bir puanlayıcıyla değerlendirebiliyorsun.

- **Platform:** iOS 17.0+ (iPhone ve iPad)
- **Teknoloji:** SwiftUI, harici bağımlılık yok
- **Veri:** tamamen cihazda, tek bir JSON dosyasında — sunucu yok, hesap yok

## Xcode'da açmak

```
open Gunluk.xcodeproj
```

Çalıştırmadan önce yapman gereken tek şey imzalama:

1. Proje gezgininde **Gunluk** hedefini seç → **Signing & Capabilities**
2. **Team** alanına kendi Apple Developer hesabını seç
3. Gerekirse **Bundle Identifier**'ı değiştir (şu an `com.haydarsahin.gunluk`)

Proje Xcode 16 ve sonrasının "senkronize klasör" biçimini kullanıyor: `Gunluk/`
klasörüne yeni bir `.swift` dosyası eklediğinde projeye elle eklemene gerek yok,
Xcode kendiliğinden görüyor.

## Nasıl çalışıyor

### Sayfa çevirme — `Gunluk/Book/BookView.swift`

Defter her zaman iki sayfa gösteriyor: bir *açılım* (spread) ardışık iki gün.
Sürükleme ilerlemesi `turn` değerinde -1 ile 1 arasında tutuluyor.

- `turn > 0` → ileri: sağdaki yaprak sırtın (`anchor: .leading`) etrafında sola dönüyor
- `turn < 0` → geri: soldaki yaprak sırtın (`anchor: .trailing`) etrafında sağa dönüyor

Dönen yaprak tek bir görünüm. Ön yüzü 90 dereceye kadar, arka yüzü ondan sonra
görünüyor. Arka yüz `scaleEffect(x: -1)` ile aynalanıyor; yaprak 180 dereceye
vardığında dönüşün kendisi de aynaladığı için ikisi birbirini götürüyor ve yazı
düz çıkıyor.

Açının işareti önemli: SwiftUI'da Y ekseni ekranda aşağıyı gösterdiği için,
sayfanın serbest kenarının kullanıcıya *doğru* kalkması negatif açı gerektiriyor.
Bu yüzden ileri çevirmede açı negatif, geri çevirmede pozitif.

Çevirme tamamlandığında `spread` bir artırılıp `turn` sıfırlanıyor. O anki
görüntü yeni açılımla birebir aynı olduğu için geçiş görünmüyor.

### Puanlama — `Gunluk/Editor/RatingSlider.swift`

Henüz puanlanmamış soru kesikli boş bir rayla duruyor. İlk dokunuşta değer
yaylanarak yerine oturuyor, sonraki sürüklemelerde anlık takip ediyor. Parmak
kalkınca düğmenin çevresinde bir halka açılıp kayboluyor. Değer değiştikçe
`UISelectionFeedbackGenerator` ile tık tık titreşim veriliyor; 1 ve 100 uçlarında
daha sert bir geri bildirim geliyor.

Verilen puan o güne kalıcı olarak yazılıyor ve deftere döndüğünde sayfanın
altında küçük renkli bir halka olarak görünüyor — halkanın doluluğu puanı
gösteriyor.

### Sorular — `Gunluk/Models/RatingQuestion.swift`

Dört soru geliyor: mutluluk, önem, enerji, üretkenlik. Yeni soru eklemek için
`RatingQuestion.all` dizisine bir eleman eklemen yeterli.

> `id` değeri kayıtların içinde saklanıyor. Bir kez yayınlandıktan sonra
> **asla değiştirme**, yoksa kullanıcıların o soruya verdiği puanlar kaybolur.
> Soruyu kaldırmak istersen diziden çıkarman yeterli; eski puanlar dosyada
> durmaya devam eder.

### Veri — `Gunluk/Store/DiaryStore.swift`

Kayıtlar Application Support altında `gunluk-kayitlar.json` dosyasında. Yazma
işlemi 0,6 saniyelik gecikmeyle ve arka planda, `.atomic` olarak yapılıyor;
uygulama arka plana alındığında bekleyen yazma hemen tamamlanıyor.

Diskte gün numarası değil `"yyyy-MM-dd"` tarih anahtarı tutuluyor, böylece
iç gün sayacı ileride değişse bile veri bozulmuyor.

## Proje yapısı

```
Gunluk/
├── App/        GunlukApp, RootView (ana ekran), SettingsView
├── Models/     DayIndex (takvim), DiaryEntry, RatingQuestion
├── Store/      DiaryStore (kalıcılık), Haptics
├── Book/       BookView (sayfa çevirme), PageView (tek sayfa)
├── Editor/     EntryEditorView (yazma ekranı), RatingSlider
├── Theme/      Renkler ve kağıt tonları
└── Resources/  Assets.xcassets, PrivacyInfo.xcprivacy
Config/
└── Info.plist
```

## App Store'a çıkarken

Hazır olanlar:

- `PrivacyInfo.xcprivacy` — hiçbir veri toplanmıyor, izleme yok, `UserDefaults`
  erişimi `CA92.1` gerekçesiyle bildirildi
- `ITSAppUsesNonExemptEncryption = false` — şifreleme sorusu Info.plist'te
  yanıtlandığı için her yüklemede tekrar sorulmaz
- Uygulama ikonu (1024×1024, alfa kanalsız)
- Açık ve koyu tema, VoiceOver etiketleri

Senin yapman gerekenler:

1. **Bundle ID** — App Store Connect'te aynı kimlikle bir uygulama kaydı aç
2. **Sürüm** — `MARKETING_VERSION` (1.0) ve `CURRENT_PROJECT_VERSION` (1);
   her yüklemede build numarasını artır
3. **Ekran görüntüleri** — 6,9" ve 6,5" iPhone için zorunlu
4. **Gizlilik politikası bağlantısı** — veri toplanmasa da App Store Connect
   bir URL istiyor
5. **Yaş sınırı ve kategori** — Yaşam Tarzı ya da Sağlık & Fitness uygun
6. Archive → Distribute App → App Store Connect

### Sonraki adımlar için fikirler

Bunlar bilinçli olarak ilk sürüme konmadı:

- iCloud yedekleme (CloudKit) — şu anki JSON dosyası buna kolay taşınır
- Face ID ile kilit
- Günlük hatırlatma bildirimi
- Puanların zaman içindeki grafiği
- İngilizce yerelleştirme — arayüz metinleri şu an doğrudan Türkçe yazılı,
  String Catalog'a (`Localizable.xcstrings`) çıkarılması gerekir
