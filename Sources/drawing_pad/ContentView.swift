import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: CanvasViewModel

    private let toolbarPadding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

    var body: some View {
        ZStack {
            DrawingCanvasContainer(viewModel: viewModel)
                .background(Color(nsColor: viewModel.backgroundColor))
                .ignoresSafeArea()

            VStack {
                HStack {
                    ToolbarView()
                        .environmentObject(viewModel)
                        .padding(toolbarPadding)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.windowBackgroundColor))
                                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                        )
                    Spacer()
                }
                Spacer()
            }
            .padding()

            VStack {
                Spacer()
                HStack {
                    HintView()
                        .environmentObject(viewModel)
                        .padding(.bottom, 12)
                        .padding(.leading, 20)
                    Spacer()
                }
            }
        }
    }
}
