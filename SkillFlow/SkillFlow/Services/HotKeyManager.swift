//
//  HotKeyManager.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation
import AppKit
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var onToggle: (() -> Void)?
    
    private init() {}
    
    // MARK: - Register HotKey
    
    func registerHotKey(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        
        // ⌘ + Shift + Space
        let keyCode: UInt32 = 49 // Space key
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("SKFL".fourCharCodeValue)
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onToggle?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}

// MARK: - String Extension

extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        if let data = self.data(using: .macOSRoman), data.count == 4 {
            data.withUnsafeBytes { bytes in
                result = bytes.load(as: FourCharCode.self)
            }
        }
        return result
    }
}
