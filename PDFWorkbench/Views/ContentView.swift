import SwiftUI

struct ContentView: View {
    @State private var model = WorkbenchModel()
    @State private var isDropTargeted = false
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 340)
        } detail: {
            DetailView(model: model)
        }
        .navigationTitle("PDF Workbench")
        .navigationSubtitle(subtitle)
        .toolbar { toolbarContent }
        .frame(minWidth: 640, minHeight: 420)
        // Drop di mana saja pada jendela menambahkan file di akhir daftar.
        // Drop di antara baris sidebar menyisipkan di posisi itu (lihat SidebarView).
        .dropDestination(for: URL.self) { urls, _ in
            model.addFiles(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .focusedSceneValue(\.workbench, model)
        .onAppear { model.undoManager = undoManager }
        .onChange(of: undoManager) { _, newValue in model.undoManager = newValue }
        .alert(
            model.alert?.title ?? "",
            isPresented: Binding(
                get: { model.alert != nil },
                set: { if !$0 { model.alert = nil } }
            ),
            presenting: model.alert
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    private var subtitle: String {
        let count = model.pages.count
        return count == 0 ? "" : String(localized: "\(count) halaman")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                model.presentOpenPanel()
            } label: {
                Label("Tambah File", systemImage: "plus")
            }
            .help("Tambah file PDF atau gambar (⌘O)")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.rotateSelected(by: -90)
            } label: {
                Label("Putar ke Kiri", systemImage: "rotate.left")
            }
            .help("Putar halaman terpilih ke kiri (⌘L)")
            .disabled(model.selection.isEmpty)

            Button {
                model.rotateSelected(by: 90)
            } label: {
                Label("Putar ke Kanan", systemImage: "rotate.right")
            }
            .help("Putar halaman terpilih ke kanan (⌘R)")
            .disabled(model.selection.isEmpty)

            Button {
                model.deleteSelected()
            } label: {
                Label("Hapus Halaman", systemImage: "trash")
            }
            .help("Hapus halaman terpilih (⌫)")
            .disabled(model.selection.isEmpty)

            Button {
                model.presentExportPanel()
            } label: {
                Label("Ekspor", systemImage: "square.and.arrow.up")
            }
            .help("Ekspor sebagai PDF (⇧⌘E)")
            .disabled(model.pages.isEmpty)
        }
    }
}
