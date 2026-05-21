import AppKit

// Sits as the panel's contentView; captures all mouse events so drag/tap work
// regardless of what the SwiftUI subtree does with them.
final class WidgetContainerView: NSView {
    var onTap: (() -> Void)?
    // Offset from window origin to mouse click point, in screen coords.
    // Kept fixed for the lifetime of a drag so the window tracks the cursor exactly.
    private var clickOffset: CGPoint = .zero
    private var didDrag = false

    // Route every hit to self so SwiftUI subviews never see raw mouse events.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        clickOffset = CGPoint(x: mouse.x - window.frame.origin.x,
                              y: mouse.y - window.frame.origin.y)
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        didDrag = true
        let mouse = NSEvent.mouseLocation
        window.setFrameOrigin(CGPoint(x: mouse.x - clickOffset.x,
                                      y: mouse.y - clickOffset.y))
        (window as? FloatingPanel)?.savePosition()
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag { onTap?() }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class FloatingPanel: NSPanel {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
    }

    func restorePosition() {
        let defaults = UserDefaults.standard
        let x = defaults.double(forKey: "focuson.windowX")
        let y = defaults.double(forKey: "focuson.windowY")

        if x != 0 || y != 0 {
            let savedOrigin = CGPoint(x: x, y: y)
            let clampedOrigin = clampToScreen(savedOrigin)
            setFrameOrigin(clampedOrigin)
        } else {
            applyDefaultPosition()
        }
    }

    func applyDefaultPosition() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 20
        let origin = CGPoint(
            x: visibleFrame.maxX - frame.width - margin,
            y: visibleFrame.minY + margin
        )
        setFrameOrigin(origin)
    }

    func savePosition() {
        UserDefaults.standard.set(frame.origin.x, forKey: "focuson.windowX")
        UserDefaults.standard.set(frame.origin.y, forKey: "focuson.windowY")
    }

    private func clampToScreen(_ origin: CGPoint) -> CGPoint {
        let screens = NSScreen.screens
        let windowFrame = CGRect(origin: origin, size: frame.size)
        for screen in screens {
            if screen.frame.intersects(windowFrame) {
                let visible = screen.visibleFrame
                let x = max(visible.minX, min(origin.x, visible.maxX - frame.width))
                let y = max(visible.minY, min(origin.y, visible.maxY - frame.height))
                return CGPoint(x: x, y: y)
            }
        }
        // Off all screens — use default
        applyDefaultPosition()
        return frame.origin
    }

}
