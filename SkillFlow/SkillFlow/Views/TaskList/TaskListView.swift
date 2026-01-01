//
//  TaskListView.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import SwiftUI

struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
    @State private var selectedTaskId: String?
    
    var body: some View {
        NavigationSplitView {
            // Task list
            List(selection: $selectedTaskId) {
                ForEach(viewModel.tasks) { task in
                    TaskListRow(task: task)
                        .tag(task.entryId)
                }
            }
            .navigationTitle("任务列表")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: viewModel.refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    ProgressView("加载中...")
                }
            }
            .overlay {
                if !viewModel.isLoading && viewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "暂无任务",
                        systemImage: "tray",
                        description: Text("解析视频后任务会显示在这里")
                    )
                }
            }
            .refreshable {
                await viewModel.loadTasks()
            }
            
        } detail: {
            // Task detail
            if let taskId = selectedTaskId {
                TaskDetailView(entryId: taskId, viewModel: viewModel)
            } else {
                ContentUnavailableView(
                    "选择一个任务",
                    systemImage: "sidebar.left",
                    description: Text("从左侧列表选择任务查看详情")
                )
            }
        }
        .task {
            await viewModel.loadTasks()
        }
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

struct TaskListRow: View {
    let task: TaskSummary
    
    var body: some View {
        HStack {
            // Status icon
            statusIcon
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.entryId)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .created:
            Image(systemName: "doc.badge.plus")
                .foregroundColor(.gray)
        case .processing:
            ProgressView()
                .scaleEffect(0.8)
        case .audioDone:
            Image(systemName: "waveform.circle.fill")
                .foregroundColor(.blue)
        case .videoDone:
            Image(systemName: "video.circle.fill")
                .foregroundColor(.purple)
        case .finished:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }
    
    private var statusText: String {
        switch task.status {
        case .created:
            return "已创建"
        case .processing:
            return "处理中"
        case .audioDone:
            return "音频完成"
        case .videoDone:
            return "视频完成"
        case .finished:
            return "已完成"
        case .failed:
            return "失败"
        }
    }
}

#Preview {
    TaskListView()
        .frame(width: 800, height: 600)
}
