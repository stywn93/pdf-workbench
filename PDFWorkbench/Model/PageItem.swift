import PDFKit

/// Satu halaman di daftar kerja.
///
/// `page` adalah halaman asli dari `source` dan TIDAK PERNAH diubah.
/// Rotasi tambahan disimpan di `rotation` (nilai biasa), sehingga undo/redo
/// cukup menyimpan salinan array `[PageItem]`.
struct PageItem: Identifiable {
    let id = UUID()
    /// Dokumen sumber, disimpan kuat-kuat supaya `page` tetap valid.
    let source: PDFDocument
    let page: PDFPage
    let sourceName: String
    /// Nomor halaman di dokumen sumber (mulai dari 1).
    let sourcePageNumber: Int
    /// Rotasi tambahan dari pengguna: 0, 90, 180, atau 270.
    var rotation: Int = 0

    /// Rotasi akhir yang dipakai saat render dan ekspor.
    var effectiveRotation: Int {
        (((page.rotation + rotation) % 360) + 360) % 360
    }

    /// Teks keterangan sumber untuk baris sidebar.
    var sourceDescription: String {
        source.pageCount > 1 ? "\(sourceName) · hlm. \(sourcePageNumber)" : sourceName
    }

    /// Salinan halaman dengan rotasi akhir diterapkan.
    /// Salinan dipakai karena memasukkan halaman milik dokumen lain ke dokumen
    /// baru bisa memengaruhi dokumen sumbernya.
    func renderedPage() -> PDFPage {
        if let copy = page.copy() as? PDFPage {
            copy.rotation = effectiveRotation
            return copy
        }
        return page
    }
}
