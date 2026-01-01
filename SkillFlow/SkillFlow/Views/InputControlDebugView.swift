//
//  InputControlDebugView.swift
//  SkillFlow
//
//  Created by SkillFlow Input Control on 2026/1/2.
//

import SwiftUI

struct InputControlDebugView: View {
    @State private var context: InputContext?
    @State private var timer: Timer?
    @State private var isMonitoring = false
    @State private var statusMessage = "Ready"
    @State private var smoothX: String = "500"
    @State private var smoothY: String = "500"
    @State private var smoothDuration: String = "1000"
    
    private let service = InputControlService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Input Control Debugger")
                    .font(.title)
                    .bold()
                
                // Context Display
                GroupBox(label: Text("Current Context")) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let ctx = context {
                            HStack {
                                Text("Active Window:")
                                    .bold()
                                Text(ctx.activeWindowTitle)
                            }
                            HStack {
                                Text("Mouse Position:")
                                    .bold()
                                Text("(\(Int(ctx.mousePosition.x)), \(Int(ctx.mousePosition.y)))")
                            }
                            Text("Timestamp: \(ctx.timestamp.formatted(date: .omitted, time: .standard))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("No context data available")
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                
                // Monitoring Toggle
                Toggle("Enable Real-time Monitoring", isOn: $isMonitoring)
                    .onChange(of: isMonitoring) { newValue in
                        if newValue {
                            startMonitoring()
                        } else {
                            stopMonitoring()
                        }
                    }
                
                Divider()
                
                // Smooth Move Test
                GroupBox(label: Text("Smooth Move Test")) {
                    VStack(spacing: 10) {
                        HStack {
                            TextField("X", text: $smoothX)
                                .textFieldStyle(.roundedBorder)
                            TextField("Y", text: $smoothY)
                                .textFieldStyle(.roundedBorder)
                            TextField("Duration (ms)", text: $smoothDuration)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Button(action: {
                            Task {
                                guard let x = Double(smoothX),
                                      let y = Double(smoothY),
                                      let duration = Int(smoothDuration) else {
                                    updateStatus("Invalid input for smooth move")
                                    return
                                }
                                
                                updateStatus("Starting smooth move to (\(x), \(y)) in \(duration)ms")
                                await service.smooth_move_mouse(x: x, y: y, durationMs: duration)
                                updateStatus("Smooth move completed")
                            }
                        }) {
                            Text("Execute Smooth Move")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                
                // Actions
                GroupBox(label: Text("Test Actions")) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        
                        Button("Move Mouse Center") {
                            Task {
                                if let screen = NSScreen.main {
                                    let center = CGPoint(x: screen.frame.width / 2, y: screen.frame.height / 2)
                                    await service.move_mouse(x: center.x, y: center.y)
                                    updateStatus("Moved mouse to center")
                                }
                            }
                        }
                        
                        Button("Click (Left)") {
                            Task {
                                await service.mouse_down(button: .left)
                                await service.mouse_up(button: .left)
                                updateStatus("Clicked Left")
                            }
                        }
                        
                        Button("Type 'Hello'") {
                            Task {
                                updateStatus("Typing 'Hello'...")
                                // H
                                await service.key_press(key: .h)
                                await service.key_release(key: .h)
                                await service.delay(50)
                                // E
                                await service.key_press(key: .e)
                                await service.key_release(key: .e)
                                await service.delay(50)
                                // L
                                await service.key_press(key: .l)
                                await service.key_release(key: .l)
                                await service.delay(50)
                                // L
                                await service.key_press(key: .l)
                                await service.key_release(key: .l)
                                await service.delay(50)
                                // O
                                await service.key_press(key: .o)
                                await service.key_release(key: .o)
                                updateStatus("Finished typing")
                            }
                        }
                        
                        Button("Superimpose Test (Shift+Click)") {
                            Task {
                                updateStatus("Holding Shift...")
                                await service.key_press(key: .shift)
                                await service.delay(500)
                                updateStatus("Clicking...")
                                await service.mouse_down(button: .left)
                                await service.mouse_up(button: .left)
                                await service.delay(500)
                                updateStatus("Releasing Shift...")
                                await service.key_release(key: .shift)
                                updateStatus("Done")
                            }
                        }
                        
                        Button("Release All") {
                            Task {
                                await service.all_release()
                                updateStatus("Released all keys/buttons")
                            }
                        }
                    }
                    .padding()
                }
                
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .padding(.top)
            }
            .padding()
        }
        .frame(width: 400, height: 700)
        .onAppear {
            // Fetch initial state
            refreshContext()
        }
        .onDisappear {
            stopMonitoring()
        }
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            refreshContext()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func refreshContext() {
        Task {
            let newContext = await service.getCurrentContext()
            await MainActor.run {
                self.context = newContext
            }
        }
    }
    
    private func updateStatus(_ msg: String) {
        statusMessage = "\(Date().formatted(date: .omitted, time: .standard)): \(msg)"
    }
}

#Preview {
    InputControlDebugView()
}
