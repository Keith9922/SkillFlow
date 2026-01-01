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
                        
                        // Show detailed progress if processing VIDEO (not just regular chat)
                        // Use a simple check: if stageDetails has any "inProgress" other than idle, and it's video related
                        if viewModel.isProcessing && viewModel.currentStage != .idle {
                            StageProgressView(
                                stageDetails: viewModel.stageDetails,
                                currentProgress: viewModel.parseProgress
                            )
                            .padding(.horizontal)
                            .transition(.opacity)
                        } else if viewModel.isProcessing {
                            // Simple loading indicator for chat processing
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("思考中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
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
        
        // 优先尝试直接加载 URL 对象，这样能更好地保留沙盒权限信息
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                DispatchQueue.main.async {
                    if let url = url {
                        self.validateAndProcess(url: url)
                    } else if let error = error {
                        print("Drop error: \(error.localizedDescription)")
                        self.viewModel.errorMessage = "无法读取文件: \(error.localizedDescription)"
                    }
                }
            }
            return true
        }
        
        // 降级方案：尝试加载 file-url 数据
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
            DispatchQueue.main.async {
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    self.validateAndProcess(url: url)
                } else if let url = item as? URL {
                    self.validateAndProcess(url: url)
                } else {
                    print("Drop failed to load URL")
                }
            }
        }
        
        return true
    }
    
    private func validateAndProcess(url: URL) {
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
