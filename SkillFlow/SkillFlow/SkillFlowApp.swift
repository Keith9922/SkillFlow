//
//  SkillFlowApp.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct SkillFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Hidden main window (required for menu bar app)
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
        }
        .modelContainer(appDelegate.sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 0, height: 0)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingWindow: NSWindow?
    var statusItem: NSStatusItem?
    
    // Lazy initialization for better startup performance
    lazy var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Skill.self,
            SkillStep.self,
            Message.self,
            TaskEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        registerHotKey()
        createFloatingWindow()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregisterHotKey()
    }
    
    // MARK: - Status Bar
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Use custom AppLogo from Assets
            if let logo = NSImage(named: "AppLogo") {
                logo.isTemplate = true // Makes it adapt to light/dark mode
                button.image = logo
            } else {
                // Fallback to SF Symbol if logo not found
                button.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "SkillFlow")
            }
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示/隐藏", action: #selector(toggleFloatingWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "偏好设置...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func statusBarButtonClicked() {
        toggleFloatingWindow()
    }
    
    @objc private func openPreferences() {
        // TODO: Open preferences window
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Floating Window
    
    private func createFloatingWindow() {
        let window = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        
        let contentView = FloatingWindowView()
            .modelContainer(sharedModelContainer)
        
        window.contentView = NSHostingView(rootView: contentView)
        
        centerWindow(window)
        
        self.floatingWindow = window
        window.orderFront(nil)
    }
    
    private func centerWindow(_ window: NSWindow) {
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = window.frame
            let x = screenRect.midX - windowRect.width / 2
            let y = screenRect.midY - windowRect.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    @objc private func toggleFloatingWindow() {
        guard let window = floatingWindow else { return }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // MARK: - HotKey
    
    private func registerHotKey() {
        HotKeyManager.shared.registerHotKey { [weak self] in
            self?.toggleFloatingWindow()
        }
    }
}

// MARK: - Custom Floating Panel

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}


