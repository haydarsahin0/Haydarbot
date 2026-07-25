import UIKit

/// Günlere eklenen fotoğrafların dosya deposu.
///
/// Görseller JSON kaydının içine değil, Application Support altındaki ayrı bir
/// klasöre yazılıyor; kayıt dosyasında yalnızca kimlikleri duruyor. Böylece
/// günlük dosyası küçük kalıyor ve her açılışta yüzlerce megabayt çözümlenmiyor.
@MainActor
final class PhotoStore: ObservableObject {

    private let directory: URL
    private let thumbnailCache = NSCache<NSString, UIImage>()

    /// Tam boy görsellerin uzun kenarı bu değere indiriliyor. Telefonun ürettiği
    /// 12 MP kareler günlük için gereğinden büyük; bu boyut ekranda kayıpsız
    /// görünüyor ama dosyayı onda birine düşürüyor.
    private let maxDimension: CGFloat = 2048
    private let thumbnailDimension: CGFloat = 400
    private let compressionQuality: CGFloat = 0.82

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true))
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = base.appendingPathComponent("fotograflar", isDirectory: true)
        }
        thumbnailCache.countLimit = 120
        try? FileManager.default.createDirectory(at: self.directory,
                                                 withIntermediateDirectories: true)
    }

    // MARK: - Yollar

    func url(for id: String) -> URL {
        directory.appendingPathComponent("\(id).jpg")
    }

    func exists(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    // MARK: - Yazma

    /// Görseli küçültüp diske yazar ve kimliğini döndürür.
    @discardableResult
    func save(_ image: UIImage) -> String? {
        let id = UUID().uuidString
        let resized = image.downscaled(toMaxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        do {
            try data.write(to: url(for: id), options: .atomic)
            return id
        } catch {
            assertionFailure("Fotoğraf yazılamadı: \(error)")
            return nil
        }
    }

    /// Fotoğraf seçicinin verdiği ham veriyi kaydeder.
    @discardableResult
    func save(data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        return save(image)
    }

    func delete(_ id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
        thumbnailCache.removeObject(forKey: id as NSString)
    }

    func delete(_ ids: [String]) {
        ids.forEach(delete)
    }

    // MARK: - Okuma

    func image(_ id: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: id).path)
    }

    /// Listelerde kullanılan küçük kopya. Bir kez üretilip bellekte tutuluyor.
    func thumbnail(_ id: String) -> UIImage? {
        if let cached = thumbnailCache.object(forKey: id as NSString) {
            return cached
        }
        guard let full = image(id) else { return nil }
        let small = full.downscaled(toMaxDimension: thumbnailDimension)
        thumbnailCache.setObject(small, forKey: id as NSString)
        return small
    }

    /// Kayıtlarda artık geçmeyen dosyaları siler. Uygulama açılışında çağrılıyor.
    func removeOrphans(keeping usedIDs: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.pathExtension == "jpg" {
            let id = file.deletingPathExtension().lastPathComponent
            if !usedIDs.contains(id) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    var totalBytes: Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return files.reduce(into: Int64(0)) { total, file in
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
    }
}

extension UIImage {
    /// Uzun kenarı verilen değere indirir. Zaten küçükse dokunmaz.
    func downscaled(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }

        let scale = maxDimension / longest
        let target = CGSize(width: (size.width * scale).rounded(),
                            height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
