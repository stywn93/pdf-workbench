import SwiftUI

struct SidebarView: View {
    @Bindable var model: WorkbenchModel

    var body: some View {
        List(selection: $model.selection) {
            ForEach(Array(model.pages.enumerated()), id: \.element.id) { index, item in
                PageRow(item: item, number: index + 1)
            }
            // Urutkan ulang dengan menyeret baris.
            .onMove { source, destination in
                model.move(from: source, to: destination)
            }
            // File dari Finder disisipkan tepat di posisi drop.
            .dropDestination(for: URL.self) { urls, index in
                model.addFiles(urls, at: index)
            }
        }
        .onDeleteCommand { model.deleteSelected() }
    }
}

struct PageRow: View {
    let item: PageItem
    let number: Int

    var body: some View {
        HStack(spacing: 10) {
            PageThumbnail(item: item)

            VStack(alignment: .leading, spacing: 2) {
                Text("Halaman \(number)")
                Text(item.sourceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct PageThumbnail: View {
    let item: PageItem
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: 64, height: 84)
        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 0.5)
        .accessibilityHidden(true)
        // Dijalankan ulang saat rotasi berubah. Hasilnya di-cache.
        // @MainActor eksplisit: PDFKit tidak dijamin aman dipakai dari thread lain.
        .task(id: "\(item.id)-\(item.rotation)") { @MainActor in
            image = ThumbnailRenderer.thumbnail(for: item)
        }
    }
}
