import SwiftUI

@main
struct WindockApp: App {
    // Inject the ViewModel at the root level
    @State private var viewModel = DockViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .background(Color.clear)
        }
        .windowStyle(.hiddenTitleBar) // Hides standard macOS window chrome
        .windowResizability(.contentSize)
        // In a real app, you would use NSPanel to make it float above everything
    }
}
