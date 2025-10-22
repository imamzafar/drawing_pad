import SwiftUI
import AppKit

struct ToolbarView: View {
    @EnvironmentObject private var viewModel: CanvasViewModel

    var body: some View {
        HStack(spacing: 10) {
            ToolbarButton(title: viewModel.toggleDrawButtonTitle, variant: .primary, isActive: viewModel.allowDrawing, action: viewModel.toggleDrawing)

            ToolbarButton(title: "Hand", variant: .secondary, isActive: viewModel.usingHandTool, action: viewModel.toggleHandTool)

            ToolbarButton(title: "Eraser", variant: .secondary, isActive: viewModel.erasing, action: viewModel.toggleEraser)

            ValueSlider(
                label: "Eraser Size",
                value: Binding(
                    get: { Double(viewModel.eraserSize) },
                    set: { viewModel.setEraserSize(CGFloat($0)) }
                ),
                range: 5...60
            )

            ValueSlider(
                label: "Pen Size",
                value: Binding(
                    get: { Double(viewModel.penSize) },
                    set: { viewModel.setPenSize(CGFloat($0)) }
                ),
                range: 1...20
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Ink")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.75))
                ColorPicker("", selection: Binding(
                    get: { Color(nsColor: viewModel.inkColor) },
                    set: { newValue in
                        if let cgColor = newValue.cgColor, let ns = NSColor(cgColor: cgColor) {
                            viewModel.setInkColor(ns)
                        }
                    }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 46, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Background")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.75))
                Picker("", selection: Binding(
                    get: { viewModel.selectedBackgroundPresetHex ?? ToolbarConstants.customPresetToken },
                    set: { newValue in
                        if newValue == ToolbarConstants.customPresetToken {
                            return
                        }
                        viewModel.setBackgroundPreset(hex: newValue)
                    }
                )) {
                    Text("Custom").tag(ToolbarConstants.customPresetToken)
                    ForEach(viewModel.backgroundPresets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)

                ColorPicker("", selection: Binding(
                    get: { Color(nsColor: viewModel.backgroundColor) },
                    set: { newValue in
                        if let cgColor = newValue.cgColor, let ns = NSColor(cgColor: cgColor) {
                            viewModel.setCustomBackgroundColor(ns)
                        }
                    }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 46, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Spacer()

            Text("Zoom")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.75))

            ToolbarButton(title: "+", variant: .ghost, isActive: false, action: viewModel.zoomIn)
                .frame(width: 36)

            ToolbarButton(title: "−", variant: .ghost, isActive: false, action: viewModel.zoomOut)
                .frame(width: 36)

            ToolbarButton(title: "Clear", variant: .secondary, isActive: false, action: viewModel.clearCanvas)

            ToolbarButton(title: "Save", variant: .primary, isActive: false, action: viewModel.exportDrawing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 12)
    }
}

private struct ValueSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.primary.opacity(0.75))
            Slider(value: $value, in: range, step: 1)
                .frame(width: 140)
        }
    }
}

private struct ToolbarButton: View {
    let title: String
    let variant: ToolbarButtonVariant
    let isActive: Bool
    let action: () -> Void

    init(title: String, variant: ToolbarButtonVariant, isActive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.variant = variant
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 0)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return Color(.white)
        case .secondary:
            return isActive ? Color(.white) : Color(nsColor: .labelColor)
        case .ghost:
            return Color(nsColor: .labelColor)
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary:
            return isActive ? Color(nsColor: NSColor.systemBlue.blended(withFraction: 0.1, of: .black) ?? .systemBlue) : Color(nsColor: .systemBlue)
        case .secondary:
            let base = Color(nsColor: .systemGray)
            return isActive ? base.opacity(0.9) : base.opacity(0.35)
        case .ghost:
            return Color(nsColor: .windowBackgroundColor).opacity(0.8)
        }
    }
}

private enum ToolbarButtonVariant {
    case primary
    case secondary
    case ghost
}

private enum ToolbarConstants {
    static let customPresetToken = "__custom__"
}
