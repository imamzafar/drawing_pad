import SwiftUI
import AppKit
import Combine

struct DrawingCanvasContainer: NSViewRepresentable {
    @ObservedObject var viewModel: CanvasViewModel

    func makeNSView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView(viewModel: viewModel)
        view.setCoordinator(context.coordinator)
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: DrawingCanvasView, context: Context) {
        nsView.syncCursor()
        nsView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator { }
}

final class DrawingCanvasView: NSView {
    private(set) var viewModel: CanvasViewModel
    private var cancellables: Set<AnyCancellable> = []
    private var trackingArea: NSTrackingArea?
    private var lastPanLocation: CGPoint?

    init(viewModel: CanvasViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        ctx.setFillColor(viewModel.backgroundColor.cgColorOrFallback)
        ctx.fill(bounds)

        ctx.saveGState()
        ctx.translateBy(x: -viewModel.offset.width * viewModel.scale, y: -viewModel.offset.height * viewModel.scale)
        ctx.scaleBy(x: viewModel.scale, y: viewModel.scale)

        for segment in viewModel.segments {
            ctx.setStrokeColor(segment.drawingColor().cgColorOrFallback)
            ctx.setLineWidth(segment.width)
            ctx.setLineCap(.round)
            ctx.beginPath()
            ctx.move(to: segment.start)
            ctx.addLine(to: segment.end)
            ctx.strokePath()
        }
        ctx.restoreGState()

        if viewModel.erasing, let location = viewModel.mouseLocation {
            ctx.saveGState()
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.45).cgColorOrFallback)
            ctx.setLineWidth(1)
            let radius = viewModel.eraserSize / 2
            let rect = CGRect(x: location.x - radius, y: location.y - radius, width: radius * 2, height: radius * 2)
            ctx.strokeEllipse(in: rect)
            ctx.restoreGState()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        handlePointerEvent(event)
    }

    override func mouseDragged(with event: NSEvent) {
        handlePointerEvent(event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let location = convert(event.locationInWindow, from: nil)
        viewModel.mouseLocation = location
        if viewModel.usingHandTool || viewModel.spacePanActive {
            viewModel.beginPanning()
            lastPanLocation = location
        }
    }

    override func mouseUp(with event: NSEvent) {
        lastPanLocation = nil
        if !viewModel.spacePanActive {
            viewModel.endPanning()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        viewModel.mouseLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        viewModel.mouseLocation = nil
        lastPanLocation = nil
        viewModel.resetLastPoint()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else {
            super.keyDown(with: event)
            return
        }
        switch characters {
        case "d":
            viewModel.toggleDrawing()
        case " ":
            if !viewModel.spacePanActive {
                viewModel.setSpacePanActive(true)
                lastPanLocation = nil
            }
        default:
            super.keyDown(with: event)
        }
        syncCursor()
        needsDisplay = true
    }

    override func keyUp(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else {
            super.keyUp(with: event)
            return
        }
        if characters == " " {
            viewModel.setSpacePanActive(false)
            lastPanLocation = nil
        } else {
            super.keyUp(with: event)
        }
        syncCursor()
        needsDisplay = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        let cursor: NSCursor
        switch viewModel.cursorStyle {
        case .arrow:
            cursor = .arrow
        case .draw:
            cursor = .crosshair
        case .eraser:
            cursor = .crosshair
        case .hand:
            cursor = viewModel.isPanning ? .closedHand : .openHand
        }
        addCursorRect(bounds, cursor: cursor)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        viewModel.updateCanvasSize(newSize)
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        window?.makeFirstResponder(self)
    }

    func setCoordinator(_ coordinator: DrawingCanvasContainer.Coordinator) {
        // Placeholder for future coordination needs.
    }

    func syncCursor() {
        window?.invalidateCursorRects(for: self)
    }

    private func setup() {
        wantsLayer = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cursorNeedsUpdate),
            name: CanvasViewModel.cursorDidChangeNotification,
            object: viewModel
        )

        viewModel.$segments
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &cancellables)

        viewModel.$backgroundColor
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &cancellables)

        viewModel.$offset
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &cancellables)

        viewModel.$scale
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &cancellables)

        viewModel.$mouseLocation
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
            .store(in: &cancellables)
    }

    @objc private func cursorNeedsUpdate() {
        syncCursor()
    }

    private func handlePointerEvent(_ event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        viewModel.mouseLocation = location

        if viewModel.isPanning {
            if let last = lastPanLocation {
                let delta = CGSize(width: location.x - last.x, height: location.y - last.y)
                viewModel.pan(by: delta)
            }
            lastPanLocation = location
            needsDisplay = true
            return
        }

        lastPanLocation = nil
        if viewModel.allowDrawing {
            let worldPoint = viewModel.worldPoint(from: location)
            if let lastPoint = viewModel.lastWorldPoint {
                if !worldPoint.isApproximatelyEqual(to: lastPoint) {
                    viewModel.addSegment(from: lastPoint, to: worldPoint)
                }
            }
            viewModel.lastWorldPoint = worldPoint
        } else {
            viewModel.resetLastPoint()
        }

        needsDisplay = true
    }
}

private extension CGPoint {
    func isApproximatelyEqual(to other: CGPoint, tolerance: CGFloat = 0.3) -> Bool {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy) < (tolerance * tolerance)
    }
}
