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
    var guideOverlayWindow: GuideOverlayWindow?
    var statusItem: NSStatusItem?
    
    // ModelContainer 直接在 AppDelegate 中创建
    lazy var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Skill.self,
            SkillStep.self,
            Message.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (optional - comment out if you want dock icon)
        // NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        setupStatusBar()
        
        // Setup permissions
        checkPermissions()
        
        // Register global hotkey
        HotKeyManager.shared.registerHotKey { [weak self] in
            self?.toggleFloatingWindow()
        }
        
        // Create floating window
        createFloatingWindow()
        
        // Listen for execution events
        NotificationCenter.default.addObserver(
            forName: .highlightElement,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showGuideOverlay()
        }
        
        NotificationCenter.default.addObserver(
            forName: .hideHighlight,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.hideGuideOverlay()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregisterHotKey()
    }
    
    // MARK: - Status Bar
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "SkillFlow")
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
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        
        // 使用自己的 ModelContainer
        let contentView = FloatingWindowView()
            .modelContainer(sharedModelContainer)
        
        window.contentView = NSHostingView(rootView: contentView)
        
        // Center window
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = window.frame
            let x = screenRect.midX - windowRect.width / 2
            let y = screenRect.midY - windowRect.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.floatingWindow = window
        
        // Show window initially
        window.orderFront(nil)
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
    
    // MARK: - Guide Overlay
    
    private func showGuideOverlay() {
        if guideOverlayWindow == nil {
            guideOverlayWindow = GuideOverlayWindow()
        }
        
        guideOverlayWindow?.makeKeyAndOrderFront(nil)
    }
    
    private func hideGuideOverlay() {
        guideOverlayWindow?.orderOut(nil)
    }
    
    // MARK: - Permissions
    
    private func checkPermissions() {
        let permissionManager = PermissionManager.shared
        
        if !permissionManager.allPermissionsGranted() {
            // Show permission request alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showPermissionAlert()
            }
        }
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要权限"
        alert.informativeText = "SkillFlow 需要辅助功能和屏幕录制权限才能正常工作。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "稍后")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            PermissionManager.shared.requestAccessibilityPermission()
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


