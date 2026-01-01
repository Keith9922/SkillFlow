//
//  TaskListViewModel.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class TaskListViewModel: ObservableObject {
    @Published var tasks: [TaskSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTask: TaskSummary?
    
    private let apiService: SEEDOAPIService
    private let dataConverter: DataConverter
    
    init(apiService: SEEDOAPIService? = nil, dataConverter: DataConverter? = nil) {
        let tokenManager = TokenManager.shared
        self.apiService = apiService ?? SEEDOAPIService(
            baseURL: "https://api.seedo.example.com",
            tokenManager: tokenManager
        )
        self.dataConverter = dataConverter ?? DataConverter()
    }
    
    // MARK: - Load Tasks
    
    func loadTasks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.listTasks()
            tasks = response.tasks
            isLoading = false
        } catch {
            isLoading = false
            if let seedoError = error as? SEEDOError {
                errorMessage = seedoError.localizedDescription
            } else {
                errorMessage = "加载任务列表失败: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Task Details
    
    func loadTaskDetails(entryId: String) async -> TaskDetail? {
        do {
            let status = try await apiService.getTaskStatus(entryId: entryId)
            
            var taskDetail = TaskDetail(
                entryId: entryId,
                status: status,
                transcriptText: nil,
                videoAnalysis: nil,
                skill: nil,
                errorMessage: nil
            )
            
            // Load artifacts based on status
            if status == .audioDone || status == .videoDone || status == .finished {
                if let audioArtifact = try? await apiService.getArtifact(entryId: entryId, track: .audio) {
                    taskDetail.transcriptText = audioArtifact.data as? String
                }
            }
            
            if status == .videoDone || status == .finished {
                if let videoArtifact = try? await apiService.getArtifact(entryId: entryId, track: .video) {
                    taskDetail.videoAnalysis = try? dataConverter.convertVideoAnalysis(from: videoArtifact.data)
                }
            }
            
            if status == .finished {
                if let stepsArtifact = try? await apiService.getArtifact(entryId: entryId, track: .steps) {
                    taskDetail.skill = try? dataConverter.convertSkill(from: stepsArtifact.data)
                }
            }
            
            if status == .failed {
                // Try to get error message from status response
                taskDetail.errorMessage = "任务处理失败"
            }
            
            return taskDetail
            
        } catch {
            errorMessage = "加载任务详情失败: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Refresh
    
    func refresh() {
        Task {
            await loadTasks()
        }
    }
}

// MARK: - Task Detail Model

struct TaskDetail {
    let entryId: String
    let status: TaskStatus
    var transcriptText: String?
    var videoAnalysis: VideoAnalysisData?
    var skill: Skill?
    var errorMessage: String?
}
