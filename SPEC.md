# SPEC: PDF Workbench

Dokumen ini untuk pengembang atau tool AI yang melanjutkan proyek. Baca seluruhnya sebelum mengubah kode.

## 1. Tujuan

Aplikasi macOS native bergaya Preview, tetapi untuk **membuat** PDF: gabung PDF dan gambar,
atur halaman, putar, dan kompres. Syarat dari pemilik:

1. Gabung PDF lewat drag and drop.
2. Ringan.
3. Mendukung rotasi.
4. Kompresi berdasarkan persentase **kualitas** atau berdasarkan **target ukuran**.
5. Mengikuti Apple Human Interface Guidelines (HIG) untuk macOS.

## 2. Keputusan yang sudah final

- Swift + SwiftUI + PDFKit. Mac saja. macOS 14+ minimum.
- Tanpa dependensi pihak ketiga (tidak ada Ghostscript, qpdf, dsb.).
- Teks di PDF hasil kompresi **boleh hilang** (halaman dirasterisasi). Pengguna sudah menyetujui ini.
- "Persentase" berarti **kualitas**, bukan ukuran. Target ukuran adalah mode terpisah.
- Berbahasa Indonesia untuk UI. Semua string lewat `String(localized:)` atau `LocalizedStringKey`
  supaya bisa dipindah ke String Catalog.

## 3. Asumsi yang belum dikonfirmasi pemilik

Pemilik belum memilih antara aplikasi berbasis dokumen dan satu jendela kerja.
M1 mengasumsikan **satu jendela kerja** (daftar halaman di memori, hasil lewat "Ekspor").
Konsekuensi yang harus ditangani di M4: tidak ada peringatan saat menutup jendela yang
masih berisi pekerjaan belum diekspor.

Penempatan gambar di halaman: A4, margin 1 cm, diskalakan muat, di tengah. Ini keputusan
default; ubah di `ImagePageBuilder` kalau pemilik ingin perilaku lain.

## 4. Arsitektur M1

- `PageItem` adalah value type. `page` dan `source` tidak pernah dimutasi. Rotasi disimpan
  di `rotation` dan baru diterapkan pada **salinan** halaman lewat `renderedPage()`.
- Semua perubahan pengguna terhadap `pages`/`selection` lewat `WorkbenchModel.apply(...)`,
  yang menyimpan snapshot untuk undo. Jangan memutasi `pages` langsung dari tempat lain.
- `WorkbenchModel` sengaja **tidak** `@MainActor` (closure `UndoManager` bersifat `@Sendable`).
  Project memakai Swift 5 mode dengan strict concurrency minimal. Jangan menaikkannya tanpa
  merapikan isolasi aktor lebih dulu.
- File PDF dibaca penuh ke memori (`Data`) saat impor, supaya halaman tidak bergantung pada
  file di disk. Konsekuensi: PDF sangat besar memakan memori sebesar filenya.
- Hanya URL file lokal yang diterima. URL web ditolak (aplikasi tidak boleh mengunduh).
- Sandbox aktif dengan entitlement `files.user-selected.read-write` saja. Tidak ada akses jaringan.

## 5. Risiko dan hal yang harus diverifikasi di M1

Kode M1 belum pernah dikompilasi atau dijalankan. Verifikasi poin berikut secara manual
dan perbaiki bila salah:

1. **Reorder dan drop eksternal bersamaan.** `ForEach` memakai `.onMove` dan `.dropDestination`
   sekaligus. Pastikan menyeret thumbnail untuk mengurutkan tetap jalan, dan drop file dari
   Finder di antara baris menyisipkan di posisi yang benar. Kalau konflik, pisahkan lewat
   `.onDrop`/`DropDelegate`.
2. **Aspek thumbnail halaman yang diputar.** `ThumbnailRenderer` menganggap `bounds(for:)`
   tidak memperhitungkan rotasi dan menukar lebar/tinggi untuk 90/270 derajat. Uji dengan PDF
   lanskap dan PDF yang punya `/Rotate` bawaan. Kalau gambar gepeng atau berbingkai putih,
   hapus penukaran itu.
3. **Menu enable/disable.** `WorkbenchCommands` membaca properti `@Observable` dari
   `@FocusedValue`. Pastikan item "Putar" dan "Hapus" ikut aktif/nonaktif saat pilihan berubah.
   Kalau tidak ikut, ganti `FocusedValue` ke `FocusedValues` yang membawa closure atau
   state sederhana (`hasSelection: Bool`).
4. **Undo/redo.** Tiap operasi (tambah, hapus, pindah, putar) harus bisa di-undo dan di-redo,
   dan nama aksi muncul di menu Edit (mis. "Urungkan Putar ke Kanan").
5. **Gambar.** Uji JPG dengan metadata rotasi dari HP, PNG transparan, HEIC, dan foto besar
   (mis. 12 MP). Periksa orientasi, margin, dan ukuran file hasil ekspor.
6. **PDF bermasalah.** PDF berkata sandi harus muncul di alert dengan pesan jelas, tidak
   memblokir file lain dalam satu drop, dan tidak membuat aplikasi crash.
7. **Thumbnail di main thread.** Thumbnail dibuat sinkron di main actor per baris yang tampil.
   Uji PDF 200+ halaman. Kalau scroll tersendat, pindahkan ke antrean latar dengan
   `CGPDFDocument` terpisah (jangan membagi objek PDFKit antar thread).
8. **Ekspor menimpa file sumber.** Memilih nama file yang sama dengan salah satu sumber harus
   tetap aman (data sumber sudah di memori). Verifikasi.

## 6. Milestone berikutnya

### M2: kompresi mode kualitas

