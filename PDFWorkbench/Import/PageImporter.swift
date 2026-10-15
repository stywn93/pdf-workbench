import PDFKit
import UniformTypeIdentifiers

/// Mengubah satu file (PDF atau gambar) menjadi daftar `PageItem`.
enum PageImporter {
    enum ImportError: LocalizedError {
        case notAFile
        case unsupported
        case unreadable
        case locked
        case empty

        var errorDescription: String? {
            switch self {
            case .notAFile:
                return String(localized: "Bukan file di komputer ini.")
            case .unsupported:
                return String(localized: "Format tidak didukung. Gunakan PDF atau gambar (JPG, PNG, HEIC, TIFF).")
            case .unreadable:
                return String(localized: "File tidak bisa dibuka atau rusak.")
            case .locked:
                return String(localized: "PDF ini terkunci dengan kata sandi.")
            case .empty:
                return String(localized: "PDF ini tidak memiliki halaman.")
            }
        }
    }

    static func items(from url: URL) -> Result<[PageItem], ImportError> {
        // Hanya file lokal. URL web (misalnya gambar yang diseret dari browser)
        // ditolak supaya aplikasi tidak pernah mengunduh apa pun.
        guard url.isFileURL else { return .failure(.notAFile) }

        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else {
            return .failure(.unsupported)
        }
        if type.conforms(to: .pdf) { return pdfItems(from: url) }
        if type.conforms(to: .image) { return imageItems(from: url) }
        return .failure(.unsupported)
    }

    // MARK: - PDF

    private static func pdfItems(from url: URL) -> Result<[PageItem], ImportError> {
        // Dibaca penuh ke memori (bukan lazy dari disk) supaya halaman tetap valid
        // walau file di disk berubah atau dipakai sebagai tujuan ekspor.
        guard let data = try? Data(contentsOf: url),
              let document = PDFDocument(data: data) else {
            return .failure(.unreadable)
        }
        if document.isLocked && !document.unlock(withPassword: "") {
            return .failure(.locked)
        }
        guard document.pageCount > 0 else { return .failure(.empty) }

        let name = url.lastPathComponent
        let items = (0..<document.pageCount).compactMap { index -> PageItem? in
            guard let page = document.page(at: index) else { return nil }
            return PageItem(source: document, page: page,
                            sourceName: name, sourcePageNumber: index + 1)
        }
        return items.isEmpty ? .failure(.unreadable) : .success(items)
    }

    // MARK: - Gambar

    private static func imageItems(from url: URL) -> Result<[PageItem], ImportError> {
        guard let document = ImagePageBuilder.makeDocument(from: url),
              let page = document.page(at: 0) else {
            return .failure(.unreadable)
        }
        return .success([
            PageItem(source: document, page: page,
                     sourceName: url.lastPathComponent, sourcePageNumber: 1)
        ])
    }
}
