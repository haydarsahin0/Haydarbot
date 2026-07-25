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
                .photoLibrary(purposeString: "Günlüğüne galerinden fotoğraf ekleyebilmek için kullanılıyor.")
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