UI: sheet ekspor dengan pilihan "Tanpa kompresi" / "Kualitas" / "Ukuran target" (M3).
Mode kualitas memakai slider 1 sampai 100 persen. Tidak menampilkan perkiraan ukuran sebelum
proses berjalan; ukuran asli dan ukuran hasil ditampilkan setelah selesai.

Pipeline (halaman per halaman, di dalam `autoreleasepool`):

1. Tulis dokumen gabungan ke `Data`, buat `CGPDFDocument` baru dari data itu di worker
   (jangan membagi objek PDFKit antar thread).
2. Render tiap halaman ke `CGImage` pada DPI tertentu dengan latar putih
   (`CGContext.drawPDFPage` atau `PDFPage.draw(with:to:)`, hormati rotasi dan `cropBox`).
3. Encode JPEG dengan `CGImageDestination`, kualitas tertentu.
4. Buat `CGImage` dari data JPEG itu lewat `CGImage(jpegDataProviderSource:...)` supaya
   Quartz menyematkan aliran JPEG apa adanya, tidak meng-encode ulang.
5. Gambar ke `CGContext` PDF dengan ukuran halaman asli (dalam poin), bukan ukuran piksel.

Titik awal pemetaan kualitas ke parameter (tuning secara empiris, jangan dianggap final):

| Kualitas | DPI | JPEG quality |
|---|---|---|
| 100 | 300 | 0.90 |
| 75 | 200 | 0.75 |
| 50 | 150 | 0.60 |
| 25 | 110 | 0.45 |
| 1 | 72 | 0.30 |

Pengaman wajib:

- Jika hasil **lebih besar** dari ukuran dokumen gabungan tanpa kompresi, jangan pakai hasilnya;
  beri tahu pengguna dan ekspor tanpa kompresi.
- Sebelum menjalankan, tampilkan peringatan bahwa teks tidak lagi bisa dipilih atau dicari.
- Jangan pernah menimpa file asli. Hasil kompresi selalu file baru lewat panel simpan.
- Progress per halaman, tombol Batal yang benar-benar menghentikan kerja (`Task` yang dibatalkan,
  periksa `Task.isCancelled` tiap halaman), dan tidak memblokir UI.

### M3: kompresi mode ukuran target

Pencarian biner atas parameter kualitas (maksimal sekitar 8 iterasi), tiap iterasi merender
ulang. Toleransi: hasil antara 90 dan 100 persen dari target. Catatan:

- Ukuran tidak akan persis sama dengan target.
- Ada batas bawah (kualitas 1 pada DPI minimum). Kalau target di bawah batas itu, hentikan
  dan beri tahu pengguna ukuran terkecil yang bisa dicapai. Jangan menyerahkan hasil
  yang tidak sesuai tanpa penjelasan.
- Input target dalam KB atau MB. Opsi "persen dari ukuran asli" boleh ditambahkan sebagai
  jalan pintas, bukan sebagai arti "persentase" di mode kualitas.
- Progress menampilkan iterasi dan tetap bisa dibatalkan.

### M4: polesan

- Drop file ke ikon Dock dan "Buka Dengan" dari Finder (`CFBundleDocumentTypes` untuk PDF dan gambar).
- Peringatan saat menutup jendela yang berisi halaman belum diekspor.
- Prompt kata sandi untuk PDF terkunci.
- Pindahkan string ke String Catalog.
- Audit aksesibilitas (VoiceOver, navigasi keyboard penuh, kontras), uji mode gelap dan terang.
- Ikon aplikasi.

## 7. Checklist HIG (berlaku di semua milestone)

Halaman prinsip desain Apple tidak bisa dibaca otomatis saat spesifikasi ini ditulis
(butuh JavaScript). Checklist ini berasal dari pengetahuan umum tentang HIG dan harus
dicocokkan dengan halaman aslinya oleh pemilik:
https://developer.apple.com/design/human-interface-guidelines/design-principles

- Komponen standar: `NavigationSplitView`, toolbar, `List`, panel sebagai sheet, `Settings`
  untuk preferensi (⌘,). Tidak ada chrome buatan sendiri.
- Setiap aksi ada di menu bar dengan shortcut standar. Toolbar tidak boleh jadi satu-satunya jalan.
- Item toolbar dan menu yang tidak berlaku dinonaktifkan, bukan disembunyikan.
- Drag and drop memberi umpan balik visual (sorotan jendela, indikator posisi sisip).
- Undo/redo untuk semua operasi yang mengubah dokumen kerja.
- Aksi destruktif diberi tahu dan dapat dibatalkan. Kompresi tidak pernah menimpa file asli.
- Pesan error spesifik dan bisa ditindaklanjuti, bukan "Gagal".
- Warna semantik, font sistem, SF Symbols. Mode gelap otomatis. Jangan hardcode warna.
- Seluruh fitur dapat dipakai dengan keyboard dan VoiceOver. Setiap kontrol punya label.
- Operasi panjang punya progress dan tombol Batal.

## 8. Aturan untuk pengembang atau tool AI

- Jangan menambah dependensi pihak ketiga tanpa persetujuan pemilik.
- Jangan mengubah keputusan di bagian 2 tanpa persetujuan pemilik.
- Jangan memutasi `PageItem.page` atau dokumen sumbernya.
- Jangan menyatakan fitur "sudah jalan" sebelum diuji manual dengan daftar di bagian 5.
- Jika sebuah API PDFKit/AppKit tidak berperilaku seperti dugaan di spesifikasi ini,
  perbaiki kode dan catat koreksinya di bagian 5, jangan menyembunyikannya.
- Ketika menimbang pembuatan fitur redaksi atau edit teks PDF: **jangan**. Di luar cakupan
  (redaksi yang salah membocorkan data, dan dokumen pemilik sering bersifat sensitif).
