//
//  TaskListViewModel.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class TaskListViewModel: ObservableObject {
    @Published var tasks: [TaskSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTask: TaskSummary?
    
    // MARK: - Initialization
    
    init() {
    }
    
    // MARK: - Load Tasks
    
    func loadTasks() async {
        isLoading = true
        errorMessage = nil
        
        // Mock loading
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Return empty or dummy list
        tasks = [] 
        isLoading = false
    }
    
    // MARK: - Task Details
    
    func loadTaskDetails(entryId: String) async -> TaskDetail? {
        // Mock implementation
        return TaskDetail(
            entryId: entryId,
            status: .finished,
            transcriptText: "Mock Transcript",
            videoAnalysis: nil,
            skill: nil,
            errorMessage: nil
        )
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

// Define TaskSummary here since it was likely in a deleted service file
struct TaskSummary: Identifiable, Codable {
    let id: String
    let status: TaskStatus
    let createdAt: Date
    let errorMessage: String?
    
    var entryId: String { id }
}
