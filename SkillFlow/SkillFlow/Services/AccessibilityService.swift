//
//  AccessibilityService.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation
import AppKit
import ApplicationServices

class AccessibilityService {
    static let shared = AccessibilityService()
    
    private init() {}
    
    // MARK: - Find Element
    
    func findElement(
        in app: NSRunningApplication,
        matching locators: [String: Any]
    ) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // Try different locator strategies
        if let axPath = locators["ax_path"] as? String {
            if let element = findByAccessibilityPath(appElement, path: axPath) {
                return element
            }
        }
        
        if let text = locators["text"] as? String {
            if let element = findByText(appElement, text: text) {
                return element
            }
        }
        
        if let position = locators["position_desc"] as? String {
            if let element = findByPositionDescription(appElement, description: position) {
                return element
            }
        }
        
        return nil
    }
    
    private func findByAccessibilityPath(_ root: AXUIElement, path: String) -> AXUIElement? {
        let components = path.split(separator: "/").map(String.init)
        var current = root
        
        for component in components {
            guard let next = findChildByRole(current, role: component) else {
                return nil
            }
            current = next
        }
        
        return current
    }
    
    private func findChildByRole(_ element: AXUIElement, role: String) -> AXUIElement? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let childArray = children as? [AXUIElement] else {
            return nil
        }
        
        for child in childArray {
            var roleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)
            
            if let childRole = roleValue as? String, childRole.contains(role) {
                return child
            }
            
            // Recursive search
            if let found = findChildByRole(child, role: role) {
                return found
            }
        }
        
        return nil
    }
    
    private func findByText(_ root: AXUIElement, text: String) -> AXUIElement? {
        return findElementRecursive(root) { element in
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
            
            if let title = titleValue as? String, title.contains(text) {
                return true
            }
            
            var descValue: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descValue)
            
            if let desc = descValue as? String, desc.contains(text) {
                return true
            }
            
            return false
        }
    }
    
    private func findByPositionDescription(_ root: AXUIElement, description: String) -> AXUIElement? {
        // Simplified position matching - can be enhanced
        return findElementRecursive(root) { element in
            var posValue: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
            
            if let position = posValue as? CGPoint {
                // Match based on description like "top-left", "center", etc.
                return matchesPositionDescription(position, description: description)
            }
            
            return false
        }
    }
    
    private func findElementRecursive(_ element: AXUIElement, matching predicate: (AXUIElement) -> Bool) -> AXUIElement? {
        if predicate(element) {
            return element
        }
        
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let childArray = children as? [AXUIElement] else {
            return nil
        }
        
        for child in childArray {
            if let found = findElementRecursive(child, matching: predicate) {
                return found
            }
        }
        
        return nil
    }
    
    private func matchesPositionDescription(_ position: CGPoint, description: String) -> Bool {
        // Simplified matching - can be enhanced with screen bounds
        let desc = description.lowercased()
        
        if desc.contains("top") && position.y < 200 {
            return true
        }
        if desc.contains("bottom") && position.y > 600 {
            return true
        }
        if desc.contains("left") && position.x < 200 {
            return true
        }
        if desc.contains("right") && position.x > 600 {
            return true
        }
        
        return false
    }
    
    // MARK: - Perform Actions
    
    func click(element: AXUIElement) -> Bool {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        return result == .success
    }
    
    func input(element: AXUIElement, text: String) -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        return result == .success
    }
    
    func getPosition(element: AXUIElement) -> CGPoint? {
        var posValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
        
        guard result == .success else { return nil }
        return posValue as? CGPoint
    }
    
    func getSize(element: AXUIElement) -> CGSize? {
        var sizeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        
        guard result == .success else { return nil }
        return sizeValue as? CGSize
    }
    
    // MARK: - App Management
    
    func launchApp(bundleIdentifier: String) -> NSRunningApplication? {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            app.activate()
            return app
        }
        
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            
            var launchedApp: NSRunningApplication?
            let semaphore = DispatchSemaphore(value: 0)
            
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
                if let error = error {
                    print("Failed to launch app: \(error)")
                } else {
                    launchedApp = app
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            return launchedApp
        }
        
        return nil
    }
    
    func getRunningApp(bundleIdentifier: String) -> NSRunningApplication? {
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
    }
}
