import SwiftUI
import PhotosUI

/// Gün editöründeki fotoğraf bölümü: eklenen kareler, çekme ve galeriden
/// seçme düğmeleri, tam ekran önizleme.
@MainActor
struct PhotoSection: View {

    let day: Int
    @ObservedObject var store: DiaryStore
    @ObservedObject var photos: PhotoStore
    var isEnabled: Bool = true

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsCamera = false
    @State private var preview: PhotoPreview?
    @State private var isImporting = false

    private var photoIDs: [String] {
        store.entry(for: day)?.photoIDs ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle

            if !photoIDs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoIDs, id: \.self) { id in
                            thumbnail(id: id)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if isEnabled {
                buttons
            }
        }
        .sheet(isPresented: $showsCamera) {
            CameraPicker { image in
                add(image: image)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $preview) { item in
            PhotoPreviewView(id: item.id, photos: photos) {
                remove(id: item.id)
                preview = nil
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            importPicked(items)
        }
    }

    // MARK: - Parçalar

    private var sectionTitle: some View {
        HStack(spacing: 8) {
            Text("Fotoğraflar")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Theme.inkFaint)

            if isImporting {
                ProgressView()
                    .controlSize(.mini)
            }

            Rectangle()
                .fill(Theme.paperEdge)
                .frame(height: 1)
        }
    }

    private func thumbnail(id: String) -> some View {
        Button {
            preview = PhotoPreview(id: id)
        } label: {
            ZStack {
                if let image = photos.thumbnail(id) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Dosya bulunamadıysa (ör. iCloud'dan henüz inmediyse)
                    // boş bir çerçeve göster, çökme.
                    Theme.paperShade
                    Image(systemName: "photo")
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .frame(width: 96, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                showsCamera = true
            } label: {
                actionLabel(symbol: "camera.fill", title: "Çek")
            }

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                actionLabel(symbol: "photo.on.rectangle", title: "Galeriden seç")
            }
        }
    }

    private func actionLabel(symbol: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(Theme.paper)
        )
        .overlay(
            Capsule().strokeBorder(Theme.paperEdge, lineWidth: 1)
        )
    }

    // MARK: - Eylemler

    private func add(image: UIImage) {
        guard let id = photos.save(image) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            store.addPhoto(id: id, for: day)
        }
        Haptics.success()
    }

    private func importPicked(_ items: [PhotosPickerItem]) {
        isImporting = true
        Task {
            var newIDs: [String] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let id = photos.save(data: data) {
                    newIDs.append(id)
                }
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                for id in newIDs {
                    store.addPhoto(id: id, for: day)
                }
            }
            pickerItems = []
            isImporting = false
            if !newIDs.isEmpty { Haptics.success() }
        }
    }

    private func remove(id: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            store.removePhoto(id: id, for: day)
        }
        photos.delete(id)
        Haptics.tap()
    }
}

struct PhotoPreview: Identifiable {
    let id: String
}

/// Fotoğrafa dokununca açılan tam ekran görünüm.
@MainActor
private struct PhotoPreviewView: View {
    let id: String
    @ObservedObject var photos: PhotoStore
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = photos.image(id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                Text("Fotoğraf bulunamadı")
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(11)
                            .background(Circle().fill(.black.opacity(0.45)))
                    }
                    .accessibilityLabel("Kapat")

                    Spacer()

                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(11)
                            .background(Circle().fill(.black.opacity(0.45)))
                    }
                    .accessibilityLabel("Fotoğrafı sil")
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                Spacer()
            }
        }
        .confirmationDialog("Bu fotoğraf silinsin mi?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Sil", role: .destructive) { onDelete() }
            Button("Vazgeç", role: .cancel) {}
        }
    }
}
