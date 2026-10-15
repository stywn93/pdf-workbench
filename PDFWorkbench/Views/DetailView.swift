import SwiftUI
import PDFKit

struct DetailView: View {
    let model: WorkbenchModel

    var body: some View {
        if model.pages.isEmpty {
            ContentUnavailableView {
                Label("Belum ada halaman", systemImage: "doc.on.doc")
            } description: {
                Text("Seret file PDF atau gambar ke jendela ini, atau pilih Tambah File.")
            } actions: {
                Button("Tambah File…") { model.presentOpenPanel() }
            }
        } else {
            PagePreview(item: previewItem)
        }
    }

    /// Halaman terpilih pertama (menurut urutan daftar), atau halaman pertama.
    private var previewItem: PageItem? {
        model.pages.first { model.selection.contains($0.id) } ?? model.pages.first
    }
}

/// Pratinjau satu halaman memakai PDFView bawaan.
struct PagePreview: NSViewRepresentable {
    let item: PageItem?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePage
        view.autoScales = true
        view.displaysPageBreaks = false
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        guard let item else {
            view.document = nil
            context.coordinator.key = ""
            return
        }
        let key = "\(item.id)-\(item.rotation)"
        guard context.coordinator.key != key else { return }
        context.coordinator.key = key

        let document = PDFDocument()
        document.insert(item.renderedPage(), at: 0)
        view.document = document
        view.autoScales = true
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var key = ""
    }
}
