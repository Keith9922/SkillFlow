//
//  PermissionManager.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation
import AppKit
import ApplicationServices
import Combine

class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var hasAccessibilityPermission = false
    @Published var hasScreenRecordingPermission = false
    
    private init() {
        checkPermissions()
    }
    
    // MARK: - Check Permissions
    
    func checkPermissions() {
        hasAccessibilityPermission = checkAccessibilityPermission()
        hasScreenRecordingPermission = checkScreenRecordingPermission()
    }
    
    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func checkScreenRecordingPermission() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return !windows.isEmpty
    }
    
    // MARK: - Request Permissions
    
    func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
        
        // Check again after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkPermissions()
        }
    }
    
    func openSystemPreferences(for permission: PermissionType) {
        switch permission {
        case .accessibility:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        case .screenRecording:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func allPermissionsGranted() -> Bool {
        return hasAccessibilityPermission && hasScreenRecordingPermission
    }
}

enum PermissionType {
    case accessibility
    case screenRecording
}
