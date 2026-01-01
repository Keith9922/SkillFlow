//
//  TaskDetailView.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import SwiftUI

struct TaskDetailView: View {
    let entryId: String
    @ObservedObject var viewModel: TaskListViewModel
    
    @State private var taskDetail: TaskDetail?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView("加载任务详情...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail = taskDetail {
                    // Task ID
                    VStack(alignment: .leading, spacing: 8) {
                        Text("任务 ID")
                            .font(.headline)
                        Text(detail.entryId)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    }
                    
                    // Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("状态")
                            .font(.headline)
                        StatusBadge(status: detail.status)
                    }
                    
                    // Content based on status
                    switch detail.status {
                    case .processing, .audioDone, .videoDone:
                        ProcessingContent(detail: detail)
                        
                    case .finished:
                        if let skill = detail.skill {
                            FinishedContent(skill: skill, detail: detail)
                        }
                        
                    case .failed:
                        FailedContent(detail: detail)
                    }
                    
                } else {
                    ContentUnavailableView(
                        "无法加载任务详情",
                        systemImage: "exclamationmark.triangle",
                        description: Text("请稍后重试")
                    )
                }
            }
            .padding()
        }
        .navigationTitle("任务详情")
        .task {
            await loadDetail()
        }
    }
    
    private func loadDetail() async {
        isLoading = true
        taskDetail = await viewModel.loadTaskDetails(entryId: entryId)
        isLoading = false
    }
}

struct StatusBadge: View {
    let status: TaskStatus
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
            Text(statusText)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
    
    private var iconName: String {
        switch status {
        case .processing: return "hourglass"
        case .audioDone: return "waveform"
        case .videoDone: return "video"
        case .finished: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }
    
    private var statusText: String {
        switch status {
        case .processing: return "处理中"
        case .audioDone: return "音频完成"
        case .videoDone: return "视频完成"
        case .finished: return "已完成"
        case .failed: return "失败"
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .processing: return .blue
        case .audioDone: return .cyan
        case .videoDone: return .purple
        case .finished: return .green
        case .failed: return .red
        }
    }
}

struct ProcessingContent: View {
    let detail: TaskDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let transcript = detail.transcriptText {
                VStack(alignment: .leading, spacing: 8) {
                    Text("音频转录")
                        .font(.headline)
                    Text(transcript)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }
            
            if let videoAnalysis = detail.videoAnalysis {
                VStack(alignment: .leading, spacing: 8) {
                    Text("视频分析")
                        .font(.headline)
                    Text("软件: \(videoAnalysis.software)")
                        .font(.body)
                    Text("检测到 \(videoAnalysis.frames.count) 个关键帧")
                        .font(.body)
                    Text("识别到 \(videoAnalysis.operations.count) 个操作")
                        .font(.body)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            Text("任务正在处理中，请稍后刷新查看结果")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct FinishedContent: View {
    let skill: Skill
    let detail: TaskDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Skill info
            VStack(alignment: .leading, spacing: 8) {
                Text("生成的技能")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(skill.software)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.body)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            // Steps
            VStack(alignment: .leading, spacing: 8) {
                Text("操作步骤 (\(skill.steps.count))")
                    .font(.headline)
                
                ForEach(Array(skill.steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.blue)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.instruction)
                                .font(.body)
                            
                            HStack {
                                Text(step.actionType)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                                
                                Text(step.targetName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            // Transcript
            if let transcript = detail.transcriptText {
                VStack(alignment: .leading, spacing: 8) {
                    Text("原始转录")
                        .font(.headline)
                    
                    DisclosureGroup("查看完整转录") {
                        Text(transcript)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct FailedContent: View {
    let detail: TaskDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("任务处理失败")
                        .font(.headline)
                    
                    if let errorMessage = detail.errorMessage {
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            
            if let transcript = detail.transcriptText {
                VStack(alignment: .leading, spacing: 8) {
                    Text("已完成的音频转录")
                        .font(.headline)
                    Text(transcript)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TaskDetailView(
            entryId: "test-entry-id-123",
            viewModel: TaskListViewModel()
        )
    }
}
