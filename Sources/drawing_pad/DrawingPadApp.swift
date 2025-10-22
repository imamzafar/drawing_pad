import SwiftUI

@main
struct DrawingPadApp: App {
    @StateObject private var viewModel = CanvasViewModel()

    var body: some Scene {
        WindowGroup("Drawing Pad") {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowResizability(.contentSize)
    }
}
