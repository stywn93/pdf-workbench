import PDFKit
import ImageIO
import CoreGraphics

/// Membuat halaman PDF A4 dari sebuah gambar.
///
/// Aturan: orientasi halaman mengikuti gambar (potret/lanskap), gambar
/// diskalakan agar muat dengan margin 1 cm dan diletakkan di tengah.
/// Orientasi EXIF diterapkan lewat ImageIO. Resolusi dibatasi agar PDF
/// tidak membengkak.
enum ImagePageBuilder {
    static let a4Portrait = CGSize(width: 595.28, height: 841.89)
    static let margin: CGFloat = 28.35          // 1 cm
    static let maxPixelSize = 2600              // sisi terpanjang, dalam piksel

    static func makeDocument(from url: URL) -> PDFDocument? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let longEdge = max(width, height)
        guard longEdge > 0 else { return nil }

        // Jangan diperbesar: batas = min(sisi asli, maxPixelSize).
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // terapkan orientasi EXIF
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(longEdge, maxPixelSize)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let isLandscape = image.width > image.height
        let pageSize = isLandscape
            ? CGSize(width: a4Portrait.height, height: a4Portrait.width)
            : a4Portrait
        var mediaBox = CGRect(origin: .zero, size: pageSize)

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return nil
        }

        let available = mediaBox.insetBy(dx: margin, dy: margin)
        let scale = min(available.width / CGFloat(image.width),
                        available.height / CGFloat(image.height))
        let drawSize = CGSize(width: CGFloat(image.width) * scale,
                              height: CGFloat(image.height) * scale)
        let drawRect = CGRect(x: available.midX - drawSize.width / 2,
                              y: available.midY - drawSize.height / 2,
                              width: drawSize.width,
                              height: drawSize.height)

        context.beginPDFPage(nil)
        context.interpolationQuality = .high
        context.draw(image, in: drawRect)
        context.endPDFPage()
        context.closePDF()

        return PDFDocument(data: data as Data)
    }
}
