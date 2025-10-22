import SwiftUI

struct HintView: View {
    @EnvironmentObject private var viewModel: CanvasViewModel

    var body: some View {
        Text("Hold Space to pan · Toggle draw: D")
            .font(.system(size: 12, weight: .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
            )
            .foregroundColor(.primary)
    }
}
