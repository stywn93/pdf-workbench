# PDF Workbench

Aplikasi macOS native (Swift, SwiftUI, PDFKit) untuk menggabungkan PDF dan gambar,
memutar halaman, dan (milestone berikutnya) mengompres. Offline, tanpa dependensi pihak ketiga.

Status: **M1 scaffold**. Kode ini ditulis tanpa dikompilasi. Perkirakan beberapa putaran
perbaikan error build sebelum jalan. Baca `SPEC.md` untuk keputusan, batasan, dan milestone.

## Menjalankan

Prasyarat: macOS 14+, Xcode 15.4+ (disarankan Xcode terbaru).

```bash
brew install xcodegen
cd PDFWorkbench
xcodegen generate
open PDFWorkbench.xcodeproj
```

Lalu di Xcode: pilih target **PDFWorkbench**, tab *Signing & Capabilities*, pilih Team Anda,
dan ganti `com.example` di `project.yml` dengan bundle ID Anda (lalu jalankan `xcodegen generate` lagi).
Tekan ⌘R.

Tanpa XcodeGen: buat proyek App macOS baru (SwiftUI), hapus file bawaan, tambahkan seluruh
folder `PDFWorkbench/`, aktifkan App Sandbox dengan *User Selected File: Read/Write*,
set deployment target ke macOS 14.0, Swift Language Version ke 5, dan
*Strict Concurrency Checking* ke Minimal.

## Struktur

```
PDFWorkbench/
  PDFWorkbenchApp.swift          entry point, daftar menu
  Model/
    PageItem.swift               satu halaman + rotasi (value type)
    WorkbenchModel.swift         daftar halaman, pilihan, operasi + undo/redo
    WorkbenchModel+Dialogs.swift panel buka/simpan (sheet)
  Import/
    PageImporter.swift           PDF/gambar -> [PageItem], penanganan error
    ImagePageBuilder.swift       gambar -> halaman A4
  Views/
    ContentView.swift            jendela, toolbar, drop target, alert
    SidebarView.swift            daftar thumbnail, reorder, drop di antara baris
    DetailView.swift             pratinjau halaman, tampilan kosong
  Support/
    ThumbnailRenderer.swift      thumbnail + cache
    WorkbenchCommands.swift      menu bar
```

## Fitur M1

- Seret PDF/gambar ke jendela (di akhir daftar) atau ke antara baris sidebar (disisipkan di posisi itu)
- Tambah File… (⌘O)
- Urutkan ulang dengan menyeret thumbnail
- Putar kiri (⌘L) / kanan (⌘R), hapus halaman (⌫), multi-pilih
- Undo/redo (⌘Z / ⇧⌘Z) untuk semua operasi halaman
- Ekspor sebagai PDF (⇧⌘E)
- Gambar masuk sebagai halaman A4 (orientasi mengikuti gambar, margin 1 cm, orientasi EXIF diterapkan)
