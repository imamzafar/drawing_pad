import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

struct LineSegment: Codable, Identifiable {
    let id: UUID
    var start: CGPoint
    var end: CGPoint
    var color: CodableColor
    var width: CGFloat

    init(start: CGPoint, end: CGPoint, color: NSColor, width: CGFloat) {
        self.id = UUID()
        self.start = start
        self.end = end
        self.color = CodableColor(color: color)
        self.width = width
    }

    func drawingColor() -> NSColor {
        color.nsColor
    }
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(color: NSColor) {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        self.red = Double(srgb.redComponent)
        self.green = Double(srgb.greenComponent)
        self.blue = Double(srgb.blueComponent)
        self.alpha = Double(srgb.alphaComponent)
    }

    var nsColor: NSColor {
        NSColor(calibratedRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    var hexString: String {
        let r = Int(red * 255.0)
        let g = Int(green * 255.0)
        let b = Int(blue * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct BackgroundPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let color: NSColor

    init(hex: String, name: String) {
        self.id = hex
        self.name = name
        self.color = NSColor(hexString: hex) ?? .white
    }
}

struct DrawingArchive: Codable {
    var segments: [LineSegment]
    var background: CodableColor
    var ink: CodableColor
    var penSize: Double
    var eraserSize: Double
}

@MainActor
final class CanvasViewModel: ObservableObject {
    @Published var allowDrawing = false
    @Published var erasing = false
    @Published var usingHandTool = false
    @Published var penSize: CGFloat = 2
    @Published var eraserSize: CGFloat = 20
    @Published var inkColor: NSColor = .black
    @Published var backgroundColor: NSColor = .white
    @Published var scale: CGFloat = 1
    @Published var offset: CGSize = .zero
    @Published var spacePanActive = false
    @Published var isPanning = false
    @Published var mouseLocation: CGPoint?
    @Published var segments: [LineSegment] = []
    @Published var canvasSize: CGSize = CGSize(width: 1280, height: 800)
    @Published var selectedBackgroundPresetHex: String? = "#ffffff"

    let backgroundPresets: [BackgroundPreset] = [
        BackgroundPreset(hex: "#ffffff", name: "White"),
        BackgroundPreset(hex: "#f5f5f0", name: "Cream"),
        BackgroundPreset(hex: "#f1f3f5", name: "Light Gray"),
        BackgroundPreset(hex: "#e7f5ff", name: "Sky Blue"),
        BackgroundPreset(hex: "#000000", name: "Black")
    ]

    private let persistence = CanvasPersistence()
    private var isRestoringState = false

    var lastWorldPoint: CGPoint?

    init() {
        restoreState()
    }

    var toggleDrawButtonTitle: String {
        allowDrawing ? "Stop Drawing (D)" : "Start Drawing (D)"
    }

    var cursorStyle: CanvasCursorStyle {
        if erasing {
            return .eraser
        }
        if usingHandTool || spacePanActive || isPanning {
            return .hand
        }
        if allowDrawing {
            return .draw
        }
        return .arrow
    }

    var activeStrokeColor: NSColor {
        erasing ? backgroundColor : inkColor
    }

    var activeStrokeWidth: CGFloat {
        erasing ? eraserSize : penSize
    }

    func toggleDrawing() {
        allowDrawing.toggle()
        if allowDrawing {
            erasing = false
            usingHandTool = false
        } else {
            resetLastPoint()
        }
        notifyCursorChange()
    }

    func toggleHandTool() {
        usingHandTool.toggle()
        if usingHandTool {
            allowDrawing = false
            erasing = false
        }
        resetLastPoint()
        notifyCursorChange()
    }

    func toggleEraser() {
        erasing.toggle()
        if erasing {
            allowDrawing = true
            usingHandTool = false
        } else {
            allowDrawing = false
        }
        resetLastPoint()
        notifyCursorChange()
    }

    func setPenSize(_ value: CGFloat) {
        penSize = value
        saveState()
    }

    func setEraserSize(_ value: CGFloat) {
        eraserSize = value
        saveState()
    }

    func setInkColor(_ color: NSColor) {
        inkColor = color
        saveState()
    }

    func setBackgroundPreset(hex: String) {
        if let preset = backgroundPresets.first(where: { $0.id == hex }) {
            selectedBackgroundPresetHex = preset.id
            setBackgroundColor(preset.color, shouldPersistPreset: false)
        }
    }

    func setBackgroundColor(_ color: NSColor, shouldPersistPreset: Bool = true) {
        backgroundColor = color
        if shouldPersistPreset {
            if let preset = backgroundPresets.first(where: { $0.color.matches(color) }) {
                selectedBackgroundPresetHex = preset.id
            } else {
                selectedBackgroundPresetHex = nil
            }
        }
        saveState()
    }

    func setCustomBackgroundColor(_ color: NSColor) {
        selectedBackgroundPresetHex = nil
        setBackgroundColor(color, shouldPersistPreset: false)
    }

    func zoomIn() {
        scale = min(scale * 1.2, 8)
    }

    func zoomOut() {
        scale = max(scale / 1.2, 0.1)
    }

    func clearCanvas() {
        segments.removeAll()
        saveState()
    }

    func addSegment(from start: CGPoint, to end: CGPoint) {
        let width = max(activeStrokeWidth / max(scale, 0.0001), 0.5)
        let segment = LineSegment(start: start, end: end, color: activeStrokeColor, width: width)
        segments.append(segment)
        saveState()
    }

    func resetLastPoint() {
        lastWorldPoint = nil
    }

    func beginPanning() {
        isPanning = true
        resetLastPoint()
        notifyCursorChange()
    }

    func endPanning() {
        isPanning = false
        notifyCursorChange()
    }

    func setSpacePanActive(_ active: Bool) {
        spacePanActive = active
        if active {
            beginPanning()
        } else {
            endPanning()
        }
    }

    func pan(by delta: CGSize) {
        let divisor = max(scale, 0.0001)
        offset.width -= delta.width / divisor
        offset.height -= delta.height / divisor
    }

    func worldPoint(from viewPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (viewPoint.x / max(scale, 0.0001)) + offset.width,
            y: (viewPoint.y / max(scale, 0.0001)) + offset.height
        )
    }

    func updateCanvasSize(_ newSize: CGSize) {
        canvasSize = newSize
    }

    func exportDrawing() {
        guard let image = renderImage() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "drawing.png"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.write(image: image, to: url)
        }
    }

    private func write(image: NSImage, to url: URL) {
        guard let data = image.pngData else { return }
        do {
            try data.write(to: url)
        } catch {
            print("Failed to save image:", error)
        }
    }

    private func renderImage() -> NSImage? {
        if segments.isEmpty {
            let size = canvasSize == .zero ? CGSize(width: 1200, height: 800) : canvasSize
            let image = NSImage(size: size)
            image.lockFocus()
            backgroundColor.setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            image.unlockFocus()
            return image
        }

        let padding: CGFloat = 20
        guard let bounds = drawingBounds()?.insetBy(dx: -padding, dy: -padding) else {
            return nil
        }

        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)

        guard let ctx = CGContext(
            data: nil,
            width: Int(ceil(width)),
            height: Int(ceil(height)),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(CGRect(origin: .zero, size: CGSize(width: width, height: height)))

        ctx.saveGState()
        ctx.translateBy(x: -bounds.minX, y: -bounds.minY)
        for segment in segments {
            ctx.setStrokeColor(segment.drawingColor().cgColor)
            ctx.setLineWidth(segment.width)
            ctx.setLineCap(.round)
            ctx.beginPath()
            ctx.move(to: segment.start)
            ctx.addLine(to: segment.end)
            ctx.strokePath()
        }
        ctx.restoreGState()

        guard let cgImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: CGSize(width: width, height: height))
    }

    private func drawingBounds() -> CGRect? {
        guard !segments.isEmpty else { return nil }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for segment in segments {
            minX = min(minX, segment.start.x, segment.end.x)
            minY = min(minY, segment.start.y, segment.end.y)
            maxX = max(maxX, segment.start.x, segment.end.x)
            maxY = max(maxY, segment.start.y, segment.end.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func notifyCursorChange() {
        NotificationCenter.default.post(name: CanvasViewModel.cursorDidChangeNotification, object: self)
    }

    private func saveState() {
        guard !isRestoringState else { return }
        let archive = DrawingArchive(
            segments: segments,
            background: CodableColor(color: backgroundColor),
            ink: CodableColor(color: inkColor),
            penSize: Double(penSize),
            eraserSize: Double(eraserSize)
        )
        persistence.save(archive: archive)
    }

    private func restoreState() {
        guard let archive = persistence.restore() else { return }
        isRestoringState = true
        segments = archive.segments
        backgroundColor = archive.background.nsColor
        inkColor = archive.ink.nsColor
        penSize = CGFloat(archive.penSize)
        eraserSize = CGFloat(archive.eraserSize)
        if let preset = backgroundPresets.first(where: { $0.color.matches(backgroundColor) }) {
            selectedBackgroundPresetHex = preset.id
        } else {
            selectedBackgroundPresetHex = nil
        }
        isRestoringState = false
    }
}

extension CanvasViewModel {
    static let cursorDidChangeNotification = Notification.Name("CanvasViewModelCursorDidChange")
}

enum CanvasCursorStyle {
    case arrow
    case draw
    case eraser
    case hand
}

extension NSColor {
    convenience init?(hexString: String) {
        var sanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }
        guard sanitized.count == 6, let value = Int(sanitized, radix: 16) else {
            return nil
        }
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        self.init(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
    }

    func matches(_ other: NSColor) -> Bool {
        let left = (usingColorSpace(.sRGB) ?? self)
        let right = (other.usingColorSpace(.sRGB) ?? other)
        let epsilon: CGFloat = 0.001
        return abs(left.redComponent - right.redComponent) < epsilon &&
            abs(left.greenComponent - right.greenComponent) < epsilon &&
            abs(left.blueComponent - right.blueComponent) < epsilon
    }

    var cgColorOrFallback: CGColor {
        if let converted = usingColorSpace(.sRGB) {
            return converted.cgColor
        }
        return cgColor
    }

    var hexString: String {
        let srgb = usingColorSpace(.sRGB) ?? self
        let r = Int(round(srgb.redComponent * 255))
        let g = Int(round(srgb.greenComponent * 255))
        let b = Int(round(srgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

private final class CanvasPersistence {
    private let defaults = UserDefaults.standard
    private let key = "infiniteCanvasState"

    func save(archive: DrawingArchive) {
        guard let data = try? JSONEncoder().encode(archive) else { return }
        defaults.set(data, forKey: key)
    }

    func restore() -> DrawingArchive? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DrawingArchive.self, from: data)
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
