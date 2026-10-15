import SwiftUI

@main
struct PDFWorkbenchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            WorkbenchCommands()
        }
    }
}
