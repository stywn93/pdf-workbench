import SwiftUI

// Model jendela yang sedang aktif, dibagikan ke menu bar.
private struct WorkbenchFocusKey: FocusedValueKey {
    typealias Value = WorkbenchModel
}

extension FocusedValues {
    var workbench: WorkbenchModel? {
        get { self[WorkbenchFocusKey.self] }
        set { self[WorkbenchFocusKey.self] = newValue }
    }
}

/// Menu bar. Undo/Redo di menu Edit disediakan otomatis oleh SwiftUI dan
/// terhubung ke UndoManager jendela yang sama dengan yang dipakai model.
struct WorkbenchCommands: Commands {
    @FocusedValue(\.workbench) private var model: WorkbenchModel?

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Tambah File…") { model?.presentOpenPanel() }
                .keyboardShortcut("o")
                .disabled(model == nil)

            Button("Ekspor sebagai PDF…") { model?.presentExportPanel() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model?.pages.isEmpty ?? true)
        }

        CommandMenu("Halaman") {
            Button("Putar ke Kiri") { model?.rotateSelected(by: -90) }
                .keyboardShortcut("l")
                .disabled(!hasSelection)

            Button("Putar ke Kanan") { model?.rotateSelected(by: 90) }
                .keyboardShortcut("r")
                .disabled(!hasSelection)

            Divider()

            Button("Hapus Halaman") { model?.deleteSelected() }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(!hasSelection)
        }
    }

    private var hasSelection: Bool {
        !(model?.selection.isEmpty ?? true)
    }
}
