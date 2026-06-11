import AppKit
import SwiftUI

private final class QuickEntryWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class QuickEntryManager: NSObject {
    private var window: NSWindow?
    private var hotKey: GlobalHotKey?
    private let db: ALMSDatabase

    init(db: ALMSDatabase) {
        self.db = db
        super.init()
    }

    func setup() {
        guard hotKey == nil else { return }
        GlobalHotKey.onFire = { [weak self] in
            DispatchQueue.main.async { self?.toggle() }
        }
        hotKey = GlobalHotKey()
    }

    private func toggle() {
        if let w = window, w.isVisible {
            hide()
        } else {
            show()
        }
    }

    private func show() {
        if window == nil { buildWindow() }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func buildWindow() {
        let view = QuickEntryView(db: db) { [weak self] in
            DispatchQueue.main.async { self?.hide() }
        }
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 520, height: 68)

        let w = QuickEntryWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 68),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.level = .floating
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.contentView = hosting
        w.isReleasedWhenClosed = false
        w.delegate = self
        self.window = w
    }
}

extension QuickEntryManager: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
