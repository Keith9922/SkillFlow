import SwiftUI

@main
struct AIAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSWindow?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        createFloatingWindow()
    }
    
    func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "AI Assistant")
            button.action = #selector(toggleWindow)
            button.target = self
        }
    }
    
    func createFloatingWindow() {
        let contentView = FloatingWindowView()
        
        floatingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        floatingWindow?.isOpaque = false
        floatingWindow?.backgroundColor = .clear
        floatingWindow?.level = .floating
        floatingWindow?.hasShadow = true
        floatingWindow?.contentView = NSHostingView(rootView: contentView)
        floatingWindow?.isMovableByWindowBackground = true
        floatingWindow?.center()
        floatingWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func toggleWindow() {
        if floatingWindow?.isVisible == true {
            floatingWindow?.orderOut(nil)
        } else {
            floatingWindow?.makeKeyAndOrderFront(nil)
        }
    }
}
