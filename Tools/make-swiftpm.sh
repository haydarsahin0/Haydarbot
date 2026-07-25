#!/usr/bin/env bash
#
# Gunluk.swiftpm'i Gunluk/ altındaki kaynaklardan üretir.
#
# Swift Playgrounds Xcode projesi açamıyor, kendi paket biçimini istiyor.
# Kaynağı iki yerde tutmamak için Playgrounds sürümü bu betikle üretiliyor;
# CI her koşuda yeniden üretip fark var mı diye bakıyor, böylece iki sürüm
# birbirinden ayrı düşemiyor.
#
# Kullanım:  ./Tools/make-swiftpm.sh
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="Gunluk"
OUT="Gunluk.swiftpm"
OVERRIDES="Tools/swiftpm-overrides"

rm -rf "$OUT"
mkdir -p "$OUT/Sources"

# Swift kaynaklarını klasör yapısını koruyarak kopyala.
# Resources/ dışarıda: varlık kataloğu yalnızca Xcode hedefi için, uygulamanın
# renkleri kodda tanımlı.
( cd "$SRC" && find . -name "*.swift" -not -path "./Resources/*" -print0 ) \
  | while IFS= read -r -d '' file; do
      mkdir -p "$OUT/Sources/$(dirname "$file")"
      cp "$SRC/$file" "$OUT/Sources/$file"
    done

# Playgrounds'a özgü değişimler (şimdilik yalnızca CloudKit'in boş karşılığı).
if [ -d "$OVERRIDES" ]; then
  ( cd "$OVERRIDES" && find . -name "*.swift" -print0 ) \
    | while IFS= read -r -d '' file; do
        mkdir -p "$OUT/Sources/$(dirname "$file")"
        cp "$OVERRIDES/$file" "$OUT/Sources/$file"
      done
fi

cat > "$OUT/Package.swift" <<'SWIFT'
// swift-tools-version: 5.9

// Bu dosya Tools/make-swiftpm.sh tarafından üretiliyor — elle düzenleme.
// Kaynak kod Gunluk/ altında; buradaki kopyalar oradan geliyor.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Gunluk",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Günlük",
            targets: ["Gunluk"],
            bundleIdentifier: "com.haydarsahin.gunluk.playground",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeLeft,
                .landscapeRight
            ],
            capabilities: [
                .camera(purposeString: "Günlüğüne o günün fotoğrafını doğrudan çekerek eklemek için kamera kullanılıyor."),
                .photoLibrary(purposeString: "Günlüğüne galerinden fotoğraf ekleyebilmek için kullanılıyor."),
                .microphone(purposeString: "Günlüğüne yazmak yerine konuşarak sesli kayıt bırakabilmen için mikrofon kullanılıyor.")
            ],
            appCategory: .lifestyle
        )
    ],
    targets: [
        .executableTarget(
            name: "Gunluk",
            path: "Sources"
        )
    ]
)
SWIFT

cat > "$OUT/README.md" <<'MD'
# Günlük — Swift Playgrounds sürümü

Bu klasör `Tools/make-swiftpm.sh` tarafından üretiliyor. Kaynak kodu buradan
değil, deponun kökündeki `Gunluk/` klasöründen düzenle.

iPad'de açmak için: bu klasörü Dosyalar uygulamasına indir ve Swift
Playgrounds ile aç.

iCloud yedekleme bu sürümde kapalı — Swift Playgrounds projelerine CloudKit
yetkisi verilemiyor. Günlük yine cihazda saklanıyor, sadece yedeklenmiyor.
MD

echo "Üretildi: $OUT"
find "$OUT/Sources" -name "*.swift" | wc -l | xargs echo "Swift dosyası:"
