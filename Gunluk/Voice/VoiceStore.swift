import Foundation

/// Sesli günlük kayıtlarının dosya deposu.
///
/// `PhotoStore` ile aynı mantık: ses dosyaları JSON kaydının içine gömülmüyor,
/// Application Support altındaki ayrı bir klasörde duruyor; kayıtta yalnızca
/// kimlikleri geçiyor.
@MainActor
final class VoiceStore: ObservableObject {

    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: true))
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = base.appendingPathComponent("sesler", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory,
                                                 withIntermediateDirectories: true)
    }

    func url(for id: String) -> URL {
        directory.appendingPathComponent("\(id).m4a")
    }

    func exists(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    func delete(_ id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    /// Kayıtlarda artık geçmeyen ses dosyalarını siler.
    func removeOrphans(keeping usedIDs: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.pathExtension == "m4a" {
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
