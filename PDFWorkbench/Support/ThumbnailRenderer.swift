import PDFKit
import AppKit

/// Membuat dan menyimpan thumbnail halaman (dengan rotasi sudah diterapkan).
enum ThumbnailRenderer {
    /// Sisi terpanjang thumbnail dalam piksel (cukup untuk layar Retina).
    static let maxEdge: CGFloat = 160

    private static let cache = NSCache<NSString, NSImage>()

    static func thumbnail(for item: PageItem) -> NSImage? {
        let key = "\(item.id.uuidString)-\(item.rotation)" as NSString
        if let hit = cache.object(forKey: key) { return hit }

        let page = item.renderedPage()

        // ASUMSI YANG HARUS DIVERIFIKASI: bounds(for:) mengembalikan kotak halaman
        // tanpa rotasi, sehingga lebar/tinggi ditukar untuk rotasi 90/270.
        // Kalau thumbnail halaman yang diputar tampak gepeng atau berbingkai putih,
        // hapus penukaran ini.
        var size = page.bounds(for: .cropBox).size
        if page.rotation % 180 != 0 {
            size = CGSize(width: size.height, height: size.width)
        }
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = maxEdge / max(size.width, size.height)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let image = page.thumbnail(of: target, for: .cropBox)
        cache.setObject(image, forKey: key)
        return image
    }
}
