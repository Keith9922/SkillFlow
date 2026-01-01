//
//  ChatView.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var executionViewModel = ExecutionViewModel()
    @Environment(\.modelContext) private var modelContext
    
    @State private var isDraggingOver = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Show skill card if available
                        if let skill = viewModel.currentSkill {
                            SkillCard(skill: skill) { mode in
                                executionViewModel.executeSkill(skill, mode: mode)
                            }
                        }
                        
                        // Show detailed progress if processing
                        if viewModel.isProcessing {
                            StageProgressView(
                                stageDetails: viewModel.stageDetails,
                                currentProgress: viewModel.parseProgress
                            )
                            .padding(.horizontal)
                            .transition(.opacity)
                        }
                        
                        // Show error if present
                        if let errorMessage = viewModel.errorMessage, !viewModel.isProcessing {
                            ErrorView(
                                errorMessage: errorMessage,
                                onRetry: {
                                    viewModel.retryParsing()
                                },
                                onDismiss: {
                                    viewModel.errorMessage = nil
                                }
                            )
                            .padding(.horizontal)
                            .transition(.scale)
                        }
                        
                        // Show drag hint when dragging
                        if isDraggingOver {
                            VStack(spacing: 12) {
                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundColor(.blue)
                                
                                Text("松开以上传视频")
                                    .font(.headline)
                                
                                Text("支持 MP4, MOV, AVI 等格式")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [10]))
                            )
                            .padding()
                            .transition(.scale)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
                handleDrop(providers: providers)
            }
            
            Divider()
            
            // Input Bar
            InputBar(
                text: $viewModel.inputText,
                onSend: viewModel.sendMessage,
                onFileSelect: { url in
                    viewModel.processLocalVideo(url: url)
                },
                isProcessing: viewModel.isProcessing
            )
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
    
    // MARK: - Drag & Drop Handling
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
            DispatchQueue.main.async {
                if let urlData = urlData as? Data,
                   let path = String(data: urlData, encoding: .utf8),
                   let url = URL(string: path) {
                    
                    // Check if it's a video file
                    let videoExtensions = ["mp4", "mov", "avi", "mkv", "flv", "wmv", "m4v"]
                    let fileExtension = url.pathExtension.lowercased()
                    
                    if videoExtensions.contains(fileExtension) {
                        viewModel.processLocalVideo(url: url)
                    } else {
                        viewModel.errorMessage = "不支持的文件格式。请上传视频文件（MP4, MOV, AVI 等）"
                    }
                }
            }
        }
        
        return true
    }
}
