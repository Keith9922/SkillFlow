//
//  APIService.swift
//  SkillFlow
//
//  后端 API 通信服务
//

import Foundation
import Combine

class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = "http://localhost:8000"
    private var webSocketTask: URLSessionWebSocketTask?
    
    @Published var isConnected = false
    
    // MARK: - HTTP Requests
    
    func analyzeVideo(videoURL: String, clientID: String) async throws -> AnalysisResponse {
        let url = URL(string: "\(baseURL)/api/analyze-video")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "video_url": videoURL,
            "client_id": clientID,
            "target_software": NSNull()
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(AnalysisResponse.self, from: data)
    }
    
    func healthCheck() async throws -> HealthResponse {
        let url = URL(string: "\(baseURL)/api/health")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }
    
    // MARK: - WebSocket
    
    func connectWebSocket(clientID: String, onProgress: @escaping (ProgressUpdate) -> Void) {
        let url = URL(string: "ws://localhost:8000/ws/progress/\(clientID)")!
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        
        receiveMessage(onProgress: onProgress)
    }
    
    private func receiveMessage(onProgress: @escaping (ProgressUpdate) -> Void) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let progress = try? JSONDecoder().decode(ProgressUpdate.self, from: data) {
                        DispatchQueue.main.async {
                            onProgress(progress)
                        }
                    }
                case .data(let data):
                    if let progress = try? JSONDecoder().decode(ProgressUpdate.self, from: data) {
                        DispatchQueue.main.async {
                            onProgress(progress)
                        }
                    }
                @unknown default:
                    break
                }
                
                // 继续接收
                self?.receiveMessage(onProgress: onProgress)
                
            case .failure(let error):
                print("WebSocket error: \(error)")
                self?.isConnected = false
            }
        }
    }
    
    func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }
}

// MARK: - Models

struct AnalysisResponse: Codable {
    let taskId: String
    let status: String
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case status
        case message
    }
}

struct HealthResponse: Codable {
    let status: String
    let qwenApi: String
    let deepseekApi: String
    
    enum CodingKeys: String, CodingKey {
        case status
        case qwenApi = "qwen_api"
        case deepseekApi = "deepseek_api"
    }
}

struct ProgressUpdate: Codable, Sendable {
    let stage: String
    let progress: Int
    let message: String
    let data: SkillData?
}

struct SkillData: Codable {
    let skillId: String
    let name: String
    let software: String
    let description: String
    let steps: [StepData]
    let totalSteps: Int
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case skillId = "skill_id"
        case name
        case software
        case description
        case steps
        case totalSteps = "total_steps"
        case tags
    }
}

struct StepData: Codable {
    let stepId: Int
    let actionType: String
    let target: TargetData
    let instruction: String
    let confidence: Double
    
    enum CodingKeys: String, CodingKey {
        case stepId = "step_id"
        case actionType = "action_type"
        case target
        case instruction
        case confidence
    }
}

struct TargetData: Codable {
    let type: String
    let name: String
    let locators: [LocatorData]
}

struct LocatorData: Codable {
    let method: String
    let value: String
    let priority: Int
}

enum APIError: Error {
    case invalidResponse
    case networkError
    case decodingError
}
