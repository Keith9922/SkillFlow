//
//  ChatView.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var executionViewModel = ExecutionViewModel()
    @Environment(\.modelContext) private var modelContext
    
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
                        
                        // Show progress if processing
                        if viewModel.isProcessing {
                            ProgressView(value: viewModel.parseProgress) {
                                Text("解析中...")
                                    .font(.caption)
                            }
                            .padding()
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
            
            Divider()
            
            // Input Bar
            InputBar(
                text: $viewModel.inputText,
                onSend: viewModel.sendMessage,
                isProcessing: viewModel.isProcessing
            )
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
}
