import SwiftUI
import PDFKit
import Observation

struct UserAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// State satu jendela: daftar halaman, pilihan, dan operasi dengan undo/redo.
///
/// Sengaja TIDAK diberi @MainActor supaya closure undo (yang @Sendable)
/// bisa memanggil method di sini tanpa error isolasi. Semua pemanggilan
/// datang dari main thread (SwiftUI dan AppKit).
@Observable
final class WorkbenchModel {
    var pages: [PageItem] = []
    var selection: Set<PageItem.ID> = []
    var alert: UserAlert?

    @ObservationIgnored var undoManager: UndoManager?

    // MARK: - Impor

    /// Menambahkan file PDF atau gambar. `index` = posisi sisip (nil = di akhir).
    func addFiles(_ urls: [URL], at index: Int? = nil) {
        var newItems: [PageItem] = []
        var failures: [String] = []

        for url in urls {
            switch PageImporter.items(from: url) {
            case .success(let items):
                newItems.append(contentsOf: items)
            case .failure(let error):
                failures.append("• \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if !newItems.isEmpty {
            var updated = pages
            let position = min(max(index ?? updated.count, 0), updated.count)
            updated.insert(contentsOf: newItems, at: position)
            apply(updated,
                  selecting: Set(newItems.map(\.id)),
                  actionName: String(localized: "Tambah Halaman"))
        }

        if !failures.isEmpty {
            alert = UserAlert(
                title: String(localized: "Sebagian file tidak bisa ditambahkan"),
                message: failures.joined(separator: "\n")
            )
        }
    }

    // MARK: - Operasi halaman (semua lewat apply, jadi otomatis bisa di-undo)

    func deleteSelected() {
        guard !selection.isEmpty else { return }
        apply(pages.filter { !selection.contains($0.id) },
              selecting: [],
              actionName: String(localized: "Hapus Halaman"))
    }

    func move(from source: IndexSet, to destination: Int) {
        var updated = pages
        updated.move(fromOffsets: source, toOffset: destination)
        apply(updated,
              selecting: selection,
              actionName: String(localized: "Pindahkan Halaman"))
    }

    /// `degrees`: 90 = ke kanan (searah jarum jam), -90 = ke kiri.
    func rotateSelected(by degrees: Int) {
        guard !selection.isEmpty else { return }
        var updated = pages
        for index in updated.indices where selection.contains(updated[index].id) {
            updated[index].rotation = (((updated[index].rotation + degrees) % 360) + 360) % 360
        }
        let name = degrees > 0
            ? String(localized: "Putar ke Kanan")
            : String(localized: "Putar ke Kiri")
        apply(updated, selecting: selection, actionName: name)
    }

    // MARK: - Ekspor

    func export(to url: URL) {
        let document = PDFDocument()
        for (index, item) in pages.enumerated() {
            document.insert(item.renderedPage(), at: index)
        }
        if !document.write(to: url) {
            alert = UserAlert(
                title: String(localized: "Ekspor gagal"),
                message: String(localized: "File tidak bisa ditulis ke \(url.lastPathComponent). Periksa izin folder dan ruang penyimpanan, lalu coba lagi.")
            )
        }
    }

    // MARK: - Undo

    /// Satu-satunya tempat `pages` dan `selection` diubah oleh pengguna.
    /// Menyimpan kondisi lama untuk undo; saat undo berjalan, pemanggilan
    /// rekursif ini otomatis mendaftarkan redo.
    private func apply(_ newPages: [PageItem],
                       selecting newSelection: Set<PageItem.ID>,
                       actionName: String) {
        let oldPages = pages
        let oldSelection = selection
        pages = newPages
        selection = newSelection
        undoManager?.registerUndo(withTarget: self) { target in
            target.apply(oldPages, selecting: oldSelection, actionName: actionName)
        }
        undoManager?.setActionName(actionName)
    }
}
