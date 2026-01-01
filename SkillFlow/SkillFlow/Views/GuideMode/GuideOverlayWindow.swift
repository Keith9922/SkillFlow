//
//  GuideOverlayWindow.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import SwiftUI
import AppKit

class GuideOverlayWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        
        let hostingView = NSHostingView(rootView: GuideOverlayView())
        self.contentView = hostingView
    }
}

struct GuideOverlayView: View {
    @StateObject private var executionViewModel = ExecutionViewModel()
    @State private var highlightRect: CGRect?
    @State private var instruction = ""
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Highlight circle
            if let rect = highlightRect {
                HighlightCircle(rect: rect)
                
                // Instruction tooltip
                VStack(spacing: 12) {
                    Text(instruction)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.8))
                        )
                    
                    // Control buttons
                    HStack(spacing: 16) {
                        if executionViewModel.canPause {
                            Button(action: {
                                executionViewModel.pauseExecution()
                            }) {
                                Label("暂停", systemImage: "pause.fill")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if executionViewModel.canResume {
                            Button(action: {
                                executionViewModel.resumeExecution()
                            }) {
                                Label("继续", systemImage: "play.fill")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if executionViewModel.canProceed {
                            Button(action: {
                                executionViewModel.proceedToNextStep()
                            }) {
                                Label("下一步", systemImage: "arrow.right")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: {
                            executionViewModel.stopExecution()
                        }) {
                            Label("停止", systemImage: "stop.fill")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .position(x: rect.midX, y: rect.maxY + 80)
            }
            
            // Progress indicator
            if executionViewModel.isExecuting {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        ProgressView(value: executionViewModel.progress)
                            .frame(width: 200)
                        
                        Text(executionViewModel.progressText)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding(.bottom, 40)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .highlightElement)) { notification in
            if let userInfo = notification.userInfo,
               let position = userInfo["position"] as? CGPoint,
               let size = userInfo["size"] as? CGSize,
               let inst = userInfo["instruction"] as? String {
                highlightRect = CGRect(origin: position, size: size)
                instruction = inst
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hideHighlight)) { _ in
            highlightRect = nil
            instruction = ""
        }
    }
}

struct HighlightCircle: View {
    let rect: CGRect
    @State private var animationAmount: CGFloat = 1
    
    var body: some View {
        ZStack {
            // Clear hole in overlay
            Rectangle()
                .fill(Color.clear)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .blendMode(.destinationOut)
            
            // Animated ring
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 3)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .scaleEffect(animationAmount)
                .opacity(2 - animationAmount)
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: animationAmount
                )
        }
        .compositingGroup()
        .onAppear {
            animationAmount = 1.3
        }
    }
}
